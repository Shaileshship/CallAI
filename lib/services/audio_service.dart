import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'firebase_service.dart';

class AudioService {
  static const platform = MethodChannel('com.shailesh.callai/audio');
  static const audioChannel = MethodChannel('com.shailesh.callai/audio');
  
  static AudioService? _instance;
  static AudioService get instance => _instance ??= AudioService._();
  
  AudioService._() {
    _initAudioProcessing();
  }

  stt.SpeechToText? _speechToText;
  FlutterTts? _tts;
  bool _isListening = false;
  String _currentConversation = '';
  String _contactName = '';
  String _prompt = '';
  String _deviceId = '';

  void _initAudioProcessing() {
    _speechToText = stt.SpeechToText();
    _tts = FlutterTts();
    
    // Set up TTS
    _tts?.setLanguage('en-US');
    _tts?.setSpeechRate(0.5);
    _tts?.setVolume(1.0);
    
    // Set up method channel handler
    audioChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'processAudio':
          final audioData = call.arguments['audioData'] as List<int>?;
          if (audioData != null) {
            await _processAudioData(audioData);
          }
          break;
        default:
          throw PlatformException(
            code: 'Unimplemented',
            details: 'Method ${call.method} not implemented',
          );
      }
    });
  }

  Future<void> startCall(String contactName, String prompt, String deviceId) async {
    _contactName = contactName;
    _prompt = prompt;
    _deviceId = deviceId;
    _currentConversation = '';
    
    // Initialize speech recognition
    await _speechToText?.initialize();
    
    // Start listening for speech
    await _startListening();
  }

  Future<void> _startListening() async {
    if (_isListening) return;
    
    _isListening = true;
    await _speechToText?.listen(
      onResult: (result) async {
        if (result.finalResult) {
          final text = result.recognizedWords;
          if (text.isNotEmpty) {
            await _processSpeech(text);
          }
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
    );
  }

  Future<void> _processSpeech(String speech) async {
    // Add to conversation history
    _currentConversation += 'User: $speech\n';
    
    try {
      // Get Gemini API key
      final apiKeys = await FirebaseService.getUserApiKeys(_deviceId);
      final geminiApiKey = apiKeys['gemini'];
      
      if (geminiApiKey == null || geminiApiKey.isEmpty) {
        throw Exception('No Gemini API key available');
      }

      // Generate AI response
      final aiResponse = await _generateAIResponse(speech, geminiApiKey);
      
      // Add AI response to conversation
      _currentConversation += 'AI: $aiResponse\n';
      
      // Convert AI response to speech and play it
      await _speakResponse(aiResponse);
      
      // Continue listening
      await _startListening();
      
    } catch (e) {
      print('Error processing speech: $e');
      // Continue listening even if there's an error
      await _startListening();
    }
  }

  Future<String> _generateAIResponse(String userSpeech, String apiKey) async {
    final context = '''
You are an AI assistant making a cold call. The person's name is $_contactName.
Your role: $_prompt

Previous conversation:
$_currentConversation

Current user speech: $userSpeech

Generate a natural, conversational response that continues the conversation. Keep it brief and engaging.
''';

    return await FirebaseService.generateResponseWithGemini(context, apiKey);
  }

  Future<void> _speakResponse(String text) async {
    await _tts?.speak(text);
    
    // Wait for TTS to complete
    _tts?.setCompletionHandler(() {
      // TTS completed, continue listening
    });
  }

  Future<void> _processAudioData(List<int> audioData) async {
    // This is where we would process the raw audio data
    // For now, we'll rely on the speech_to_text plugin
    // In a full implementation, we would:
    // 1. Convert audio data to the right format
    // 2. Send to speech recognition service
    // 3. Process the result
    
    print('Received audio data: ${audioData.length} bytes');
  }

  Future<void> endCall() async {
    _isListening = false;
    await _speechToText?.stop();
    await _tts?.stop();
    
    // Save conversation log
    await _saveConversationLog();
  }

  Future<void> _saveConversationLog() async {
    try {
      // Generate summary using Gemini
      final apiKeys = await FirebaseService.getUserApiKeys(_deviceId);
      final geminiApiKey = apiKeys['gemini'];
      
      if (geminiApiKey != null) {
        final summary = await _generateCallSummary(geminiApiKey);
        
        // Save to Firebase
        await FirebaseService.saveCallResult(
          _deviceId,
          _contactName,
          _currentConversation,
          summary,
        );
      }
    } catch (e) {
      print('Error saving conversation log: $e');
    }
  }

  Future<String> _generateCallSummary(String apiKey) async {
    final prompt = '''
Summarize this cold call conversation in one word or short phrase:
$_currentConversation

Choose from: Interested, Not interested, Requested callback, No answer, Wrong number, or similar.
''';

    return await FirebaseService.generateResponseWithGemini(prompt, apiKey);
  }
} 