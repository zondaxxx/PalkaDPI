package io.github.romanvht.byedpi.palka

import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import io.github.romanvht.byedpi.R
import io.github.romanvht.byedpi.core.ByeDpiProxy
import io.github.romanvht.byedpi.core.ByeDpiProxyCmdPreferences
import io.github.romanvht.byedpi.data.AppStatus
import io.github.romanvht.byedpi.services.appStatus
import io.github.romanvht.byedpi.utility.shellSplit
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.net.InetSocketAddress
import java.net.Socket

data class PalkaStrategyScore(
    val id: String,
    val name: String,
    val succeededServices: Int,
    val totalServices: Int,
    val medianLatencyMs: Int?,
    val score: Int,
    val stalledServices: Int = 0,
    val bulkKbps: Int? = null,
    val coreFailed: Boolean = false
)

data class PalkaRecoverySuggestion(val id: String, val name: String, val template: List<String>)

data class PalkaCandidate(val id: String, val name: String, val template: List<String>, val extended: Boolean = false)

/**
 * In-process ByeDPI core on its own port, used to test strategies without
 * touching the VPN. The native core is a single global instance (native-lib.c),
 * so nothing else may run it at the same time: the VPN/proxy services call
 * [PalkaAutomation.claimCoreForService] before starting theirs.
 */
private class PalkaTestCore(private val port: Int) {
    private val proxy = ByeDpiProxy()
    @Volatile private var finished = false
    private var thread: Thread? = null

    fun start(args: List<String>): Boolean {
        val argv = arrayOf("ciadpi", "--ip", "127.0.0.1", "--port", port.toString()) + args
        finished = false
        val worker = Thread({
            runCatching { proxy.startProxy(ByeDpiProxyCmdPreferences(argv)) }
                .onFailure { Log.w("PalkaTestCore", "core crashed", it) }
            finished = true
        }, "palka-test-core").apply { isDaemon = true; start() }
        synchronized(this) { thread = worker }
        // Wait until the listener accepts connections, or the core exits on bad args.
        val deadline = System.currentTimeMillis() + 3_000
        while (System.currentTimeMillis() < deadline && !finished) {
            val ok = runCatching {
                Socket().use { it.connect(InetSocketAddress("127.0.0.1", port), 200) }
            }.isSuccess
            if (ok) return true
            Thread.sleep(80)
        }
        return false
    }

    /**
     * Stops only the core this object started. When our core already exited
     * (bad arguments, or the global core was busy) jniStopProxy would shut down
     * whichever core currently owns the listener, so it is not called.
     */
    @Synchronized
    fun stop() {
        val worker = thread ?: return
        thread = null
        if (!worker.isAlive) return
        runCatching { proxy.stopProxy() }
        worker.join(2_000)
        if (worker.isAlive) {
            runCatching { proxy.jniForceClose() }
            worker.join(1_000)
        }
    }
}

/**
 * Automatic setup, the Android port of StrategyAutomationManager. Unlike iOS
 * there is no separate tunnel confirmation: the VPN hands every packet to the
 * same SOCKS core, so a probe through the core on a side port is the real test.
 */
object PalkaAutomation {
    private const val TEST_PORT = 10801
    private const val STRATEGY_DEADLINE_MS = 30_000L
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private var job: Job? = null
    private var failureStreak = 0
    @Volatile private var currentCore: PalkaTestCore? = null
    /** True while candidates run on the in-process core; the services must not start theirs. */
    @Volatile var isScreening = false
        private set
    /** A service claimed the core: it is starting the VPN/proxy itself, so do not reconnect. */
    @Volatile private var claimedByService = false

    var isRunning by mutableStateOf(false); private set
    var currentStrategyName by mutableStateOf(""); private set
    var currentStage by mutableStateOf(""); private set
    var completed by mutableStateOf(0); private set
    var total by mutableStateOf(0); private set
    var bestStrategyName by mutableStateOf<String?>(null); private set
    var errorText by mutableStateOf<String?>(null); private set
    /** Strategies that opened services / strategies checked; formatted by the screen. */
    var summary by mutableStateOf<Pair<Int, Int>?>(null); private set
    /** The error is "catalog not loaded yet"; the screen hides it once the catalog arrives. */
    var errorNeedsCatalog by mutableStateOf(false); private set
    var recoverySuggestion by mutableStateOf<PalkaRecoverySuggestion?>(null); private set
    val scores = mutableStateListOf<PalkaStrategyScore>()
    val logLines = mutableStateListOf<String>()

    /** Set by the visible activity: launches the system VPN consent dialog. */
    var launchVpnConsent: ((android.content.Intent) -> Unit)? = null
    /** Pending consent request; completed by whichever activity instance receives the result. */
    @Volatile var pendingConsent: kotlinx.coroutines.CompletableDeferred<Boolean>? = null

    private fun str(id: Int, vararg args: Any) = Palka.str(id, *args)

    fun extendedCandidates(): List<PalkaCandidate> = runCatching {
        Palka.context.assets.open("proxytest_strategies.list").bufferedReader().readLines()
    }.getOrDefault(emptyList())
        .map { it.trim().replace("{sni}", "google.com") }
        .filter { it.isNotEmpty() }
        .mapIndexed { index, line ->
            PalkaCandidate(
                "ext:" + line.hashCode().toUInt().toString(16),
                str(R.string.palka_extended_name, index + 1),
                shellSplit(line),
                extended = true
            )
        }

    fun start() {
        if (isRunning) return
        isRunning = true
        claimedByService = false
        errorText = null
        errorNeedsCatalog = false
        bestStrategyName = null
        summary = null
        completed = 0
        total = 0
        scores.clear()
        logLines.clear()
        PalkaAutomationService.start(Palka.context)
        job = scope.launch {
            try {
                run()
            } finally {
                isScreening = false
                isRunning = false
                currentStage = ""
                PalkaAutomationService.stop(Palka.context)
            }
        }
    }

    fun cancel() {
        val running = job ?: return
        if (!running.isActive) return
        log("cancelled")
        running.cancel()
        // Blocking probes cannot be interrupted; killing the core makes them fail fast.
        currentCore?.let { core -> Thread { core.stop() }.start() }
    }

    /**
     * Called by the VPN and proxy services before they start the shared native
     * core (connect button, quick tile, boot, always-on). A user-initiated start
     * wins: the automation run is cancelled and its test core released.
     */
    suspend fun claimCoreForService() {
        if (!isScreening) return
        claimedByService = true
        withContext(Dispatchers.Main) { cancel() }
        val deadline = System.currentTimeMillis() + 8_000
        while (isScreening && System.currentTimeMillis() < deadline) delay(100)
    }

    private suspend fun loadCatalogIfNeeded(): Boolean {
        PalkaCatalog.loadCache()
        if (PalkaCatalog.strategies.isNotEmpty()) return true
        currentStage = str(R.string.palka_catalog_loading)
        PalkaCatalog.load()
        // Two sequential downloads with 10 s connect + 10 s read timeouts each.
        val deadline = System.currentTimeMillis() + 45_000
        while (PalkaCatalog.isLoading && System.currentTimeMillis() < deadline) delay(200)
        return PalkaCatalog.strategies.isNotEmpty()
    }

    private suspend fun run() {
        // From here until screening ends a user-started VPN/proxy wins (claimCoreForService).
        isScreening = true
        if (!loadCatalogIfNeeded()) {
            errorText = PalkaCatalog.errorText ?: str(R.string.palka_auto_catalog_needed)
            errorNeedsCatalog = true
            return
        }
        val candidates = PalkaCatalog.strategies
            .map { PalkaCandidate(it.id, it.displayName, it.commandArgs) }
            .sortedByDescending { Palka.isFavorite(it.id) } +
            (if (Palka.extendedSearch) extendedCandidates() else emptyList())
        total = candidates.size
        log("start: ${candidates.size} strategies, services ${Palka.selectedServiceIds.joinToString(",")}")

        val previous = Palka.snapshotActive()
        Palka.syncStatus()
        val reconnectOnFailure = Palka.vpnRunning
        var committed = false
        try {
            currentStage = str(R.string.palka_auto_stopping_vpn)
            if (Palka.vpnRunning) {
                Palka.stop()
                val stopped = waitForStatus(AppStatus.Halted, 12_000)
                log(if (stopped) "VPN stopped" else "VPN did not stop in 12 s")
                if (!stopped) {
                    errorText = str(R.string.palka_vpn_disconnect_timeout)
                    return
                }
            }
            val targets = PalkaServices.diagnosticTargets(Palka.selectedServiceIds, Palka.customDomains)
            val core = PalkaTestCore(TEST_PORT)
            currentCore = core
            for ((index, candidate) in candidates.withIndex()) {
                if (appStatus.first == AppStatus.Running) {
                    // Something started the VPN/proxy in between (tile, boot, always-on): let it win.
                    claimedByService = true
                    log("service started elsewhere, stopping the search")
                    throw CancellationException("service took the core")
                }
                currentStrategyName = candidate.name
                currentStage = str(R.string.palka_auto_screening)
                val results = withContext(Dispatchers.IO) { screen(core, candidate, targets) }
                if (results == null) {
                    log("${candidate.name}: " + str(R.string.palka_auto_core_failed))
                    scores.add(PalkaStrategyScore(candidate.id, candidate.name, 0, targets.size, null, Int.MAX_VALUE, coreFailed = true))
                } else {
                    appendScore(candidate, results, targets.size)
                }
                completed = index + 1
            }
            currentCore = null
            isScreening = false

            val passed = scores.count { it.succeededServices > 0 }
            summary = passed to scores.size
            val best = scores.sortedWith(
                compareByDescending<PalkaStrategyScore> { it.succeededServices }
                    .thenBy { it.score }
                    .thenByDescending { it.bulkKbps ?: 0 }
            ).firstOrNull()
            val strategy = best?.takeIf { it.succeededServices > 0 }?.let { b -> candidates.firstOrNull { it.id == b.id } }
            if (strategy == null) {
                log("no working strategy; restoring previous")
                Palka.restoreActive(previous)
                errorText = str(R.string.palka_auto_no_working_strategy)
                if (reconnectOnFailure) connect()
                return
            }
            log("best: ${strategy.name} (${best.succeededServices}/${best.totalServices})")
            committed = true
            if (strategy.extended) {
                Palka.recordResult(strategy.id, strategy.name, strategy.template, true, best.medianLatencyMs)
            }
            Palka.applyStrategy(strategy.id, strategy.name, strategy.template)
            Palka.saveCurrentStrategy()
            bestStrategyName = strategy.name
            currentStrategyName = strategy.name
            if (connect()) log("connected with ${strategy.name}")
        } catch (e: CancellationException) {
            withContext(NonCancellable) {
                withContext(Dispatchers.IO) { currentCore?.stop() }
                currentCore = null
                isScreening = false
                // Once the winner is applied and saved, cancelling only stops the connect step.
                if (!committed) {
                    Palka.restoreActive(previous)
                    errorText = str(R.string.palka_auto_cancelled)
                }
                if (reconnectOnFailure && !committed && !claimedByService) {
                    // Cancelled while our own stop was still running: let it finish, then reconnect.
                    waitForStatus(AppStatus.Halted, 12_000)
                    if (appStatus.first != AppStatus.Running) connect()
                }
            }
            throw e
        }
    }

    /** One candidate on the side-port core; null when the core did not come up. */
    private suspend fun screen(core: PalkaTestCore, candidate: PalkaCandidate, targets: List<PalkaService>): List<PalkaServiceProbe>? {
        val args = Palka.resolve(candidate.template)
        return try {
            withTimeoutOrNull(STRATEGY_DEADLINE_MS) {
                if (!core.start(args)) return@withTimeoutOrNull null
                // Quick pass first: a strategy that opens nothing is not worth a bulk download.
                val quick = PalkaProbe.probe(targets, TEST_PORT, 1, includeBulk = false, timings = false, smallTimeoutMs = 5_000)
                val passed = quick.filter { it.status != PalkaProbeStatus.Unavailable }.map { it.id }.toSet()
                if (passed.isEmpty()) quick
                else {
                    val full = PalkaProbe.probe(
                        targets.filter { it.id in passed }, TEST_PORT, 1,
                        includeBulk = true, timings = false, smallTimeoutMs = 5_000, bulkTimeoutMs = 10_000
                    )
                    quick.map { q -> full.firstOrNull { it.id == q.id } ?: q }
                }
            }
        } finally {
            core.stop()
        }
    }

    private suspend fun connect(): Boolean {
        currentStage = str(R.string.palka_auto_connecting_vpn)
        val consent = Palka.vpnConsentIntent()
        if (consent != null) {
            val launcher = launchVpnConsent
            val granted = if (launcher == null) false else {
                val deferred = kotlinx.coroutines.CompletableDeferred<Boolean>()
                pendingConsent?.complete(false)
                pendingConsent = deferred
                launcher(consent)
                // Never wait forever: a dismissed or lost dialog counts as "no".
                withTimeoutOrNull(120_000) { deferred.await() } ?: false
            }
            pendingConsent = null
            if (!granted) {
                errorText = str(R.string.palka_auto_vpn_permission)
                log("VPN consent not granted")
                return false
            }
        }
        Palka.start()
        val ok = waitForStatus(AppStatus.Running, 20_000)
        if (!ok) {
            errorText = str(R.string.palka_vpn_connect_timeout)
            log("final connect failed")
        }
        return ok
    }

    private suspend fun waitForStatus(status: AppStatus, timeoutMs: Long): Boolean {
        val deadline = System.currentTimeMillis() + timeoutMs
        while (System.currentTimeMillis() < deadline) {
            if (appStatus.first == status) {
                Palka.syncStatus()
                delay(300)
                return true
            }
            delay(100)
        }
        Palka.syncStatus()
        return false
    }

    private fun appendScore(candidate: PalkaCandidate, results: List<PalkaServiceProbe>, targetCount: Int) {
        // "Works" means the bulk transfer on the real delivery host completed:
        // a stalled bulk probe counts as a failure for ranking.
        val successful = results.filter {
            (it.status == PalkaProbeStatus.Reachable || it.status == PalkaProbeStatus.Partial) && it.bulkStalled != true
        }
        val stalled = results.count { it.bulkStalled == true }
        val latencies = successful.mapNotNull { it.latencyMs }.sorted()
        val median = latencies.getOrNull(latencies.size / 2)
        val throughputs = successful.mapNotNull { it.bulkKbps }.sorted()
        val failures = maxOf(targetCount - successful.size, 0)
        val score = PalkaStrategyScore(
            id = candidate.id,
            name = candidate.name,
            succeededServices = successful.size,
            totalServices = maxOf(results.size, targetCount),
            medianLatencyMs = median,
            score = failures * 100_000 + stalled * 20_000 + (median ?: 99_999),
            stalledServices = stalled,
            bulkKbps = throughputs.getOrNull(throughputs.size / 2)
        )
        scores.add(score)
        log("${candidate.name}: ${successful.size}/${score.totalServices}" +
            (median?.let { " · $it ms" } ?: "") + (if (stalled > 0) " · stalled $stalled" else ""))
        // The 60 extended strategies would flood the 40-entry history: only the winner
        // among them is recorded (in run()), catalog strategies are recorded as on iOS.
        if (!candidate.extended) {
            Palka.recordResult(candidate.id, candidate.name, candidate.template, successful.isNotEmpty(), median)
        }
    }

    // region Smart recovery

    fun evaluateRecovery(results: List<PalkaServiceProbe>) {
        Palka.syncStatus()
        if (!Palka.smartRecovery || !Palka.vpnRunning || isRunning || results.isEmpty()) {
            failureStreak = 0
            if (!Palka.vpnRunning) recoverySuggestion = null
            return
        }
        if (results.any { it.status == PalkaProbeStatus.Reachable || it.status == PalkaProbeStatus.Partial }) {
            failureStreak = 0
            recoverySuggestion = null
            return
        }
        failureStreak += 1
        if (failureStreak < 2 || recoverySuggestion != null) return
        val fallback = Palka.bestFallback(Palka.activeStrategyId) ?: return
        recoverySuggestion = PalkaRecoverySuggestion(fallback.id, fallback.name, fallback.commandTemplate)
    }

    fun acceptRecoverySuggestion() {
        val suggestion = recoverySuggestion ?: return
        recoverySuggestion = null
        failureStreak = 0
        Palka.syncStatus()
        if (!Palka.vpnRunning || isRunning) return
        scope.launch {
            Palka.stop()
            if (!waitForStatus(AppStatus.Halted, 12_000)) return@launch
            Palka.applyStrategy(suggestion.id, suggestion.name, suggestion.template)
            Palka.log("info", "recovery → ${suggestion.name}")
            connect()
        }
    }

    fun dismissRecoverySuggestion() {
        recoverySuggestion = null
        failureStreak = 0
    }

    // endregion

    private fun log(message: String) {
        logLines.add(Palka.formatTime(System.currentTimeMillis()) + " " + message)
        while (logLines.size > 80) logLines.removeAt(0)
    }
}
