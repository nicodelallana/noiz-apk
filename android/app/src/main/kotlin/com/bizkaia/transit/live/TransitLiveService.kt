package com.bizkaia.transit.live

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.bizkaia.transit.MainActivity
import com.bizkaia.transit.R

/**
 * Android Foreground Service for lock-screen live transit journey tracking.
 *
 * Implements Android 14+ foreground service standards (with specialUse type),
 * public lock-screen visibility, dynamic progress tracking, and chronometer countdown.
 */
class TransitLiveService : Service() {

    companion object {
        const val CHANNEL_ID = "transit_live_trip_channel"
        const val CHANNEL_NAME = "Viaje en directo"
        const val NOTIFICATION_ID = 4001

        const val ACTION_START = "com.bizkaia.transit.action.START_LIVE_TRIP"
        const val ACTION_UPDATE = "com.bizkaia.transit.action.UPDATE_LIVE_TRIP"
        const val ACTION_STOP = "com.bizkaia.transit.action.STOP_LIVE_TRIP"

        const val EXTRA_LINE_NAME = "lineName"
        const val EXTRA_LINE_COLOR = "lineColor"
        const val EXTRA_DESTINATION = "destination"
        const val EXTRA_CURRENT_STOP = "currentStop"
        const val EXTRA_NEXT_STOP = "nextStop"
        const val EXTRA_STOPS_REMAINING = "stopsRemaining"
        const val EXTRA_PROGRESS = "progress"
        const val EXTRA_ARRIVAL_TIME_MS = "arrivalTimeMs"
        const val EXTRA_STATUS = "status"
        const val EXTRA_IS_REALTIME = "isRealtime"
        const val EXTRA_DELAY_SECONDS = "delaySeconds"
        const val EXTRA_INSTRUCTION = "instruction"

        fun startOrUpdate(
            context: Context,
            lineName: String,
            lineColor: String,
            destination: String,
            currentStop: String,
            nextStop: String,
            stopsRemaining: Int,
            progress: Double,
            arrivalTimeMs: Long,
            status: String,
            isRealtime: Boolean,
            delaySeconds: Int,
            instruction: String?
        ) {
            val intent = Intent(context, TransitLiveService::class.java).apply {
                action = ACTION_UPDATE
                putExtra(EXTRA_LINE_NAME, lineName)
                putExtra(EXTRA_LINE_COLOR, lineColor)
                putExtra(EXTRA_DESTINATION, destination)
                putExtra(EXTRA_CURRENT_STOP, currentStop)
                putExtra(EXTRA_NEXT_STOP, nextStop)
                putExtra(EXTRA_STOPS_REMAINING, stopsRemaining)
                putExtra(EXTRA_PROGRESS, progress)
                putExtra(EXTRA_ARRIVAL_TIME_MS, arrivalTimeMs)
                putExtra(EXTRA_STATUS, status)
                putExtra(EXTRA_IS_REALTIME, isRealtime)
                putExtra(EXTRA_DELAY_SECONDS, delaySeconds)
                putExtra(EXTRA_INSTRUCTION, instruction)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, TransitLiveService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null || intent.action == ACTION_STOP) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }

        val lineName = intent.getStringExtra(EXTRA_LINE_NAME) ?: "Línea"
        val lineColorHex = intent.getStringExtra(EXTRA_LINE_COLOR) ?: "#E2001A"
        val destination = intent.getStringExtra(EXTRA_DESTINATION) ?: "Destino"
        val currentStop = intent.getStringExtra(EXTRA_CURRENT_STOP) ?: ""
        val nextStop = intent.getStringExtra(EXTRA_NEXT_STOP) ?: ""
        val stopsRemaining = intent.getIntExtra(EXTRA_STOPS_REMAINING, 0)
        val progress = intent.getDoubleExtra(EXTRA_PROGRESS, 0.0)
        val arrivalTimeMs = intent.getLongExtra(EXTRA_ARRIVAL_TIME_MS, System.currentTimeMillis() + 600000L)
        val status = intent.getStringExtra(EXTRA_STATUS) ?: "tracking"
        val isRealtime = intent.getBooleanExtra(EXTRA_IS_REALTIME, false)
        val delaySeconds = intent.getIntExtra(EXTRA_DELAY_SECONDS, 0)
        val instruction = intent.getStringExtra(EXTRA_INSTRUCTION)

        val notification = buildNotification(
            lineName = lineName,
            lineColorHex = lineColorHex,
            destination = destination,
            currentStop = currentStop,
            nextStop = nextStop,
            stopsRemaining = stopsRemaining,
            progress = progress,
            arrivalTimeMs = arrivalTimeMs,
            status = status,
            isRealtime = isRealtime,
            delaySeconds = delaySeconds,
            instruction = instruction
        )

        startForeground(NOTIFICATION_ID, notification)

        if (status == "ended") {
            // Stop service gracefully after showing arrival
            android.os.Handler(mainLooper).postDelayed({
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }, 8000L)
        }

        return START_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Muestra el progreso de tu viaje en tiempo real en la pantalla de bloqueo"
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                enableVibration(false)
                setShowBadge(false)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(
        lineName: String,
        lineColorHex: String,
        destination: String,
        currentStop: String,
        nextStop: String,
        stopsRemaining: Int,
        progress: Double,
        arrivalTimeMs: Long,
        status: String,
        isRealtime: Boolean,
        delaySeconds: Int,
        instruction: String?
    ): Notification {
        val tapIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingTapIntent = PendingIntent.getActivity(
            this,
            0,
            tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val stopIntent = Intent(this, TransitLiveService::class.java).apply {
            action = ACTION_STOP
        }
        val pendingStopIntent = PendingIntent.getService(
            this,
            1,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val parsedColor = try {
            Color.parseColor(lineColorHex)
        } catch (_: Exception) {
            Color.parseColor("#E2001A")
        }

        val statusLabel = when {
            status == "arriving" -> "Llegando a parada"
            status == "at_stop" -> "En parada"
            status == "ended" -> "Has llegado a tu destino"
            delaySeconds > 60 -> "+${delaySeconds / 60} min retraso"
            isRealtime -> "En directo"
            else -> "Según horario"
        }

        val title = "$lineName hacia $destination · $statusLabel"
        val contentText = when {
            status == "ended" -> "Viaje finalizado en $destination"
            !instruction.isNullOrBlank() -> instruction
            nextStop.isNotBlank() -> "Próxima parada: $nextStop ($stopsRemaining restantes)"
            else -> "$stopsRemaining paradas para tu destino"
        }

        val progressPercent = (progress.coerceIn(0.0, 1.0) * 100).toInt()

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(contentText)
            .setSubText("Barik Live")
            .setColor(parsedColor)
            .setColorized(true)
            .setContentIntent(pendingTapIntent)
            .setOngoing(status != "ended")
            .setOnlyAlertOnce(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setProgress(100, progressPercent, false)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Finalizar", pendingStopIntent)

        // Native chronometer countdown to target arrival time
        if (status != "ended" && arrivalTimeMs > System.currentTimeMillis()) {
            builder.setUsesChronometer(true)
            builder.setChronometerCountDown(true)
            builder.setWhen(arrivalTimeMs)
        }

        return builder.build()
    }
}
