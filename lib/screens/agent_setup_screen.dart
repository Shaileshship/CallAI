import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/firebase_service.dart';
import '../services/audio_service.dart';
import '../widgets/callai_logo.dart';
import 'profile_page.dart';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:permission_handler/permission_handler.dart';
import '../services/device_service.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; // Import to access getIt
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:phone_state/phone_state.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';

class AgentSetupScreen extends StatefulWidget {
  final String name;
  final String company;
  final String phone;
  final String deviceId;
  const AgentSetupScreen({
    Key? key, 
    required this.name, 
    required this.company, 
    required this.phone, 
    required this.deviceId,
  }) : super(key: key);

  @override
  State<AgentSetupScreen> createState() => _AgentSetupScreenState();
}

class _AgentSetupScreenState extends State<AgentSetupScreen> {
  String? _excelFilePath;
  String _personalityType = 'Sales Person';
  final _talkAboutController = TextEditingController();
  final _customPersonalityController = TextEditingController();
  bool _improving = false;
  bool _loading = false;
  Map<String, String?> _availableApis = {};

  static const platform = MethodChannel('com.shailesh.callai/call');

  final List<String> _personalities = [
    'Sales Person',
    'Customer Enquiry Agent',
    'Custom Personality',
  ];

  @override
  void initState() {
    super.initState();
    _loadApiKeys();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // We will now start the process after the disclaimer
    });
  }

  Future<void> _loadApiKeys() async {
    final apis = await FirebaseService.getUserApiKeys(widget.deviceId);
    setState(() {
      _availableApis = apis;
    });
  }

  String get _personalityText {
    if (_personalityType == 'Custom Personality') {
      return 'act as a ${_customPersonalityController.text}';
    } else {
      return 'act as a $_personalityType';
    }
  }

  Future<void> _pickExcelFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xls', 'xlsx', 'csv'],
    );
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      // Only support CSV for header check (xls/xlsx would need more deps)
      if (path.endsWith('.csv')) {
        final file = File(path);
        final content = await file.readAsString();
        final rows = const CsvToListConverter().convert(content);
        if (rows.isEmpty || rows[0].length < 3) {
          _showHeaderError();
          return;
        }
        final headers = rows[0].map((e) => e.toString().trim().toLowerCase()).toList();
        if (headers.length < 3 || headers[0] != 'name' || headers[1] != 'number' || headers[2] != 'result') {
          _showHeaderError();
          return;
        }
      }
      setState(() {
        _excelFilePath = path;
      });
    }
  }

  void _showHeaderError() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invalid Excel File'),
        content: const Text('Headers do not match. Please upload an Excel with columns: 1st: name, 2nd: number, 3rd: result.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showNoApiKeyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Activation Required'),
        content: const Text('Your account needs to be activated by admin. Please contact admin to get API keys for the service.'),
        actions: [
          TextButton(
            onPressed: () async {
              const url = 'https://wa.me/918368706486?text=Hi%20I%20just%20logged%20in%20to%20Call%20AI%20looking%20for%20activating%20my%20account';
              if (await canLaunch(url)) {
                await launch(url);
              }
            },
            child: const Text('Contact Admin'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _goAndEnhancePrompt() async {
    if (_excelFilePath == null || _talkAboutController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and upload an Excel file.')),
      );
      return;
    }

    // Check for any available API key
    final hasApiKey = await FirebaseService.hasAnyApiKey(widget.deviceId);
    if (!hasApiKey) {
      _showNoApiKeyDialog();
      return;
    }

    setState(() => _improving = true);

    try {
      // Get the Gemini API key
      final apiKeys = await FirebaseService.getUserApiKeys(widget.deviceId);
      final geminiApiKey = apiKeys['gemini'];
      if (geminiApiKey == null || geminiApiKey.isEmpty) {
        throw Exception('No Gemini API key available');
      }

      final originalPrompt = _talkAboutController.text.trim();
      // Call Gemini API to improve the prompt
      final improvedPrompt = await FirebaseService.improvePromptWithGemini(originalPrompt, geminiApiKey);

      setState(() => _improving = false);

      // Show dialog to let user choose between original and improved prompt
      final useImproved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Choose Prompt'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Original:'),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(8),
                  color: Colors.grey[200],
                  child: Text(originalPrompt),
                ),
                const Text('Improved:'),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(8),
                  color: Colors.green[50],
                  child: Text(improvedPrompt),
                ),
                const SizedBox(height: 12),
                const Text('Do you want to use the improved prompt?'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Use Original'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Use Improved'),
            ),
          ],
        ),
      );

      if (useImproved != null) {
        final selectedPrompt = useImproved ? improvedPrompt : originalPrompt;
        _startCallingProcess(selectedPrompt);
      }
    } catch (e) {
      setState(() => _improving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _startCallingProcess(String prompt) async {
    if (_excelFilePath == null) return;

    setState(() {
      _loading = true;
    });

    try {
      final contacts = await _readContactsFromFile(_excelFilePath!);
      if (contacts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No contacts found in the file.')),
        );
        setState(() => _loading = false);
        return;
      }

      // For now, just call the first contact to test the native integration
      final firstContact = contacts.first;
      
      // Start the audio service for AI conversation
      await AudioService.instance.startCall(
        firstContact['name']!,
        prompt,
        widget.deviceId,
      );
      
      // Initiate the native call
      await _initiateCall(firstContact['number']!);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error during calling process: $e")),
      );
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _initiateCall(String number) async {
    try {
      final String result = await platform.invokeMethod('startCall', {'number': number});
      print('Native call result: $result');
    } on PlatformException catch (e) {
      print("Failed to invoke native method: '${e.message}'.");
    }
  }

  Future<List<Map<String, String>>> _readContactsFromFile(String path) async {
    List<Map<String, String>> contacts = [];
    var file = File(path);

    if (path.endsWith('.csv')) {
      final content = await file.readAsString();
      final rows = const CsvToListConverter(shouldParseNumbers: false).convert(content);
      // Skip header row, start from the second row (index 1)
      for (var i = 1; i < rows.length; i++) {
        var row = rows[i];
        if (row.length >= 2) {
          contacts.add({'name': row[0].toString(), 'number': row[1].toString()});
        }
      }
    } else if (path.endsWith('.xls') || path.endsWith('.xlsx')) {
      var bytes = await file.readAsBytes();
      var excel = Excel.decodeBytes(bytes);
      var sheet = excel.tables[excel.tables.keys.first];
      if (sheet != null) {
        // Skip header row, start from the second row (index 1)
        for (var i = 1; i < sheet.maxRows; i++) {
          var row = sheet.row(i);
          if (row.length >= 2 && row[0]?.value != null && row[1]?.value != null) {
            contacts.add({
              'name': row[0]!.value.toString(),
              'number': row[1]!.value.toString()
            });
          }
        }
      }
    }
    return contacts;
  }

  void _onNext() async {
    if (_excelFilePath == null || _talkAboutController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all fields and upload an Excel file.')),
      );
      return;
    }

    // Check for any available API key
    final hasApiKey = await FirebaseService.hasAnyApiKey(widget.deviceId);
    if (!hasApiKey) {
      _showNoApiKeyDialog();
      return;
    }

    setState(() => _loading = true);
    try {
      await FirebaseService.saveSessionData(
        name: widget.name,
        company: widget.company,
        phone: widget.phone,
        excelFilePath: _excelFilePath!,
        personality: _personalityText,
        talkAbout: _talkAboutController.text.trim(),
      );
      setState(() => _loading = false);
      // TODO: Navigate to next step or show success
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade900,
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0f2027),
                  Color(0xFF2c5364),
                  Color(0xFF1c92d2),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo + CallAI
                    const CallAILogo(size: 100),
                    // Glassmorphism Card
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Agent Setup',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Upload Excel File',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _excelFilePath ?? 'No file selected',
                                  style: GoogleFonts.poppins(color: Colors.white),
                                ),
                              ),
                              OutlinedButton(
                                onPressed: _pickExcelFile,
                                child: Text(
                                  'Choose File',
                                  style: GoogleFonts.poppins(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Your Excel must have columns: 1st: name, 2nd: number, 3rd: result. The result column will be filled by our agent after the call. If these column names do not match, the file will be rejected.',
                            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Talk About',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _talkAboutController,
                            maxLines: 3,
                            style: GoogleFonts.poppins(color: Colors.white),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.18),
                              hintText: 'act as',
                              hintStyle: GoogleFonts.poppins(color: Colors.white70),
                            ),
                          ),
                          const SizedBox(height: 18),
                          GestureDetector(
                            onTap: _improving ? null : _goAndEnhancePrompt,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                gradient: LinearGradient(
                                  colors: _improving
                                      ? [Colors.blueGrey, Colors.blueGrey]
                                      : [
                                          Colors.blue.shade700,
                                          Colors.blue.shade400,
                                          Colors.cyanAccent.shade200,
                                        ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.shade900.withOpacity(0.18),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: _improving
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : Text(
                                        'Let\'s Go',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DialerScreen extends StatefulWidget {
  final List<Map<String, String>> contacts;
  final String excelFilePath;
  final String prompt;
  const DialerScreen({Key? key, required this.contacts, required this.excelFilePath, required this.prompt}) : super(key: key);

  @override
  State<DialerScreen> createState() => _DialerScreenState();
}

class _DialerScreenState extends State<DialerScreen> {
  int _currentIndex = 0;
  bool _isCalling = false;
  String _log = '';
  List<Map<String, String>> _conversation = [];
  late FlutterTts _tts;
  late stt.SpeechToText _stt;
  StreamSubscription<PhoneState>? _phoneStateSubscription;
  bool _callConnected = false;
  bool _conversationActive = false;

  @override
  void initState() {
    super.initState();
    _tts = getIt<FlutterTts>();
    _stt = getIt<stt.SpeechToText>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showDisclaimerAndAskForResume();
    });
  }

  Future<void> _showDisclaimerAndAskForResume() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Call Recording Notice'),
        content: const Text(
          'Call recording is not available on this device.\n\n'
          'All other features (AI, TTS/STT, logging) will work as expected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    await _initPermissions();
    await _loadResumeIndexAndStart();
  }

  Future<void> _initPermissions() async {
    await Permission.microphone.request();
    await Permission.phone.request();
    await Permission.storage.request();
    await Permission.manageExternalStorage.request();
    await Permission.ignoreBatteryOptimizations.request();
    await Permission.systemAlertWindow.request();
    await Permission.requestInstallPackages.request();
    await Permission.accessNotificationPolicy.request();
  }

  Future<void> _loadResumeIndexAndStart() async {
    final prefs = await SharedPreferences.getInstance();
    int lastIndex = prefs.getInt('last_completed_index') ?? 0;

    if (lastIndex > 0 && lastIndex < widget.contacts.length) {
      // Ask user to resume or restart
      final resume = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Resume Session?'),
          content: Text('You have an unfinished session. Do you want to resume from where you left off (Contact ${lastIndex + 1})?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Start Over'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Resume'),
            ),
          ],
        ),
      );

      if (resume ?? false) {
        setState(() {
          _currentIndex = lastIndex;
        });
      } else {
        // Reset progress and start over
        await prefs.setInt('last_completed_index', 0);
        setState(() {
          _currentIndex = 0;
        });
      }
    }
    _processNextCall();
  }

  void _processNextCall() {
    if (_currentIndex >= widget.contacts.length) {
      // All calls are done
      setState(() {
        // You can update the UI to show completion
      });
      // TODO: After all calls, trigger upload to drive/backend
      return;
    }
    final contact = widget.contacts[_currentIndex];
    _callContact(contact);
  }

  Future<void> _callContact(Map<String, String> contact) async {
    setState(() { _isCalling = true; _callConnected = false; });
    final name = contact['name'] ?? '';
    final number = contact['number'] ?? '';

    // Start call
    await FlutterPhoneDirectCaller.callNumber(number);

    // Listen for call state (phone_state v2.x)
    _phoneStateSubscription = PhoneState.stream.listen((event) async {
      if (event.status == PhoneStateStatus.CALL_STARTED && !_callConnected) {
        _callConnected = true;
        await _onCallConnected(name, number);
      } else if (event.status == PhoneStateStatus.CALL_ENDED && _callConnected) {
        _callConnected = false;
        await _onCallEnded(name, number);
      }
    });
  }

  Future<void> _onCallConnected(String name, String number) async {
    print('DEBUG: _onCallConnected triggered for $name');
    // Speak intro
    await _speak('Hi, is it $name? ... [1 second pause] I am Ashith, an AI developed by Mr. Sharma, talking on behalf of Sunstone company. Is it right time to talk?');
    _conversationActive = true;
    _conversation.clear();
    await _conversationLoop(name, number);
  }

  Future<void> _conversationLoop(String name, String number) async {
    // Get Gemini API key and prompt
    final deviceId = await DeviceService.getDeviceId();
    final apiKeys = await FirebaseService.getUserApiKeys(deviceId);
    final geminiApiKey = apiKeys['gemini'];
    final prompt = widget.prompt.isNotEmpty ? widget.prompt : 'You are a helpful assistant.';
    String aiReply = '';
    bool firstTurn = true;
    while (_conversationActive && _callConnected) {
      if (!firstTurn) {
        // Get AI reply from Gemini
        final contextText = _conversation.map((e) => '${e['role']}: ${e['text']}').join('\n');
        aiReply = await FirebaseService.improvePromptWithGemini('$prompt\n$contextText', geminiApiKey ?? '');
        _conversation.add({'role': 'AI', 'text': aiReply});
        _log += 'AI: $aiReply\n';
        await _speak(aiReply);
      } else {
        firstTurn = false;
      }
      // Listen for user response
      if (!await _stt.initialize()) {
        print("STT failed to initialize");
        // Handle error, maybe break the loop
        break;
      }
      final userText = await _listenForUserSpeech();
      if (userText.trim().isEmpty) continue;
      _conversation.add({'role': 'User', 'text': userText});
      _log += 'User: $userText\n';
      // Stop if user says bye/stop/exit
      if (userText.toLowerCase().contains('bye') || userText.toLowerCase().contains('stop') || userText.toLowerCase().contains('exit')) {
        _conversationActive = false;
      }
    }
  }

  Future<String> _listenForUserSpeech() async {
    String resultText = '';
    final completer = Completer<String>();
    _stt.listen(onResult: (result) {
      if (result.finalResult) {
        resultText = result.recognizedWords;
        completer.complete(resultText);
      }
    });
    return completer.future;
  }

  Future<void> _onCallEnded(String name, String number) async {
    _conversationActive = false;
    final logFile = await DeviceService.createLogFile(name, number);
    await logFile.writeAsString(_log, mode: FileMode.writeOnlyAppend);
    final deviceId = await DeviceService.getDeviceId();
    final apiKeys = await FirebaseService.getUserApiKeys(deviceId);
    final geminiApiKey = apiKeys['gemini'];
    String resultSummary = 'No result';
    if (geminiApiKey != null && geminiApiKey.isNotEmpty) {
      resultSummary = await FirebaseService.analyzeCallLogWithGemini(_log, geminiApiKey);
    }
    // Store call result in Firebase
    await FirebaseService.storeCallResult(
      deviceId: deviceId,
      contactName: name,
      contactNumber: number,
      log: _log,
      result: resultSummary,
    );
    _log = '';
    setState(() {
      _isCalling = false;
      _currentIndex++; // Move to the next contact
    });

    // Save progress and process the next call
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_completed_index', _currentIndex);
    _processNextCall();
  }

  Future<void> _speak(String text) async {
    print('TTS: Attempting to speak: "$text"');
    await _tts.speak(text);
  }

  @override
  void dispose() {
    _phoneStateSubscription?.cancel();
    _tts.stop();
    _stt.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contact = widget.contacts.isNotEmpty && _currentIndex < widget.contacts.length
        ? widget.contacts[_currentIndex]
        : null;
    return Scaffold(
      backgroundColor: Colors.blue.shade900,
      body: Center(
        child: contact == null
            ? Text(
                _currentIndex >= widget.contacts.length ? 'All calls completed!' : 'Loading contacts...',
                style: const TextStyle(color: Colors.white, fontSize: 24)
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Calling: ${contact['name']} (${contact['number']})', style: const TextStyle(color: Colors.white, fontSize: 24)),
                  if (_isCalling) const SizedBox(height: 16),
                  if (_isCalling) const CircularProgressIndicator(),
                ],
              ),
      ),
    );
  }
} 