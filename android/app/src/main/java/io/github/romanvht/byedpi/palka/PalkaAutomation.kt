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

data class PalkaCandidate(val id: String, val name: String, val template: List<String>)

/**
 * In-process ByeDPI core on its own port, used to test strategies without
 * touching the VPN. The native core is a single global instance, so the VPN
 * (or proxy service) must be stopped first.
 */
private class PalkaTestCore(private val port: Int) {
    private val proxy = ByeDpiProxy()
    @Volatile private var finished = false
    private var thread: Thread? = null

    fun start(args: List<String>): Boolean {
        val argv = arrayOf("ciadpi", "--ip", "127.0.0.1", "--port", port.toString()) + args
        finished = false
        thread = Thread({
            runCatching { proxy.startProxy(ByeDpiProxyCmdPreferences(argv)) }
                .onFailure { Log.w("PalkaTestCore", "core crashed", it) }
            finished = true
        }, "palka-test-core").apply { isDaemon = true; start() }
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

    fun stop() {
        runCatching { proxy.stopProxy() }
        thread?.join(2_000)
        if (thread?.isAlive == true) runCatching { proxy.jniForceClose() }
        thread?.join(1_000)
        thread = null
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

    var isRunning by mutableStateOf(false); private set
    var currentStrategyName by mutableStateOf(""); private set
    var currentStage by mutableStateOf(""); private set
    var completed by mutableStateOf(0); private set
    var total by mutableStateOf(0); private set
    var bestStrategyName by mutableStateOf<String?>(null); private set
    var errorText by mutableStateOf<String?>(null); private set
    var summary by mutableStateOf<String?>(null); private set
    var recoverySuggestion by mutableStateOf<PalkaRecoverySuggestion?>(null); private set
    val scores = mutableStateListOf<PalkaStrategyScore>()
    val logLines = mutableStateListOf<String>()

    /** Set by the activity: asks the user for VPN consent, true when granted. */
    var requestVpnConsent: (suspend () -> Boolean)? = null

    private fun str(id: Int, vararg args: Any) = Palka.context.getString(id, *args)

    fun extendedCandidates(): List<PalkaCandidate> = runCatching {
        Palka.context.assets.open("proxytest_strategies.list").bufferedReader().readLines()
    }.getOrDefault(emptyList())
        .map { it.trim().replace("{sni}", "google.com") }
        .filter { it.isNotEmpty() }
        .mapIndexed { index, line ->
            PalkaCandidate("ext:" + line.hashCode().toUInt().toString(16), str(R.string.palka_extended_name, index + 1), shellSplit(line))
        }

    fun start() {
        if (isRunning) return
        PalkaCatalog.loadCache()
        val catalog = PalkaCatalog.strategies
        if (catalog.isEmpty()) {
            errorText = str(R.string.palka_auto_catalog_needed)
            PalkaCatalog.load()
            return
        }
        val candidates = catalog
            .map { PalkaCandidate(it.id, it.displayName, it.commandArgs) }
            .sortedByDescending { Palka.isFavorite(it.id) } +
            (if (Palka.extendedSearch) extendedCandidates() else emptyList())

        isRunning = true
        errorText = null
        bestStrategyName = null
        summary = null
        completed = 0
        total = candidates.size
        scores.clear()
        logLines.clear()
        currentStage = str(R.string.palka_auto_stopping_vpn)
        log("start: ${candidates.size} strategies, services ${Palka.selectedServiceIds.joinToString(",")}")
        job = scope.launch { run(candidates) }
    }

    fun cancel() {
        val running = job ?: return
        log("cancelled by user")
        running.cancel()
    }

    private suspend fun run(candidates: List<PalkaCandidate>) {
        val previousId = Palka.activeStrategyId
        val previousName = Palka.activeStrategyName
        val previousTemplate = Palka.activeTemplate()
        Palka.syncStatus()
        val reconnectOnFailure = Palka.vpnRunning
        try {
            if (Palka.vpnRunning) {
                Palka.stop()
                val stopped = waitForStatus(AppStatus.Halted, 12_000)
                log(if (stopped) "VPN stopped" else "VPN did not stop in 12 s")
            }
            val targets = PalkaServices.diagnosticTargets(Palka.selectedServiceIds, Palka.customDomains)
            val core = PalkaTestCore(TEST_PORT)
            for ((index, candidate) in candidates.withIndex()) {
                currentStrategyName = candidate.name
                currentStage = str(R.string.palka_auto_testing_format, index + 1, candidates.size)
                val args = Palka.resolve(candidate.template)
                val results = withContext(Dispatchers.IO) {
                    withTimeoutOrNull(STRATEGY_DEADLINE_MS) {
                        if (!core.start(args)) return@withTimeoutOrNull null
                        try {
                            // Quick pass first: a strategy that opens nothing is not worth a bulk download.
                            val quick = PalkaProbe.probe(targets, TEST_PORT, 1, includeBulk = false, timings = false, smallTimeoutMs = 5_000)
                            val passed = quick.filter { it.status != PalkaProbeStatus.Unavailable }.map { it.id }.toSet()
                            if (passed.isEmpty()) quick
                            else {
                                val full = PalkaProbe.probe(targets.filter { it.id in passed }, TEST_PORT, 1, includeBulk = true, timings = false, smallTimeoutMs = 5_000, bulkTimeoutMs = 10_000)
                                quick.map { q -> full.firstOrNull { it.id == q.id } ?: q }
                            }
                        } finally {
                            core.stop()
                        }
                    }.also { if (it == null) core.stop() }
                }
                if (results == null) {
                    log("${candidate.name}: " + str(R.string.palka_auto_core_failed))
                    scores.add(PalkaStrategyScore(candidate.id, candidate.name, 0, targets.size, null, Int.MAX_VALUE, coreFailed = true))
                } else {
                    appendScore(candidate, results, targets.size)
                }
                completed = index + 1
            }
            finish(candidates, previousId, previousName, previousTemplate, reconnectOnFailure)
        } catch (e: CancellationException) {
            restore(previousId, previousName, previousTemplate)
            isRunning = false
            currentStage = ""
            if (reconnectOnFailure) scope.launch { connect() }
            throw e
        }
    }

    private suspend fun finish(
        candidates: List<PalkaCandidate>,
        previousId: String,
        previousName: String,
        previousTemplate: List<String>,
        reconnectOnFailure: Boolean
    ) {
        val passed = scores.count { it.succeededServices > 0 }
        summary = str(R.string.palka_auto_screening_summary_short, passed, scores.size)
        val best = scores.sortedWith(
            compareByDescending<PalkaStrategyScore> { it.succeededServices }
                .thenBy { it.score }
                .thenByDescending { it.bulkKbps ?: 0 }
        ).firstOrNull()
        val strategy = best?.takeIf { it.succeededServices > 0 }?.let { b -> candidates.firstOrNull { it.id == b.id } }
        if (strategy == null) {
            log("no working strategy; restoring previous")
            restore(previousId, previousName, previousTemplate)
            errorText = str(R.string.palka_auto_no_working_strategy)
            if (reconnectOnFailure) connect()
            isRunning = false
            currentStage = ""
            return
        }
        log("best: ${strategy.name} (${best.succeededServices}/${best.totalServices})")
        Palka.applyStrategy(strategy.id, strategy.name, strategy.template)
        Palka.saveCurrentStrategy()
        bestStrategyName = strategy.name
        currentStrategyName = strategy.name
        val connected = connect()
        if (connected) log("connected with ${strategy.name}")
        isRunning = false
        currentStage = ""
    }

    private fun restore(id: String, name: String, template: List<String>) {
        if (template.isNotEmpty()) Palka.applyStrategy(id, name, template)
        else if (id != "custom") Palka.applyRecommendedPreset()
    }

    private suspend fun connect(): Boolean {
        currentStage = str(R.string.palka_auto_connecting_vpn)
        if (Palka.vpnConsentIntent() != null) {
            val granted = requestVpnConsent?.invoke() ?: false
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
        Palka.recordResult(candidate.id, candidate.name, candidate.template, successful.isNotEmpty(), median)
    }

    // region Smart recovery

    fun evaluateRecovery(results: List<PalkaServiceProbe>) {
        Palka.syncStatus()
        if (!Palka.smartRecovery || !Palka.vpnRunning || isRunning || results.isEmpty()) {
            failureStreak = 0
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
        scope.launch {
            Palka.stop()
            waitForStatus(AppStatus.Halted, 12_000)
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
