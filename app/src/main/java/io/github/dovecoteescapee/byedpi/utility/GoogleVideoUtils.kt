package io.github.dovecoteescapee.byedpi.utility

import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL

class GoogleVideoUtils {

    companion object {
        private val lettersListA = listOf(
            'u', 'z', 'p', 'k', 'f', 'a', '5', '0', 'v', 'q', 'l', 'g',
            'b', '6', '1', 'w', 'r', 'm', 'h', 'c', '7', '2', 'x', 's',
            'n', 'i', 'd', '8', '3', 'y', 't', 'o', 'j', 'e', '9', '4', '-'
        )
        private val lettersListB = listOf(
            '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b',
            'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n',
            'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', '-'
        )
        private val lettersMap = lettersListA.zip(lettersListB).toMap()
    }

    suspend fun generateGoogleVideoDomain(): String? {
        val clusterCodename = getClusterCodename()
        if (clusterCodename == null) {
            Log.e("AutoGCS", "Failed to obtain cluster codename")
            return null
        }
        Log.i("AutoGCS", "Cluster codename: $clusterCodename")
        val clusterName = convertClusterCodename(clusterCodename)
        Log.i("AutoGCS", "Cluster name: $clusterName")
        val autoGCS = buildAutoGCS(clusterName)
        Log.i("AutoGCS", "Generated domain: $autoGCS")
        return autoGCS
    }

    private suspend fun getClusterCodename(): String? {
        val urls = listOf(
            "https://redirector.gvt1.com/report_mapping?di=no",
            "https://redirector.googlevideo.com/report_mapping?di=no"
        )
        for (url in urls) {
            try {
                val responseBody = withContext(Dispatchers.IO) { httpGet(url) }
                if (responseBody != null) {
                    val clusterCodename = extractClusterCodenameFromBody(responseBody)
                    if (clusterCodename != null) {
                        return clusterCodename
                    }
                }
            } catch (e: Exception) {
                Log.e("ClusterCodename", "Error fetching cluster codename from $url", e)
            }
        }
        return null
    }

    private fun extractClusterCodenameFromBody(body: String): String? {
        val regex = Regex("""=>\s*(\S+)\s*(?:\(|:)""")
        val matchResult = regex.find(body)
        val codename = matchResult?.groupValues?.get(1)
        if (codename != null) {
            return codename.trimEnd(':', ' ')
        }
        return null
    }

    private fun convertClusterCodename(clusterCodename: String): String {
        val clusterNameBuilder = StringBuilder()
        for (char in clusterCodename) {
            val mappedChar = lettersMap[char]
            if (mappedChar != null) {
                clusterNameBuilder.append(mappedChar)
            } else {
                Log.w("ClusterCodename", "Character '$char' not found in mapping")
            }
        }
        return clusterNameBuilder.toString()
    }

    private fun buildAutoGCS(clusterName: String): String {
        return "rr1---sn-$clusterName.googlevideo.com"
    }

    private fun httpGet(urlStr: String): String? {
        var connection: HttpURLConnection? = null
        return try {
            val url = URL(urlStr)
            connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = "GET"
            connection.connectTimeout = 2000
            connection.readTimeout = 2000

            val responseCode = connection.responseCode
            if (responseCode == HttpURLConnection.HTTP_OK) {
                val inputStream = connection.inputStream
                val reader = BufferedReader(InputStreamReader(inputStream))
                val response = reader.readText()
                reader.close()
                response
            } else {
                Log.e("HTTPGet", "Non-OK response code: $responseCode")
                null
            }
        } catch (e: Exception) {
            Log.e("HTTPGet", "Exception during HTTP GET", e)
            null
        } finally {
            connection?.disconnect()
        }
    }
}
