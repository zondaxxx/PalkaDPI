package io.github.dovecoteescapee.byedpi.activities

import android.os.Bundle
import android.util.Log
import android.view.MenuItem
import android.widget.Button
import android.widget.ScrollView
import android.widget.TextView
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import io.github.dovecoteescapee.byedpi.R
import io.github.dovecoteescapee.byedpi.core.ByeDpiProxy
import io.github.dovecoteescapee.byedpi.core.ByeDpiProxyCmdPreferences
import io.github.dovecoteescapee.byedpi.core.ByeDpiProxyPreferences
import io.github.dovecoteescapee.byedpi.core.ByeDpiProxyUIPreferences
import io.github.dovecoteescapee.byedpi.utility.GoogleVideoDomainGenerator
import io.github.dovecoteescapee.byedpi.utility.getPreferences
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.net.HttpURLConnection
import java.net.InetSocketAddress
import java.net.Proxy
import java.net.URL

class TestActivity : AppCompatActivity() {
    private lateinit var sites: List<String>
    private lateinit var cmds: List<String>

    private var isTesting = false
    private lateinit var testJob: Job

    private lateinit var progressTextView: TextView
    private lateinit var resultsTextView: TextView
    private lateinit var startStopButton: Button

    private var originalCmdArgs: String? = null

    private val proxy = ByeDpiProxy()
    private var proxyJob: Job? = null
    private var proxyIp: String = "127.0.0.1"
    private var proxyPort: Int = 1080

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_proxy_test)

        startStopButton = findViewById(R.id.startStopButton)
        resultsTextView = findViewById(R.id.resultsTextView)
        progressTextView = findViewById(R.id.progressTextView)

        sites = loadSitesFromFile().toMutableList()
        cmds = loadCmdsFromFile()

        val domainGenerator = GoogleVideoDomainGenerator()
        lifecycleScope.launch {
            val autoGCS = domainGenerator.generateGoogleVideoDomain()
            if (autoGCS != null) {
                (sites as MutableList<String>).add(autoGCS)
                Log.i("TestActivity", "Added auto-generated Google domain: $autoGCS")
            } else {
                Log.e("TestActivity", "Failed to generate Google domain")
            }
        }

        originalCmdArgs = getPreferences().getString("byedpi_cmd_args", null)

        startStopButton.setOnClickListener {
            if (isTesting) {
                stopTesting()
            } else {
                startTesting()
            }
        }

        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                if (isTesting) {
                    stopTesting()
                }
                finish()
            }
        })

        supportActionBar?.setDisplayHomeAsUpEnabled(true)
    }

    override fun onOptionsItemSelected(item: MenuItem): Boolean = when (item.itemId) {
        android.R.id.home -> {
            onBackPressedDispatcher.onBackPressed()
            true
        }

        else -> super.onOptionsItemSelected(item)
    }

    private fun updateCmdInPreferences(cmd: String) {
        val sharedPreferences = getPreferences()
        val editor = sharedPreferences.edit()
        editor.putString("byedpi_cmd_args", cmd)
        editor.apply()
    }

    private fun getByeDpiPreferences(): ByeDpiProxyPreferences =
        ByeDpiProxyPreferences.fromSharedPreferences(getPreferences())

    private suspend fun checkSiteAccessibility(site: String): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                val connectProxy = Proxy(Proxy.Type.SOCKS, InetSocketAddress(proxyIp, proxyPort))

                val formattedUrl = if (!site.startsWith("http://") && !site.startsWith("https://")) {
                    "https://$site"
                } else {
                    site
                }

                val url = URL(formattedUrl)
                val connection = url.openConnection(connectProxy) as HttpURLConnection
                connection.connectTimeout = 2000
                connection.readTimeout = 2000

                val responseCode = connection.responseCode
                Log.i("CheckSite", "Response $site: $responseCode")
                true
            } catch (e: Exception) {
                Log.e("CheckSite", "Error $site: proxy", e)
                false
            }
        }
    }

    private fun loadSitesFromFile(): List<String> {
        val inputStream = assets.open("sites.txt")
        return inputStream.bufferedReader().useLines { it.toList() }
    }

    private fun loadCmdsFromFile(): List<String> {
        val inputStream = assets.open("cmds.txt")
        return inputStream.bufferedReader().useLines { it.toList() }
    }

    private fun appendTextToResults(text: String) {
        val scrollView = findViewById<ScrollView>(R.id.scrollView)

        resultsTextView.append(text)

        scrollView.post {
            scrollView.fullScroll(ScrollView.FOCUS_DOWN)
        }
    }

    private fun startTesting() {
        isTesting = true
        startStopButton.text = "Стоп"
        resultsTextView.text = ""
        progressTextView.text = ""

        testJob = lifecycleScope.launch {
            val successfulCmds = mutableListOf<String>()
            var cmdIndex = 0

            for (cmd in cmds) {
                cmdIndex++
                progressTextView.text = "Проверка $cmdIndex из ${cmds.size}"

                val successfulSites = mutableListOf<String>()

                appendTextToResults("$cmd:\n")

                startProxyWithCmd(cmd)

                val proxyStarted = waitForProxyToStart()
                if (!proxyStarted) {
                    appendTextToResults("Не удалось запустить прокси\n\n")
                    stopProxy()
                    continue
                }

                for (site in sites) {
                    val isAccessible = checkSiteAccessibility(site)
                    if (isAccessible) {
                        successfulSites.add(site)
                        appendTextToResults("$site - доступен\n")
                    } else {
                        appendTextToResults("$site - недоступен\n")
                    }
                }

                val successPercentage = (successfulSites.size * 100) / sites.size
                val logMessage = if (successPercentage >= 50) {
                    successfulCmds.add("$cmd ($successPercentage%)")
                    "Успех: $successPercentage%"
                } else {
                    "Провал: $successPercentage%"
                }

                appendTextToResults("$logMessage\n\n")
                stopProxy()
            }

            progressTextView.text = "Проверка завершена"
            appendTextToResults("Успешные команды:\n\n${successfulCmds.joinToString("\n\n")}")
            stopTesting()
        }
    }

    private fun stopTesting() {
        isTesting = false
        startStopButton.text = "Старт"

        if (::testJob.isInitialized && testJob.isActive) {
            testJob.cancel()
        }

        lifecycleScope.launch {
            stopProxy()
        }

        originalCmdArgs?.let {
            updateCmdInPreferences(it)
        }
    }

    private fun startProxyWithCmd(cmd: String) {
        updateCmdInPreferences(cmd)
        Log.i("TestDPI", "Starting test proxy with cmd: $cmd")
        val preferences = getByeDpiPreferences()

        proxyJob = lifecycleScope.launch(Dispatchers.IO) {
            try {
                val code = proxy.startProxy(preferences)

                when (preferences) {
                    is ByeDpiProxyUIPreferences -> {
                        proxyIp = preferences.ip
                        proxyPort = preferences.port
                    }
                    is ByeDpiProxyCmdPreferences -> {
                        proxyIp = "127.0.0.1"
                        proxyPort = 1080
                    }
                }

                Log.i("TestDPI", "Proxy stopped with code: $code")
            } catch (e: Exception) {
                Log.e("TestDPI", "Error starting proxy", e)
            }
        }
    }

    private suspend fun stopProxy() {
        Log.i("TestDPI", "Stopping test proxy")
        try {
            withContext(Dispatchers.IO) {
                proxy.stopProxy()
            }
            proxyJob = null
            Log.i("TestDPI", "Proxy stopped")
        } catch (e: Exception) {
            Log.e("TestDPI", "Error stopping proxy", e)
            proxyJob = null
        }
    }

    private suspend fun waitForProxyToStart(timeout: Long = 5000): Boolean {
        val startTime = System.currentTimeMillis()
        while (System.currentTimeMillis() - startTime < timeout) {
            if (isProxyRunning()) {
                return true
            }
            delay(100)
        }
        return false
    }

    private suspend fun isProxyRunning(): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                val socket = java.net.Socket()
                socket.connect(InetSocketAddress(proxyIp, proxyPort), 500)
                socket.close()
                true
            } catch (e: Exception) {
                false
            }
        }
    }
}

