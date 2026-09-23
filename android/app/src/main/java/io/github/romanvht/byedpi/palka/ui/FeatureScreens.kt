package io.github.romanvht.byedpi.palka.ui

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.relocation.BringIntoViewRequester
import androidx.compose.foundation.relocation.bringIntoViewRequester
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.IosShare
import androidx.compose.material.icons.rounded.AlternateEmail
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.AutoFixHigh
import androidx.compose.material.icons.rounded.BatteryChargingFull
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.DeleteOutline
import androidx.compose.material.icons.rounded.Error
import androidx.compose.material.icons.rounded.Forum
import androidx.compose.material.icons.rounded.GridView
import androidx.compose.material.icons.rounded.History
import androidx.compose.material.icons.rounded.Hub
import androidx.compose.material.icons.rounded.MonitorHeart
import androidx.compose.material.icons.rounded.MusicNote
import androidx.compose.material.icons.rounded.PhotoCamera
import androidx.compose.material.icons.rounded.Public
import androidx.compose.material.icons.rounded.RadioButtonUnchecked
import androidx.compose.material.icons.rounded.Send
import androidx.compose.material.icons.rounded.SettingsEthernet
import androidx.compose.material.icons.rounded.SignalCellularAlt
import androidx.compose.material.icons.rounded.SmartDisplay
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.VpnLock
import androidx.compose.material.icons.rounded.Wifi
import androidx.compose.material.icons.rounded.WifiOff
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.focus.onFocusChanged
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.FileProvider
import androidx.lifecycle.compose.LifecycleResumeEffect
import com.google.gson.GsonBuilder
import io.github.romanvht.byedpi.BuildConfig
import io.github.romanvht.byedpi.R
import io.github.romanvht.byedpi.palka.Palka
import io.github.romanvht.byedpi.palka.PalkaAutomation
import io.github.romanvht.byedpi.palka.PalkaCatalog
import io.github.romanvht.byedpi.palka.PalkaDiagnostics
import io.github.romanvht.byedpi.palka.PalkaNetworkKind
import io.github.romanvht.byedpi.palka.PalkaProbeStatus
import io.github.romanvht.byedpi.palka.PalkaServiceProbe
import io.github.romanvht.byedpi.palka.PalkaServices
import io.github.romanvht.byedpi.palka.PalkaStrategyScore
import io.github.romanvht.byedpi.utility.PermissionUtils
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

// region Automation

@Composable
fun AutomationScreen() {
    val context = LocalContext.current
    LaunchedEffect(Unit) { if (PalkaCatalog.strategies.isEmpty()) PalkaCatalog.load() }
    PalkaScaffold(stringResource(R.string.palka_auto_title)) {
        PalkaFeatureHeader(
            stringResource(R.string.palka_auto_heading),
            stringResource(R.string.palka_auto_description) + "\n" + stringResource(R.string.palka_auto_fast_hint),
            Icons.Rounded.AutoFixHigh
        )

        if (PalkaAutomation.isRunning) {
            Column(
                Modifier.fillMaxWidth().palkaCard(selected = true).padding(18.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(PalkaAutomation.currentStrategyName, style = palkaText(15.sp, FontWeight.Bold))
                        Text(PalkaAutomation.currentStage, style = palkaText(11.sp, FontWeight.Medium, PalkaDesign.textSecondary))
                    }
                    Text(
                        "${PalkaAutomation.completed}/${PalkaAutomation.total}",
                        style = palkaText(12.sp, FontWeight.SemiBold, PalkaDesign.textMuted, mono = true)
                    )
                }
                PalkaProgressBar(PalkaAutomation.completed.toFloat() / maxOf(PalkaAutomation.total, 1))
                PalkaSecondaryButton(PalkaAutomation::cancel) { Text(stringResource(R.string.palka_auto_cancel)) }
            }
        } else {
            PalkaPrimaryButton(PalkaAutomation::start) {
                Icon(Icons.Rounded.AutoAwesome, null, modifier = Modifier.size(18.dp))
                Text(stringResource(R.string.palka_auto_start))
            }
            PalkaToggleRow(
                stringResource(R.string.palka_extended_title),
                context.getString(R.string.palka_extended_description, remember { PalkaAutomation.extendedCandidates().size }),
                Palka.extendedSearch
            ) { Palka.updateExtendedSearch(it) }
        }

        PalkaAutomation.bestStrategyName?.takeIf { it == Palka.activeStrategyName }?.let {
            PalkaFeedbackBanner(stringResource(R.string.palka_auto_selected_format, it), PalkaFeedbackKind.Success)
        }
        PalkaAutomation.errorText
            ?.takeUnless { PalkaAutomation.errorNeedsCatalog && PalkaCatalog.strategies.isNotEmpty() }
            ?.let { PalkaFeedbackBanner(it, PalkaFeedbackKind.Error) }
        PalkaAutomation.summary?.let { (passed, checked) ->
            PalkaFeedbackBanner(stringResource(R.string.palka_auto_screening_summary_short, passed, checked), PalkaFeedbackKind.Success)
        }

        if (PalkaAutomation.scores.isNotEmpty()) {
            PalkaSection(stringResource(R.string.palka_auto_results)) {
                PalkaAutomation.scores
                    .sortedWith(compareByDescending<PalkaStrategyScore> { it.succeededServices }.thenBy { it.score })
                    .forEach { ScoreRow(it) }
            }
        }

        if (PalkaAutomation.logLines.isNotEmpty()) {
            PalkaSection(stringResource(R.string.palka_auto_log)) {
                Column(
                    Modifier.fillMaxWidth().palkaCard().padding(12.dp),
                    verticalArrangement = Arrangement.spacedBy(3.dp)
                ) {
                    PalkaAutomation.logLines.takeLast(40).forEach {
                        Text(it, style = palkaText(10.sp, color = PalkaDesign.textMuted, mono = true))
                    }
                }
            }
        }

        if (PalkaCatalog.strategies.isEmpty() && PalkaCatalog.isLoading) {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                PalkaSpinner()
                Text(stringResource(R.string.palka_catalog_loading), style = palkaText(13.sp, FontWeight.Medium))
            }
        }
    }
}

@Composable
private fun ScoreRow(score: PalkaStrategyScore) {
    val details = buildList {
        add("${score.succeededServices}/${score.totalServices}")
        add(score.medianLatencyMs?.let { "$it ms" } ?: "—")
        if (score.stalledServices > 0) add(stringResource(R.string.palka_auto_stalled_format, score.stalledServices))
        else score.bulkKbps?.let { add("$it KB/s") }
        if (score.coreFailed) add(stringResource(R.string.palka_auto_core_failed))
    }.joinToString(" · ")
    Row(
        Modifier.fillMaxWidth().palkaCard().padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Icon(
            if (score.succeededServices == score.totalServices) Icons.Rounded.CheckCircle else Icons.Rounded.Error, null,
            tint = if (score.succeededServices > 0) PalkaDesign.successText else PalkaDesign.errorText,
            modifier = Modifier.size(20.dp)
        )
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(score.name, style = palkaText(14.sp, FontWeight.SemiBold))
            Text(details, style = palkaText(11.sp, color = PalkaDesign.textMuted, mono = true))
        }
    }
}

// endregion

// region Services

fun serviceIcon(id: String): ImageVector = when (id) {
    "discord" -> Icons.Rounded.Forum
    "youtube" -> Icons.Rounded.SmartDisplay
    "instagram" -> Icons.Rounded.PhotoCamera
    "tiktok" -> Icons.Rounded.MusicNote
    "x" -> Icons.Rounded.AlternateEmail
    "telegram" -> @Suppress("DEPRECATION") Icons.Rounded.Send
    else -> Icons.Rounded.Public
}

@Composable
fun ServiceSelectionScreen() {
    val running = Palka.locked
    var customText by remember { mutableStateOf(Palka.customDomains.joinToString("\n")) }
    // When the field gets focus, scroll so the save button sits above the keyboard too.
    val saveInView = remember { BringIntoViewRequester() }
    val scope = rememberCoroutineScope()
    PalkaScaffold(stringResource(R.string.palka_services_title)) {
        PalkaFeatureHeader(stringResource(R.string.palka_services_heading), stringResource(R.string.palka_services_description), Icons.Rounded.GridView)
        if (running) PalkaFeedbackBanner(stringResource(R.string.palka_services_stop_first), PalkaFeedbackKind.Error)

        PalkaServices.all.forEach { service ->
            val selected = service.id in Palka.selectedServiceIds
            Row(
                Modifier
                    .fillMaxWidth()
                    .alpha(if (running) 0.55f else 1f)
                    .palkaPressable(enabled = !running) {
                        val ids = Palka.selectedServiceIds.toMutableList()
                        if (selected) {
                            if (ids.size > 1) ids.remove(service.id)
                        } else ids.add(service.id)
                        Palka.updateServices(ids)
                    }
                    .palkaCard(selected = selected)
                    .padding(15.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                PalkaIconTile(serviceIcon(service.id), size = 42.dp, iconSize = 20.dp, radius = 12.dp, background = Color.White.copy(alpha = 0.06f))
                Text(service.name, style = palkaText(16.sp, FontWeight.Bold), modifier = Modifier.weight(1f))
                Icon(
                    if (selected) Icons.Rounded.CheckCircle else Icons.Rounded.RadioButtonUnchecked, null,
                    tint = if (selected) PalkaDesign.successText else PalkaDesign.textDim,
                    modifier = Modifier.size(24.dp)
                )
            }
        }

        Column(
            Modifier.fillMaxWidth().palkaCard().padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text(stringResource(R.string.palka_custom_domains_title), style = palkaText(15.sp, FontWeight.Bold))
            Text(stringResource(R.string.palka_custom_domains_description), style = palkaText(11.sp, color = PalkaDesign.textMuted))
            BasicTextField(
                value = customText,
                onValueChange = { customText = it },
                enabled = !running,
                textStyle = palkaText(13.sp, mono = true),
                cursorBrush = SolidColor(Color.White),
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 110.dp)
                    .onFocusChanged { focus ->
                        if (focus.isFocused) scope.launch {
                            delay(350) // wait for the keyboard inset to settle
                            saveInView.bringIntoView()
                        }
                    }
                    .clip(RoundedCornerShape(10.dp))
                    .background(Color.White.copy(alpha = 0.045f))
                    .padding(12.dp)
            )
            PalkaSecondaryButton(
                { Palka.updateCustomDomains(customText.lines()); customText = Palka.customDomains.joinToString("\n") },
                modifier = Modifier.bringIntoViewRequester(saveInView),
                enabled = !running
            ) {
                Text(stringResource(R.string.palka_custom_domains_save))
            }
        }
    }
}

// endregion

// region Diagnostics

@Composable
fun DiagnosticsScreen() {
    val host = LocalHost.current
    val context = LocalContext.current
    LaunchedEffect(Unit) { PalkaDiagnostics.ensureIdle() }
    PalkaScaffold(stringResource(R.string.palka_diagnostics_title)) {
        PalkaFeatureHeader(stringResource(R.string.palka_diagnostics_heading), stringResource(R.string.palka_diagnostics_description), Icons.Rounded.MonitorHeart)
        PalkaPrimaryButton(
            onClick = { PalkaDiagnostics.refresh(attempts = 3, timings = true) { PalkaAutomation.evaluateRecovery(it) } },
            enabled = !PalkaDiagnostics.isRefreshing
        ) {
            if (PalkaDiagnostics.isRefreshing) PalkaSpinner(Color.Black.copy(alpha = 0.78f))
            else Icon(Icons.Rounded.MonitorHeart, null, modifier = Modifier.size(18.dp))
            Text(stringResource(if (PalkaDiagnostics.isRefreshing) R.string.palka_service_ping_testing else R.string.palka_diagnostics_run))
        }
        PalkaDiagnostics.services.forEach { DiagnosticCard(it) }
        PalkaSecondaryButton({
            val file = buildSupportReport(context) ?: return@PalkaSecondaryButton
            val uri = FileProvider.getUriForFile(context, "${BuildConfig.APPLICATION_ID}.palka.files", file)
            val send = Intent(Intent.ACTION_SEND)
                .setType("application/json")
                .putExtra(Intent.EXTRA_STREAM, uri)
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            host.open(Intent.createChooser(send, context.getString(R.string.palka_report_share)))
        }) {
            Icon(Icons.Rounded.IosShare, null, modifier = Modifier.size(18.dp))
            Text(stringResource(R.string.palka_diagnostics_export))
        }
    }
}

@Composable
private fun DiagnosticCard(service: PalkaServiceProbe) {
    Column(
        Modifier.fillMaxWidth().palkaCard(selected = service.status == PalkaProbeStatus.Reachable).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(service.name, style = palkaText(16.sp, FontWeight.Bold), modifier = Modifier.weight(1f))
            Text(
                serviceStatusText(service.status),
                style = palkaText(11.sp, FontWeight.SemiBold, when (service.status) {
                    PalkaProbeStatus.Reachable -> PalkaDesign.successText
                    PalkaProbeStatus.Partial -> PalkaDesign.warning
                    PalkaProbeStatus.Unavailable -> PalkaDesign.errorText
                    else -> PalkaDesign.textMuted
                })
            )
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Metric("DNS", service.dnsMs?.let { "$it ms" } ?: "—", false, Modifier.weight(1f))
            Metric("TLS", service.tlsMs?.let { "$it ms" } ?: "—", false, Modifier.weight(1f))
            Metric("HTTP", service.latencyMs?.let { "$it ms" } ?: "—", false, Modifier.weight(1f))
            if (service.bulkStalled == true) {
                Metric(stringResource(R.string.palka_diagnostic_bulk), stringResource(R.string.palka_diagnostic_stalled_format, service.bulkReceivedKb ?: 0), true, Modifier.weight(1.3f))
            } else if (service.bulkKbps != null) {
                Metric(stringResource(R.string.palka_diagnostic_bulk), "${service.bulkKbps} KB/s", false, Modifier.weight(1.3f))
            }
        }
        Text(
            "${service.successfulAttempts}/${service.totalAttempts} · HTTP ${service.statusCode ?: "—"}" +
                (service.errorText?.takeIf { service.status != PalkaProbeStatus.Reachable }?.let { " · $it" } ?: ""),
            style = palkaText(11.sp, color = PalkaDesign.textMuted, mono = true)
        )
    }
}

@Composable
private fun Metric(title: String, value: String, highlighted: Boolean, modifier: Modifier) {
    Column(
        modifier.clip(RoundedCornerShape(10.dp)).background(Color.White.copy(alpha = 0.045f)).padding(10.dp),
        verticalArrangement = Arrangement.spacedBy(3.dp)
    ) {
        Text(title, style = palkaText(9.sp, FontWeight.SemiBold, PalkaDesign.textMuted), maxLines = 1)
        Text(value, style = palkaText(12.sp, FontWeight.SemiBold, if (highlighted) PalkaDesign.errorText else PalkaDesign.textPrimary, mono = true), maxLines = 1)
    }
}

/** Privacy-safe JSON report: settings and probe timings, no traffic, history or identifiers. */
private fun buildSupportReport(context: android.content.Context): File? = runCatching {
    val report = linkedMapOf(
        "privacy" to "No traffic contents, browsing history, device IP, account, or advertising identifiers are included.",
        "created_at" to SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssZ", Locale.US).format(Date()),
        "platform" to "android",
        "android_api" to Build.VERSION.SDK_INT,
        "app_version" to BuildConfig.VERSION_NAME,
        "engine_version" to PalkaCatalog.ENGINE_VERSION,
        "network_type" to Palka.networkKind.name.lowercase(),
        "mode" to Palka.mode.name.lowercase(),
        "active_strategy_id" to Palka.activeStrategyId,
        "active_strategy_name" to Palka.activeStrategyName,
        "selected_services" to Palka.selectedServiceIds,
        "custom_domain_count" to Palka.customDomains.size,
        "smart_recovery" to Palka.smartRecovery,
        "block_quic" to Palka.blockQuic,
        "split_tunnel" to Palka.appListType,
        "diagnostics" to PalkaDiagnostics.services.map {
            linkedMapOf(
                "service" to it.name, "status" to it.status.name.lowercase(),
                "dns_ms" to it.dnsMs, "tls_ms" to it.tlsMs, "http_ms" to it.latencyMs,
                "bulk_kbps" to it.bulkKbps, "bulk_stalled" to it.bulkStalled,
                "successful_attempts" to it.successfulAttempts, "total_attempts" to it.totalAttempts,
                "http_status" to it.statusCode
            )
        }
    )
    val dir = File(context.cacheDir, "reports").apply { mkdirs() }
    File(dir, "PalkaDPI-support-report.json").apply {
        writeText(GsonBuilder().setPrettyPrinting().serializeNulls().create().toJson(report))
    }
}.getOrNull()

// endregion

// region Networks

fun networkIcon(kind: PalkaNetworkKind): ImageVector = when (kind) {
    PalkaNetworkKind.Wifi -> Icons.Rounded.Wifi
    PalkaNetworkKind.Cellular -> Icons.Rounded.SignalCellularAlt
    PalkaNetworkKind.Wired -> Icons.Rounded.SettingsEthernet
    PalkaNetworkKind.Other -> Icons.Rounded.Hub
    PalkaNetworkKind.Offline -> Icons.Rounded.WifiOff
}

@Composable
fun NetworkProfilesScreen() {
    val host = LocalHost.current
    val context = LocalContext.current
    var message by remember { mutableStateOf<String?>(null) }
    val kind = Palka.networkKind
    PalkaScaffold(stringResource(R.string.palka_network_profiles_title)) {
        PalkaFeatureHeader(stringResource(R.string.palka_network_profiles_heading), stringResource(R.string.palka_android_networks_description), networkIcon(kind))

        PalkaSection(stringResource(R.string.palka_autostart_section)) {
            PalkaToggleRow(stringResource(R.string.palka_autostart_boot), stringResource(R.string.palka_autostart_boot_description), Palka.autostartOnBoot) {
                Palka.updateAutostartOnBoot(it)
            }
            PalkaToggleRow(stringResource(R.string.palka_autostart_launch), stringResource(R.string.palka_autostart_launch_description), Palka.connectOnLaunch) {
                Palka.updateConnectOnLaunch(it)
            }
            PalkaNavRow(stringResource(R.string.palka_always_on), stringResource(R.string.palka_always_on_description), Icons.Rounded.VpnLock) {
                host.open(Intent(Settings.ACTION_VPN_SETTINGS))
            }
            // Re-read on every resume: the exemption is granted in a system dialog.
            var batteryFree by remember { mutableStateOf(PermissionUtils.isBatteryOptimizationDisabled(context)) }
            LifecycleResumeEffect(Unit) {
                batteryFree = PermissionUtils.isBatteryOptimizationDisabled(context)
                onPauseOrDispose { }
            }
            PalkaNavRow(
                stringResource(R.string.palka_battery),
                stringResource(if (batteryFree) R.string.palka_battery_done else R.string.palka_battery_description),
                Icons.Rounded.BatteryChargingFull,
                showsDisclosure = !batteryFree
            ) {
                if (!batteryFree && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    @android.annotation.SuppressLint("BatteryLife")
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:${context.packageName}"))
                    host.open(intent)
                }
            }
        }

        PalkaSection(stringResource(R.string.palka_recovery_section)) {
            PalkaToggleRow(stringResource(R.string.palka_recovery_enabled), stringResource(R.string.palka_recovery_description), Palka.smartRecovery) {
                Palka.updateSmartRecovery(it)
            }
            PalkaToggleRow(stringResource(R.string.palka_quic_block_enabled), stringResource(R.string.palka_quic_block_description), Palka.blockQuic, enabled = !Palka.locked) {
                Palka.updateBlockQuic(it)
            }
        }

        PalkaSection(stringResource(R.string.palka_current_network)) {
            Row(
                Modifier.fillMaxWidth().palkaCard().padding(15.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Icon(networkIcon(kind), null, tint = PalkaDesign.textPrimary, modifier = Modifier.size(22.dp))
                Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                    Text(Palka.networkTitle(kind), style = palkaText(15.sp, FontWeight.Bold))
                    Text(Palka.activeStrategyName, style = palkaText(11.sp, color = PalkaDesign.textMuted))
                }
            }
            PalkaSecondaryButton({
                Palka.saveCurrentStrategy(kind)
                message = context.getString(R.string.palka_network_profile_saved)
            }, enabled = kind != PalkaNetworkKind.Offline) {
                Text(stringResource(R.string.palka_save_network_profile))
            }
        }

        Palka.networkProfiles.forEach { profile ->
            Row(
                Modifier.fillMaxWidth().palkaCard().padding(14.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Icon(networkIcon(profile.networkKind), null, tint = PalkaDesign.textPrimary, modifier = Modifier.size(22.dp))
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                    Text(Palka.networkTitle(profile.networkKind), style = palkaText(14.sp, FontWeight.Bold))
                    Text(profile.strategyName, style = palkaText(11.sp, color = PalkaDesign.textMuted))
                }
                PalkaCompactPrimaryButton(
                    stringResource(R.string.palka_catalog_apply),
                    { Palka.applyNetworkProfile(profile.networkKind) },
                    enabled = !Palka.locked
                )
            }
        }

        message?.let { PalkaFeedbackBanner(it, PalkaFeedbackKind.Success) }
    }
}

// endregion

// region History

@Composable
fun HistoryScreen() {
    PalkaScaffold(stringResource(R.string.palka_history_title)) {
        PalkaFeatureHeader(stringResource(R.string.palka_history_heading), stringResource(R.string.palka_history_description), Icons.Rounded.History)
        if (Palka.library.isEmpty()) {
            Box(Modifier.fillMaxWidth().palkaCard().padding(18.dp), contentAlignment = Alignment.Center) {
                Text(stringResource(R.string.palka_history_empty), style = palkaText(14.sp, FontWeight.Medium, PalkaDesign.textSecondary))
            }
        }
        Palka.library.toList().forEach { record ->
            Column(
                Modifier.fillMaxWidth().palkaCard(selected = record.id == Palka.activeStrategyId).padding(15.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(record.name, style = palkaText(15.sp, FontWeight.Bold), modifier = Modifier.weight(1f))
                    if (record.isFavorite) Icon(Icons.Rounded.Star, null, tint = PalkaDesign.successText, modifier = Modifier.size(18.dp))
                }
                Text(
                    stringResource(
                        R.string.palka_history_reliability_format,
                        (record.reliability * 100).toInt(),
                        record.averageLatencyMs?.let { "$it ms" } ?: "—"
                    ),
                    style = palkaText(11.sp, color = PalkaDesign.textMuted, mono = true)
                )
                Row(verticalAlignment = Alignment.CenterVertically) {
                    PalkaCompactPrimaryButton(
                        stringResource(R.string.palka_catalog_apply),
                        { Palka.applyStrategy(record.id, record.name, record.commandTemplate) },
                        enabled = !Palka.locked && record.commandTemplate.isNotEmpty()
                    )
                    Box(Modifier.weight(1f))
                    PalkaCircleButton({ Palka.removeHistory(record.id) }) {
                        Icon(Icons.Rounded.DeleteOutline, null, tint = PalkaDesign.textSecondary, modifier = Modifier.size(18.dp))
                    }
                }
            }
        }
    }
}

// endregion
