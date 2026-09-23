package io.github.romanvht.byedpi.palka

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.Proxy
import java.net.Socket
import java.net.SocketTimeoutException
import java.net.URL
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.SSLSocket
import javax.net.ssl.SSLSocketFactory

enum class PalkaProbeStatus { Idle, Testing, Reachable, Partial, Unavailable }

data class PalkaServiceProbe(
    val id: String,
    val name: String,
    val status: PalkaProbeStatus,
    val latencyMs: Int? = null,
    val dnsMs: Int? = null,
    val tlsMs: Int? = null,
    val successfulAttempts: Int = 0,
    val totalAttempts: Int = 0,
    val statusCode: Int? = null,
    val checkedAt: Long? = null,
    val errorText: String? = null,
    val bulkKbps: Int? = null,
    val bulkReceivedKb: Int? = null,
    /** The bulk transfer started and then froze: the TSPU "16-20 KB then silence" signature. */
    val bulkStalled: Boolean? = null
)

private class Measurement(
    val succeeded: Boolean,
    val totalMs: Int? = null,
    val statusCode: Int? = null,
    val errorText: String? = null,
    val isBulk: Boolean = false,
    val receivedBytes: Int = 0,
    val stalled: Boolean = false,
    val kbps: Int? = null
)

/**
 * HTTP probes that decide whether a service works, ported from PalkaHTTPProbe
 * on iOS: a small marker-checked request plus a 256 KB Range download on the
 * real delivery host with a 4 s stall watchdog. `proxyPort` routes the probe
 * through a local ByeDPI SOCKS listener; null goes direct (the app itself is
 * excluded from its own VPN, so "direct" is the raw, unbypassed path).
 */
object PalkaProbe {
    private const val BULK_RANGE_BYTES = 256 * 1024
    private const val BULK_PROOF_BYTES = 20 * 1024
    private const val BULK_STALL_MS = 4_000
    private const val USER_AGENT =
        "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0 Mobile Safari/537.36"

    private fun proxy(port: Int?): Proxy =
        if (port == null) Proxy.NO_PROXY else Proxy(Proxy.Type.SOCKS, InetSocketAddress("127.0.0.1", port))

    private fun hostMatches(expected: String, final: String, allowSameSite: Boolean): Boolean {
        if (final == expected || final.endsWith(".$expected")) return true
        if (!allowSameSite) return false
        val root = { h: String -> h.split('.').takeLast(2).joinToString(".") }
        return root(expected) == root(final)
    }

    private fun small(service: PalkaService, port: Int?, timeoutMs: Int): Measurement {
        val started = System.nanoTime()
        var connection: HttpURLConnection? = null
        return try {
            connection = (URL(service.probeUrl).openConnection(proxy(port)) as HttpURLConnection).apply {
                connectTimeout = timeoutMs
                readTimeout = timeoutMs
                instanceFollowRedirects = true
                useCaches = false
                setRequestProperty("Cache-Control", "no-cache")
                setRequestProperty("Range", "bytes=0-${BULK_RANGE_BYTES - 1}")
                setRequestProperty("Connection", "close")
            }
            val code = connection.responseCode
            val body = if (code in 200..299) readLimited(connection.inputStream, 128 * 1024) else ""
            val expectedHost = URL(service.probeUrl).host.lowercase()
            val finalHost = connection.url.host.lowercase()
            val ok = code in 200..299 && hostMatches(expectedHost, finalHost, false) &&
                (service.marker == null || body.contains(service.marker, ignoreCase = true))
            Measurement(
                succeeded = ok,
                totalMs = if (ok) elapsedMs(started) else null,
                statusCode = code,
                errorText = if (ok) null else "HTTP $code"
            )
        } catch (e: Exception) {
            Measurement(false, errorText = e.javaClass.simpleName + (e.message?.let { ": $it" } ?: ""))
        } finally {
            connection?.disconnect()
        }
    }

    private fun bulk(service: PalkaService, port: Int?, timeoutMs: Int): Measurement {
        val target = service.bulkUrl ?: service.probeUrl
        val requestStartedAt = System.currentTimeMillis()
        val deadline = requestStartedAt + timeoutMs
        var received = 0
        var firstByteAt = 0L
        var lastDataAt = 0L
        var connection: HttpURLConnection? = null
        return try {
            connection = (URL(target).openConnection(proxy(port)) as HttpURLConnection).apply {
                connectTimeout = timeoutMs
                // The read timeout is the stall watchdog: no bytes for 4 s = frozen flow.
                readTimeout = BULK_STALL_MS
                instanceFollowRedirects = true
                useCaches = false
                setRequestProperty("Range", "bytes=0-${BULK_RANGE_BYTES - 1}")
                setRequestProperty("User-Agent", USER_AGENT)
                setRequestProperty("Cache-Control", "no-cache")
                setRequestProperty("Connection", "close")
            }
            val code = connection.responseCode
            val total = connection.getHeaderField("Content-Range")?.substringAfterLast('/')?.toIntOrNull()
                ?: connection.contentLength.takeIf { it > 0 }
            val expected = minOf(total ?: BULK_RANGE_BYTES, BULK_RANGE_BYTES)
            val hostOk = hostMatches(URL(target).host.lowercase(), connection.url.host.lowercase(), true)
            if (code !in 200..299 || !hostOk) {
                return Measurement(false, statusCode = code, errorText = "HTTP $code", isBulk = true)
            }
            val buffer = ByteArray(16 * 1024)
            connection.inputStream.use { input ->
                while (received < BULK_RANGE_BYTES && System.currentTimeMillis() < deadline) {
                    val n = input.read(buffer)
                    if (n < 0) break
                    val now = System.currentTimeMillis()
                    if (firstByteAt == 0L) firstByteAt = now
                    lastDataAt = now
                    received += n
                }
            }
            val proof = minOf(expected, BULK_PROOF_BYTES)
            val ok = received >= proof
            // From the request start: a body that fits in the socket buffer arrives
            // "instantly" between first and last byte and would report absurd speeds.
            val kbps = if (ok && firstByteAt > 0) {
                val seconds = maxOf(0.05, (lastDataAt - requestStartedAt) / 1000.0)
                (received / 1024.0 / seconds).toInt()
            } else null
            Measurement(
                succeeded = ok, statusCode = code, isBulk = true, receivedBytes = received,
                stalled = !ok && received > 0, kbps = kbps,
                errorText = if (ok) null else "Transfer stalled after ${received / 1024} KB"
            )
        } catch (e: SocketTimeoutException) {
            Measurement(
                false, isBulk = true, receivedBytes = received, stalled = received > 0,
                errorText = if (received > 0) "Transfer stalled after ${received / 1024} KB" else "Timed out"
            )
        } catch (e: Exception) {
            Measurement(
                false, isBulk = true, receivedBytes = received, stalled = received > 0,
                errorText = e.javaClass.simpleName + (e.message?.let { ": $it" } ?: "")
            )
        } finally {
            connection?.disconnect()
        }
    }

    /** System resolver time for the probe host (the app is outside its own tunnel). */
    private fun dnsMs(host: String): Int? = runCatching {
        val started = System.nanoTime()
        InetAddress.getAllByName(host)
        elapsedMs(started)
    }.getOrNull()

    /** TCP connect + TLS handshake to the probe host, through the SOCKS core when given. */
    private fun tlsMs(host: String, port: Int?, timeoutMs: Int): Int? = runCatching {
        val raw = Socket(proxy(port))
        raw.soTimeout = timeoutMs
        try {
            raw.connect(
                if (port == null) InetSocketAddress(host, 443) else InetSocketAddress.createUnresolved(host, 443),
                timeoutMs
            )
            val started = System.nanoTime()
            val ssl = (SSLSocketFactory.getDefault() as SSLSocketFactory)
                .createSocket(raw, host, 443, true) as SSLSocket
            ssl.use {
                it.startHandshake()
                if (!HttpsURLConnection.getDefaultHostnameVerifier().verify(host, it.session)) return null
                elapsedMs(started)
            }
        } finally {
            runCatching { raw.close() }
        }
    }.getOrNull()

    private fun elapsedMs(startNanos: Long) = maxOf(1, ((System.nanoTime() - startNanos) / 1_000_000).toInt())

    private fun readLimited(input: InputStream, limit: Int): String = input.use {
        val out = java.io.ByteArrayOutputStream()
        val buffer = ByteArray(8192)
        while (out.size() < limit) {
            val n = it.read(buffer)
            if (n < 0) break
            out.write(buffer, 0, n)
        }
        out.toString("UTF-8")
    }

    /**
     * Probes every target in parallel. `attempts` small probes per service plus
     * one bulk probe when the service has a bulk target. `timings` adds the
     * separate DNS and TLS measurements shown on the diagnostics screen.
     */
    suspend fun probe(
        targets: List<PalkaService>,
        proxyPort: Int?,
        attempts: Int,
        includeBulk: Boolean,
        timings: Boolean,
        smallTimeoutMs: Int = 7_000,
        bulkTimeoutMs: Int = 12_000
    ): List<PalkaServiceProbe> = coroutineScope {
        val safeAttempts = attempts.coerceIn(1, 4)
        targets.map { service ->
            async(Dispatchers.IO) {
                val smalls = (0 until safeAttempts).map {
                    async(Dispatchers.IO) { small(service, proxyPort, smallTimeoutMs) }
                }
                val bulkJob = if (includeBulk && service.bulkUrl != null) {
                    async(Dispatchers.IO) { bulk(service, proxyPort, bulkTimeoutMs) }
                } else null
                val host = URL(service.probeUrl).host
                val dns = if (timings) async(Dispatchers.IO) { dnsMs(host) } else null
                val tls = if (timings) async(Dispatchers.IO) { tlsMs(host, proxyPort, smallTimeoutMs) } else null
                aggregate(
                    service, smalls.awaitAll(), bulkJob?.await(), safeAttempts,
                    dns?.await(), tls?.await()
                )
            }
        }.awaitAll()
    }

    private fun aggregate(
        service: PalkaService,
        small: List<Measurement>,
        bulk: Measurement?,
        attempts: Int,
        dns: Int?,
        tls: Int?
    ): PalkaServiceProbe {
        val successful = small.filter { it.succeeded }
        val bulkStalled = bulk?.let { it.stalled || (!it.succeeded && it.receivedBytes > 0) }
        val status = when {
            successful.size == attempts && bulk?.succeeded != false -> PalkaProbeStatus.Reachable
            successful.isNotEmpty() || bulk?.succeeded == true -> PalkaProbeStatus.Partial
            else -> PalkaProbeStatus.Unavailable
        }
        var error = (small + listOfNotNull(bulk)).mapNotNull { it.errorText }.lastOrNull()
        if (bulkStalled == true) bulk?.errorText?.let { error = it }
        return PalkaServiceProbe(
            id = service.id,
            name = service.name,
            status = status,
            latencyMs = median(successful.mapNotNull { it.totalMs }),
            dnsMs = dns,
            tlsMs = tls,
            successfulAttempts = successful.size,
            totalAttempts = attempts,
            statusCode = successful.mapNotNull { it.statusCode }.lastOrNull()
                ?: (small + listOfNotNull(bulk)).mapNotNull { it.statusCode }.lastOrNull(),
            checkedAt = System.currentTimeMillis(),
            errorText = error,
            bulkKbps = bulk?.kbps,
            bulkReceivedKb = bulk?.let { it.receivedBytes / 1024 },
            bulkStalled = bulkStalled
        )
    }

    fun median(values: List<Int>): Int? {
        if (values.isEmpty()) return null
        val sorted = values.sorted()
        return if (sorted.size % 2 == 1) sorted[sorted.size / 2]
        else (sorted[sorted.size / 2 - 1] + sorted[sorted.size / 2]) / 2
    }
}

/** Home "service response" card and the diagnostics screen (ServiceDiagnosticsMonitor on iOS). */
object PalkaDiagnostics {
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private var job: Job? = null

    var services by mutableStateOf(emptyList<PalkaServiceProbe>()); private set
    var isRefreshing by mutableStateOf(false); private set

    fun ensureIdle() {
        if (services.isEmpty()) {
            services = PalkaServices.diagnosticTargets(Palka.selectedServiceIds, Palka.customDomains)
                .map { PalkaServiceProbe(it.id, it.name, PalkaProbeStatus.Idle) }
        }
    }

    fun refresh(
        attempts: Int = 2,
        includeBulk: Boolean = true,
        timings: Boolean = false,
        completion: ((List<PalkaServiceProbe>) -> Unit)? = null
    ) {
        job?.cancel()
        val targets = PalkaServices.diagnosticTargets(Palka.selectedServiceIds, Palka.customDomains)
        services = targets.map { PalkaServiceProbe(it.id, it.name, PalkaProbeStatus.Testing, totalAttempts = attempts) }
        isRefreshing = true
        Palka.syncStatus()
        // Through the running core when connected, raw network otherwise.
        val port = if (Palka.vpnRunning) Palka.proxyPort else null
        job = scope.launch {
            val results = withContext(Dispatchers.IO) {
                withTimeoutOrNull(40_000) {
                    PalkaProbe.probe(targets, port, attempts, includeBulk, timings)
                }
            } ?: targets.map { PalkaServiceProbe(it.id, it.name, PalkaProbeStatus.Unavailable, errorText = "timeout") }
            services = results
            isRefreshing = false
            completion?.invoke(results)
        }
    }
}
