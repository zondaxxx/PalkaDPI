package io.github.romanvht.byedpi.palka

import android.content.Intent
import android.net.VpnService
import android.os.Bundle
import android.view.View
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.ListView
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.core.content.edit
import androidx.lifecycle.lifecycleScope
import com.google.android.material.materialswitch.MaterialSwitch
import io.github.romanvht.byedpi.R
import io.github.romanvht.byedpi.activities.BaseActivity
import io.github.romanvht.byedpi.activities.TestActivity
import io.github.romanvht.byedpi.data.AppStatus
import io.github.romanvht.byedpi.data.Mode
import io.github.romanvht.byedpi.services.ServiceManager
import io.github.romanvht.byedpi.services.appStatus
import io.github.romanvht.byedpi.utility.HistoryUtils
import io.github.romanvht.byedpi.utility.getPreferences
import io.github.romanvht.byedpi.utility.mode
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * PalkaDPI catalog screen: signed online strategies, one-tap apply, and a
 * catalog-driven run of the built-in strategy tester.
 */
class PalkaCatalogActivity : BaseActivity() {

    private lateinit var statusView: TextView
    private lateinit var listView: ListView
    private lateinit var quicSwitch: MaterialSwitch
    private var strategies: List<OnlineStrategy> = emptyList()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_palka_catalog)
        setupToolbar()
        supportActionBar?.setDisplayHomeAsUpEnabled(true)
        supportActionBar?.title = getString(R.string.palka_catalog_title)

        statusView = findViewById(R.id.palkaCatalogStatus)
        listView = findViewById(R.id.palkaCatalogList)
        quicSwitch = findViewById(R.id.palkaQuicSwitch)

        val prefs = getPreferences()
        quicSwitch.isChecked = prefs.getBoolean(PalkaCatalog.PREF_BLOCK_QUIC, true)
        quicSwitch.setOnCheckedChangeListener { _, checked ->
            prefs.edit { putBoolean(PalkaCatalog.PREF_BLOCK_QUIC, checked) }
        }

        findViewById<Button>(R.id.palkaRefreshButton).setOnClickListener { refresh() }
        findViewById<Button>(R.id.palkaAutoButton).setOnClickListener { startCatalogTest() }

        listView.setOnItemClickListener { _, _, position, _ ->
            strategies.getOrNull(position)?.let { confirmApply(it) }
        }

        PalkaCatalog.loadCached(this)?.let { show(it, fromCache = true) }
        refresh()
    }

    override fun onSupportNavigateUp(): Boolean {
        finish()
        return true
    }

    private fun refresh() {
        statusView.text = getString(R.string.palka_catalog_loading)
        lifecycleScope.launch(Dispatchers.IO) {
            val result = runCatching { PalkaCatalog.refresh(this@PalkaCatalogActivity) }
            withContext(Dispatchers.Main) {
                result.onSuccess { show(it, fromCache = false) }
                    .onFailure { error ->
                        val cached = PalkaCatalog.loadCached(this@PalkaCatalogActivity)
                        if (cached != null) show(cached, fromCache = true)
                        statusView.text = getString(R.string.palka_catalog_error, error.message ?: "?")
                    }
            }
        }
    }

    private fun show(catalog: OnlineStrategyCatalog, fromCache: Boolean) {
        strategies = PalkaCatalog.usable(catalog)
        val activeId = getPreferences().getString(PalkaCatalog.PREF_ACTIVE_STRATEGY_ID, null)
        val rows = strategies.map { strategy ->
            val marker = if (strategy.id == activeId) "● " else ""
            val stability = strategy.displayStability.takeIf { it.isNotBlank() }?.let { " · $it" } ?: ""
            Row(marker + strategy.displayName + stability, strategy.displaySummary)
        }
        listView.adapter = object : ArrayAdapter<Row>(this, android.R.layout.simple_list_item_2, android.R.id.text1, rows) {
            override fun getView(position: Int, convertView: View?, parent: android.view.ViewGroup): View {
                val view = super.getView(position, convertView, parent)
                view.findViewById<TextView>(android.R.id.text1).text = rows[position].title
                view.findViewById<TextView>(android.R.id.text2).apply {
                    text = rows[position].subtitle
                    textSize = 12f
                }
                return view
            }
        }
        statusView.text = getString(
            if (fromCache) R.string.palka_catalog_cached else R.string.palka_catalog_loaded,
            catalog.generation, strategies.size, catalog.updatedAt
        )
    }

    private data class Row(val title: String, val subtitle: String) {
        override fun toString() = title
    }

    private fun confirmApply(strategy: OnlineStrategy) {
        val commandLine = PalkaCatalog.resolveCommandLine(this, strategy)
        AlertDialog.Builder(this)
            .setTitle(strategy.displayName)
            .setMessage(strategy.displaySummary + "\n\n" + commandLine.take(600) + if (commandLine.length > 600) "…" else "")
            .setPositiveButton(R.string.palka_catalog_apply) { _, _ -> apply(strategy, commandLine) }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }

    private fun apply(strategy: OnlineStrategy, commandLine: String) {
        val prefs = getPreferences()
        prefs.edit(commit = true) {
            putBoolean("byedpi_enable_cmd_settings", true)
            putString("byedpi_cmd_args", commandLine)
            putString(PalkaCatalog.PREF_ACTIVE_STRATEGY_ID, strategy.id)
            putString(PalkaCatalog.PREF_ACTIVE_STRATEGY_NAME, strategy.displayName)
        }
        HistoryUtils(this).addCommand(commandLine)
        HistoryUtils(this).renameCommand(commandLine, "PalkaDPI: " + strategy.displayName)

        val mode = prefs.mode()
        val restart = appStatus.first == AppStatus.Running &&
            !(mode == Mode.VPN && VpnService.prepare(this) != null)
        if (restart) ServiceManager.restart(this, mode)
        Toast.makeText(
            this,
            if (restart) R.string.service_restart else R.string.cmd_history_applied,
            Toast.LENGTH_SHORT
        ).show()
        PalkaCatalog.loadCached(this)?.let { show(it, fromCache = true) }
    }

    /**
     * Feeds every usable catalog strategy (resolved for the selected services)
     * into the app's own proxy tester as a custom command list, then opens it.
     * The tester restarts the core per strategy and ranks by site success.
     */
    private fun startCatalogTest() {
        if (strategies.isEmpty()) {
            Toast.makeText(this, R.string.palka_catalog_empty, Toast.LENGTH_SHORT).show()
            return
        }
        val lines = strategies.joinToString("\n") { PalkaCatalog.resolveCommandLine(this, it) }
        getPreferences().edit(commit = true) {
            putBoolean("byedpi_proxytest_usercommands", true)
            putString("byedpi_proxytest_commands", lines)
        }
        Toast.makeText(this, getString(R.string.palka_catalog_test_prepared, strategies.size), Toast.LENGTH_LONG).show()
        startActivity(Intent(this, TestActivity::class.java))
    }
}
