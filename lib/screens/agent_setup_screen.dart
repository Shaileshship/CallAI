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
import 'package:phone_state/phone_state.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'enhanced_calling_screen.dart';
import 'phone_dialer_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'calling_screen.dart';

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
  final _talkAboutController = TextEditingController();
  Map<String, String?> _availableApis = {};
  String? _selectedProvider;
  String _selectedDialer = 'Native Dialer';
  List<Map<String, String>> _contactsPreview = [];
  String? _userPrompt;
  String? _refinedPrompt;
  String? _refineAnswer1;
  String? _refineAnswer2;
  bool _showRefineQ1 = false;
  bool _showRefineQ2 = false;
  bool _showLoadingRefine = false;
  bool _showRefinedPrompt = false;
  bool _showPreview = false;
  List<String> _aiQuestions = [];
  List<TextEditingController> _aiAnswerControllers = [];
  bool _showAiQuestions = false;
  bool _showLoading = false;
  String? _finalPitch;

  static const platform = MethodChannel('com.shailesh.callai/call');

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
      _availableApis = apis.map((key, value) => MapEntry(key, value))..removeWhere((key, value) => value == null || value.isEmpty);
      if (_availableApis.isNotEmpty) {
        _selectedProvider = _availableApis.keys.first;
      }
    });
  }

  Future<void> _pickExcelFile() async {
    // Clear any existing file path first
    setState(() {
      _excelFilePath = null;
    });
    
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      if (!path.endsWith('.csv')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please upload a CSV file only.')),
        );
        return;
      }
        final file = File(path);
      if (!await file.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected file does not exist.')),
        );
        return;
      }
      try {
        final content = await file.readAsString();
        final rows = const CsvToListConverter().convert(content);
        if (rows.isEmpty || rows[0].length < 2) {
          _showHeaderError();
          return;
        }
        final headers = rows[0].map((e) => e.toString().trim().toLowerCase()).toList();
        if (headers.length < 2 || headers[0] != 'name' || headers[1] != 'number') {
          _showHeaderError();
          return;
        }
        // Parse contacts
        List<Map<String, String>> contacts = [];
        for (int i = 1; i < rows.length; i++) {
          final row = rows[i];
          if (row.length >= 2) {
            contacts.add({
              'name': row[0].toString(),
              'phone': row[1].toString(),
            });
          }
        }
        if (contacts.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No contacts found in file.')),
          );
          return;
        }
        // Show preview dialog with Close button
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Contacts Preview'),
            content: SizedBox(
              width: 300,
              height: 200,
              child: ListView.builder(
                itemCount: contacts.length,
                itemBuilder: (context, index) => ListTile(
                  title: Text(contacts[index]['name'] ?? ''),
                  subtitle: Text(contacts[index]['phone'] ?? ''),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      setState(() {
        _excelFilePath = path;
      });
        // Store contacts for next step
        _contactsPreview = contacts;
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reading file: $e')),
        );
        return;
      }
    }
  }

  void _showHeaderError() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invalid Excel File'),
        content: const Text('Headers do not match. Please upload an Excel with columns: 1st: name, 2nd: number.'),
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

  Future<void> _prepareColdCall() async {
    if (_excelFilePath == null || _talkAboutController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill all fields and upload an Excel file.')),
      );
      return;
    }

    // Check for API key
    final hasApiKey = await FirebaseService.hasAnyApiKey(widget.deviceId);
    if (!hasApiKey) {
      _showNoApiKeyDialog();
      return;
    }

    setState(() => _showLoading = true); // Using existing loading indicator

    try {
      final geminiApiKey =
          await FirebaseService.getSpecificApiKey(widget.deviceId, 'gemini');
      if (geminiApiKey == null || geminiApiKey.isEmpty) {
        throw Exception('No Gemini API key available');
      }

      // Prompt refinement
      final userPrompt = _talkAboutController.text.trim();
      final aiResponse = await FirebaseService.refineColdCallPrompt(
          userPrompt, geminiApiKey);

      if (aiResponse.trim().toUpperCase() != 'READY') {
        setState(() {
          _showLoading = false;
        });

        // Show AI questions and ask user to update
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Let\'s refine your script'),
            content: Text(
                "To make your cold call more effective, please answer the following questions and update your 'Talk About' section:\n\n$aiResponse"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK, I\'ll update it'),
              ),
            ],
          ),
        );
        return; // Stop the process so user can update.
      }

      // If response is READY, proceed to calling screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EnhancedCallingScreen(
            contacts: _contactsPreview,
            prompt: userPrompt, // Use original user prompt
            excelFilePath: _excelFilePath!,
            deviceId: widget.deviceId,
            selectedProvider: _selectedProvider!,
            selectedDialer: _selectedDialer, // Pass the selected dialer
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error preparing call: $e')),
      );
    } finally {
      setState(() => _showLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showLoading) {
      return Scaffold(
        backgroundColor: Colors.blue.shade900,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 24),
                Text('Letting AI craft your perfect sales pitch...', style: TextStyle(color: Colors.white, fontSize: 18)),
              ],
            ),
          ),
        ),
      );
    }
    if (_showAiQuestions) {
      return Scaffold(
        backgroundColor: Colors.blue.shade900,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('AI needs a bit more info:', style: TextStyle(color: Colors.white, fontSize: 18)),
                const SizedBox(height: 16),
                ...List.generate(_aiQuestions.length, (i) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_aiQuestions[i], style: TextStyle(color: Colors.white, fontSize: 16)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _aiAnswerControllers[i],
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        hintText: 'Your answer...',
                        hintStyle: TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                )),
                ElevatedButton(
                  onPressed: () async {
                    setState(() { _showLoading = true; });
                    final answers = _aiAnswerControllers.map((c) => c.text.trim()).toList();
                    final userPrompt = _talkAboutController.text.trim();
                    final combinedPrompt = '$userPrompt\n' + List.generate(_aiQuestions.length, (i) => '${_aiQuestions[i]} ${answers[i]}').join('\n');
                    final geminiApiKey = await FirebaseService.getSpecificApiKey(widget.deviceId, 'gemini');
                    if (geminiApiKey == null || geminiApiKey.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No Gemini API key available. Please contact admin.')),
                      );
                      setState(() { _showLoading = false; });
                      return;
                    }
                    // Always generate the pitch after the first set of answers, no matter what
                    final pitch = await FirebaseService.generateResponseWithGemini(
                      'Using the following information, write a professional, super interesting, and highly effective cold call sales pitch. Make it engaging and persuasive, but always professional.\n\n$combinedPrompt',
                      geminiApiKey,
                    );
                    setState(() {
                      _finalPitch = pitch;
                      _showAiQuestions = false;
                      _showLoading = false;
                    });
                  },
                  child: const Text('Generate My Sales Pitch'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue.shade900,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_finalPitch != null) {
      return Scaffold(
        backgroundColor: Colors.blue.shade900,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Your final sales pitch:', style: TextStyle(color: Colors.white, fontSize: 18)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(_finalPitch!, style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => CallingScreen(
                        contacts: _contactsPreview,
                        prompt: _finalPitch!,
                        excelFilePath: _excelFilePath!,
                        deviceId: widget.deviceId,
                        selectedProvider: _selectedProvider!,
                      ),
                    ));
                  },
                  child: const Text('Proceed'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue.shade900,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    // Main combined UI: Excel upload above product/service input
    return Scaffold(
      backgroundColor: Colors.blue.shade900,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Agent Setup',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          // ... existing code for wallet, etc ...
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Excel Upload UI
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.upload_file,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Upload Your Contacts',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Upload a CSV or Excel file with your contacts.\nRequired format:\n• First column: Name\n• Second column: Phone Number',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _showLoading ? null : () async {
                        setState(() { _showLoading = true; });
                        await _pickExcelFile();
                        setState(() { _showLoading = false; });
                      },
                      icon: _showLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.upload_file),
                      label: Text(
                        _showLoading ? 'Processing...' : (_excelFilePath == null ? 'Choose File' : 'Change File'),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue.shade900,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    if (_excelFilePath != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _excelFilePath!.split('/').last,
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_contactsPreview.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _showPreview = !_showPreview;
                            });
                          },
                          icon: Icon(_showPreview ? Icons.visibility_off : Icons.visibility),
                          label: Text(_showPreview ? 'Hide Preview' : 'Show Preview'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        if (_showPreview) ...[
                          const SizedBox(height: 8),
                          Container(
                            height: 150,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListView.builder(
                              itemCount: _contactsPreview.length,
                              itemBuilder: (context, index) {
                                final contact = _contactsPreview[index];
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    contact['name'] ?? '',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Text(
                                    contact['phone'] ?? '',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blue.shade700,
                                    child: Text(
                                      (contact['name'] ?? '')[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Product/Service input
              Text(
                'What do you want to sell?',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _talkAboutController,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  hintText: 'Describe your product or service...',
                  hintStyle: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 24),
              // Dialer Selection Dropdown
              _buildCard(
                title: 'Select Dialer',
                child: DropdownButtonFormField<String>(
                  value: _selectedDialer,
                  onChanged: (value) {
                    setState(() {
                      _selectedDialer = value!;
                    });
                  },
                  items: ['Native Dialer', 'In-App Dialer']
                      .map((dialer) => DropdownMenuItem(
                            value: dialer,
                            child: Text(dialer),
                          ))
                      .toList(),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // API Provider Selection
              if (_availableApis.isNotEmpty)
                _buildCard(
                  title: 'API Provider',
                  child: DropdownButtonFormField<String>(
                    value: _selectedProvider,
                    onChanged: (value) {
                      setState(() {
                        _selectedProvider = value;
                      });
                    },
                    items: _availableApis.keys
                        .map((provider) => DropdownMenuItem(
                              value: provider,
                              child: Text(provider),
                            ))
                        .toList(),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              // Let's Go button
              ElevatedButton(
                onPressed: () async {
                  final product = _talkAboutController.text.trim();
                  if (_excelFilePath == null || _contactsPreview.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please upload a valid contacts file.')),
                    );
                    return;
                  }
                  if (product.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please describe your product or service.')),
                    );
                    return;
                  }
                  setState(() { _showLoading = true; });
                  final geminiApiKey = await FirebaseService.getSpecificApiKey(widget.deviceId, 'gemini');
                  if (geminiApiKey == null || geminiApiKey.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No Gemini API key available. Please contact admin.')),
                    );
                    setState(() { _showLoading = false; });
                    return;
                  }
                  final aiResponse = await FirebaseService.refineColdCallPrompt(product, geminiApiKey);
                  if (aiResponse.trim().toUpperCase() == 'READY') {
                    final pitch = await FirebaseService.generateResponseWithGemini(
                      'Using the following information, write a professional, super interesting, and highly effective cold call sales pitch. Make it engaging and persuasive, but always professional.\n\n$product',
                      geminiApiKey,
                    );
                    setState(() {
                      _finalPitch = pitch;
                      _showLoading = false;
                    });
                  } else {
                    final questions = aiResponse.split('\n').where((q) => q.trim().isNotEmpty).toList();
                    _aiQuestions = questions;
                    _aiAnswerControllers = List.generate(questions.length, (i) => TextEditingController());
                    setState(() {
                      _showAiQuestions = true;
                      _showLoading = false;
                    });
                  }
                },
                child: const Text("Let's Go"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue.shade900,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 