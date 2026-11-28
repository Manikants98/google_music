package com.mkx.google_music

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val channelName = "com.mkx.google_music/download_notification"
    private val downloadChannelId = "google_music_downloads"
    private val downloadCompleteChannelId = "google_music_download_complete"
    private val notificationId = 9001
    private val activeDownloadNotifs = HashSet<Int>()
    private var methodChannel: MethodChannel? = null
    private var pendingRoute: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        createNotificationChannel()
        UpdateCheckJobService.schedulePeriodicCheck(applicationContext)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        methodChannel = channel

        channel.setMethodCallHandler { call, result ->
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            when (call.method) {
                "showProgress" -> {
                    val id = call.argument<String>("id") ?: ""
                    val title = call.argument<String>("title") ?: "Downloading audio"
                    val percent = call.argument<Int>("percent") ?: 0
                    val notifId = if (id.isNotEmpty()) ((Math.abs(id.hashCode()) % 80000) + 10000) else notificationId
                    activeDownloadNotifs.add(notifId)

                    val intent = Intent(this, MainActivity::class.java).apply {
                        action = Intent.ACTION_VIEW
                        flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    }

                    val pendingIntent = PendingIntent.getActivity(
                        this,
                        notifId,
                        intent,
                        PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
                    )

                    val builder = NotificationCompat.Builder(this, downloadChannelId)
                        .setSmallIcon(R.drawable.ic_download_notification)
                        .setColor(0xFFFF4E4E.toInt())
                        .setContentTitle("Downloading: $title")
                        .setContentText("$percent% downloaded")
                        .setProgress(100, percent, false)
                        .setOngoing(true)
                        .setOnlyAlertOnce(true)
                        .setGroup("com.mkx.google_music.downloads")
                        .setContentIntent(pendingIntent)
                        .setPriority(NotificationCompat.PRIORITY_LOW)

                    notificationManager.notify(notifId, builder.build())
                    result.success(true)
                }
                "showComplete" -> {
                    val id = call.argument<String>("id") ?: ""
                    val title = call.argument<String>("title") ?: "Download Complete"
                    val notifId = if (id.isNotEmpty()) ((Math.abs(id.hashCode()) % 80000) + 10000) else notificationId

                    activeDownloadNotifs.remove(notifId)

                    val intent = Intent(this, MainActivity::class.java).apply {
                        action = Intent.ACTION_VIEW
                        flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    }

                    val pendingIntent = PendingIntent.getActivity(
                        this,
                        notifId,
                        intent,
                        PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
                    )

                    val builder = NotificationCompat.Builder(this, downloadCompleteChannelId)
                        .setSmallIcon(R.drawable.ic_download_notification)
                        .setColor(0xFFFF4E4E.toInt())
                        .setContentTitle("Downloaded: $title")
                        .setContentText("Saved for offline playback in Library")
                        .setProgress(0, 0, false)
                        .setOngoing(false)
                        .setAutoCancel(true)
                        .setContentIntent(pendingIntent)
                        .setPriority(NotificationCompat.PRIORITY_DEFAULT)

                    notificationManager.notify(notifId, builder.build())
                    result.success(true)
                }
                "cancel" -> {
                    val id = call.argument<String>("id")
                    if (id != null && id.isNotEmpty()) {
                        val notifId = (Math.abs(id.hashCode()) % 80000) + 10000
                        notificationManager.cancel(notifId)
                        activeDownloadNotifs.remove(notifId)
                    } else {
                        for (nid in activeDownloadNotifs) {
                            notificationManager.cancel(nid)
                        }
                        activeDownloadNotifs.clear()
                        notificationManager.cancel(notificationId)
                    }
                    result.success(true)
                }
                "cancelAll" -> {
                    for (nid in activeDownloadNotifs) {
                        notificationManager.cancel(nid)
                    }
                    activeDownloadNotifs.clear()
                    notificationManager.cancel(notificationId)
                    result.success(true)
                }
                "getPendingRoute" -> {
                    val route = pendingRoute
                    pendingRoute = null
                    result.success(route)
                }
                "getAppVersion" -> {
                    try {
                        val pInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            packageManager.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(0))
                        } else {
                            @Suppress("DEPRECATION")
                            packageManager.getPackageInfo(packageName, 0)
                        }
                        result.success(pInfo.versionName ?: "1.0.7-beta.6")
                    } catch (e: Exception) {
                        result.success("1.0.7-beta.6")
                    }
                }
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        val file = java.io.File(filePath)
                        if (file.exists()) {
                            val apkUri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                                androidx.core.content.FileProvider.getUriForFile(
                                    this,
                                    "${applicationContext.packageName}.fileprovider",
                                    file
                                )
                            } else {
                                android.net.Uri.fromFile(file)
                            }

                            val installIntent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(apkUri, "application/vnd.android.package-archive")
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
                            }
                            startActivity(installIntent)
                            result.success(true)
                        } else {
                            result.error("FILE_NOT_FOUND", "APK file does not exist", null)
                        }
                    } else {
                        result.error("INVALID_PATH", "File path is null", null)
                    }
                }
                "openUrl" -> {
                    val url = call.argument<String>("url")
                    if (url != null) {
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, android.net.Uri.parse(url)).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("URL_FAILED", "Could not open URL: ${e.message}", null)
                        }
                    } else {
                        result.error("INVALID_URL", "URL string is null", null)
                    }
                }
                "showUpdateNotification" -> {
                    val version = call.argument<String>("version") ?: ""
                    val title = call.argument<String>("title") ?: "New Update Available"
                    UpdateCheckJobService.showNotificationDirect(this, version, title)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val action = intent?.action
        val route = intent?.getStringExtra("route")
        if (route == "downloads") {
            if (methodChannel != null) {
                methodChannel?.invokeMethod("openDownloads", null)
            } else {
                pendingRoute = "downloads"
            }
        } else if (route == "app_update") {
            if (methodChannel != null) {
                methodChannel?.invokeMethod("openAppUpdate", null)
            } else {
                pendingRoute = "app_update"
            }
        } else if (action == "com.ryanheise.audioservice.NOTIFICATION_CLICK") {
            if (methodChannel != null) {
                methodChannel?.invokeMethod("openNowPlaying", null)
            } else {
                pendingRoute = "now_playing"
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val progressChannel = NotificationChannel(
                downloadChannelId,
                "Download Progress",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Offline Music Download Progress"
                setShowBadge(false)
            }
            notificationManager.createNotificationChannel(progressChannel)

            val completeChannel = NotificationChannel(
                downloadCompleteChannelId,
                "Completed Downloads",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Offline music download completion notifications"
                setShowBadge(true)
                enableVibration(true)
            }
            notificationManager.createNotificationChannel(completeChannel)

            val updateChannel = NotificationChannel(
                UpdateCheckJobService.UPDATE_CHANNEL_ID,
                "App Updates",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications when a new Google Music version is released"
                setShowBadge(true)
                enableVibration(true)
            }
            notificationManager.createNotificationChannel(updateChannel)
        }
    }
}
