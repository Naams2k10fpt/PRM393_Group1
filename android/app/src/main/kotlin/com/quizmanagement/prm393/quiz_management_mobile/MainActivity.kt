package com.quizmanagement.prm393.quiz_management_mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.Manifest
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import com.cloudwebrtc.webrtc.FlutterRTCVideoRenderer

class MainActivity : FlutterActivity() {
    private var voicePermissionResult: MethodChannel.Result? = null
    private val voicePermissionRequest = 7317

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "quizms/app_updates")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "installed" -> {
                        @Suppress("DEPRECATION")
                        val info = packageManager.getPackageInfo(packageName, 0)
                        @Suppress("DEPRECATION")
                        val build = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            info.longVersionCode
                        } else {
                            info.versionCode.toLong()
                        }
                        result.success(mapOf(
                            "versionName" to info.versionName,
                            "versionCode" to build,
                            "abis" to Build.SUPPORTED_ABIS.toList()
                        ))
                    }
                    "openUpdate" -> {
                        val url = call.arguments as? String
                        val uri = url?.let { Uri.parse(it) }
                        if (uri == null || uri.scheme != "https" || uri.host.isNullOrEmpty() || uri.userInfo != null) {
                            result.error("invalid_update_url", "Expected an HTTPS release URL", null)
                        } else {
                            try {
                                startActivity(Intent(Intent.ACTION_VIEW, uri))
                                result.success(null)
                            } catch (_: ActivityNotFoundException) {
                                result.error("browser_unavailable", "No app can open the release URL", null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "quizms/voice_permissions")
            .setMethodCallHandler { call, result ->
                if (call.method == "awaitVideoRelease") {
                    FlutterRTCVideoRenderer.awaitDisposals { runOnUiThread { result.success(null) } }
                    return@setMethodCallHandler
                }
                if (call.method != "request") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val permission = when (call.arguments) {
                    "audio" -> Manifest.permission.RECORD_AUDIO
                    "video" -> Manifest.permission.CAMERA
                    else -> {
                        result.error("invalid_device", "Unknown voice device", null)
                        return@setMethodCallHandler
                    }
                }
                if (checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED) {
                    result.success(true)
                } else if (voicePermissionResult != null) {
                    result.error("permission_busy", "A permission request is already open", null)
                } else {
                    voicePermissionResult = result
                    requestPermissions(arrayOf(permission), voicePermissionRequest)
                }
            }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == voicePermissionRequest) {
            val result = voicePermissionResult
            voicePermissionResult = null
            result?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
        }
    }

    override fun onDestroy() {
        voicePermissionResult?.error("activity_closed", "Activity closed during permission request", null)
        voicePermissionResult = null
        super.onDestroy()
    }
}
