package io.github.dovecoteescapee.byedpi.core

import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class ByeDpiProxy {
    companion object {
        init {
            System.loadLibrary("byedpi")
        }
    }

    private val mutex = Mutex()
    private var fd = -1

    suspend fun startProxy(preferences: ByeDpiProxyPreferences): Int {
        val result = createSocket(preferences)

        if (result < 0) {
            fd = -1
            return -1
        }

        return jniStartProxy(result)
    }

    suspend fun stopProxy(): Int {
        mutex.withLock {
            if (fd < 0) {
                throw IllegalStateException("Proxy is not running")
            }

            val result = jniStopProxy(fd)

            fd = -1
            return result
        }
    }

    private suspend fun createSocket(preferences: ByeDpiProxyPreferences): Int =
        mutex.withLock {
            if (fd >= 0) {
                throw IllegalStateException("Proxy is already running")
            }

            val result = createSocketFromPreferences(preferences)

            if (result < 0) {
                fd = -1
                return -1
            }

            fd = result
            return result
        }

    private fun createSocketFromPreferences(preferences: ByeDpiProxyPreferences) =
        when (preferences) {
            is ByeDpiProxyCmdPreferences -> jniCreateSocket(preferences.args)
            is ByeDpiProxyUIPreferences -> jniCreateSocket(preferences.uiargs)
        }

    private external fun jniCreateSocket(args: Array<String>): Int
    private external fun jniStartProxy(fd: Int): Int
    private external fun jniStopProxy(fd: Int): Int
}