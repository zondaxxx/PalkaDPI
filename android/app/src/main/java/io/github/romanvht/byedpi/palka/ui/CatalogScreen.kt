package io.github.romanvht.byedpi.palka.ui

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.Undo
import androidx.compose.material.icons.rounded.Cancel
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Link
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.StarBorder
import androidx.compose.material3.Icon
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
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.github.romanvht.byedpi.R
import io.github.romanvht.byedpi.palka.OnlineStrategy
import io.github.romanvht.byedpi.palka.Palka
import io.github.romanvht.byedpi.palka.PalkaCatalog

@Composable
fun CatalogScreen() {
    var query by remember { mutableStateOf("") }
    var appliedId by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(Unit) { PalkaCatalog.load() }

    val filtered = PalkaCatalog.strategies.let { all ->
        val q = query.trim().lowercase()
        if (q.isEmpty()) all else all.filter { it.searchableText.contains(q) }
    }

    PalkaScaffold(stringResource(R.string.palka_catalog_title)) {
        Row(Modifier.palkaEntrance(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                Text(stringResource(R.string.palka_catalog_heading), style = palkaText(24.sp, FontWeight.Black, tracking = (-0.7).sp))
                Text(
                    when {
                        PalkaCatalog.updatedAt.isEmpty() -> stringResource(R.string.palka_catalog_internet_source)
                        PalkaCatalog.isUsingCache -> stringResource(R.string.palka_catalog_cached_format, PalkaCatalog.updatedAt)
                        else -> stringResource(R.string.palka_catalog_updated_format, PalkaCatalog.updatedAt)
                    },
                    style = palkaText(12.sp, color = PalkaDesign.textSecondary)
                )
            }
            PalkaCircleButton(
                onClick = PalkaCatalog::load,
                enabled = !PalkaCatalog.isLoading,
                contentDescription = stringResource(R.string.palka_catalog_refresh)
            ) {
                if (PalkaCatalog.isLoading) PalkaSpinner()
                else Icon(Icons.Rounded.Refresh, null, tint = PalkaDesign.textPrimary, modifier = Modifier.size(18.dp))
            }
        }

        SearchField(query, { query = it }, Modifier.palkaEntrance(50))

        if (Palka.vpnRunning) PalkaFeedbackBanner(stringResource(R.string.palka_catalog_stop_first), PalkaFeedbackKind.Error)
        PalkaCatalog.errorText?.let {
            PalkaFeedbackBanner(
                if (PalkaCatalog.strategies.isEmpty()) it else stringResource(R.string.palka_catalog_offline_cache),
                PalkaFeedbackKind.Error
            )
        }
        if (PalkaCatalog.canUsePreviousVersion) {
            PalkaSecondaryButton(PalkaCatalog::usePreviousVersion) {
                Icon(Icons.AutoMirrored.Rounded.Undo, null, modifier = Modifier.size(18.dp))
                Text(stringResource(R.string.palka_catalog_rollback))
            }
        }

        when {
            PalkaCatalog.isLoading && PalkaCatalog.strategies.isEmpty() -> Row(
                Modifier.fillMaxWidth().palkaCard().padding(18.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                PalkaSpinner()
                Text(stringResource(R.string.palka_catalog_loading), style = palkaText(14.sp, FontWeight.Medium, PalkaDesign.textSecondary))
            }
            filtered.isEmpty() -> Column(
                Modifier.fillMaxWidth().palkaCard().padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Icon(Icons.Rounded.Search, null, tint = PalkaDesign.textMuted, modifier = Modifier.size(24.dp))
                Text(stringResource(R.string.palka_catalog_empty), style = palkaText(14.sp, FontWeight.Medium, PalkaDesign.textSecondary))
            }
            else -> Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                filtered.forEachIndexed { index, strategy ->
                    Box(Modifier.palkaEntrance(minOf(index * 50, 300))) {
                        StrategyCard(strategy, appliedId == strategy.id) {
                            Palka.applyStrategy(strategy.id, strategy.displayName, strategy.commandArgs)
                            appliedId = strategy.id
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SearchField(value: String, onChange: (String) -> Unit, modifier: Modifier) {
    val shape = RoundedCornerShape(14.dp)
    Row(
        modifier
            .fillMaxWidth()
            .heightIn(min = 52.dp)
            .clip(shape)
            .background(Color.White.copy(alpha = 0.055f))
            .border(1.dp, PalkaDesign.border, shape)
            .padding(start = 14.dp, end = if (value.isEmpty()) 14.dp else 0.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Icon(Icons.Rounded.Search, null, tint = PalkaDesign.textMuted, modifier = Modifier.size(20.dp))
        Box(Modifier.weight(1f)) {
            if (value.isEmpty()) {
                Text(stringResource(R.string.palka_catalog_search_placeholder), style = palkaText(15.sp, color = PalkaDesign.textMuted), maxLines = 1)
            }
            BasicTextField(
                value = value,
                onValueChange = onChange,
                singleLine = true,
                textStyle = palkaText(15.sp),
                cursorBrush = SolidColor(Color.White),
                modifier = Modifier.fillMaxWidth()
            )
        }
        if (value.isNotEmpty()) {
            Box(Modifier.size(44.dp).palkaPressable { onChange("") }, contentAlignment = Alignment.Center) {
                Icon(Icons.Rounded.Cancel, stringResource(R.string.palka_catalog_clear_search), tint = PalkaDesign.textMuted, modifier = Modifier.size(18.dp))
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun StrategyCard(strategy: OnlineStrategy, justApplied: Boolean, onApply: () -> Unit) {
    val host = LocalHost.current
    val active = Palka.activeStrategyId == strategy.id
    val favorite = Palka.isFavorite(strategy.id)
    Column(
        Modifier.fillMaxWidth().palkaCard(selected = active || justApplied).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                Text(strategy.displayName, style = palkaText(17.sp, FontWeight.Bold))
                Text(strategy.displaySummary, style = palkaText(13.sp, color = PalkaDesign.textSecondary, lineHeight = 18.sp))
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                if (active || justApplied) {
                    Icon(Icons.Rounded.CheckCircle, null, tint = PalkaDesign.successText, modifier = Modifier.size(20.dp))
                }
                Box(
                    Modifier.size(44.dp).palkaPressable {
                        Palka.toggleFavorite(strategy.id, strategy.displayName, strategy.commandArgs)
                    },
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        if (favorite) Icons.Rounded.Star else Icons.Rounded.StarBorder,
                        stringResource(R.string.palka_catalog_favorite),
                        tint = if (favorite) PalkaDesign.successText else PalkaDesign.textMuted,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }
        }
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            strategy.services?.takeIf { it.isNotEmpty() }?.let { PalkaTag(it.joinToString(" + ")) }
            strategy.displayStability.takeIf { it.isNotBlank() }?.let { PalkaTag(it) }
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(
                Modifier
                    .weight(1f)
                    .heightIn(min = 44.dp)
                    .then(
                        strategy.sourceLink?.let { link ->
                            Modifier.palkaPressable { host.open(Intent(Intent.ACTION_VIEW, Uri.parse(link))) }
                        } ?: Modifier
                    ),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                if (strategy.sourceLink != null) {
                    Icon(Icons.Rounded.Link, null, tint = PalkaDesign.textMuted, modifier = Modifier.size(14.dp))
                    Text(
                        strategy.sourceName.orEmpty(),
                        style = palkaText(11.sp, FontWeight.Medium, PalkaDesign.textMuted),
                        maxLines = 1, overflow = TextOverflow.Ellipsis
                    )
                }
            }
            PalkaCompactPrimaryButton(
                stringResource(if (active || justApplied) R.string.palka_catalog_applied else R.string.palka_catalog_apply),
                onApply,
                enabled = !Palka.vpnRunning && !active
            )
        }
    }
}
