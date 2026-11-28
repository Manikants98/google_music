package com.mkx.google_music

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

/**
 * Background JobService that periodically queries the public GitHub Releases API
 * to discover new Google Music APK releases and displays an actionable system push notification.
 */
class UpdateCheckJobService : JobService() {
    companion object {
        const val JOB_ID = 8801
        const val UPDATE_CHANNEL_ID = "google_music_updates"
        const val NOTIFICATION_ID = 8802

        /**
         * Schedules a periodic background check (runs every ~12 hours when device has network).
         */
        fun schedulePeriodicCheck(context: Context) {
            val scheduler = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as? JobScheduler ?: return
            val component = ComponentName(context, UpdateCheckJobService::class.java)

            val builder = JobInfo.Builder(JOB_ID, component)
                .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
                .setPeriodic(12 * 60 * 60 * 1000L) // 12 hours
                .setPersisted(true)

            try {
                scheduler.schedule(builder.build())
            } catch (_: Exception) {
                // If setPersisted is rejected due to boot permission, schedule non-persisted
                val fallback = JobInfo.Builder(JOB_ID, component)
                    .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
                    .setPeriodic(12 * 60 * 60 * 1000L)
                scheduler.schedule(fallback.build())
            }
        }

        /**
         * Displays a system update notification directly from Flutter or background thread.
         */
        fun showNotificationDirect(context: Context, version: String, title: String) {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    UPDATE_CHANNEL_ID,
                    "App Updates",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Notifications when a new Google Music version is released"
                    setShowBadge(true)
                    enableVibration(true)
                }
                notificationManager.createNotificationChannel(channel)
            }

            val intent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("route", "app_update")
                putExtra("update_version", version)
            }

            val pendingIntent = PendingIntent.getActivity(
                context,
                NOTIFICATION_ID,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            )

            val cleanVer = version.replace(Regex("^[vV]"), "")
            val builder = NotificationCompat.Builder(context, UPDATE_CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_download_notification)
                .setColor(0xFFFF4E4E.toInt())
                .setContentTitle("🎵 New Update Available: v$cleanVer")
                .setContentText("Tap to review changes and install the new update")
                .setStyle(
                    NotificationCompat.BigTextStyle()
                        .bigText("Google Music v$cleanVer is ready!\n\n$title\nTap to download and install.")
                )
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .setPriority(NotificationCompat.PRIORITY_HIGH)

            notificationManager.notify(NOTIFICATION_ID, builder.build())
        }
    }

    override fun onStartJob(params: JobParameters?): Boolean {
        thread {
            try {
                checkForNewRelease(applicationContext)
            } catch (_: Exception) {
                // Ignore transient network errors
            } finally {
                jobFinished(params, false)
            }
        }
        return true
    }

    override fun onStopJob(params: JobParameters?): Boolean {
        return true
    }

    private fun checkForNewRelease(context: Context) {
        val currentVersion = try {
            val pInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.packageManager.getPackageInfo(context.packageName, PackageManager.PackageInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                context.packageManager.getPackageInfo(context.packageName, 0)
            }
            pInfo.versionName ?: "1.0.0"
        } catch (_: Exception) {
            "1.0.0"
        }

        val url = URL("https://api.github.com/repos/Manikants98/google_music/releases")
        val conn = url.openConnection() as HttpURLConnection
        conn.requestMethod = "GET"
        conn.setRequestProperty("Accept", "application/vnd.github.v3+json")
        conn.setRequestProperty("User-Agent", "GoogleMusic-UpdateChecker")
        conn.connectTimeout = 10000
        conn.readTimeout = 10000

        if (conn.responseCode == 200) {
            val reader = BufferedReader(InputStreamReader(conn.inputStream))
            val sb = StringBuilder()
            var line: String? = reader.readLine()
            while (line != null) {
                sb.append(line)
                line = reader.readLine()
            }
            reader.close()

            val releases = JSONArray(sb.toString())
            for (i in 0 until releases.length()) {
                val rel = releases.getJSONObject(i)
                val tagName = rel.optString("tag_name", "")
                val assets = rel.optJSONArray("assets") ?: JSONArray()
                var hasApk = false
                for (j in 0 until assets.length()) {
                    val asset = assets.getJSONObject(j)
                    val name = asset.optString("name", "").lowercase()
                    if (name.endsWith(".apk")) {
                        hasApk = true
                        break
                    }
                }

                if (hasApk && isNewerVersion(tagName, currentVersion)) {
                    val prefs = context.getSharedPreferences("google_music_update_prefs", Context.MODE_PRIVATE)
                    val lastNotified = prefs.getString("last_notified_version", null)
                    if (lastNotified != tagName) {
                        showNotificationDirect(context, tagName, rel.optString("name", tagName))
                        prefs.edit().putString("last_notified_version", tagName).apply()
                    }
                    break
                }
            }
        }
    }

    private fun isNewerVersion(newTag: String, currentVer: String): Boolean {
        val clean1 = newTag.replace(Regex("^[vV]"), "").split("+").first().trim()
        val clean2 = currentVer.replace(Regex("^[vV]"), "").split("+").first().trim()

        val base1 = clean1.split("-").first()
        val base2 = clean2.split("-").first()

        val p1 = base1.split(".").map { it.toIntOrNull() ?: 0 }
        val p2 = base2.split(".").map { it.toIntOrNull() ?: 0 }

        val maxLen = maxOf(p1.size, p2.size)
        for (i in 0 until maxLen) {
            val v1 = if (i < p1.size) p1[i] else 0
            val v2 = if (i < p2.size) p2[i] else 0
            if (v1 > v2) return true
            if (v1 < v2) return false
        }

        if (clean1 != clean2) {
            val isPre1 = clean1.contains("-")
            val isPre2 = clean2.contains("-")
            if (!isPre1 && isPre2) return true
            if (isPre1 && !isPre2) return false
            return clean1 > clean2
        }
        return false
    }
}
