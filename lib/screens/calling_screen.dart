import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:phone_state/phone_state.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
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
import 'login_screen.dart';
import 'conversation_log_screen.dart';

const platform = MethodChannel('com.shailesh.callai/call');

class CallingScreen extends StatefulWidget {
  final List<Map<String, String>> contacts;
  final String prompt;
  final String excelFilePath;
  final String deviceId;
  final String selectedProvider;

  const CallingScreen({
    Key? key,
    required this.contacts,
    required this.prompt,
    required this.excelFilePath,
    required this.deviceId,
    required this.selectedProvider,
  }) : super(key: key);

  @override
  State<CallingScreen> createState() => _CallingScreenState();
}

class _CallingScreenState extends State<CallingScreen> {
  int _currentIndex = 0;
  bool _isCalling = false;
  String _log = '';
  List<Map<String, String>> _conversation = [];
  bool _callConnected = false;
  bool _conversationActive = false;
  String _currentStatus = "Initializing...";

  late FlutterTts _tts;
  late SpeechToText _stt;
  StreamSubscription<PhoneState>? _phoneStateSubscription;
  late AudioService _audioService;
  final Stopwatch _callTimer = Stopwatch();

  bool _walletLoaded = false;
  double _walletBalance = 0.0;

  String _selectedQuality = 'normal';
  String _selectedProvider = 'deepseek';
  double _selectedPrice = 0.2;

  @override
  void initState() {
    super.initState();
    _audioService = AudioService.instance;
    _tts = _audioService.tts;
    _stt = _audioService.stt;

    platform.setMethodCallHandler(_handleMethod);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWallet();
      _startSession();
    });
  }

  Future<dynamic> _handleMethod(MethodCall call) async {
    switch (call.method) {
      case "onSpeech":
        // We can process the user's speech here if needed in the future
        break;
      default:
        throw("Unknown method ${call.method}");
    }
  }

  Future<void> _startSession() async {
    await _initPermissions();
    await _loadWallet();
    _processNextCall();
  }

  Future<void> _initPermissions() async {
    setState(() {
      _currentStatus = "Requesting permissions...";
    });
    Map<Permission, PermissionStatus> statuses = await [
      Permission.microphone,
      Permission.phone,
    ].request();

    if (statuses[Permission.microphone] != PermissionStatus.granted ||
        statuses[Permission.phone] != PermissionStatus.granted) {
      
      setState(() {
        _currentStatus = "Permissions not granted. Please enable them in settings.";
      });

      // Show a dialog to guide the user to app settings
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
                // Optionally pop the calling screen as well if permissions are mandatory
                Navigator.of(context).pop(); 
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      // After dialog, stop further execution if permissions are not granted.
      return;
    }
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

  Future<void> _showAddMoneyDialog() async {
    TextEditingController amountController = TextEditingController();
    TextEditingController refController = TextEditingController();
    bool paidClicked = false;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          double amount = double.tryParse(amountController.text) ?? 0.0;
          String upiUrl = 'upi://pay?pa=8368706486@ptsbi&pn=CallAI&am=${amount > 0 ? amount.toStringAsFixed(2) : ''}&cu=INR';
          return AlertDialog(
            title: const Text('Add Money to Wallet'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount (INR)'),
                  onChanged: (_) => setState(() {}),
                ),
                if (amount > 0) ...[
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: QrImageView(
                      data: upiUrl,
                      version: QrVersions.auto,
                      size: 180.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Scan this QR with any UPI app to pay ₹$amount to 8368706486@ptsbi'),
                ],
                if (paidClicked) ...[
                  const SizedBox(height: 16),
                  const Text('Enter UPI Reference Number:'),
                  TextField(
                    controller: refController,
                    decoration: const InputDecoration(hintText: 'UPI Ref No.'),
                    keyboardType: TextInputType.text,
                  ),
                ],
              ],
            ),
            actions: [
              if (amount > 0 && !paidClicked)
                TextButton(
                  onPressed: () {
                    setState(() { paidClicked = true; });
                  },
                  child: const Text("I've Paid"),
                ),
              if (paidClicked)
                TextButton(
                  onPressed: () async {
                    if (refController.text.trim().isEmpty) return;
                    await WalletService.addMoney(widget.deviceId, amount, refController.text.trim());
                    await _loadWallet();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Submit Ref No.'),
                ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<bool> _checkApiKeyAvailable() async {
    final userApiKeys = await FirebaseService.getUserApiKeys(widget.deviceId);
    String? key = userApiKeys[widget.selectedProvider];
    return key != null && key.isNotEmpty;
  }

  Future<void> _showMissingApiKeyDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('API Key Missing'),
        content: const Text('The selected AI quality is not available for your account. Please contact admin to activate your access.'),
        actions: [
          TextButton(
            onPressed: () async {
              const url = 'https://wa.me/918368706486?text=Hi%20I%20just%20logged%20in%20to%20Call%20AI%20looking%20for%20activating%20my%20account';
              if (await canLaunch(url)) {
                await launch(url);
              }
              // Log out the user
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Contact Admin'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPurchasePrompt() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Insufficient Balance'),
        content: const Text('Your wallet balance is too low. Please add money to continue calling.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // The wallet widget is the primary way to purchase, so we just inform them.
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _processNextCall() async {
    print('[DEBUG] ===== STARTING NEW CALL PROCESS =====');
    await _loadWallet();
    if (_currentIndex >= widget.contacts.length) {
      print('[DEBUG] All calls completed!');
      if (mounted) {
      setState(() {
        _currentStatus = "All calls completed!";
      });
      }
      return;
    }
    
    print('[DEBUG] Processing call ${_currentIndex + 1}/${widget.contacts.length}');
    
    // Check if selected API key is available
    bool apiKeyAvailable = await _checkApiKeyAvailable();
    if (!apiKeyAvailable) {
      print('[DEBUG] API key not available, showing dialog');
      await _showMissingApiKeyDialog();
      return;
    }
    
    // Check if enough funds are left
    // We assume a minimum balance is required to even start a call
    if (_walletBalance < 0.20) { // e.g., require at least 20 paise
      print('[DEBUG] Insufficient funds: $_walletBalance');
      await _showPurchasePrompt();
      return;
    }

    final contact = widget.contacts[_currentIndex];
    final phoneNumber = contact['phone']!;
    final contactName = contact['name'] ?? 'Contact';
    
    print('[DEBUG] Calling contact: $contactName ($phoneNumber)');
    print('[DEBUG] Wallet balance: $_walletBalance');
    
    _conversation = [];
    _callConnected = false;
    _conversationActive = false;

    setState(() {
      _currentStatus = "Calling $contactName ($phoneNumber)...";
      _log += 'Calling $contactName ($phoneNumber)...\n';
    });

    try {
      print('[DEBUG] Stopping any existing audio...');
      await _audioService.stopListening();
      
      print('[DEBUG] Initiating call to $phoneNumber...');
      final callStarted = await FlutterPhoneDirectCaller.callNumber(phoneNumber);
      
      if (callStarted == true) {
        print('[DEBUG] Call initiated successfully');
        setState(() { _isCalling = true; });
        _phoneStateSubscription = PhoneState.stream.listen((state) {
          _handlePhoneState(state, contactName);
        });
      } else {
        print('[DEBUG] Failed to start call');
        _log += 'Failed to start call.\n';
        _processNextCall();
      }
    } catch (e) {
      print('[ERROR] Error making call: $e');
      _log += 'Error making call: $e\n';
      _processNextCall();
    }
  }

  Future<void> _moveAppToBackground() async {
    try {
      await AudioService.audioChannel.invokeMethod('moveTaskToBack');
    } catch (e) {
      print('Error moving app to background: $e');
    }
  }

  Future<void> _bringAppToForeground() async {
    try {
      await AudioService.audioChannel.invokeMethod('bringToFront');
    } catch (e) {
      print('Error bringing app to foreground: $e');
    }
  }

  void _handlePhoneState(PhoneState state, String contactName) {
    _logDebug('Phone state changed: ${state.status}');
    _logDebug('Current call state: connected=$_callConnected, active=$_conversationActive');
    
    switch (state.status) {
      case PhoneStateStatus.CALL_STARTED:
        _logDebug('Call started - waiting for connection...');
        if (!_callConnected) {
          _callTimer.start();
          _callConnected = true;
          setState(() {
            _currentStatus = 'Call started, waiting for connection...';
          });
          _logDebug('Call timer started, waiting for proper connection...');
          
          // Wait for a reasonable time for call to connect, then start conversation
          Future.delayed(const Duration(seconds: 5), () {
            if (!_conversationActive && _callConnected) {
              _logDebug('Call has been active for 5 seconds, starting conversation...');
              _startConversation(contactName);
            }
          });
        }
        break;
        
      case PhoneStateStatus.CALL_ENDED:
        _logDebug('Call ended');
        _callTimer.stop();
        _endCall();
        break;
        
      default:
        _logDebug('Other phone state: ${state.status}');
        break;
    }
  }

  Future<void> _startConversation(String contactName) async {
    print('[DEBUG] Starting conversation with $contactName');
    print('[DEBUG] Call connected: $_callConnected, Conversation active: $_conversationActive');
    
    if (_conversationActive) {
      print('[DEBUG] Conversation already active, skipping...');
      return;
    }
    
    setState(() {
      _currentStatus = 'In conversation with $contactName';
      _conversationActive = true;
    });

    // Wait a moment for the call audio system to be fully established
    print('[DEBUG] Waiting 3 seconds for call audio system to establish...');
    await Future.delayed(const Duration(seconds: 3));
    print('[DEBUG] Audio system establishment wait completed');

    try {
      // Validate audio system before proceeding
      print('[DEBUG] Validating audio system...');
      await _validateAudioSystem();
      
      print('[DEBUG] Requesting opening line from API...');
      final openingLine = await FirebaseService.generateOpeningLine(
        widget.prompt,
        widget.selectedProvider,
      );
      print('[DEBUG] Opening line received: "$openingLine"');
      _conversation.add({'speaker': 'AI', 'text': openingLine});
      print('[DEBUG] Conversation log after adding opening line: $_conversation');
      
      print('[DEBUG] Calling TTS with: "$openingLine"');
      await _audioService.speakResponse(openingLine);
      print('[DEBUG] TTS finished for opening line. Starting STT...');
      
      // Validate STT before starting
      print('[DEBUG] Validating STT before starting...');
      await _validateSTT();
      
      await _audioService.startListening();
      print('[DEBUG] STT started successfully');
    } catch (e, st) {
      print("[ERROR] Error in conversation: $e");
      print(st);
      setState(() {
        _currentStatus = 'Error in conversation: $e';
        _conversationActive = false;
      });
    }
  }

  Future<void> _endCall() async {
    print('[DEBUG] ===== ENDING CALL =====');
    print('[DEBUG] Call state: isCalling=$_isCalling, connected=$_callConnected, active=$_conversationActive');
    
    if (!_isCalling) {
      print('[DEBUG] Call not active, skipping end call process');
      return;
    }

    print('[DEBUG] Cancelling phone state subscription...');
    await _phoneStateSubscription?.cancel();
    _phoneStateSubscription = null;
    
    print('[DEBUG] Ending audio service...');
    await _audioService.endCall();

    // Calculate API cost and deduct from wallet
    print('[DEBUG] Calculating API cost for conversation...');
    final apiCost = await FirebaseService.calculateCostForConversation(_conversation, widget.selectedProvider);
    print('[DEBUG] API cost calculated: $apiCost');
    
    print('[DEBUG] Deducting call cost from wallet...');
    await WalletService.deductCallCost(widget.deviceId, apiCost);
    await _loadWallet(); // Refresh balance after deduction
    print('[DEBUG] Wallet balance after deduction: $_walletBalance');

    if (mounted) {
      setState(() {
        _isCalling = false;
        _callConnected = false;
          _conversationActive = false;
        _currentStatus = "Call ended.";
        _currentIndex++;
      });
    }
    
    print('[DEBUG] Call ended successfully. Moving to next call in 2 seconds...');
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      _processNextCall();
    }
  }

  double _getPriceForProvider(String provider) {
    switch (provider) {
      case 'openai':
        return 0.5; // Example price for best
      case 'gemini':
        return 0.3; // Example price for medium
      case 'deepseek':
        return 0.2; // Example price for normal
      default:
        return 0.2; // Default price
    }
  }

  Future<void> _validateAudioSystem() async {
    print('[DEBUG] Validating audio system components...');
    
    try {
      // Test TTS availability
      print('[DEBUG] Testing TTS availability...');
      final ttsAvailable = await _tts.isLanguageAvailable("en-US");
      print('[DEBUG] TTS available: $ttsAvailable');
      
      if (!ttsAvailable) {
        throw Exception('TTS not available for English');
      }
      
      // Test audio channel
      print('[DEBUG] Testing audio channel...');
      try {
        await AudioService.audioChannel.invokeMethod('testAudioChannel');
        print('[DEBUG] Audio channel test passed');
      } catch (e) {
        print('[WARNING] Audio channel test failed: $e');
        // Continue anyway as this might be optional
      }
      
      print('[DEBUG] Audio system validation completed successfully');
    } catch (e) {
      print('[ERROR] Audio system validation failed: $e');
      throw Exception('Audio system validation failed: $e');
    }
  }

  Future<void> _validateSTT() async {
    print('[DEBUG] Validating STT system...');
    
    try {
      // Test STT availability
      print('[DEBUG] Testing STT availability...');
      final sttAvailable = await _stt.initialize();
      print('[DEBUG] STT available: $sttAvailable');
      
      if (!sttAvailable) {
        throw Exception('STT not available');
      }
      
      // Test microphone permissions
      print('[DEBUG] Testing microphone permissions...');
      final micPermission = await Permission.microphone.status;
      print('[DEBUG] Microphone permission: $micPermission');
      
      if (micPermission != PermissionStatus.granted) {
        throw Exception('Microphone permission not granted');
      }
      
      print('[DEBUG] STT validation completed successfully');
    } catch (e) {
      print('[ERROR] STT validation failed: $e');
      throw Exception('STT validation failed: $e');
    }
  }

  Future<void> _writeToLogFile(String message) async {
    try {
      final dir = await getExternalStorageDirectory();
      final logFile = File('${dir!.path}/callai_debug.log');
      
      final timestamp = DateTime.now().toIso8601String();
      final logEntry = '[$timestamp] $message\n';
      
      await logFile.writeAsString(logEntry, mode: FileMode.append);
    } catch (e) {
      print('[ERROR] Failed to write to log file: $e');
    }
  }

  void _logDebug(String message) {
    print('[DEBUG] $message');
    _writeToLogFile('[DEBUG] $message');
  }

  void _logError(String message) {
    print('[ERROR] $message');
    _writeToLogFile('[ERROR] $message');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Calling Screen')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_currentStatus, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            if (_isCalling)
              ElevatedButton(
                onPressed: _endCall,
                child: const Text('End Call & Move to Next'),
              ),
            if (_audioService.isListening)
              const Text("Listening...", style: TextStyle(color: Colors.green)),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ConversationLogScreen(conversation: _conversation),
                  ),
                );
              },
              child: const Text('View Conversation Log'),
            ),
          ],
        ),
      ),
    );
  }
} 