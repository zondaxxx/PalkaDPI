package io.github.romanvht.byedpi.palka.ui

import android.content.Intent
import android.graphics.Color as AndroidColor
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBackIos
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.edit
import io.github.romanvht.byedpi.R
import io.github.romanvht.byedpi.palka.Palka
import io.github.romanvht.byedpi.palka.PalkaAutomation
import io.github.romanvht.byedpi.palka.PalkaCatalog
import io.github.romanvht.byedpi.utility.PermissionUtils
import io.github.romanvht.byedpi.utility.ShortcutUtils
import io.github.romanvht.byedpi.utility.getPreferences
import kotlinx.coroutines.CompletableDeferred

enum class PalkaRoute {
    Home, Settings, Automation, Services, Catalog, History, Diagnostics, Networks, Apps, Advanced
}

class PalkaNavigator {
    val stack = mutableStateListOf(PalkaRoute.Home)
    var forward by mutableStateOf(true); private set
    val current get() = stack.last()
    fun push(route: PalkaRoute) { forward = true; stack.add(route) }
    fun pop(): Boolean {
        if (stack.size <= 1) return false
        forward = false
        stack.removeAt(stack.lastIndex)
        return true
    }
}

/** Things screens need from the activity: VPN consent, alerts, external screens. */
interface PalkaHost {
    fun connect()
    fun disconnect()
    fun open(intent: Intent)
    fun alert(title: String, message: String?)
}

val LocalNavigator = compositionLocalOf { PalkaNavigator() }
val LocalHost = compositionLocalOf<PalkaHost> { error("no host") }

/**
 * PalkaDPI main screen on Android: the same SwiftUI layout as the iOS app,
 * rebuilt in Compose on top of the ByeByeDPI engine and services.
 */
class PalkaActivity : ComponentActivity(), PalkaHost {
    private var alertState by mutableStateOf<Pair<String, String?>?>(null)
    private var pendingConsent: CompletableDeferred<Boolean>? = null
    private var connectAfterConsent = false

    private val vpnConsent = registerForActivityResult(ActivityResultContracts.StartActivityForResult()) {
        val granted = it.resultCode == RESULT_OK
        pendingConsent?.complete(granted)
        pendingConsent = null
        if (connectAfterConsent) {
            connectAfterConsent = false
            if (granted) Palka.start()
            else alert(getString(R.string.palka_start_error_title), getString(R.string.palka_vpn_permission_denied))
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(AndroidColor.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.dark(AndroidColor.TRANSPARENT)
        )
        super.onCreate(savedInstanceState)
        Palka.init(this)
        PalkaCatalog.loadCache()
        PalkaAutomation.requestVpnConsent = {
            val deferred = CompletableDeferred<Boolean>()
            pendingConsent = deferred
            val intent = Palka.vpnConsentIntent()
            if (intent == null) deferred.complete(true) else vpnConsent.launch(intent)
            deferred.await()
        }

        requestFirstRunPermissions()
        if (savedInstanceState == null && Palka.connectOnLaunch) connect()
        ShortcutUtils.update(this)

        val navigator = PalkaNavigator()
        setContent {
            MaterialTheme(
                colorScheme = darkColorScheme(
                    primary = Color.White,
                    onPrimary = PalkaDesign.onPrimary,
                    background = PalkaDesign.background,
                    surface = Color(0xFF16161C),
                    onSurface = PalkaDesign.textPrimary
                )
            ) {
                CompositionLocalProvider(LocalNavigator provides navigator, LocalHost provides this) {
                    Box(Modifier.fillMaxSize()) {
                        PalkaBackground()
                        BackHandler(enabled = navigator.stack.size > 1) { navigator.pop() }
                        AnimatedContent(
                            targetState = navigator.current,
                            transitionSpec = {
                                val dir = if (navigator.forward) 1 else -1
                                (slideInHorizontally(tween(320, easing = PalkaDesign.easing)) { it * dir / 3 } + fadeIn(tween(220)))
                                    .togetherWith(slideOutHorizontally(tween(320, easing = PalkaDesign.easing)) { -it * dir / 4 } + fadeOut(tween(160)))
                            },
                            label = "nav"
                        ) { route -> PalkaScreen(route) }
                        alertState?.let { (title, message) ->
                            AlertDialog(
                                onDismissRequest = { alertState = null },
                                confirmButton = {
                                    TextButton(onClick = { alertState = null }) {
                                        Text(stringResource(R.string.palka_ok), color = Color.White)
                                    }
                                },
                                title = { Text(title) },
                                text = message?.let { { Text(it) } },
                                containerColor = Color(0xFF16161C),
                                titleContentColor = PalkaDesign.textPrimary,
                                textContentColor = PalkaDesign.textSecondary
                            )
                        }
                    }
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        Palka.refreshExternalSettings()
        Palka.syncStatus()
    }

    override fun connect() {
        val consent = Palka.vpnConsentIntent()
        if (consent != null) {
            connectAfterConsent = true
            vpnConsent.launch(consent)
        } else {
            Palka.start()
        }
    }

    override fun disconnect() = Palka.stop()

    override fun open(intent: Intent) {
        runCatching { startActivity(intent) }
    }

    override fun alert(title: String, message: String?) {
        alertState = title to message
    }

    private fun requestFirstRunPermissions() {
        val prefs = getPreferences()
        if (!PermissionUtils.hasNotificationPermission(this)) {
            PermissionUtils.requestNotificationPermission(this, 1)
        } else if (!prefs.getBoolean("battery_optimization_requested", false) &&
            !PermissionUtils.isBatteryOptimizationDisabled(this)
        ) {
            PermissionUtils.requestBatteryOptimization(this)
            prefs.edit { putBoolean("battery_optimization_requested", true) }
        }
    }
}

@Composable
private fun PalkaScreen(route: PalkaRoute) {
    when (route) {
        PalkaRoute.Home -> HomeScreen()
        PalkaRoute.Settings -> SettingsScreen()
        PalkaRoute.Automation -> AutomationScreen()
        PalkaRoute.Services -> ServiceSelectionScreen()
        PalkaRoute.Catalog -> CatalogScreen()
        PalkaRoute.History -> HistoryScreen()
        PalkaRoute.Diagnostics -> DiagnosticsScreen()
        PalkaRoute.Networks -> NetworkProfilesScreen()
        PalkaRoute.Apps -> AppsScreen()
        PalkaRoute.Advanced -> AdvancedScreen()
    }
}

/** Inline navigation bar: back chevron on the left, centered title (iOS inline title). */
@Composable
fun PalkaTopBar(title: String) {
    val navigator = LocalNavigator.current
    Box(
        Modifier.fillMaxWidth().height(48.dp).padding(horizontal = 6.dp),
        contentAlignment = Alignment.Center
    ) {
        Row(
            Modifier.align(Alignment.CenterStart)
                .palkaPressable { navigator.pop() }
                .padding(horizontal = 10.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                Icons.AutoMirrored.Rounded.ArrowBackIos, stringResource(R.string.palka_back),
                tint = PalkaDesign.textPrimary, modifier = Modifier.size(18.dp)
            )
        }
        Text(
            title,
            style = palkaText(17.sp, FontWeight.SemiBold),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(horizontal = 56.dp)
        )
    }
}

/** FeatureContainer: top bar + scrolling column with the standard paddings. */
@Composable
fun PalkaScaffold(
    title: String?,
    spacing: androidx.compose.ui.unit.Dp = 18.dp,
    content: @Composable ColumnScope.() -> Unit
) {
    Column(Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.safeDrawing)) {
        if (title != null) PalkaTopBar(title)
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = PalkaDesign.screenPadding)
                .padding(top = if (title != null) 12.dp else 18.dp, bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(spacing)
        ) {
            content()
        }
    }
}
