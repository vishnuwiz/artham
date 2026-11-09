package com.artham.app.artham

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "artham/automatic_sms"
    private val permissionRequestCode = 5107
    private var pendingPermissionResult: MethodChannel.Result? = null

    private val smsPreferences by lazy {
        getSharedPreferences("artham_sms_import", MODE_PRIVATE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getStatus" -> {
                        val defaultAccountId = smsPreferences.getLong(
                            "default_account_id",
                            -1L,
                        )
                        result.success(
                            mapOf(
                                "supported" to true,
                                "permissionGranted" to hasReceiveSmsPermission(),
                                "enabled" to smsPreferences.getBoolean(
                                    "enabled",
                                    false,
                                ),
                                "defaultAccountId" to if (defaultAccountId > 0L) {
                                    defaultAccountId
                                } else {
                                    null
                                },
                            ),
                        )
                    }

                    "requestPermission" -> {
                        if (hasReceiveSmsPermission()) {
                            result.success(true)
                        } else if (pendingPermissionResult != null) {
                            result.error(
                                "REQUEST_IN_PROGRESS",
                                "An SMS permission request is already in progress.",
                                null,
                            )
                        } else {
                            pendingPermissionResult = result
                            requestPermissions(
                                arrayOf(Manifest.permission.RECEIVE_SMS),
                                permissionRequestCode,
                            )
                        }
                    }

                    "setEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        if (enabled && !hasReceiveSmsPermission()) {
                            result.error(
                                "PERMISSION_REQUIRED",
                                "SMS permission must be granted before enabling automatic import.",
                                null,
                            )
                        } else {
                            smsPreferences.edit()
                                .putBoolean("enabled", enabled)
                                .apply()
                            result.success(true)
                        }
                    }

                    "setDefaultAccountId" -> {
                        val accountId = call.argument<Number>("accountId")?.toLong()
                        smsPreferences.edit()
                            .putLong("default_account_id", accountId ?: -1L)
                            .apply()
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun hasReceiveSmsPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.RECEIVE_SMS,
        ) == PackageManager.PERMISSION_GRANTED
    }

    @Deprecated("Deprecated in Android API")
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == permissionRequestCode) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }
}
