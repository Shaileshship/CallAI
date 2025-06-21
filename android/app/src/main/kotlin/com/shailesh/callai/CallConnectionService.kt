package com.shailesh.callai

import android.content.Intent
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.telecom.Connection
import android.telecom.ConnectionRequest
import android.telecom.ConnectionService
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import android.util.Log
import androidx.annotation.RequiresApi
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.nio.ByteBuffer
import java.nio.ByteOrder

@RequiresApi(Build.VERSION_CODES.M)
class CallConnectionService : ConnectionService() {
    private val audioScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var audioRecord: AudioRecord? = null
    private var audioTrack: AudioTrack? = null
    private var isRecording = false
    private var isPlaying = false
    private val sampleRate = 16000
    private val channelConfig = AudioFormat.CHANNEL_IN_MONO
    private val audioFormat = AudioFormat.ENCODING_PCM_16BIT
    private val bufferSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat)
    
    companion object {
        private const val TAG = "CallConnectionService"
        private var methodChannel: MethodChannel? = null
        
        fun setMethodChannel(channel: MethodChannel) {
            methodChannel = channel
        }
    }

    override fun onCreateOutgoingConnection(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ): Connection {
        Log.d(TAG, "onCreateOutgoingConnection")
        request ?: throw RuntimeException("ConnectionRequest cannot be null")

        val connection = CallConnection()
        connection.setInitializing()
        connection.setAddress(request.address, TelecomManager.PRESENTATION_ALLOWED)
        
        // Set up audio capabilities
        connection.audioModeIsVoip = true
        connection.setConnectionCapabilities(Connection.CAPABILITY_MUTE)
        
        // Start audio processing when call becomes active
        connection.setCallAudioStateChangedListener { audioState ->
            Log.d(TAG, "Audio state changed: $audioState")
            if (audioState?.isMuted == false) {
                startAudioProcessing()
            } else {
                stopAudioProcessing()
            }
        }

        connection.setActive()
        return connection
    }

    private fun startAudioProcessing() {
        if (isRecording) return
        
        Log.d(TAG, "Starting audio processing")
        isRecording = true
        
        audioScope.launch {
            try {
                setupAudioRecord()
                setupAudioTrack()
                processAudioStream()
            } catch (e: Exception) {
                Log.e(TAG, "Error in audio processing", e)
            }
        }
    }

    private fun stopAudioProcessing() {
        Log.d(TAG, "Stopping audio processing")
        isRecording = false
        isPlaying = false
        
        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null
        
        audioTrack?.stop()
        audioTrack?.release()
        audioTrack = null
    }

    private fun setupAudioRecord() {
        audioRecord = AudioRecord(
            MediaRecorder.AudioSource.VOICE_COMMUNICATION,
            sampleRate,
            channelConfig,
            audioFormat,
            bufferSize
        )
        audioRecord?.startRecording()
        Log.d(TAG, "AudioRecord started")
    }

    private fun setupAudioTrack() {
        audioTrack = AudioTrack.Builder()
            .setAudioAttributes(android.media.AudioAttributes.Builder()
                .setUsage(android.media.AudioAttributes.USAGE_VOICE_COMMUNICATION)
                .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SPEECH)
                .build())
            .setAudioFormat(android.media.AudioFormat.Builder()
                .setEncoding(android.media.AudioFormat.ENCODING_PCM_16BIT)
                .setSampleRate(sampleRate)
                .setChannelMask(android.media.AudioFormat.CHANNEL_OUT_MONO)
                .build())
            .setBufferSizeInBytes(bufferSize)
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()
        
        audioTrack?.play()
        Log.d(TAG, "AudioTrack started")
    }

    private suspend fun processAudioStream() {
        val buffer = ByteArray(bufferSize)
        
        while (isRecording) {
            val readSize = audioRecord?.read(buffer, 0, bufferSize) ?: 0
            if (readSize > 0) {
                // Send audio data to Flutter for processing
                sendAudioToFlutter(buffer.copyOf(readSize))
                
                // For now, just echo the audio back (we'll replace this with AI processing)
                if (isPlaying) {
                    audioTrack?.write(buffer, 0, readSize)
                }
            }
        }
    }

    private suspend fun sendAudioToFlutter(audioData: ByteArray) {
        try {
            methodChannel?.invokeMethod("processAudio", mapOf("audioData" to audioData))
        } catch (e: Exception) {
            Log.e(TAG, "Error sending audio to Flutter", e)
        }
    }

    override fun onCreateOutgoingConnectionFailed(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ) {
        super.onCreateOutgoingConnectionFailed(connectionManagerPhoneAccount, request)
        Log.e(TAG, "onCreateOutgoingConnectionFailed")
    }

    override fun onCreateIncomingConnection(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ): Connection {
        Log.d(TAG, "onCreateIncomingConnection - Rejecting")
        request ?: throw RuntimeException("ConnectionRequest cannot be null")
        val connection = CallConnection()
        connection.setDisconnected("Not supported")
        return connection
    }

    override fun onDestroy() {
        super.onDestroy()
        stopAudioProcessing()
        audioScope.cancel()
    }
}

@RequiresApi(Build.VERSION_CODES.M)
class CallConnection : Connection() {

    init {
        audioModeIsVoip = true
    }

    override fun onShowIncomingCallUi() {
        // We don't handle incoming calls.
    }

    override fun onCallAudioStateChanged(state: android.telecom.CallAudioState?) {
        Log.d("CallConnection", "onCallAudioStateChanged: $state")
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
        destroy()
    }

    override fun onSeparate() {
        // Not implemented
    }

    override fun onAbort() {
        Log.d("CallConnection", "onAbort")
        destroy()
    }

    override fun onHold() {
        // Not implemented
    }

    override fun onUnhold() {
        // Not implemented
    }
} 