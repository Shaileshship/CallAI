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
import android.telecom.DisconnectCause
import android.content.Context
import android.speech.tts.TextToSpeech
import android.speech.SpeechRecognizer
import android.media.AudioFocusRequest
import android.media.AudioManager.OnAudioFocusChangeListener
import java.util.Locale

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
    private var tts: TextToSpeech? = null
    private var stt: SpeechRecognizer? = null
    private var ttsReady = false
    private var sttReady = false
    private var aiSpeaking = false
    private var audioFocusRequest: AudioFocusRequest? = null
    private var audioManager: AudioManager? = null
    private var rnnoiseState: Long = 0L // JNI handle for RNNoise
    
    companion object {
        private const val TAG = "CallConnectionService"
        private var methodChannel: MethodChannel? = null
        private var instance: CallConnectionService? = null
        
        fun setMethodChannel(channel: MethodChannel) {
            methodChannel = channel
        }

        fun playAudio(audioData: ByteArray) {
            instance?.playAudioData(audioData)
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        // Request audio focus for the app
        val focusListener = OnAudioFocusChangeListener { focusChange ->
            // Handle focus changes if needed
        }
        audioFocusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
            .setOnAudioFocusChangeListener(focusListener)
            .build()
        audioManager?.requestAudioFocus(audioFocusRequest!!)
        // Force speakerphone ON
        audioManager?.mode = AudioManager.MODE_IN_COMMUNICATION
        audioManager?.isSpeakerphoneOn = true
        // Initialize TTS
        tts = TextToSpeech(this) { status ->
            ttsReady = (status == TextToSpeech.SUCCESS)
            if (ttsReady) {
                tts?.language = Locale.US
                // Use best available voice (e.g., Wavenet)
                tts?.voice = tts?.voices?.find { it.locale == Locale.US && it.name.contains("wavenet", true) } ?: tts?.defaultVoice
            }
        }
        // Initialize STT
        stt = SpeechRecognizer.createSpeechRecognizer(this)
        sttReady = true // You may want to add a listener for full readiness
        // Initialize RNNoise
        rnnoiseState = RNNoise.create()
    }

    override fun onDestroy() {
        super.onDestroy()
        RNNoise.destroy(rnnoiseState)
        audioScope.cancel()
        instance = null
        tts?.shutdown()
        stt?.destroy()
        audioManager?.abandonAudioFocusRequest(audioFocusRequest!!)
    }

    override fun onCreateOutgoingConnection(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ): Connection {
        Log.d(TAG, "onCreateOutgoingConnection")
        request ?: throw RuntimeException("ConnectionRequest cannot be null")

        val connection = CallConnection { audioState ->
            Log.d(TAG, "Audio state changed: $audioState")
            if (audioState?.isMuted == false) {
                startAudioProcessing()
            } else {
                stopAudioProcessing()
            }
        }
        connection.setInitializing()
        connection.setAddress(request.address, TelecomManager.PRESENTATION_ALLOWED)
        
        // Set up audio capabilities
        connection.audioModeIsVoip = true
        connection.setConnectionCapabilities(Connection.CAPABILITY_MUTE)
        
        connection.setActive()
        return connection
    }

    private fun startAudioProcessing() {
        if (isRecording) return
        Log.d(TAG, "Starting audio processing")
        isRecording = true
        // Request audio focus and force speakerphone ON
        audioManager?.requestAudioFocus(audioFocusRequest!!)
        audioManager?.mode = AudioManager.MODE_IN_COMMUNICATION
        audioManager?.isSpeakerphoneOn = true
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
        audioTrack = AudioTrack(
            AudioManager.STREAM_VOICE_CALL,
            sampleRate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            bufferSize,
            AudioTrack.MODE_STREAM
        )
        audioTrack?.play()
        Log.d(TAG, "AudioTrack started (STREAM_VOICE_CALL)")
    }

    private suspend fun processAudioStream() {
        val buffer = ShortArray(bufferSize / 2)
        val byteBuffer = ByteBuffer.allocate(bufferSize).order(ByteOrder.LITTLE_ENDIAN)
        while (isRecording) {
            val readSize = audioRecord?.read(byteBuffer.array(), 0, byteBuffer.capacity()) ?: 0
            if (readSize > 0) {
                byteBuffer.asShortBuffer().get(buffer)

                // Noise cancellation with RNNoise JNI
                RNNoise.processFrame(rnnoiseState, buffer)

                byteBuffer.asShortBuffer().put(buffer)
                
                // Send processed audio to Flutter for AI/STT
                sendAudioToFlutter(byteBuffer.array().copyOf(readSize))
                // Barge-in logic: if AI is speaking and user starts speaking, stop TTS
                if (aiSpeaking && userSpeechDetected(byteBuffer.array())) {
                    tts?.stop()
                    aiSpeaking = false
                    // Start STT listening here
                }
                // Echo or play AI audio if needed
                if (isPlaying) {
                    audioTrack?.write(byteBuffer.array(), 0, readSize)
                }
            }
        }
    }

    private suspend fun sendAudioToFlutter(audioData: ByteArray) {
        try {
            methodChannel?.invokeMethod("onSpeech", mapOf("audioData" to audioData))
        } catch (e: Exception) {
            Log.e(TAG, "Error sending audio to Flutter", e)
        }
    }

    fun playAudioData(audioData: ByteArray) {
        audioScope.launch {
            try {
                val written = audioTrack?.write(audioData, 0, audioData.size)
                Log.d(TAG, "AudioTrack write result: $written bytes")
            } catch (e: Exception) {
                Log.e(TAG, "Error playing audio data", e)
            }
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
        val connection = CallConnection {}
        connection.setDisconnected(DisconnectCause(DisconnectCause.REJECTED, "Not supported"))
        return connection
    }

    fun speakAI(text: String) {
        if (ttsReady) {
            aiSpeaking = true
            tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "AI_TTS")
        }
    }

    fun stopAISpeech() {
        tts?.stop()
        aiSpeaking = false
    }

    // Placeholder for user speech detection (could use amplitude or partial STT)
    private fun userSpeechDetected(audio: ByteArray): Boolean {
        // TODO: Implement real VAD or use STT partial results
        return false
    }

    // JNI methods for RNNoise
    external fun rnnoiseInit(): Long
    external fun rnnoiseProcess(state: Long, input: ByteArray, output: ByteArray, length: Int): Int
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