package com.bizkaia.transit.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.widget.RemoteViews
import com.bizkaia.transit.MainActivity
import com.bizkaia.transit.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * Native Android AppWidgetProvider for Bizkaia Transit.
 * Renders glanceable next departures from local precalculated schedules.
 */
class TransitWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        updateWidget(context, appWidgetManager, appWidgetId)
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
        val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 40)
        val isMedium = minHeight >= 80

        val layoutId = if (isMedium) R.layout.transit_widget_medium else R.layout.transit_widget_small
        val views = RemoteViews(context.packageName, layoutId)

        // Read preferences populated by Flutter HomeWidget plugin
        val widgetData = HomeWidgetPlugin.getData(context)
        val rawJson = widgetData.getString("transit_widget_data", null)

        var tripId: String? = null
        var tripName = widgetData.getString("top_trip_name", "Mis viajes") ?: "Mis viajes"
        var originName = widgetData.getString("top_trip_origin", "") ?: ""
        var destName = widgetData.getString("top_trip_dest", "") ?: ""
        var lineBadge = widgetData.getString("top_trip_line", "METRO") ?: "METRO"
        var depTime = widgetData.getString("top_trip_time", "--:--") ?: "--:-- voice"
        var countdown = widgetData.getString("top_trip_countdown", "Añadir en app") ?: "Añadir en app"
        var nextDepsSummary = "Sin salidas próximas"

        if (!rawJson.isNullOrEmpty()) {
            try {
                val json = JSONObject(rawJson)
                val tripsArray = json.optJSONArray("trips")
                if (tripsArray != null && tripsArray.length() > 0) {
                    val trip = tripsArray.getJSONObject(0)
                    tripId = trip.optString("id")
                    tripName = trip.optString("name", tripName)
                    originName = trip.optString("origin_name", originName)
                    destName = trip.optString("dest_name", destName)
                    lineBadge = trip.optString("line", lineBadge)

                    val departures = trip.optJSONArray("departures")
                    if (departures != null && departures.length() > 0) {
                        val firstDep = departures.getJSONObject(0)
                        val schedIso = firstDep.optString("sched")
                        val formattedTime = firstDep.optString("formatted", "--:--")
                        val mins = calculateMinutesRemaining(schedIso, firstDep.optInt("mins", 0))

                        depTime = formattedTime
                        countdown = if (mins <= 0) "Ahora" else "$mins min"

                        // Build secondary summary for medium layout
                        if (departures.length() > 1) {
                            val nextList = mutableListOf<String>()
                            for (i in 1 until departures.length().coerceAtMost(3)) {
                                val d = departures.getJSONObject(i)
                                val m = calculateMinutesRemaining(d.optString("sched"), d.optInt("mins", 0))
                                val t = d.optString("formatted")
                                nextList.add("$t (${m}m)")
                            }
                            nextDepsSummary = "Próximas: " + nextList.joinToString(" • ")
                        }
                    } else {
                        depTime = "--:--"
                        countdown = "Sin salidas"
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        val routeSummary = if (originName.isNotEmpty() && destName.isNotEmpty()) {
            "$originName → $destName"
        } else {
            "Abre la app para configurar viajes"
        }

        if (isMedium) {
            views.setTextViewText(R.id.widget_medium_line, lineBadge)
            views.setTextViewText(R.id.widget_medium_trip_name, tripName)
            views.setTextViewText(R.id.widget_medium_route, routeSummary)
            views.setTextViewText(R.id.widget_medium_time, depTime)
            views.setTextViewText(R.id.widget_medium_countdown, countdown)
            views.setTextViewText(R.id.widget_medium_next_departures, nextDepsSummary)
        } else {
            views.setTextViewText(R.id.widget_line, lineBadge)
            views.setTextViewText(R.id.widget_trip_name, tripName)
            views.setTextViewText(R.id.widget_route_summary, routeSummary)
            views.setTextViewText(R.id.widget_departure_time, depTime)
            views.setTextViewText(R.id.widget_countdown, countdown)
        }

        // Configure deep link click action
        val targetUri = if (!tripId.isNullOrEmpty()) {
            Uri.parse("bizkaiatransit://trip/$tripId")
        } else {
            Uri.parse("bizkaiatransit://trips")
        }

        val pendingIntent = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            targetUri
        )

        val rootId = if (isMedium) R.id.widget_medium_root else R.id.widget_root
        views.setOnClickPendingIntent(rootId, pendingIntent)

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun calculateMinutesRemaining(schedIso: String?, defaultMins: Int): Int {
        if (schedIso.isNullOrEmpty()) return defaultMins
        return try {
            val sdf = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US).apply {
                timeZone = TimeZone.getTimeZone("UTC")
            }
            val date = sdf.parse(schedIso) ?: return defaultMins
            val diffMs = date.time - System.currentTimeMillis()
            (diffMs / 60000).toInt().coerceAtLeast(0)
        } catch (e: Exception) {
            defaultMins
        }
    }
}
