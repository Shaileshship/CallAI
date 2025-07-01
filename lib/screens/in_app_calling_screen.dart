import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart';
import '../services/speech_to_text_service.dart';
// TODO: Add a streaming speech-to-text package

class InAppCallingScreen extends StatefulWidget {
  final List<Map<String, String>> contacts;
  final String prompt;
  final String excelFilePath;
  final String deviceId;
  final String selectedProvider;

  const InAppCallingScreen({
    Key? key,
    required this.contacts,
    required this.prompt,
    required this.excelFilePath,
    required this.deviceId,
    required this.selectedProvider,
  }) : super(key: key);

  @override
  _InAppCallingScreenState createState() => _InAppCallingScreenState();
}

class _InAppCallingScreenState extends State<InAppCallingScreen> {
  static const platform = MethodChannel('com.shailesh.callai/call');

  int _currentIndex = 0;
  String _callStatus = 'Initializing...';
  int _callDuration = 0;
  Timer? _callTimer;
  bool _isSpeakerOn = true;
  List<String> _transcript = [];
  final SpeechToTextService _sttService = SpeechToTextService();

  @override
  void initState() {
    super.initState();
    _setupPlatformListener();
    _startCallCycle();
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    // TODO: Dispose of speech-to-text resources
    super.dispose();
  }

  void _setupPlatformListener() {
    platform.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onSpeech':
          final audioData = call.arguments['audioData'] as Uint8List?;
          if (audioData != null) {
            final transcript = await _sttService.transcribe(audioData);
            if (transcript.isNotEmpty) {
              setState(() {
                _transcript.add('User: $transcript');
              });
            }
          }
          break;
        case 'onCallStateChanged':
          final state = call.arguments as String?;
          if(state != null){
            setState(() {
              _callStatus = state;
            });
          }
          break;
      }
    });
  }

  Future<void> _startCallCycle() async {
    if (_currentIndex >= widget.contacts.length) {
      setState(() {
        _callStatus = 'All calls completed.';
      });
      return;
    }
    
    final contact = widget.contacts[_currentIndex];
    final phoneNumber = contact['phone']!;
    final contactName = contact['name'] ?? 'Unknown';

    setState(() {
      _callStatus = 'Calling $contactName...';
      _callDuration = 0;
      _transcript = []; // Clear transcript for new call
    });

    try {
      await platform.invokeMethod('startCall', {'number': phoneNumber});
      _startCallTimer();
    } on PlatformException catch (e) {
      setState(() {
        _callStatus = 'Failed to call: ${e.message}';
      });
    }
  }

  void _startCallTimer() {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _callDuration++;
      });
    });
  }

  Future<void> _endCall() async {
    _callTimer?.cancel();
    try {
      await platform.invokeMethod('endCall');
      setState(() {
        _callStatus = 'Call Ended';
        // TODO: Trigger automated note-taking here with the final transcript
      });
      await Future.delayed(const Duration(seconds: 2));
      _currentIndex++;
      _startCallCycle();
    } on PlatformException catch (e) {
      setState(() {
        _callStatus = 'Failed to end call: ${e.message}';
      });
    }
  }

  Future<void> _toggleSpeaker() async {
    try {
      final newSpeakerState = !_isSpeakerOn;
      await platform.invokeMethod('setSpeakerphoneOn', {'on': newSpeakerState});
      setState(() {
        _isSpeakerOn = newSpeakerState;
      });
    } on PlatformException catch (e) {
      // Handle error
      print("Failed to toggle speaker: '${e.message}'.");
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final contact = widget.contacts.length > _currentIndex ? widget.contacts[_currentIndex] : {'name': 'Done', 'phone': ''};
    final contactName = contact['name'] ?? 'Unknown';

    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Top Info
              Column(
                children: [
                  Text(
                    contactName,
                    style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _callStatus,
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade400),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _formatDuration(_callDuration),
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade400),
                  ),
                ],
              ),
              
              // Transcript View
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 20),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10)
                  ),
                  child: ListView.builder(
                    itemCount: _transcript.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Text(
                          _transcript[index],
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FloatingActionButton(
                    heroTag: 'speaker_btn',
                    onPressed: _toggleSpeaker,
                    backgroundColor: _isSpeakerOn ? Colors.blue : Colors.grey.shade800,
                    child: Icon(_isSpeakerOn ? Icons.volume_up : Icons.volume_off, color: Colors.white),
                  ),
                  FloatingActionButton(
                    heroTag: 'end_call_btn',
                    onPressed: _endCall,
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.call_end, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
} 