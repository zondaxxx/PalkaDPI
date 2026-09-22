package io.github.romanvht.byedpi.palka

import android.annotation.SuppressLint
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.content.ContextCompat
import androidx.core.content.edit
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import io.github.romanvht.byedpi.R
import io.github.romanvht.byedpi.core.TProxyService
import io.github.romanvht.byedpi.data.AppStatus
import io.github.romanvht.byedpi.data.FAILED_BROADCAST
import io.github.romanvht.byedpi.data.Mode
import io.github.romanvht.byedpi.data.STARTED_BROADCAST
import io.github.romanvht.byedpi.data.STOPPED_BROADCAST
import io.github.romanvht.byedpi.services.ServiceManager
import io.github.romanvht.byedpi.services.appStatus
import io.github.romanvht.byedpi.utility.HistoryUtils
import io.github.romanvht.byedpi.utility.getCmdArgs
import io.github.romanvht.byedpi.utility.getPreferences
import io.github.romanvht.byedpi.utility.getProxyIpAndPort
import io.github.romanvht.byedpi.utility.getSelectedApps
import io.github.romanvht.byedpi.utility.getStringNotNull
import io.github.romanvht.byedpi.utility.mode
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

enum class PalkaNetworkKind { Wifi, Cellular, Wired, Other, Offline }

data class PalkaNetworkProfile(
    val networkKind: PalkaNetworkKind,
    val strategyId: String,
    val strategyName: String,
    val commandTemplate: List<String>
)

data class PalkaRuntimeLogEntry(val timestamp: Long, val level: String, val message: String)

data class PalkaTunnelStats(val upPackets: Long, val upBytes: Long, val downPackets: Long, val downBytes: Long) {
    val totalPackets: Long get() = upPackets + downPackets
}

data class PalkaStrategyStats(
    val id: String,
    var name: String,
    var commandTemplate: List<String>,
    var successCount: Int = 0,
    var failureCount: Int = 0,
    var averageLatencyMs: Int? = null,
    var lastUsedAt: Long = System.currentTimeMillis(),
    var lastSuccessAt: Long? = null,
    var isFavorite: Boolean = false
) {
    val reliability: Double
        get() = (successCount + failureCount).let { if (it == 0) 0.0 else successCount.toDouble() / it }
}

/**
 * Process-wide PalkaDPI state, the Android counterpart of AppProperties +
 * StrategyLibraryStore + NetworkEnvironmentMonitor on iOS. Everything is
 * Compose state so screens recompose on change; persistence is the app's
 * default SharedPreferences, shared with the classic ByeByeDPI screens.
 */
@SuppressLint("StaticFieldLeak")
object Palka {
    private const val PREF_SERVICES = "palka_services_list"
    private const val PREF_CUSTOM_DOMAINS = "palka_custom_domains"
    private const val PREF_ACTIVE_ID = "palka_active_strategy_id"
    private const val PREF_ACTIVE_NAME = "palka_active_strategy_name"
    private const val PREF_ACTIVE_TEMPLATE = "palka_active_template"
    const val PREF_BLOCK_QUIC = "palka_block_quic"
    private const val PREF_RECOVERY = "palka_smart_recovery"
    private const val PREF_EXTENDED = "palka_extended_search"
    private const val PREF_PROFILES = "palka_network_profiles"
    private const val PREF_LIBRARY = "palka_strategy_library"
    private const val PREF_RUNTIME_LOG = "palka_runtime_log"

    lateinit var context: Context
        private set
    private val gson = Gson()
    private val main = Handler(Looper.getMainLooper())
    private var initialized = false

    var vpnRunning by mutableStateOf(false); private set
    var runningMode by mutableStateOf(Mode.VPN); private set
    var mode by mutableStateOf(Mode.VPN); private set
    var activeStrategyId by mutableStateOf(""); private set
    var activeStrategyName by mutableStateOf(""); private set
    var selectedServiceIds by mutableStateOf(PalkaServices.defaultIds); private set
    var customDomains by mutableStateOf(emptyList<String>()); private set
    var blockQuic by mutableStateOf(true); private set
    var smartRecovery by mutableStateOf(true); private set
    var extendedSearch by mutableStateOf(false); private set
    var autostartOnBoot by mutableStateOf(false); private set
    var connectOnLaunch by mutableStateOf(false); private set
    var appListType by mutableStateOf("disable"); private set
    var selectedAppsCount by mutableStateOf(0); private set
    var networkProfiles by mutableStateOf(emptyList<PalkaNetworkProfile>()); private set
    var networkKind by mutableStateOf(PalkaNetworkKind.Other); private set
    var tunnelStats by mutableStateOf<PalkaTunnelStats?>(null); private set
    val runtimeLogs = mutableStateListOf<PalkaRuntimeLogEntry>()
    val library = mutableStateListOf<PalkaStrategyStats>()

    private val prefs get() = context.getPreferences()

    val proxyAddress: String
        get() = prefs.getProxyIpAndPort().let { (ip, port) -> "$ip:$port" }

    val proxyPort: Int
        get() = prefs.getProxyIpAndPort().second.toIntOrNull() ?: 1080

    fun init(appContext: Context) {
        if (initialized) return
        initialized = true
        context = appContext.applicationContext
        loadFromPrefs()
        migrateIfNeeded()
        registerStatusReceiver()
        registerNetworkCallback()
        syncStatus()
    }

    // region Settings

    private fun loadFromPrefs() {
        val p = prefs
        selectedServiceIds = p.getString(PREF_SERVICES, null)
            ?.split(',')?.filter { id -> PalkaServices.all.any { it.id == id } }
            ?.takeIf { it.isNotEmpty() } ?: PalkaServices.defaultIds
        customDomains = p.getString(PREF_CUSTOM_DOMAINS, "").orEmpty().lines().filter { it.isNotBlank() }
        activeStrategyId = p.getString(PREF_ACTIVE_ID, "").orEmpty()
        activeStrategyName = p.getString(PREF_ACTIVE_NAME, "").orEmpty()
        blockQuic = p.getBoolean(PREF_BLOCK_QUIC, true)
        smartRecovery = p.getBoolean(PREF_RECOVERY, true)
        extendedSearch = p.getBoolean(PREF_EXTENDED, false)
        autostartOnBoot = p.getBoolean("autostart", false)
        connectOnLaunch = p.getBoolean("auto_connect", false)
        mode = p.mode()
        appListType = p.getStringNotNull("applist_type", "disable")
        selectedAppsCount = p.getSelectedApps().size
        networkProfiles = readJson(PREF_PROFILES, object : TypeToken<List<PalkaNetworkProfile>>() {}) ?: emptyList()
        library.clear()
        library.addAll(readJson(PREF_LIBRARY, object : TypeToken<List<PalkaStrategyStats>>() {}) ?: emptyList())
        runtimeLogs.clear()
        runtimeLogs.addAll(readJson(PREF_RUNTIME_LOG, object : TypeToken<List<PalkaRuntimeLogEntry>>() {}) ?: emptyList())
    }

    /** Reload the values the classic settings screens may have changed. */
    fun refreshExternalSettings() {
        val p = prefs
        mode = p.mode()
        appListType = p.getStringNotNull("applist_type", "disable")
        selectedAppsCount = p.getSelectedApps().size
        autostartOnBoot = p.getBoolean("autostart", false)
        connectOnLaunch = p.getBoolean("auto_connect", false)
        activeStrategyName = p.getString(PREF_ACTIVE_NAME, "").orEmpty()
        activeStrategyId = p.getString(PREF_ACTIVE_ID, "").orEmpty()
        detectManualCommand()
    }

    private fun migrateIfNeeded() {
        if (activeStrategyId.isNotEmpty()) {
            detectManualCommand()
            return
        }
        val current = prefs.getString("byedpi_cmd_args", null)
        if (current.isNullOrBlank() || current == "-o1 -a1 -r-5+se") {
            applyRecommendedPreset()
        } else {
            setActive("custom", context.getString(R.string.palka_custom_strategy), emptyList(), current)
        }
    }

    /**
     * The classic editor can change `byedpi_cmd_args` behind our back; when the
     * stored line no longer matches what we resolved, show it as a custom one.
     */
    private fun detectManualCommand() {
        val template = activeTemplate()
        if (template.isEmpty()) return
        val expected = PalkaPreset.commandLine(resolve(template))
        if (prefs.getCmdArgs() != expected || !prefs.getBoolean("byedpi_enable_cmd_settings", true)) {
            setActive("custom", context.getString(R.string.palka_custom_strategy), emptyList(), null)
        }
    }

    fun activeTemplate(): List<String> =
        readJson(PREF_ACTIVE_TEMPLATE, object : TypeToken<List<String>>() {}) ?: emptyList()

    fun resolve(template: List<String>): List<String> =
        PalkaPreset.resolve(template, selectedServiceIds, customDomains, blockQuic)

    fun applyRecommendedPreset() =
        applyStrategy(PalkaPreset.ID, PalkaPreset.NAME, PalkaPreset.recommendedTemplate)

    /** Applies a catalog/history template, resolving `{palka_targets}` and the QUIC group. */
    fun applyStrategy(id: String, name: String, template: List<String>) {
        if (template.isEmpty()) return
        val line = PalkaPreset.commandLine(resolve(template))
        setActive(id, name, template, line)
        HistoryUtils(context).apply {
            addCommand(line)
            renameCommand(line, "PalkaDPI: $name")
        }
    }

    private fun setActive(id: String, name: String, template: List<String>, commandLine: String?) {
        prefs.edit(commit = true) {
            putString(PREF_ACTIVE_ID, id)
            putString(PREF_ACTIVE_NAME, name)
            putString(PREF_ACTIVE_TEMPLATE, gson.toJson(template))
            if (commandLine != null) {
                putBoolean("byedpi_enable_cmd_settings", true)
                putString("byedpi_cmd_args", commandLine)
            }
        }
        activeStrategyId = id
        activeStrategyName = name
    }

    private fun reapplyActive() {
        val template = activeTemplate()
        if (template.isNotEmpty()) applyStrategy(activeStrategyId, activeStrategyName, template)
    }

    fun updateServices(ids: List<String>) {
        selectedServiceIds = ids.ifEmpty { PalkaServices.defaultIds }
        prefs.edit { putString(PREF_SERVICES, selectedServiceIds.joinToString(",")) }
        reapplyActive()
    }

    fun updateCustomDomains(raw: List<String>) {
        customDomains = PalkaServices.sanitizedCustomDomains(raw)
        prefs.edit { putString(PREF_CUSTOM_DOMAINS, customDomains.joinToString("\n")) }
        reapplyActive()
    }

    fun updateBlockQuic(value: Boolean) {
        blockQuic = value
        prefs.edit(commit = true) { putBoolean(PREF_BLOCK_QUIC, value) }
        reapplyActive()
    }

    fun updateSmartRecovery(value: Boolean) {
        smartRecovery = value
        prefs.edit { putBoolean(PREF_RECOVERY, value) }
    }

    fun updateExtendedSearch(value: Boolean) {
        extendedSearch = value
        prefs.edit { putBoolean(PREF_EXTENDED, value) }
    }

    fun updateAutostartOnBoot(value: Boolean) {
        autostartOnBoot = value
        prefs.edit { putBoolean("autostart", value) }
    }

    fun updateConnectOnLaunch(value: Boolean) {
        connectOnLaunch = value
        prefs.edit { putBoolean("auto_connect", value) }
    }

    fun updateMode(value: Mode) {
        mode = value
        prefs.edit { putString("byedpi_mode", if (value == Mode.VPN) "vpn" else "proxy") }
    }

    fun updateAppListType(value: String) {
        appListType = value
        prefs.edit { putString("applist_type", value) }
    }

    // endregion

    // region Network profiles

    fun saveCurrentStrategy(kind: PalkaNetworkKind = networkKind) {
        if (kind == PalkaNetworkKind.Offline) return
        val profile = PalkaNetworkProfile(kind, activeStrategyId, activeStrategyName, activeTemplate())
        networkProfiles = networkProfiles.filter { it.networkKind != kind } + profile
        writeJson(PREF_PROFILES, networkProfiles)
    }

    fun applyNetworkProfile(kind: PalkaNetworkKind): Boolean {
        val profile = networkProfiles.firstOrNull { it.networkKind == kind } ?: return false
        if (profile.commandTemplate.isEmpty()) return false
        applyStrategy(profile.strategyId, profile.strategyName, profile.commandTemplate)
        return true
    }

    fun networkTitle(kind: PalkaNetworkKind): String = when (kind) {
        PalkaNetworkKind.Wifi -> "Wi‑Fi"
        PalkaNetworkKind.Cellular -> context.getString(R.string.palka_cellular)
        PalkaNetworkKind.Wired -> context.getString(R.string.palka_wired)
        PalkaNetworkKind.Other -> context.getString(R.string.palka_other_network)
        PalkaNetworkKind.Offline -> context.getString(R.string.palka_offline)
    }

    private fun currentNetworkKind(): PalkaNetworkKind {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            // Our own VPN is the default network while connected; look at the
            // underlying transports instead so profiles follow the real uplink.
            val networks = cm.allNetworks.mapNotNull { cm.getNetworkCapabilities(it) }
                .filter { !it.hasTransport(NetworkCapabilities.TRANSPORT_VPN) &&
                    it.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) }
            if (networks.isEmpty()) return PalkaNetworkKind.Offline
            return when {
                networks.any { it.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) } -> PalkaNetworkKind.Wifi
                networks.any { it.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) } -> PalkaNetworkKind.Wired
                networks.any { it.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) } -> PalkaNetworkKind.Cellular
                else -> PalkaNetworkKind.Other
            }
        }
        @Suppress("DEPRECATION")
        val info = cm.activeNetworkInfo ?: return PalkaNetworkKind.Offline
        @Suppress("DEPRECATION")
        return when (info.type) {
            ConnectivityManager.TYPE_WIFI -> PalkaNetworkKind.Wifi
            ConnectivityManager.TYPE_MOBILE -> PalkaNetworkKind.Cellular
            ConnectivityManager.TYPE_ETHERNET -> PalkaNetworkKind.Wired
            else -> PalkaNetworkKind.Other
        }
    }

    private fun registerNetworkCallback() {
        networkKind = currentNetworkKind()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val recheck = Runnable { onNetworkMaybeChanged() }
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) = post()
            override fun onLost(network: Network) = post()
            override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) = post()
            private fun post() {
                main.removeCallbacks(recheck)
                main.postDelayed(recheck, 1500)
            }
        }
        runCatching {
            cm.registerNetworkCallback(android.net.NetworkRequest.Builder().build(), callback)
        }
    }

    private fun onNetworkMaybeChanged() {
        val kind = currentNetworkKind()
        if (kind == networkKind) return
        networkKind = kind
        if (kind == PalkaNetworkKind.Offline || PalkaAutomation.isRunning) return
        val profile = networkProfiles.firstOrNull { it.networkKind == kind } ?: return
        if (profile.strategyId == activeStrategyId || profile.commandTemplate.isEmpty()) return
        applyNetworkProfile(kind)
        log("info", context.getString(R.string.palka_network_auto_applied, networkTitle(kind), profile.strategyName))
        if (vpnRunning) ServiceManager.restart(context, runningMode)
    }

    // endregion

    // region Strategy library (favorites + history)

    fun recordResult(id: String, name: String, template: List<String>, succeeded: Boolean, latencyMs: Int?) {
        val record = library.firstOrNull { it.id == id }?.copy()
            ?: PalkaStrategyStats(id, name, template)
        record.name = name
        record.commandTemplate = template
        record.lastUsedAt = System.currentTimeMillis()
        if (succeeded) {
            record.successCount += 1
            record.lastSuccessAt = System.currentTimeMillis()
            if (latencyMs != null) {
                record.averageLatencyMs = record.averageLatencyMs
                    ?.let { (it * 0.7 + latencyMs * 0.3).toInt() } ?: latencyMs
            }
        } else {
            record.failureCount += 1
        }
        library.removeAll { it.id == id }
        library.add(0, record)
        while (library.size > 40) library.removeAt(library.lastIndex)
        persistLibrary()
    }

    fun isFavorite(id: String) = library.any { it.id == id && it.isFavorite }

    fun toggleFavorite(id: String, name: String, template: List<String>) {
        val record = library.firstOrNull { it.id == id }?.copy() ?: PalkaStrategyStats(id, name, template)
        record.name = name
        record.commandTemplate = template
        record.isFavorite = !record.isFavorite
        library.removeAll { it.id == id }
        library.add(0, record)
        persistLibrary()
    }

    fun removeHistory(id: String) {
        val record = library.firstOrNull { it.id == id } ?: return
        library.removeAll { it.id == id }
        if (record.isFavorite) {
            library.add(record.copy(successCount = 0, failureCount = 0, averageLatencyMs = null, lastSuccessAt = null))
        }
        persistLibrary()
    }

    fun bestFallback(excluding: String): PalkaStrategyStats? = library
        .filter { it.id != excluding && it.commandTemplate.isNotEmpty() && it.successCount > 0 }
        .sortedWith(
            compareByDescending<PalkaStrategyStats> { it.isFavorite }
                .thenByDescending { it.reliability }
                .thenBy { it.averageLatencyMs ?: Int.MAX_VALUE }
        )
        .firstOrNull()

    private fun persistLibrary() = writeJson(PREF_LIBRARY, library.toList())

    // endregion

    // region Connection status, runtime log, tunnel counters

    fun syncStatus() {
        val (status, running) = appStatus
        val isRunning = status == AppStatus.Running
        if (isRunning != vpnRunning) {
            vpnRunning = isRunning
            if (!isRunning) tunnelStats = null
        }
        runningMode = running
    }

    private fun registerStatusReceiver() {
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                val wasRunning = vpnRunning
                syncStatus()
                when (intent?.action) {
                    STARTED_BROADCAST -> if (!wasRunning || vpnRunning) log(
                        "success",
                        "${if (runningMode == Mode.VPN) "VPN" else "SOCKS5"} ↑ ${activeStrategyName.ifBlank { "—" }} · $proxyAddress"
                    )
                    STOPPED_BROADCAST -> log("info", "stopped")
                    FAILED_BROADCAST -> log("error", "core failed to start")
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(STARTED_BROADCAST)
            addAction(STOPPED_BROADCAST)
            addAction(FAILED_BROADCAST)
        }
        ContextCompat.registerReceiver(context, receiver, filter, ContextCompat.RECEIVER_EXPORTED)
    }

    /** Polled by the home screen while connected; hev-socks5-tunnel keeps the counters. */
    fun refreshTunnelStats() {
        syncStatus()
        if (!vpnRunning || runningMode != Mode.VPN) {
            tunnelStats = null
            return
        }
        tunnelStats = runCatching {
            val s = TProxyService.TProxyGetStats()
            PalkaTunnelStats(s[0], s[1], s[2], s[3])
        }.getOrNull()
    }

    fun log(level: String, message: String) {
        val append = {
            runtimeLogs.add(PalkaRuntimeLogEntry(System.currentTimeMillis(), level, message))
            while (runtimeLogs.size > 60) runtimeLogs.removeAt(0)
            writeJson(PREF_RUNTIME_LOG, runtimeLogs.toList())
        }
        if (Looper.myLooper() == Looper.getMainLooper()) append() else main.post(append)
    }

    fun formatTime(timestamp: Long): String =
        SimpleDateFormat("HH:mm:ss", Locale.US).format(Date(timestamp))

    // endregion

    // region Connect / disconnect

    /** Null when the VPN may start right away, otherwise the system consent intent. */
    fun vpnConsentIntent(): Intent? = if (mode == Mode.VPN) VpnService.prepare(context) else null

    fun start() {
        syncStatus()
        if (vpnRunning) return
        ServiceManager.start(context, mode)
    }

    fun stop() {
        syncStatus()
        ServiceManager.stop(context)
    }

    // endregion

    private fun <T> readJson(key: String, type: TypeToken<T>): T? =
        prefs.getString(key, null)?.let { runCatching { gson.fromJson<T>(it, type.type) }.getOrNull() }

    private fun writeJson(key: String, value: Any) {
        prefs.edit { putString(key, gson.toJson(value)) }
    }
}
