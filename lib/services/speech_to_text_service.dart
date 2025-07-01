import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis/speech/v1.dart' as speech;
import 'package:googleapis_auth/auth_io.dart';

class SpeechToTextService {
  static final SpeechToTextService _instance = SpeechToTextService._internal();
  factory SpeechToTextService() => _instance;
  SpeechToTextService._internal();

  speech.SpeechApi? _speechApi;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    final credentialsJson = await rootBundle.loadString('assets/google_cloud_credentials.json');
    final credentials = ServiceAccountCredentials.fromJson(credentialsJson);
    final client = await clientViaServiceAccount(
      credentials,
      [speech.SpeechApi.cloudPlatformScope],
    );
    _speechApi = speech.SpeechApi(client);
    _initialized = true;
  }

  /// Transcribes a list of audio bytes (PCM 16-bit, 16kHz, mono)
  Future<String> transcribe(Uint8List audioBytes) async {
    await initialize();
    final config = speech.RecognitionConfig(
      encoding: 'LINEAR16',
      sampleRateHertz: 16000,
      languageCode: 'en-US',
      enableAutomaticPunctuation: true,
    );
    final audio = speech.RecognitionAudio(content: base64Encode(audioBytes));
    final request = speech.RecognizeRequest(config: config, audio: audio);
    final response = await _speechApi!.speech.recognize(request);
    if (response.results == null || response.results!.isEmpty) return '';
    return response.results!.map((r) => r.alternatives?.first.transcript ?? '').join(' ');
  }
} 