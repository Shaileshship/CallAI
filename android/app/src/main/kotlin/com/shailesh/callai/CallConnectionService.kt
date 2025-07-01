package com.shailesh.callai

import android.annotation.SuppressLint
import android.content.Context
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.telecom.Connection
import android.telecom.ConnectionRequest
import android.telecom.ConnectionService
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import android.util.Log
import androidx.annotation.RequiresApi
import io.flutter.plugin.common.MethodChannel
import android.telecom.DisconnectCause
import android.media.AudioFormat
import android.media.AudioTrack

@RequiresApi(Build.VERSION_CODES.M)
class CallConnectionService : ConnectionService() {

    private var currentConnection: CallConnection? = null
    private lateinit var audioManager: AudioManager
    private var audioTrack: AudioTrack? = null

    companion object {
        private const val TAG = "CallConnectionService"
        private var methodChannel: MethodChannel? = null
        private var instance: CallConnectionService? = null

        fun setMethodChannel(channel: MethodChannel) {
            methodChannel = channel
            instance = CallConnectionService()
            instance?.setupMethodCallHandler()
        }

        @JvmStatic
        fun playAudio(audioData: ByteArray) {
            instance?.playAudioInternal(audioData)
        }
    }

    override fun onCreate() {
        super.onCreate()
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
    }

    private fun setupMethodCallHandler() {
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startCall" -> {
                    val number = call.argument<String>("number")
                    if (number != null) {
                        startCall(number)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Phone number is required.", null)
                    }
                }
                "endCall" -> {
                    endCall()
                    result.success(null)
                }
                "setSpeakerphoneOn" -> {
                    val on = call.argument<Boolean>("on")
                    if (on != null) {
                        setSpeakerphoneOn(on)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Boolean 'on' is required.", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun startCall(number: String) {
        val telecomManager = getSystemService(Context.TELECOM_SERVICE) as TelecomManager
        val phoneAccountHandle = PhoneAccountManager.getPhoneAccountHandle(this)
        val uri = Uri.fromParts("tel", number, null)

        val extras = Bundle()
        extras.putBoolean(TelecomManager.EXTRA_START_CALL_WITH_SPEAKERPHONE, true)

        telecomManager.placeCall(uri, extras)
    }

    private fun endCall() {
        currentConnection?.onDisconnect()
    }

    private fun setSpeakerphoneOn(on: Boolean) {
        audioManager.isSpeakerphoneOn = on
    }

    override fun onCreateOutgoingConnection(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest
    ): Connection {
        Log.d(TAG, "onCreateOutgoingConnection")
        
        val connection = CallConnection {
            // Handle state changes if needed
        }.apply {
            setAddress(request.address, TelecomManager.PRESENTATION_ALLOWED)
            audioModeIsVoip = true
            setCallerDisplayName("Call-AI", TelecomManager.PRESENTATION_ALLOWED)
            setInitializing()
        }
        
        currentConnection = connection
        return connection
    }

    override fun onCreateOutgoingConnectionFailed(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ) {
        super.onCreateOutgoingConnectionFailed(connectionManagerPhoneAccount, request)
        Log.e(TAG, "onCreateOutgoingConnectionFailed")
        methodChannel?.invokeMethod("onCallStateChanged", "failed")
    }

    fun playAudioInternal(audioData: ByteArray) {
        val sampleRate = 16000 // Match your TTS output
        if (audioTrack == null) {
            audioTrack = AudioTrack(
                AudioManager.STREAM_VOICE_CALL,
                sampleRate,
                AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                AudioTrack.getMinBufferSize(sampleRate, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT),
                AudioTrack.MODE_STREAM
            )
            audioTrack?.play()
        }
        audioTrack?.write(audioData, 0, audioData.size)
    }

    fun stopAudioPlayback() {
        audioTrack?.stop()
        audioTrack?.release()
        audioTrack = null
    }
}

@RequiresApi(Build.VERSION_CODES.M)
class CallConnection(private val onAudioStateChanged: (state: android.telecom.CallAudioState?) -> Unit) : Connection() {

    init {
        audioModeIsVoip = true
    }

    override fun onShowIncomingCallUi() {
        // We don't handle incoming calls.
    }

    override fun onCallAudioStateChanged(state: android.telecom.CallAudioState?) {
        Log.d("CallConnection", "onCallAudioStateChanged: $state")
        onAudioStateChanged(state)
    }

    override fun onStateChanged(state: Int) {
        super.onStateChanged(state)
        Log.d("CallConnection", "onStateChanged: $state")
        
        when (state) {
            STATE_ACTIVE -> {
                Log.d("CallConnection", "Call is now active")
            }
            STATE_DISCONNECTED -> {
                Log.d("CallConnection", "Call disconnected")
                destroy()
            }
        }
    }

    override fun onPlayDtmfTone(c: Char) {
        // Not implemented
    }

    override fun onDisconnect() {
        Log.d("CallConnection", "onDisconnect")
        setDisconnected(DisconnectCause(DisconnectCause.LOCAL))
        destroy()
    }

    override fun onSeparate() {
        // Not implemented
    }

    override fun onAbort() {
        Log.d("CallConnection", "onAbort")
        setDisconnected(DisconnectCause(DisconnectCause.LOCAL))
        destroy()
    }

    override fun onHold() {
        // Not implemented
    }

    override fun onUnhold() {
        // Not implemented
    }
} 