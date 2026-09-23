package io.github.romanvht.byedpi.palka

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import io.github.romanvht.byedpi.R
import io.github.romanvht.byedpi.utility.registerNotificationChannel

/**
 * Keeps the process in the foreground while automatic setup runs. The search
 * stops the VPN service first and can take minutes; without a foreground
 * service Android may freeze or kill the app as soon as the user leaves it,
 * leaving the phone with neither the VPN nor a chosen strategy.
 */
class PalkaAutomationService : Service() {
    companion object {
        private const val CHANNEL_ID = "PalkaAutomation"
        private const val NOTIFICATION_ID = 4

        fun start(context: Context) {
            runCatching {
                ContextCompat.startForegroundService(context, Intent(context, PalkaAutomationService::class.java))
            }
        }

        fun stop(context: Context) {
            runCatching { context.stopService(Intent(context, PalkaAutomationService::class.java)) }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        registerNotificationChannel(this, CHANNEL_ID, R.string.palka_auto_title)
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(getString(R.string.palka_auto_title))
            .setContentText(getString(R.string.palka_auto_notification))
            .setProgress(0, 0, true)
            .setOngoing(true)
            .setSilent(true)
            .setContentIntent(
                android.app.PendingIntent.getActivity(
                    this, 0,
                    Intent(this, io.github.romanvht.byedpi.palka.ui.PalkaActivity::class.java),
                    android.app.PendingIntent.FLAG_IMMUTABLE
                )
            )
            .build()
        ServiceCompat.startForeground(
            this, NOTIFICATION_ID, notification,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC else 0
        )
        if (!PalkaAutomation.isRunning) stopSelf()
        return START_NOT_STICKY
    }
}
