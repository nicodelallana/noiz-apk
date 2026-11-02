package com.bizkaia.transit

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.bizkaia.transit.live.TransitLiveService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.bizkaia.transit/live_trip"
    private val NOTIFICATION_PERMISSION_CODE = 1002

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startTrip", "updateTrip" -> {
                    val lineName = call.argument<String>("lineName") ?: "Línea"
                    val lineColor = call.argument<String>("lineColor") ?: "#E2001A"
                    val destination = call.argument<String>("destination") ?: "Destino"
                    val currentStop = call.argument<String>("currentStop") ?: ""
                    val nextStop = call.argument<String>("nextStop") ?: ""
                    val stopsRemaining = call.argument<Int>("stopsRemaining") ?: 0
                    val progress = call.argument<Double>("progress") ?: 0.0
                    val arrivalTimeMs = (call.argument<Number>("arrivalTimeEpochMs"))?.toLong()
                        ?: (System.currentTimeMillis() + 600000L)
                    val status = call.argument<String>("status") ?: "tracking"
                    val isRealtime = call.argument<Boolean>("isRealtime") ?: false
                    val delaySeconds = call.argument<Int>("delaySeconds") ?: 0
                    val instruction = call.argument<String>("instruction")

                    TransitLiveService.startOrUpdate(
                        context = this,
                        lineName = lineName,
                        lineColor = lineColor,
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
                    result.success(true)
                }
                "endTrip" -> {
                    TransitLiveService.stop(this)
                    result.success(true)
                }
                "isSupported" -> {
                    result.success(true)
                }
                "requestPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        val granted = ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.POST_NOTIFICATIONS
                        ) == PackageManager.PERMISSION_GRANTED

                        if (!granted) {
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                NOTIFICATION_PERMISSION_CODE
                            )
                        }
                        result.success(granted)
                    } else {
                        result.success(true)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
