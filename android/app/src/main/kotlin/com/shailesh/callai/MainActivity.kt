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
import android.telephony.PhoneStateListener
import android.telephony.TelephonyManager
import android.telephony.TelephonyCallback
import android.util.Log
import androidx.annotation.RequiresApi
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.media.AudioManager
import android.content.BroadcastReceiver
import android.content.IntentFilter
import androidx.annotation.NonNull

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.shailesh.callai/call"
    private val AUDIO_CHANNEL = "com.shailesh.callai/audio"
    private val CALL_STATE_CHANNEL = "com.shailesh.callai/callstate"
    private val REQUEST_PERMISSIONS_CODE = 101
    private var pendingCallNumber: String? = null
    private lateinit var telecomManager: TelecomManager
    private lateinit var telephonyManager: TelephonyManager
    private lateinit var phoneAccountHandle: PhoneAccountHandle
    private var methodChannel: MethodChannel? = null
    private var callStateChannel: MethodChannel? = null
    private var phoneStateListener: PhoneStateListener? = null
    private var callStateReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        telecomManager = getSystemService(Context.TELECOM_SERVICE) as TelecomManager
        telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager

        // Register the phone account
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PhoneAccountManager.registerPhoneAccount(this)
        }

        // Set up the method channel for the CallConnectionService
        val audioChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_CHANNEL)
        CallConnectionService.setMethodChannel(audioChannel)

        // Set up call state channel
        callStateChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_STATE_CHANNEL)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startCall" -> {
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
                }
                "startCallStateMonitoring" -> {
                    startCallStateMonitoring()
                    result.success("Call state monitoring started")
                }
                "stopCallStateMonitoring" -> {
                    stopCallStateMonitoring()
                    result.success("Call state monitoring stopped")
                }
                "getCurrentCallState" -> {
                    val state = getCurrentCallState()
                    result.success(state)
                }
                "playAiAudio" -> {
                    val audioData = call.argument<ByteArray>("audioData")
                    if (audioData != null) {
                        CallConnectionService.playAudio(audioData)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGS", "Audio data is missing", null)
                    }
                }
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
                "setSpeakerphoneOn" -> {
                    val on = call.argument<Boolean>("on")
                    if (on != null) {
                        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        audioManager.isSpeakerphoneOn = on
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Boolean 'on' is required", null)
                    }
                }
                "moveTaskToBack" -> {
                    moveTaskToBack(true)
                    result.success(null)
                }
                "bringToFront" -> {
                    val intent = Intent(this, MainActivity::class.java)
                    intent.addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Add method channel for background/foreground control
        audioChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "moveTaskToBack" -> {
                    moveTaskToBack(true)
                    result.success(null)
                }
                "bringToFront" -> {
                    val intent = Intent(this, MainActivity::class.java)
                    intent.addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(null)
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

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Ensure TTS, STT, and noise cancellation are initialized on app launch
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val serviceIntent = Intent(this, CallConnectionService::class.java)
                startService(serviceIntent)
            } catch (e: Exception) {
                Log.e("MainActivity", "Failed to start CallConnectionService for audio init", e)
            }
        }
    }

    private fun startCallStateMonitoring() {
        Log.d("MainActivity", "Starting call state monitoring")
        
        // Register phone state listener
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            telephonyManager.registerTelephonyCallback(
                mainExecutor,
                object : TelephonyCallback(), TelephonyCallback.CallStateListener {
                    override fun onCallStateChanged(state: Int) {
                        handleCallStateChange(state)
                    }
                }
            )
        } else {
            @Suppress("DEPRECATION")
            phoneStateListener = object : PhoneStateListener() {
                override fun onCallStateChanged(state: Int, phoneNumber: String?) {
                    handleCallStateChange(state)
                }
            }
            telephonyManager.listen(phoneStateListener, PhoneStateListener.LISTEN_CALL_STATE)
        }

        // Register broadcast receiver for call events
        callStateReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {
                    TelephonyManager.ACTION_PHONE_STATE_CHANGED -> {
                        val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE)
                        val number = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)
                        Log.d("MainActivity", "Call state changed via broadcast: $state, number: $number")
                        handleCallStateChange(getCallStateFromString(state))
                    }
                }
            }
        }
        
        val filter = IntentFilter().apply {
            addAction(TelephonyManager.ACTION_PHONE_STATE_CHANGED)
        }
        registerReceiver(callStateReceiver, filter)
    }

    private fun stopCallStateMonitoring() {
        Log.d("MainActivity", "Stopping call state monitoring")
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            telephonyManager.unregisterTelephonyCallback(object : TelephonyCallback() {})
        } else {
            @Suppress("DEPRECATION")
            phoneStateListener?.let { telephonyManager.listen(it, PhoneStateListener.LISTEN_NONE) }
        }
        
        callStateReceiver?.let { unregisterReceiver(it) }
    }

    private fun handleCallStateChange(state: Int) {
        val stateString = when (state) {
            TelephonyManager.CALL_STATE_IDLE -> "IDLE"
            TelephonyManager.CALL_STATE_RINGING -> "RINGING"
            TelephonyManager.CALL_STATE_OFFHOOK -> "OFFHOOK"
            else -> "UNKNOWN"
        }
        
        Log.d("MainActivity", "Call state changed: $stateString ($state)")
        
        // Send state to Flutter
        callStateChannel?.invokeMethod("onCallStateChanged", mapOf(
            "state" to stateString,
            "stateCode" to state,
            "timestamp" to System.currentTimeMillis()
        ))
    }

    private fun getCallStateFromString(state: String?): Int {
        return when (state) {
            TelephonyManager.EXTRA_STATE_IDLE -> TelephonyManager.CALL_STATE_IDLE
            TelephonyManager.EXTRA_STATE_RINGING -> TelephonyManager.CALL_STATE_RINGING
            TelephonyManager.EXTRA_STATE_OFFHOOK -> TelephonyManager.CALL_STATE_OFFHOOK
            else -> TelephonyManager.CALL_STATE_IDLE
        }
    }

    private fun getCurrentCallState(): Map<String, Any> {
        val state = telephonyManager.callState
        val stateString = when (state) {
            TelephonyManager.CALL_STATE_IDLE -> "IDLE"
            TelephonyManager.CALL_STATE_RINGING -> "RINGING"
            TelephonyManager.CALL_STATE_OFFHOOK -> "OFFHOOK"
            else -> "UNKNOWN"
        }
        
        return mapOf(
            "state" to stateString,
            "stateCode" to state,
            "timestamp" to System.currentTimeMillis()
        )
    }
}
