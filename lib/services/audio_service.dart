import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'firebase_service.dart';
import 'package:get_it/get_it.dart';
import 'wallet_service.dart';
import 'dart:async';

class AudioService {
  static const platform = MethodChannel('com.shailesh.callai/audio');
  static const audioChannel = MethodChannel('com.shailesh.callai/audio');
  
  final FlutterTts tts;
  final SpeechToText stt;

  AudioService(this.tts, this.stt);

  static void register() {
    GetIt.I.registerSingletonAsync<AudioService>(() async {
      final tts = FlutterTts();
      final sttInstance = SpeechToText();
      
      // Set up TTS
      // These settings can be adjusted as needed
      await tts.setLanguage("en-US");
      await tts.setSpeechRate(0.5);
      await tts.setVolume(1.0);
      await tts.setPitch(1.0);
      
      // Await for TTS settings to be set before proceeding.
      // On Android, this might help in forcing audio to the speaker.
      await tts.awaitSpeakCompletion(true);
      await tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback, 
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers
        ]
      );

      // Initialize STT
      await sttInstance.initialize(
        onError: (error) => print('STT Error: $error'),
        onStatus: (status) => print('STT Status: $status'),
      );

      final service = AudioService(tts, sttInstance);
      return service;
    });
  }

  static AudioService get instance => GetIt.I<AudioService>();

  bool get isListening => _isListening;
  
  Future<void> stopListening() async {
    if (_isListening) {
      await stt.stop();
      _isListening = false;
    }
  }

  bool _isListening = false;
  bool _isSpeaking = false;
  String _currentConversation = '';
  String _contactName = '';
  String _prompt = '';
  String _deviceId = '';
  String _aiProvider = 'deepseek';
  double _aiPrice = 0.2;

  void _initAudioProcessing() {
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

  Future<void> startCall(String contactName, String prompt, String deviceId, {String provider = 'deepseek', double price = 0.2}) async {
    _contactName = contactName;
    _prompt = prompt;
    _deviceId = deviceId;
    _aiProvider = provider;
    _aiPrice = price;
    _currentConversation = '';
    // Deduct price from wallet
    await WalletService.buyPackFromWallet(deviceId); // You may want to create a new method to deduct exact price
    // Start listening for speech
    await startListening();
  }

  Future<String> startListening() async {
    if (_isListening || _isSpeaking) return '';
    _isListening = true;

    final completer = Completer<String>();

    await stt.listen(
      onResult: (result) async {
        if (result.finalResult) {
          final text = result.recognizedWords;
          if (text.isNotEmpty) {
            completer.complete(text);
          } else {
            completer.complete('');
          }
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
    );

    // Wait for the result and return it
    final recognizedText = await completer.future;
    _isListening = false;
    return recognizedText;
  }

  Future<void> _processSpeech(String speech) async {
    _currentConversation += 'User: $speech\n';
    try {
      final apiKeys = await FirebaseService.getUserApiKeys(_deviceId);
      final apiKey = apiKeys[_aiProvider];
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('No $_aiProvider API key available');
      }
      final aiResponse = await FirebaseService.generateAIResponse(speech, _aiProvider, apiKey);
      _currentConversation += 'AI: $aiResponse\n';
      await speakResponse(aiResponse);
    } catch (e) {
      print('Error processing speech: $e');
    } finally {
      await startListening();
    }
  }

  Future<void> _setSpeakerphoneOn(bool on) async {
    try {
      // This method call corresponds to the native code in MainActivity.kt
      await audioChannel.invokeMethod('setSpeakerphoneOn', {'on': on});
    } on PlatformException catch (e) {
      print("Failed to set speakerphone on Android: '${e.message}'.");
    }
  }

  Future<void> speakResponse(String text) async {
    if (_isSpeaking) return; // Prevent concurrent speech attempts
    await stopListening();
    _isSpeaking = true;
    
    try {
      // Turn speaker ON before speaking
      await _setSpeakerphoneOn(true);
      // Since awaitSpeakCompletion(true) was set at initialization,
      // this will wait until speaking is done.
      await tts.speak(text);
    } catch (e) {
      print("TTS Error: $e");
    } finally {
      // Turn speaker OFF after speaking or if an error occurred
      await _setSpeakerphoneOn(false);
      _isSpeaking = false;
      // Resume listening for the user
      startListening();
    }
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
    await stt.stop();
    await tts.stop();
    
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