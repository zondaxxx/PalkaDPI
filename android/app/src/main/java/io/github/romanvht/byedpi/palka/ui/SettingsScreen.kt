package io.github.romanvht.byedpi.palka.ui

import android.content.Intent
import android.net.Uri
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Apps
import androidx.compose.material.icons.rounded.AutoFixHigh
import androidx.compose.material.icons.rounded.Build
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.CloudDownload
import androidx.compose.material.icons.rounded.Code
import androidx.compose.material.icons.rounded.DataObject
import androidx.compose.material.icons.rounded.FavoriteBorder
import androidx.compose.material.icons.rounded.GridView
import androidx.compose.material.icons.rounded.History
import androidx.compose.material.icons.rounded.Hub
import androidx.compose.material.icons.rounded.Info
import androidx.compose.material.icons.rounded.MonitorHeart
import androidx.compose.material.icons.rounded.Speed
import androidx.compose.material.icons.rounded.Terminal
import androidx.compose.material.icons.automirrored.rounded.ViewList
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.github.romanvht.byedpi.BuildConfig
import io.github.romanvht.byedpi.R
import io.github.romanvht.byedpi.activities.MainActivity
import io.github.romanvht.byedpi.activities.SettingsActivity
import io.github.romanvht.byedpi.activities.TestActivity
import io.github.romanvht.byedpi.data.Mode
import io.github.romanvht.byedpi.palka.Palka
import io.github.romanvht.byedpi.palka.PalkaCatalog
import io.github.romanvht.byedpi.palka.PalkaServices
import kotlinx.coroutines.delay

private const val SOURCE_URL = "https://github.com/zondaxxx/PalkaDPI"
private const val ACKNOWLEDGEMENTS_URL = "https://github.com/zondaxxx/PalkaDPI/blob/main/ACKNOWLEDGEMENTS.md"

/** The short settings route for most people; expert tools live one level deeper. */
@Composable
fun SettingsScreen() {
    val nav = LocalNavigator.current
    val host = LocalHost.current
    var presetApplied by remember { mutableStateOf(false) }
    LaunchedEffect(presetApplied) {
        if (presetApplied) {
            delay(2400)
            presetApplied = false
        }
    }

    PalkaScaffold(stringResource(R.string.palka_general_settings), spacing = PalkaDesign.sectionSpacing) {
        Box(Modifier.palkaEntrance()) {
            PalkaHeaderText(stringResource(R.string.palka_simple_settings_title), stringResource(R.string.palka_simple_settings_description))
        }
        Box(Modifier.palkaEntrance(50)) {
            PalkaSection(stringResource(R.string.palka_quick_setup_section)) {
                PalkaNavRow(stringResource(R.string.palka_auto_title), stringResource(R.string.palka_auto_settings_description), Icons.Rounded.AutoFixHigh) {
                    nav.push(PalkaRoute.Automation)
                }
                PalkaNavRow(
                    stringResource(R.string.palka_apply_preset), stringResource(R.string.palka_apply_preset_description),
                    Icons.Rounded.CheckCircle, showsDisclosure = false
                ) {
                    Palka.applyRecommendedPreset()
                    presetApplied = true
                }
                AnimatedVisibility(presetApplied, enter = fadeIn(), exit = fadeOut()) {
                    PalkaFeedbackBanner(stringResource(R.string.palka_preset_applied), PalkaFeedbackKind.Success)
                }
            }
        }
        Box(Modifier.palkaEntrance(100)) {
            PalkaSection(stringResource(R.string.palka_strategies_section)) {
                PalkaNavRow(
                    stringResource(R.string.palka_services_title),
                    PalkaServices.selected(Palka.selectedServiceIds).joinToString(", ") { it.name },
                    Icons.Rounded.GridView
                ) { nav.push(PalkaRoute.Services) }
                PalkaNavRow(
                    stringResource(R.string.palka_catalog_title),
                    stringResource(R.string.palka_current_strategy_format, Palka.activeStrategyName),
                    Icons.Rounded.CloudDownload
                ) { nav.push(PalkaRoute.Catalog) }
                PalkaNavRow(
                    stringResource(R.string.palka_history_title),
                    stringResource(R.string.palka_history_settings_description),
                    Icons.Rounded.History
                ) { nav.push(PalkaRoute.History) }
            }
        }
        Box(Modifier.palkaEntrance(150)) {
            PalkaSection(stringResource(R.string.palka_connection_section)) {
                ModePicker()
                PalkaNavRow(stringResource(R.string.palka_apps_title), appsSummary(), Icons.Rounded.Apps) {
                    nav.push(PalkaRoute.Apps)
                }
                PalkaNavRow(
                    stringResource(R.string.palka_diagnostics_title),
                    stringResource(R.string.palka_diagnostics_settings_description),
                    Icons.Rounded.MonitorHeart
                ) { nav.push(PalkaRoute.Diagnostics) }
                PalkaNavRow(
                    stringResource(R.string.palka_network_profiles_title),
                    stringResource(R.string.palka_android_networks_settings_description),
                    Icons.Rounded.Hub
                ) { nav.push(PalkaRoute.Networks) }
            }
        }
        Box(Modifier.palkaEntrance(200)) {
            PalkaSection(stringResource(R.string.palka_advanced_section)) {
                PalkaNavRow(
                    stringResource(R.string.palka_advanced_settings),
                    stringResource(R.string.palka_advanced_settings_description),
                    Icons.Rounded.Build
                ) { nav.push(PalkaRoute.Advanced) }
            }
        }
        Box(Modifier.palkaEntrance(250)) {
            PalkaSection(stringResource(R.string.palka_about_section)) {
                PalkaNavRow(stringResource(R.string.palka_about_source_code), "GitHub", Icons.Rounded.Code) {
                    host.open(Intent(Intent.ACTION_VIEW, Uri.parse(SOURCE_URL)))
                }
                PalkaNavRow(
                    stringResource(R.string.palka_acknowledgements),
                    stringResource(R.string.palka_acknowledgements_description),
                    Icons.Rounded.FavoriteBorder
                ) { host.open(Intent(Intent.ACTION_VIEW, Uri.parse(ACKNOWLEDGEMENTS_URL))) }
                PalkaNavRow(
                    stringResource(R.string.palka_about_version),
                    "${BuildConfig.VERSION_NAME} · ${stringResource(R.string.palka_about_engine)} ${PalkaCatalog.ENGINE_VERSION}",
                    Icons.Rounded.Info,
                    showsDisclosure = false
                )
            }
        }
    }
}

@Composable
private fun appsSummary(): String = when (Palka.appListType) {
    "blacklist" -> stringResource(R.string.palka_apps_description_blacklist, Palka.selectedAppsCount)
    "whitelist" -> stringResource(R.string.palka_apps_description_whitelist, Palka.selectedAppsCount)
    else -> stringResource(R.string.palka_apps_description_all)
}

/** VPN / proxy switch as a two-segment control (Android-only: iOS always tunnels). */
@Composable
private fun ModePicker() {
    Column(
        Modifier.fillMaxWidth().palkaCard().padding(6.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        PalkaSegmented(
            options = listOf(stringResource(R.string.palka_mode_vpn), stringResource(R.string.palka_mode_proxy)),
            selected = if (Palka.mode == Mode.VPN) 0 else 1,
            enabled = !Palka.vpnRunning
        ) { Palka.updateMode(if (it == 0) Mode.VPN else Mode.Proxy) }
        Text(
            stringResource(if (Palka.mode == Mode.VPN) R.string.palka_mode_vpn_description else R.string.palka_mode_proxy_description),
            style = palkaText(11.sp, color = PalkaDesign.textMuted),
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp)
        )
    }
}

@Composable
fun PalkaSegmented(options: List<String>, selected: Int, enabled: Boolean = true, onSelect: (Int) -> Unit) {
    val shape = RoundedCornerShape(12.dp)
    Row(
        Modifier.fillMaxWidth().clip(shape).background(Color.White.copy(alpha = 0.04f)).padding(3.dp),
        horizontalArrangement = Arrangement.spacedBy(3.dp)
    ) {
        options.forEachIndexed { index, title ->
            val active = index == selected
            Box(
                Modifier
                    .weight(1f)
                    .heightIn(min = 40.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(if (active) Color.White.copy(alpha = 0.14f) else Color.Transparent)
                    .then(if (active) Modifier.border(1.dp, PalkaDesign.borderStrong, RoundedCornerShape(10.dp)) else Modifier)
                    .palkaPressable(enabled = enabled && !active) { onSelect(index) },
                contentAlignment = Alignment.Center
            ) {
                Text(
                    title,
                    style = palkaText(13.sp, FontWeight.SemiBold, if (active) PalkaDesign.textPrimary else PalkaDesign.textMuted),
                    textAlign = TextAlign.Center
                )
            }
        }
    }
}

/** Split tunnelling: which apps go through the bypass (Android-only). */
@Composable
fun AppsScreen() {
    val host = LocalHost.current
    val context = LocalContext.current
    val running = Palka.vpnRunning
    PalkaScaffold(stringResource(R.string.palka_apps_title)) {
        PalkaFeatureHeader(stringResource(R.string.palka_apps_heading), stringResource(R.string.palka_apps_screen_description), Icons.Rounded.Apps)
        if (running) PalkaFeedbackBanner(stringResource(R.string.palka_services_stop_first), PalkaFeedbackKind.Error)
        val types = listOf("disable", "blacklist", "whitelist")
        PalkaSegmented(
            options = listOf(
                stringResource(R.string.palka_apps_mode_all),
                stringResource(R.string.palka_apps_mode_blacklist),
                stringResource(R.string.palka_apps_mode_whitelist)
            ),
            selected = types.indexOf(Palka.appListType).coerceAtLeast(0),
            enabled = !running
        ) { Palka.updateAppListType(types[it]) }
        Text(appsSummary(), style = palkaText(12.sp, color = PalkaDesign.textSecondary), modifier = Modifier.padding(start = 4.dp))
        if (Palka.appListType != "disable") {
            PalkaPrimaryButton(onClick = {
                host.open(Intent(context, SettingsActivity::class.java).putExtra("open_fragment", "apps"))
            }, enabled = !running) {
                Text(stringResource(R.string.palka_apps_pick))
            }
        }
    }
}

/** Expert tools: the classic ByeByeDPI screens, which keep every engine knob. */
@Composable
fun AdvancedScreen() {
    val host = LocalHost.current
    val context = LocalContext.current
    PalkaScaffold(stringResource(R.string.palka_advanced_settings), spacing = PalkaDesign.sectionSpacing) {
        Box(Modifier.palkaEntrance()) {
            PalkaHeaderText(stringResource(R.string.palka_expert_title), stringResource(R.string.palka_expert_description))
        }
        Box(Modifier.palkaEntrance(50)) {
            PalkaSection("ByeDPI") {
                PalkaNavRow(stringResource(R.string.palka_command_editor), stringResource(R.string.palka_command_editor_description), Icons.Rounded.Terminal) {
                    host.open(Intent(context, SettingsActivity::class.java).putExtra("open_fragment", "cmd"))
                }
                PalkaNavRow(stringResource(R.string.palka_strategy_tester), stringResource(R.string.palka_strategy_tester_description), Icons.Rounded.Speed) {
                    host.open(Intent(context, TestActivity::class.java))
                }
                PalkaNavRow(stringResource(R.string.palka_all_parameters), stringResource(R.string.palka_all_parameters_description), Icons.Rounded.DataObject) {
                    host.open(Intent(context, SettingsActivity::class.java))
                }
            }
        }
        Box(Modifier.palkaEntrance(100)) {
            PalkaSection("ByeByeDPI") {
                PalkaNavRow(stringResource(R.string.palka_classic_screen), stringResource(R.string.palka_classic_screen_description), Icons.AutoMirrored.Rounded.ViewList) {
                    host.open(Intent(context, MainActivity::class.java))
                }
            }
        }
        Text(
            stringResource(R.string.palka_quick_tile_hint),
            style = palkaText(11.sp, color = PalkaDesign.textMuted),
            modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp)
        )
    }
}
