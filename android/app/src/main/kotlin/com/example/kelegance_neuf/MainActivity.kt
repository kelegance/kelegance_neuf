package com.example.kelegance_neuf

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    private val overlayChannel = "com.example.kelegance_neuf/overlay"
    private val navigationChannel = "com.example.kelegance_neuf/navigation"
    private val deepLinkChannel = "com.example.kelegance_neuf/deeplink"
    private val otaChannel = "com.example.kelegance_neuf/ota"
    private var pendingDeepLink: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pendingDeepLink = intent?.data?.toString() ?: pendingDeepLink

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deepLinkChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialLink" -> result.success(pendingDeepLink)
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, overlayChannel).setMethodCallHandler { call, result ->
            if (call.method == "bringToFront") {
                ramenerAuPremierPlan()
                result.success(true)
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, navigationChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "launchNavigation" -> {
                    val packageName = call.argument<String>("package")
                    val uriString = call.argument<String>("uri")
                    if (packageName.isNullOrBlank() || uriString.isNullOrBlank()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    try {
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(uriString)).apply {
                            setPackage(packageName)
                            addFlags(
                                Intent.FLAG_ACTIVITY_NEW_TASK or
                                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                                    Intent.FLAG_ACTIVITY_SINGLE_TOP
                            )
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "minimizeApp" -> {
                    moveTaskToBack(true)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, otaChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("INVALID", "Chemin APK manquant", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val fichier = File(path)
                        if (!fichier.exists()) {
                            result.error("NOT_FOUND", "APK introuvable", null)
                            return@setMethodCallHandler
                        }
                        val uri = FileProvider.getUriForFile(
                            this,
                            "$packageName.fileprovider",
                            fichier,
                        )
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: SecurityException) {
                        result.error("PERMISSION", e.message, null)
                    } catch (e: Exception) {
                        result.error("INSTALL_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun ramenerAuPremierPlan() {
        try {
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                activityManager.moveTaskToFront(taskId, ActivityManager.MOVE_TASK_WITH_HOME)
            } else {
                @Suppress("DEPRECATION")
                activityManager.moveTaskToFront(taskId, ActivityManager.MOVE_TASK_WITH_HOME)
            }
        } catch (_: Exception) {
            // moveTaskToFront peut échouer sur certains appareils.
        }

        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP
            )
        }
        startActivity(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        pendingDeepLink = intent.data?.toString()
    }
}
