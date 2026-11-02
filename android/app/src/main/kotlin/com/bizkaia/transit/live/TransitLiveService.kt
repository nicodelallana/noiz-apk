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
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import com.bizkaia.transit.MainActivity
import com.bizkaia.transit.R
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Foreground service behind the lock-screen "next departure" notification.
 *
 * Android 14+ `specialUse` foreground service, public lock-screen visibility.
 * Two layouts:
 *  - Waiting at the stop (no progress yet): "Metro Bilbao: L1 Plentzia",
 *    "Próxima salida en 3 min (14:32) • Siguiente: 8 min", "Moyua • Andén 1".
 *  - On board (progress > 0, e.g. from the route planner): next stop and
 *    stops remaining.
 * The minutes are recomputed every 30 s and on "Actualizar", so the text
 * never goes stale even if the app is killed.
 */
class TransitLiveService : Service() {

    companion object {
        const val CHANNEL_ID = "transit_live_trip_channel_v4"
        const val CHANNEL_NAME = "Viaje en directo"
        const val NOTIFICATION_ID = 4001

        const val ACTION_START = "com.bizkaia.transit.action.START_LIVE_TRIP"
        const val ACTION_UPDATE = "com.bizkaia.transit.action.UPDATE_LIVE_TRIP"
        const val ACTION_REFRESH = "com.bizkaia.transit.action.REFRESH_LIVE_TRIP"
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
        const val EXTRA_OPERATOR_NAME = "operatorName"
        const val EXTRA_PLATFORM = "platform"
        const val EXTRA_FOLLOWING_MS = "followingDepartureMs"

        private const val REFRESH_INTERVAL_MS = 30_000L

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
            instruction: String?,
            operatorName: String? = null,
            platform: String? = null,
            followingDepartureMs: Long = 0L
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
                putExtra(EXTRA_OPERATOR_NAME, operatorName)
                putExtra(EXTRA_PLATFORM, platform)
                putExtra(EXTRA_FOLLOWING_MS, followingDepartureMs)
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

    private val handler = Handler(Looper.getMainLooper())
    private var lastExtras: Bundle? = null
    private val periodicRefresh = object : Runnable {
        override fun run() {
            render()
            handler.postDelayed(this, REFRESH_INTERVAL_MS)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null || intent.action == ACTION_STOP) {
            handler.removeCallbacksAndMessages(null)
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }

        if (intent.action != ACTION_REFRESH) {
            lastExtras = intent.extras
        }
        if (lastExtras == null) {
            stopSelf()
            return START_NOT_STICKY
        }

        render()
        handler.removeCallbacks(periodicRefresh)
        handler.postDelayed(periodicRefresh, REFRESH_INTERVAL_MS)

        if (lastExtras?.getString(EXTRA_STATUS) == "ended") {
            handler.removeCallbacks(periodicRefresh)
            handler.postDelayed({
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }, 8000L)
        }

        // Not sticky: after a process kill there is no trip data to restore.
        return START_NOT_STICKY
    }

    private fun render() {
        val extras = lastExtras ?: return
        startForeground(NOTIFICATION_ID, buildNotification(extras))
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Muestra en la pantalla de bloqueo cuánto falta para tu próxima salida"
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                enableVibration(false)
                setSound(null, null)
                setShowBadge(true)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun minutesUntil(epochMs: Long): Long =
        ((epochMs - System.currentTimeMillis()) / 60_000L).coerceAtLeast(0L)

    private fun buildNotification(extras: Bundle): Notification {
        val lineName = extras.getString(EXTRA_LINE_NAME) ?: "Línea"
        val lineColorHex = extras.getString(EXTRA_LINE_COLOR) ?: "#E2001A"
        val destination = extras.getString(EXTRA_DESTINATION) ?: "Destino"
        val currentStop = extras.getString(EXTRA_CURRENT_STOP).orEmpty()
        val nextStop = extras.getString(EXTRA_NEXT_STOP).orEmpty()
        val stopsRemaining = extras.getInt(EXTRA_STOPS_REMAINING, 0)
        val progress = extras.getDouble(EXTRA_PROGRESS, 0.0)
        val departureMs = extras.getLong(
            EXTRA_ARRIVAL_TIME_MS,
            System.currentTimeMillis() + 600_000L
        )
        val status = extras.getString(EXTRA_STATUS) ?: "scheduled"
        val isRealtime = extras.getBoolean(EXTRA_IS_REALTIME, false)
        val delaySeconds = extras.getInt(EXTRA_DELAY_SECONDS, 0)
        val instruction = extras.getString(EXTRA_INSTRUCTION)
        val operatorName = extras.getString(EXTRA_OPERATOR_NAME)
        val platform = extras.getString(EXTRA_PLATFORM)
        val followingMs = extras.getLong(EXTRA_FOLLOWING_MS, 0L)

        val parsedColor = try {
            Color.parseColor(lineColorHex)
        } catch (_: IllegalArgumentException) {
            Color.parseColor("#E2001A")
        }

        val isWaiting = progress <= 0.0 && status != "ended"
        val clock = SimpleDateFormat("HH:mm", Locale.forLanguageTag("es-ES"))

        val title = when {
            status == "ended" -> "Has llegado a $destination"
            operatorName != null -> "$operatorName: $lineName $destination"
            else -> "$lineName $destination"
        }

        val contentText = when {
            status == "ended" -> "Viaje finalizado"
            isWaiting -> {
                val mins = minutesUntil(departureMs)
                val main = if (mins == 0L) {
                    "Sale ahora (${clock.format(Date(departureMs))})"
                } else {
                    "Próxima salida en $mins min (${clock.format(Date(departureMs))})"
                }
                val delay = if (isRealtime && delaySeconds >= 60) " · +${delaySeconds / 60} min" else ""
                val following = if (followingMs > System.currentTimeMillis()) {
                    " • Siguiente: ${minutesUntil(followingMs)} min"
                } else {
                    ""
                }
                main + delay + following
            }
            !instruction.isNullOrBlank() -> instruction
            nextStop.isNotBlank() -> "Próxima parada: $nextStop · $stopsRemaining restantes"
            else -> "$stopsRemaining paradas hasta tu destino"
        }

        val subText = listOfNotNull(
            currentStop.takeIf { it.isNotBlank() },
            platform?.takeIf { it.isNotBlank() }?.let { "Andén $it" },
            if (!isRealtime && status != "ended") "Según horario" else null
        ).joinToString(" • ")

        val tapIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val refreshIntent = PendingIntent.getService(
            this,
            2,
            Intent(this, TransitLiveService::class.java).apply { action = ACTION_REFRESH },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val stopIntent = PendingIntent.getService(
            this,
            1,
            Intent(this, TransitLiveService::class.java).apply { action = ACTION_STOP },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(contentText)
            .setStyle(NotificationCompat.BigTextStyle().bigText(contentText))
            .setSubText(subText.ifBlank { null })
            .setColor(parsedColor)
            .setContentIntent(tapIntent)
            .setOngoing(status != "ended")
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_NAVIGATION)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .addAction(android.R.drawable.ic_popup_sync, "Actualizar", refreshIntent)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Finalizar", stopIntent)

        if (!isWaiting && status != "ended") {
            builder.setProgress(100, (progress.coerceIn(0.0, 1.0) * 100).toInt(), false)
        }

        return builder.build()
    }
}
