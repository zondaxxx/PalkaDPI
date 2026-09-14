package io.github.romanvht.byedpi.palka

import android.content.Context
import android.util.Base64
import android.util.Log
import com.google.gson.Gson
import com.google.gson.annotations.SerializedName
import io.github.romanvht.byedpi.utility.getPreferences
import net.i2p.crypto.eddsa.EdDSAEngine
import net.i2p.crypto.eddsa.EdDSAPublicKey
import net.i2p.crypto.eddsa.spec.EdDSANamedCurveTable
import net.i2p.crypto.eddsa.spec.EdDSAPublicKeySpec
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.Locale

data class OnlineStrategy(
    val id: String,
    val name: String,
    val nameRu: String?,
    val summary: String,
    val summaryRu: String?,
    val services: List<String>?,
    val stability: String?,
    val stabilityRu: String?,
    val sourceName: String?,
    val sourceURL: String?,
    val commandArgs: List<String>,
    val minimumAppVersion: String?,
    val minimumEngineVersion: String?,
    val deprecated: Boolean?
) {
    private val russian: Boolean
        get() = Locale.getDefault().language.lowercase(Locale.ROOT).startsWith("ru")

    val displayName: String get() = if (russian) (nameRu ?: name) else name
    val displaySummary: String get() = if (russian) (summaryRu ?: summary) else summary
    val displayStability: String get() = if (russian) (stabilityRu ?: stability ?: "") else (stability ?: "")
}

data class OnlineStrategyCatalog(
    val schemaVersion: Int,
    val generation: Int,
    val updatedAt: String,
    val minimumAppVersion: String?,
    val minimumEngineVersion: String?,
    @SerializedName("revokedStrategyIDs") val revokedStrategyIDs: List<String>?,
    val strategies: List<OnlineStrategy>
)

/**
 * Signed PalkaDPI strategy catalog: the same Ed25519-signed JSON the iOS app
 * uses, fetched from GitHub and verified with the embedded public key before
 * anything from it is turned into a ByeDPI command line.
 */
object PalkaCatalog {
    private const val TAG = "PalkaCatalog"
    const val CATALOG_URL = "https://raw.githubusercontent.com/zondaxxx/PalkaDPI/main/strategy-catalog.json"
    const val SIGNATURE_URL = "https://raw.githubusercontent.com/zondaxxx/PalkaDPI/main/strategy-catalog.json.sig"
    private const val PUBLIC_KEY_BASE64 = "18bFOLUFcXXG6/56v8NnWS/SO6SxTxFIhdD5Vmz43jg="
    private const val MAX_BYTES = 512 * 1024
    private const val CACHE_FILE = "palka_catalog.json"
    private const val CACHE_SIG_FILE = "palka_catalog.sig"

    const val PREF_BLOCK_QUIC = "palka_block_quic"
    const val PREF_SERVICES = "palka_services"
    const val PREF_CUSTOM_DOMAINS = "palka_custom_domains"
    const val PREF_ACTIVE_STRATEGY_ID = "palka_active_strategy_id"
    const val PREF_ACTIVE_STRATEGY_NAME = "palka_active_strategy_name"

    private val gson = Gson()

    class CatalogException(message: String) : Exception(message)

    fun loadCached(context: Context): OnlineStrategyCatalog? {
        val data = File(context.filesDir, CACHE_FILE).takeIf { it.exists() }?.readBytes() ?: return null
        val sig = File(context.filesDir, CACHE_SIG_FILE).takeIf { it.exists() }?.readText() ?: return null
        return runCatching { verifyAndParse(data, sig) }.onFailure {
            Log.w(TAG, "cached catalog rejected: ${it.message}")
        }.getOrNull()
    }

    /** Downloads, verifies and caches the catalog. Must be called off the main thread. */
    @Throws(CatalogException::class)
    fun refresh(context: Context): OnlineStrategyCatalog {
        val sig = String(download(SIGNATURE_URL, 4096)).trim()
        val data = download(CATALOG_URL, MAX_BYTES)
        val catalog = verifyAndParse(data, sig)
        val cached = loadCached(context)
        if (cached != null && catalog.generation < cached.generation) {
            throw CatalogException("catalog generation ${catalog.generation} is older than cached ${cached.generation}")
        }
        File(context.filesDir, CACHE_FILE).writeBytes(data)
        File(context.filesDir, CACHE_SIG_FILE).writeText(sig)
        return catalog
    }

    private fun download(url: String, limit: Int): ByteArray {
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.connectTimeout = 10_000
        connection.readTimeout = 10_000
        connection.useCaches = false
        connection.setRequestProperty("Cache-Control", "no-cache")
        try {
            if (connection.responseCode != 200) {
                throw CatalogException("HTTP ${connection.responseCode} for $url")
            }
            val bytes = connection.inputStream.use { it.readBytes() }
            if (bytes.size > limit) throw CatalogException("response too large: ${bytes.size}")
            return bytes
        } finally {
            connection.disconnect()
        }
    }

    @Throws(CatalogException::class)
    fun verifyAndParse(data: ByteArray, signatureBase64: String): OnlineStrategyCatalog {
        val signature = runCatching { Base64.decode(signatureBase64, Base64.DEFAULT) }
            .getOrElse { throw CatalogException("signature is not base64") }
        if (!verify(data, signature)) throw CatalogException("catalog signature is invalid")

        val catalog = runCatching { gson.fromJson(String(data), OnlineStrategyCatalog::class.java) }
            .getOrElse { throw CatalogException("catalog JSON is invalid") }
            ?: throw CatalogException("catalog JSON is empty")
        if (catalog.schemaVersion != 2) throw CatalogException("unsupported schema ${catalog.schemaVersion}")
        if (catalog.generation <= 0 || catalog.strategies.isEmpty() || catalog.strategies.size > 100) {
            throw CatalogException("catalog has an invalid strategy list")
        }
        val ids = catalog.strategies.map { it.id }
        if (ids.toSet().size != ids.size) throw CatalogException("duplicate strategy ids")
        return catalog
    }

    private fun verify(data: ByteArray, signature: ByteArray): Boolean = try {
        val spec = EdDSANamedCurveTable.getByName(EdDSANamedCurveTable.ED_25519)
        val keyBytes = Base64.decode(PUBLIC_KEY_BASE64, Base64.DEFAULT)
        val publicKey = EdDSAPublicKey(EdDSAPublicKeySpec(keyBytes, spec))
        val engine = EdDSAEngine(MessageDigest.getInstance(spec.hashAlgorithm))
        engine.initVerify(publicKey)
        engine.update(data)
        engine.verify(signature)
    } catch (e: Exception) {
        Log.w(TAG, "verify failed", e)
        false
    }

    /** Strategies that are not revoked or deprecated, catalog order preserved. */
    fun usable(catalog: OnlineStrategyCatalog): List<OnlineStrategy> {
        val revoked = catalog.revokedStrategyIDs?.toSet() ?: emptySet()
        return catalog.strategies.filter {
            it.id !in revoked && it.deprecated != true && it.commandArgs.isNotEmpty() && it.commandArgs.size <= 160
        }
    }

    /**
     * Turns a catalog template into the single command line the app stores in
     * `byedpi_cmd_args`. Arguments with spaces (the `-H:` host list) are quoted
     * so `shellSplit` hands them to the core as one argv element.
     */
    fun resolveCommandLine(context: Context, strategy: OnlineStrategy): String {
        val prefs = context.getPreferences()
        val serviceIds = prefs.getStringSet(PREF_SERVICES, null) ?: PalkaServices.defaultIds
        val custom = prefs.getString(PREF_CUSTOM_DOMAINS, "")
            .orEmpty().split('\n', ' ', ',').filter { it.isNotBlank() }
        val targets = PalkaServices.targetsArgument(serviceIds, custom)
        val blockQuic = prefs.getBoolean(PREF_BLOCK_QUIC, true)

        val args = ArrayList<String>()
        if (blockQuic && strategy.commandArgs.none { it == "--udp-drop" }) {
            args.addAll(listOf("-Ku", "-V443", "--udp-drop", "-An"))
        }
        strategy.commandArgs.forEach { arg ->
            args.add(if (arg == PalkaServices.TARGETS_PLACEHOLDER) targets else arg)
        }
        return args.joinToString(" ") { quoteIfNeeded(it) }
    }

    private fun quoteIfNeeded(arg: String): String =
        if (arg.any { it.isWhitespace() }) "\"" + arg.replace("\"", "") + "\"" else arg
}
