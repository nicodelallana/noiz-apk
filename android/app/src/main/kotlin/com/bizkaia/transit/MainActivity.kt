package com.bizkaia.transit

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.bizkaia.transit.live.TransitLiveService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.bizkaia.transit/live_trip"
    private val NOTIFICATION_PERMISSION_CODE = 1002
    private val LOCATION_PERMISSION_CODE = 1003
    private val FRESH_FIX_MAX_AGE_MS = 2 * 60 * 1000L
    private val FRESH_FIX_TIMEOUT_MS = 8000L

    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingLocationPermissionResult: MethodChannel.Result? = null

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
                    val operatorName = call.argument<String>("operatorName")
                    val platform = call.argument<String>("platform")
                    val followingDepartureMs =
                        (call.argument<Number>("followingDepartureEpochMs"))?.toLong() ?: 0L

                    // Check notification permission on Android 13+
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
                    }

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
                        instruction = instruction,
                        operatorName = operatorName,
                        platform = platform,
                        followingDepartureMs = followingDepartureMs
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
                "checkPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        val granted = ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.POST_NOTIFICATIONS
                        ) == PackageManager.PERMISSION_GRANTED
                        result.success(granted)
                    } else {
                        result.success(true)
                    }
                }
                "requestPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        val granted = ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.POST_NOTIFICATIONS
                        ) == PackageManager.PERMISSION_GRANTED

                        if (granted) {
                            result.success(true)
                        } else {
                            pendingPermissionResult = result
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                NOTIFICATION_PERMISSION_CODE
                            )
                        }
                    } else {
                        result.success(true)
                    }
                }
                "hasLocationPermission" -> {
                    val fineGranted = ContextCompat.checkSelfPermission(
                        this, Manifest.permission.ACCESS_FINE_LOCATION
                    ) == PackageManager.PERMISSION_GRANTED
                    val coarseGranted = ContextCompat.checkSelfPermission(
                        this, Manifest.permission.ACCESS_COARSE_LOCATION
                    ) == PackageManager.PERMISSION_GRANTED
                    result.success(fineGranted || coarseGranted)
                }
                "requestLocationPermission" -> {
                    val fineGranted = ContextCompat.checkSelfPermission(
                        this, Manifest.permission.ACCESS_FINE_LOCATION
                    ) == PackageManager.PERMISSION_GRANTED
                    val coarseGranted = ContextCompat.checkSelfPermission(
                        this, Manifest.permission.ACCESS_COARSE_LOCATION
                    ) == PackageManager.PERMISSION_GRANTED

                    if (fineGranted || coarseGranted) {
                        result.success(true)
                    } else {
                        pendingLocationPermissionResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(
                                Manifest.permission.ACCESS_FINE_LOCATION,
                                Manifest.permission.ACCESS_COARSE_LOCATION
                            ),
                            LOCATION_PERMISSION_CODE
                        )
                    }
                }
                "getLocation" -> {
                    resolveLocation { loc -> result.success(loc) }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    /**
     * Replies with the last known fix when it is recent; otherwise asks the
     * best enabled provider for a fresh one-shot fix (8 s timeout) and falls
     * back to the stale fix, or null, if none arrives.
     */
    private fun resolveLocation(reply: (Map<String, Double>?) -> Unit) {
        val lastKnown = getLastKnownLocation()
        val isFresh = lastKnown != null &&
            System.currentTimeMillis() - lastKnown.time < FRESH_FIX_MAX_AGE_MS
        if (isFresh) {
            reply(lastKnown!!.toMap())
            return
        }

        val locationManager = getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        val provider = locationManager?.let {
            listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
                .firstOrNull { p -> it.isProviderEnabled(p) }
        }
        if (locationManager == null || provider == null || !hasAnyLocationPermission()) {
            reply(lastKnown?.toMap())
            return
        }

        val handler = Handler(Looper.getMainLooper())
        var replied = false
        val finish: (Location?) -> Unit = { loc ->
            if (!replied) {
                replied = true
                handler.removeCallbacksAndMessages(null)
                reply((loc ?: lastKnown)?.toMap())
            }
        }
        handler.postDelayed({ finish(null) }, FRESH_FIX_TIMEOUT_MS)

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                locationManager.getCurrentLocation(provider, null, mainExecutor) { finish(it) }
            } else {
                @Suppress("DEPRECATION")
                locationManager.requestSingleUpdate(
                    provider,
                    object : LocationListener {
                        override fun onLocationChanged(location: Location) = finish(location)
                        @Deprecated("Required on API < 29")
                        override fun onStatusChanged(p: String?, s: Int, e: Bundle?) {}
                        override fun onProviderEnabled(p: String) {}
                        override fun onProviderDisabled(p: String) = finish(null)
                    },
                    Looper.getMainLooper()
                )
            }
        } catch (_: SecurityException) {
            finish(null)
        }
    }

    private fun Location.toMap() = mapOf("latitude" to latitude, "longitude" to longitude)

    private fun hasAnyLocationPermission(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED

    private fun getLastKnownLocation(): Location? {
        val fineGranted = ContextCompat.checkSelfPermission(
            this, Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        val coarseGranted = ContextCompat.checkSelfPermission(
            this, Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        if (!fineGranted && !coarseGranted) return null

        val locationManager = getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return null
        val providers = locationManager.getProviders(true)
        var bestLocation: Location? = null

        for (provider in providers) {
            val location = try {
                locationManager.getLastKnownLocation(provider)
            } catch (_: SecurityException) {
                null
            } ?: continue

            if (bestLocation == null || location.accuracy < bestLocation.accuracy) {
                bestLocation = location
            }
        }

        return bestLocation
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        when (requestCode) {
            NOTIFICATION_PERMISSION_CODE -> {
                val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
                pendingPermissionResult?.success(granted)
                pendingPermissionResult = null
            }
            LOCATION_PERMISSION_CODE -> {
                // Fine or approximate: either one is enough to find nearby stops.
                val granted = grantResults.any { it == PackageManager.PERMISSION_GRANTED }
                pendingLocationPermissionResult?.success(granted)
                pendingLocationPermissionResult = null
            }
        }
    }
}
