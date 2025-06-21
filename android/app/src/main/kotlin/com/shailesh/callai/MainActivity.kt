package com.shailesh.callai

import android.Manifest
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.telecom.PhoneAccount
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import android.util.Log
import androidx.annotation.RequiresApi
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.shailesh.callai/call"
    private val AUDIO_CHANNEL = "com.shailesh.callai/audio"
    private val REQUEST_PERMISSIONS_CODE = 101
    private var pendingCallNumber: String? = null
    private lateinit var telecomManager: TelecomManager
    private lateinit var phoneAccountHandle: PhoneAccountHandle

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        telecomManager = getSystemService(Context.TELECOM_SERVICE) as TelecomManager

        // Set up the method channel for the CallConnectionService
        val audioChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_CHANNEL)
        CallConnectionService.setMethodChannel(audioChannel)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "startCall") {
                val number = call.argument<String>("number")
                if (number != null) {
                    pendingCallNumber = number
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        if (checkAndRequestPermissions()) {
                             registerPhoneAccountAndStartCall(number)
                        }
                        result.success("Call initiation process started")
                    } else {
                        result.error("UNSUPPORTED_OS", "Requires Android M or above", null)
                    }
                } else {
                    result.error("INVALID_ARGUMENT", "Phone number is required", null)
                }
            } else {
                result.notImplemented()
            }
        }

        // Set up audio processing channel
        audioChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "processAudio" -> {
                    val audioData = call.argument<ByteArray>("audioData")
                    if (audioData != null) {
                        // Send audio data to Flutter for AI processing
                        Log.d("MainActivity", "Received audio data: ${audioData.size} bytes")
                        // TODO: Process audio with AI
                        result.success("Audio processed")
                    } else {
                        result.error("INVALID_ARGUMENT", "Audio data is required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    @RequiresApi(Build.VERSION_CODES.M)
    private fun checkAndRequestPermissions(): Boolean {
        if (checkSelfPermission(Manifest.permission.MANAGE_OWN_CALLS) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.MANAGE_OWN_CALLS), REQUEST_PERMISSIONS_CODE)
            return false
        }
        
        // Also check if this app is the default dialer
        if (getSystemService(TelecomManager::class.java).defaultDialerPackage != packageName) {
            val intent = Intent(TelecomManager.ACTION_CHANGE_DEFAULT_DIALER)
            intent.putExtra(TelecomManager.EXTRA_CHANGE_DEFAULT_DIALER_PACKAGE_NAME, packageName)
            startActivity(intent)
            return false // The user needs to accept the change, we can't call immediately
        }
        
        return true
    }

    @RequiresApi(Build.VERSION_CODES.M)
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_PERMISSIONS_CODE) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                pendingCallNumber?.let {
                    if(checkAndRequestPermissions()) { // Re-check for default dialer
                         registerPhoneAccountAndStartCall(it)
                    }
                }
            } else {
                Log.e("MainActivity", "Permission denied: MANAGE_OWN_CALLS")
                // TODO: Inform flutter about permission denial
            }
        }
    }

    @RequiresApi(Build.VERSION_CODES.M)
    private fun registerPhoneAccountAndStartCall(number: String) {
        registerPhoneAccount()
        startCall(number)
    }

    @RequiresApi(Build.VERSION_CODES.M)
    private fun registerPhoneAccount() {
        val componentName = ComponentName(this, CallConnectionService::class.java)
        phoneAccountHandle = PhoneAccountHandle(componentName, "CallAI")

        val phoneAccount = PhoneAccount.builder(phoneAccountHandle, "CallAI")
            .setCapabilities(PhoneAccount.CAPABILITY_SELF_MANAGED) // Use CAPABILITY_SELF_MANAGED for VoIP apps that manage their own calls
            .build()
        
        telecomManager.registerPhoneAccount(phoneAccount)
        Log.d("MainActivity", "Phone account registered")
    }

    @RequiresApi(Build.VERSION_CODES.M)
    private fun startCall(number: String) {
        val uri = Uri.fromParts(PhoneAccount.SCHEME_TEL, number, null)
        val extras = Bundle()
        extras.putParcelable(TelecomManager.EXTRA_PHONE_ACCOUNT_HANDLE, phoneAccountHandle)
        
        // Permission is already checked in checkAndRequestPermissions()
        Log.d("MainActivity", "Placing call to $number")
        telecomManager.placeCall(uri, extras)
    }
}
