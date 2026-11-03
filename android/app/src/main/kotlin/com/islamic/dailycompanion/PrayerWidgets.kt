package com.islamic.dailycompanion

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * Home-screen widgets (design S07). Prayer data is pushed from Dart via the
 * home_widget plugin, which stores it in the "HomeWidgetPreferences"
 * SharedPreferences file under the keys written in PrayerController.
 *
 * NOTE: this native side is code-complete but NOT build-verified in the VM
 * environment (Gradle dependency egress is blocked there); it must be
 * confirmed by the first real APK build on the user's machine.
 */
abstract class BasePrayerWidgetProvider(private val layoutId: Int) : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        for (id in ids) {
            val views = RemoteViews(context.packageName, layoutId)
            views.setTextViewText(R.id.widget_next_prayer, prefs.getString("nextPrayerName", "—"))
            views.setTextViewText(
                R.id.widget_next_time,
                prefs.getString("nextPrayerTime", "--:--")
            )
            views.setTextViewText(
                R.id.widget_countdown,
                prefs.getString("countdownText", "")
            )
            if (layoutId == R.layout.prayer_widget_medium) {
                views.setTextViewText(R.id.widget_city, prefs.getString("cityName", ""))
                views.setTextViewText(R.id.widget_hijri, prefs.getString("hijriDate", ""))
                views.setTextViewText(R.id.widget_times, prefs.getString("timesLine", ""))
                views.setTextViewText(
                    R.id.widget_status,
                    "${prefs.getString("currentPrayerName", "")} is the current prayer"
                )
            }
            // Tap anywhere on the widget opens the app.
            val launch = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pending = PendingIntent.getActivity(
                context, id, launch,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pending)
            manager.updateAppWidget(id, views)
        }
    }
}

class PrayerWidgetProvider : BasePrayerWidgetProvider(R.layout.prayer_widget_medium)

class PrayerWidgetSmallProvider : BasePrayerWidgetProvider(R.layout.prayer_widget_small)
