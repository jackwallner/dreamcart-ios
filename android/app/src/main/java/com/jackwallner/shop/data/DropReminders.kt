package com.jackwallner.shop.data

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.jackwallner.shop.MainActivity
import com.jackwallner.shop.R
import java.util.Calendar

/**
 * `LocalNotificationCoordinator.swift`: one optional "NEW DROP" reminder a day,
 * opening dreamcart://new-drops. Inexact alarms only, so no exact-alarm
 * declaration is needed on Play.
 */
class DropReminders(private val context: Context, private val prefs: SharedPreferences) {
    var isEnabled by mutableStateOf(prefs.getBoolean(ENABLED, false))
        private set
    var minuteOfDay by mutableStateOf(prefs.getInt(MINUTE, DEFAULT_MINUTE))
        private set

    val hasPermission: Boolean
        get() = Build.VERSION.SDK_INT < 33 ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    /** Show the soft primer once, after the first reward, like iOS. */
    val shouldPresentPrimer: Boolean get() = !prefs.getBoolean(PRIMER_SHOWN, false) && !isEnabled

    fun markPrimerShown() = prefs.edit().putBoolean(PRIMER_SHOWN, true).apply()

    fun enable() {
        isEnabled = true
        prefs.edit().putBoolean(ENABLED, true).apply()
        schedule()
    }

    fun disable() {
        isEnabled = false
        prefs.edit().putBoolean(ENABLED, false).apply()
        alarms().cancel(pending())
    }

    fun setMinute(minute: Int) {
        minuteOfDay = minute
        prefs.edit().putInt(MINUTE, minute).apply()
        if (isEnabled) schedule()
    }

    fun schedule() {
        if (!isEnabled) return
        val next = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, minuteOfDay / 60)
            set(Calendar.MINUTE, minuteOfDay % 60)
            set(Calendar.SECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) add(Calendar.DAY_OF_YEAR, 1)
        }
        alarms().setInexactRepeating(AlarmManager.RTC_WAKEUP, next.timeInMillis, AlarmManager.INTERVAL_DAY, pending())
    }

    private fun alarms() = context.getSystemService(AlarmManager::class.java)

    private fun pending() = PendingIntent.getBroadcast(
        context, 0, Intent(context, DropReminderReceiver::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    companion object {
        const val CHANNEL = "new-drops"
        private const val ENABLED = "notifications.enabled"
        private const val MINUTE = "notifications.preferredMinuteOfDay"
        private const val PRIMER_SHOWN = "notifications.primerShown"
        const val DEFAULT_MINUTE = 9 * 60

        fun timeLabel(minute: Int): String {
            val h = minute / 60
            val m = minute % 60
            val h12 = if (h % 12 == 0) 12 else h % 12
            return "%d:%02d %s".format(h12, m, if (h < 12) "AM" else "PM")
        }
    }
}

class DropReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val nm = context.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel(DropReminders.CHANNEL, context.getString(R.string.reminder_channel), NotificationManager.IMPORTANCE_DEFAULT))
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return
        val open = PendingIntent.getActivity(
            context, 1,
            Intent(Intent.ACTION_VIEW, Uri.parse("dreamcart://new-drops"), context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val n = NotificationCompat.Builder(context, DropReminders.CHANNEL)
            .setSmallIcon(android.R.drawable.star_on)
            .setContentTitle("NEW DROP")
            .setContentText("Fresh styles are waiting in DreamCart.")
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        runCatching { NotificationManagerCompat.from(context).notify(7, n) }
    }
}
