package com.quizmanagement.prm393.quiz_management_mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.Manifest
import android.content.pm.PackageManager
import com.cloudwebrtc.webrtc.FlutterRTCVideoRenderer

class MainActivity : FlutterActivity() {
    private var voicePermissionResult: MethodChannel.Result? = null
    private val voicePermissionRequest = 7317

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
