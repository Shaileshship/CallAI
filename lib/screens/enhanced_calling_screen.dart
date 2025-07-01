import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/rendering.dart';

import '../main.dart';
import '../services/device_service.dart';
import '../services/firebase_service.dart';
import '../services/audio_service.dart';
import '../services/wallet_service.dart';
import '../services/call_state_service.dart';
import 'login_screen.dart';
import 'conversation_log_screen.dart';
import 'calling_screen.dart';
import 'in_app_calling_screen.dart';

class EnhancedCallingScreen extends StatefulWidget {
  final List<Map<String, String>> contacts;
  final String prompt;
  final String excelFilePath;
  final String deviceId;
  final String selectedProvider;
  final String selectedDialer;

  const EnhancedCallingScreen({
    Key? key,
    required this.contacts,
    required this.prompt,
    required this.excelFilePath,
    required this.deviceId,
    required this.selectedProvider,
    required this.selectedDialer,
  }) : super(key: key);

  @override
  State<EnhancedCallingScreen> createState() => _EnhancedCallingScreenState();
}

class _EnhancedCallingScreenState extends State<EnhancedCallingScreen> {
  int _currentIndex = 0;
  bool _isCalling = false;
  String _log = '';
  List<Map<String, String>> _conversation = [];
  bool _callConnected = false;
  bool _conversationActive = false;
  String _currentStatus = "Initializing...";
  CallState? _currentCallState;
  Timer? _callTimer;
  int _callDuration = 0;

  late FlutterTts _tts;
  late SpeechToText _stt;
  late AudioService _audioService;
  late CallStateService _callStateService;
  StreamSubscription<CallState>? _callStateSubscription;

  bool _walletLoaded = false;
  double _walletBalance = 0.0;

  List<String> _callLog = [];

  @override
  void initState() {
    super.initState();
    _audioService = AudioService.instance;
    _tts = _audioService.tts;
    _stt = _audioService.stt;
    _callStateService = CallStateService();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadWallet();
      await _startSession();
    });
  }

  @override
  void dispose() {
    _callStateSubscription?.cancel();
    _callTimer?.cancel();
    _callStateService.dispose();
    super.dispose();
  }

  Future<void> _startSession() async {
    await _initPermissions();
    await _loadWallet();
    await _startCallStateMonitoring();
    if (widget.selectedDialer == 'In-App Dialer') {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (context) => InAppCallingScreen(
          contacts: widget.contacts,
          prompt: widget.prompt,
          excelFilePath: widget.excelFilePath,
          deviceId: widget.deviceId,
          selectedProvider: widget.selectedProvider,
        ),
      ));
      return;
    }
    _processNextCall();
  }

  Future<void> _initPermissions() async {
    setState(() {
      _currentStatus = "Requesting permissions...";
    });
    
    _showToast('Requesting microphone and phone permissions...');
    
    Map<Permission, PermissionStatus> statuses = await [
      Permission.microphone,
      Permission.phone,
    ].request();

    if (statuses[Permission.microphone] != PermissionStatus.granted ||
        statuses[Permission.phone] != PermissionStatus.granted) {
      
      setState(() {
        _currentStatus = "Permissions not granted. Please enable them in settings.";
      });

      _showToast('Permissions not granted. Please enable them in settings.', isError: true);

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Permissions Required'),
          content: const Text('Microphone and Phone permissions are required to make calls. Please open settings to enable them.'),
          actions: [
            TextButton(
              onPressed: () {
                openAppSettings();
                Navigator.of(context).pop();
              },
              child: const Text('Open Settings'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); 
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      return;
    }
    
    _showToast('Permissions granted successfully');
  }

  Future<void> _startCallStateMonitoring() async {
    try {
      await _callStateService.startCallStateMonitoring();
      _callStateSubscription = _callStateService.callStateStream.listen(_handleCallStateChange);
      _logDebug('Call state monitoring started');
      _showToast('Call state monitoring started');
    } catch (e) {
      _logError('Failed to start call state monitoring: $e');
      _showToast('Failed to start call monitoring: $e', isError: true);
    }
  }

  void _handleCallStateChange(CallState callState) {
    _logDebug('Call state changed: ${callState.state} (${callState.stateCode})');
    
    setState(() {
      _currentCallState = callState;
    });

    switch (callState.state) {
      case 'IDLE':
        if (_isCalling) {
          _logDebug('Call ended (IDLE state detected)');
          _showToast('Call ended');
          _endCall();
        }
        _callLog.add('Call ended');
        break;
        
      case 'RINGING':
        _logDebug('Call is ringing');
        _showToast('Call is ringing...');
        setState(() {
          _currentStatus = 'Call is ringing...';
        });
        break;
        
      case 'OFFHOOK':
        if (!_callConnected) {
          _logDebug('Call connected (OFFHOOK state detected)');
          _showToast('Call connected! Starting AI conversation...');
          _callConnected = true;
          _startCallTimer();
          _startConversation();
        }
        _callLog.add('Call connected');
        break;
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

  Future<void> _loadWallet() async {
    final wallet = await WalletService.getWallet(widget.deviceId);
    if (mounted) {
      setState(() {
        _walletBalance = (wallet['walletBalance'] ?? 0.0).toDouble();
        _walletLoaded = true;
      });
    }
  }

  Future<bool> _checkApiKeyAvailable() async {
    final apiKeys = await FirebaseService.getUserApiKeys(widget.deviceId);
    return apiKeys[widget.selectedProvider]?.isNotEmpty == true;
  }

  Future<void> _showMissingApiKeyDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('API Key Missing'),
        content: Text('No API key available for ${widget.selectedProvider}. Please contact admin.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPurchasePrompt() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Insufficient Funds'),
        content: const Text('You need more funds to make calls. Please add money to your wallet.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _processNextCall() async {
    _logDebug('===== STARTING NEW CALL PROCESS =====');
    await _loadWallet();
    
    if (_currentIndex >= widget.contacts.length) {
      _logDebug('All calls completed!');
      _showToast('All calls completed!');
      if (mounted) {
        setState(() {
          _currentStatus = "All calls completed!";
        });
      }
      return;
    }
    
    _logDebug('Processing call ${_currentIndex + 1}/${widget.contacts.length}');
    
    // Check if selected API key is available
    bool apiKeyAvailable = await _checkApiKeyAvailable();
    if (!apiKeyAvailable) {
      _logDebug('API key not available, showing dialog');
      _showToast('No API key available for ${widget.selectedProvider}', isError: true);
      await _showMissingApiKeyDialog();
      return;
    }
    
    // Check if enough funds are left
    if (_walletBalance < 0.20) {
      _logDebug('Insufficient funds: $_walletBalance');
      _showToast('Insufficient funds. Please add money to your wallet.', isError: true);
      await _showPurchasePrompt();
      return;
    }

    final contact = widget.contacts[_currentIndex];
    final phoneNumber = contact['phone']!;
    final contactName = contact['name'] ?? 'Contact';
    
    _logDebug('Calling contact: $contactName ($phoneNumber)');
    _logDebug('Wallet balance: $_walletBalance');
    
    _showToast('Preparing to call $contactName ($phoneNumber)...');
    
    _conversation = [];
    _callConnected = false;
    _conversationActive = false;
    _callDuration = 0;

    setState(() {
      _currentStatus = "Initiating call to $contactName ($phoneNumber)...";
      _log += 'Initiating call to $contactName ($phoneNumber)...\n';
    });

    try {
      _logDebug('Stopping any existing audio...');
      _showToast('Stopping any existing audio...');
      await _audioService.stopListening();
      
      _logDebug('Starting call via native dialer...');
      _showToast('Starting call via native dialer...');
      final callStarted = await _callStateService.startCall(phoneNumber);
      
      if (callStarted) {
        _logDebug('Call initiated successfully');
        _showToast('Call initiated successfully');
        setState(() { 
          _isCalling = true;
          _currentStatus = "Call initiated, waiting for connection...";
        });
        _callLog.add('Call initiated to $contactName ($phoneNumber)');
      } else {
        _logDebug('Failed to start call');
        _showToast('Failed to start call', isError: true);
        _log += 'Failed to start call.\n';
        _processNextCall();
      }
    } catch (e) {
      _logError('Error making call: $e');
      _showToast('Error making call: $e', isError: true);
      _log += 'Error making call: $e\n';
      _processNextCall();
    }
  }

  Future<void> _startConversation() async {
    _logDebug('Starting conversation');
    _logDebug('Call connected: $_callConnected, Conversation active: $_conversationActive');
    
    if (_conversationActive) {
      _logDebug('Conversation already active, skipping...');
      return;
    }
    
    setState(() {
      _currentStatus = 'Call connected, starting AI conversation...';
      _conversationActive = true;
    });

    _callLog.add('AI conversation starting...');
    setState(() {});

    // Wait a moment for the call audio system to be fully established
    _logDebug('Waiting 3 seconds for call audio system to establish...');
    _showToast('Waiting for audio system to establish...');
    await Future.delayed(const Duration(seconds: 3));
    _logDebug('Audio system establishment wait completed');

    try {
      // Validate audio system before proceeding
      _logDebug('Validating audio system...');
      _showToast('Validating audio system...');
      await _validateAudioSystem();
      _callLog.add('TTS validated');
      setState(() {});
      
      _logDebug('Requesting opening line from API...');
      _showToast('Generating opening line...');
      final apiKeys = await FirebaseService.getUserApiKeys(widget.deviceId);
      final geminiApiKey = apiKeys['gemini'];
      if (geminiApiKey == null || geminiApiKey.isEmpty) {
        _logError('No Gemini API key available');
        _showToast('No Gemini API key available. Please contact admin.', isError: true);
        return;
      }
      final openingLine = await FirebaseService.generateOpeningLine(
        widget.prompt,
        widget.selectedProvider,
      );
      _logDebug('Opening line received: "$openingLine"');
      _conversation.add({'speaker': 'AI', 'text': openingLine});
      _callLog.add('TTS speaking: "$openingLine"');
      setState(() {});
      
      _logDebug('Calling TTS with: "$openingLine"');
      _showToast('Speaking opening line...');
      await _audioService.speakResponse(openingLine);
      _logDebug('TTS finished for opening line. Starting STT...');
      _showToast('Opening line spoken. Starting speech recognition...');
      _callLog.add('TTS finished. STT listening...');
      setState(() {});
      
      // Validate STT before starting
      _logDebug('Validating STT before starting...');
      _showToast('Validating speech recognition...');
      await _validateSTT();
      _callLog.add('STT validated');
      setState(() {});
      
      while (_conversationActive) {
        final userText = await _audioService.startListening();
        _conversation.add({'speaker': 'User', 'text': userText});
        if (geminiApiKey == null || geminiApiKey.isEmpty) {
          _logError('No Gemini API key available');
          _showToast('No Gemini API key available. Please contact admin.', isError: true);
          _conversationActive = false;
          break;
        }
        final aiResponse = await FirebaseService.generateResponseWithGemini(
          'Continue this cold call in a professional, engaging, and conversational tone. Respond to the user input below, but do not give a monologue. Keep it short and interactive.\n\nUser: $userText\nAI:',
          geminiApiKey,
        );
        _conversation.add({'speaker': 'AI', 'text': aiResponse});
        await _audioService.speakResponse(aiResponse);
      }
      
      setState(() {
        _currentStatus = 'In conversation with ${widget.contacts[_currentIndex]['name']}';
      });
      
    } catch (e, st) {
      _logError("Error in conversation: $e");
      _showToast('Error in conversation: $e', isError: true);
      _callLog.add('Error: $e');
      setState(() {
        _currentStatus = 'Error in conversation: $e';
        _conversationActive = false;
      });
    }
  }

  Future<void> _validateAudioSystem() async {
    _logDebug('Validating audio system components...');
    
    try {
      // Test TTS availability
      _logDebug('Testing TTS availability...');
      final ttsAvailable = await _tts.isLanguageAvailable("en-US");
      _logDebug('TTS available: $ttsAvailable');
      
      if (!ttsAvailable) {
        throw Exception('TTS not available for English');
      }
      
      _logDebug('Audio system validation completed successfully');
    } catch (e) {
      _logError('Audio system validation failed: $e');
      throw Exception('Audio system validation failed: $e');
    }
    _callLog.add('TTS validation completed');
  }

  Future<void> _validateSTT() async {
    _logDebug('Validating STT system...');
    
    try {
      // Test STT availability
      _logDebug('Testing STT availability...');
      final sttAvailable = await _stt.initialize();
      _logDebug('STT available: $sttAvailable');
      
      if (!sttAvailable) {
        throw Exception('STT not available');
      }
      
      // Test microphone permissions
      _logDebug('Testing microphone permissions...');
      final micPermission = await Permission.microphone.status;
      _logDebug('Microphone permission: $micPermission');
      
      if (micPermission != PermissionStatus.granted) {
        throw Exception('Microphone permission not granted');
      }
      
      _logDebug('STT validation completed successfully');
    } catch (e) {
      _logError('STT validation failed: $e');
      throw Exception('STT validation failed: $e');
    }
    _callLog.add('STT validation completed');
  }

  Future<void> _endCall() async {
    _logDebug('===== ENDING CALL =====');
    _logDebug('Call state: isCalling=$_isCalling, connected=$_callConnected, active=$_conversationActive');
    
    if (!_isCalling) {
      _logDebug('Call not active, skipping end call process');
      return;
    }

    _showToast('Ending call...');

    _logDebug('Cancelling call timer...');
    _callTimer?.cancel();
    
    _logDebug('Ending audio service...');
    _showToast('Stopping audio services...');
    await _audioService.endCall();

    // Calculate API cost and deduct from wallet
    _logDebug('Calculating API cost for conversation...');
    _showToast('Calculating call cost...');
    final apiCost = await FirebaseService.calculateCostForConversation(_conversation, widget.selectedProvider);
    _logDebug('API cost calculated: $apiCost');
    
    _logDebug('Deducting call cost from wallet...');
    _showToast('Deducting cost from wallet...');
    await WalletService.deductCallCost(widget.deviceId, apiCost);
    await _loadWallet(); // Refresh balance after deduction
    _logDebug('Wallet balance after deduction: $_walletBalance');

    // Save log and result to Firebase
    final conversationString = _conversation.map((msg) => '${msg['speaker']}: ${msg['text']}').join('\n');
    await FirebaseService.saveCallResult(
      widget.deviceId,
      widget.contacts[_currentIndex]['phone'] ?? '',
      conversationString,
      _callLog.join('\n'),
    );
    _callLog.add('Call log and result saved to Firebase.');
    setState(() {});

    if (mounted) {
      setState(() {
        _isCalling = false;
        _callConnected = false;
        _conversationActive = false;
        _currentStatus = "Call ended.";
        _currentIndex++;
      });
    }
    
    _showToast('Call ended. Cost: \$${apiCost.toStringAsFixed(4)}');
    _logDebug('Call ended successfully. Moving to next call in 2 seconds...');
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      if (_currentIndex >= widget.contacts.length) {
        _callLog.add('All calls completed!');
        setState(() {});
      }
      _processNextCall();
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _logDebug(String message) {
    print('[DEBUG] EnhancedCallingScreen: $message');
  }

  void _logError(String message) {
    print('[ERROR] EnhancedCallingScreen: $message');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade900,
      appBar: AppBar(
        title: const Text('Enhanced Calling Screen'),
        backgroundColor: Colors.blue.shade800,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Call Status
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    _currentStatus,
                    style: const TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  if (_currentCallState != null)
                    Text(
                      'Call State: ${_currentCallState!.state}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  if (_isCalling && _callDuration > 0)
                    Text(
                      'Duration: ${_formatDuration(_callDuration)}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                ],
              ),
            ),
            
            // Call Controls
            if (_isCalling)
              Column(
                children: [
                  ElevatedButton(
                    onPressed: _endCall,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    ),
                    child: const Text(
                      'End Call & Move to Next',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            
            // Audio Status
            if (_audioService.isListening)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: const Text(
                  "Listening...",
                  style: TextStyle(color: Colors.green, fontSize: 16),
                ),
              ),
            
            // Debug Info
            if (_currentCallState != null)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Debug: ${_currentCallState!.toString()}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ),

            // Call Log
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: ListView.builder(
                  itemCount: _callLog.length,
                  itemBuilder: (context, index) => Text(
                    _callLog[index],
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
            ),

            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => CallingScreen(
                    contacts: widget.contacts,
                    prompt: widget.prompt,
                    excelFilePath: widget.excelFilePath,
                    deviceId: widget.deviceId,
                    selectedProvider: widget.selectedProvider,
                  ),
                ));
              },
              child: const Text('Proceed'),
            ),
          ],
        ),
      ),
    );
  }
} 