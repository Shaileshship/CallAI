import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'screens/login_screen.dart';
import 'screens/user_info_screen.dart';
import 'screens/agent_setup_screen.dart';
import 'screens/profile_page.dart';
import 'services/firebase_service.dart';
import 'services/security_service.dart';
import 'services/analytic_service.dart';
import 'services/device_service.dart';

// Service locator
final getIt = GetIt.instance;

Future<void> setupServices() async {
  // TTS Service
  final tts = FlutterTts();
  await tts.setLanguage('en-IN');
  await tts.setSpeechRate(0.5);
  await tts.setVolume(1.0);
  getIt.registerSingleton<FlutterTts>(tts);

  // STT Service
  final sttService = stt.SpeechToText();
  await sttService.initialize();
  getIt.registerSingleton<stt.SpeechToText>(sttService);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await setupServices(); // Initialize TTS and STT
  await FirebaseService.initialize();
  
  // Register services with GetIt
  getIt.registerSingleton<AnalyticService>(AnalyticService());
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<String?> _getDeviceId() async {
    return await SecurityService.getSecureDeviceId();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CallAI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: FutureBuilder<String?>(
        future: _getDeviceId(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final deviceId = snapshot.data;
          if (deviceId != null && deviceId.isNotEmpty) {
            return MainTabScreen(
              deviceId: deviceId,
            );
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  }
}

class MainTabScreen extends StatefulWidget {
  final String deviceId;
  final String? initialName;
  final String? initialPrefix;
  final String? initialCompany;
  final String? initialPhone;
  final String? initialProfileImageUrl;
  const MainTabScreen({
    Key? key, 
    required this.deviceId, 
    this.initialName, 
    this.initialPrefix, 
    this.initialCompany, 
    this.initialPhone, 
    this.initialProfileImageUrl,
  }) : super(key: key);

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkUserData();
  }

  Future<void> _checkUserData() async {
    final data = await FirebaseService.getUserData(widget.deviceId);
    if (data == null || widget.deviceId.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Access Blocked'),
            content: const Text('You have been blocked by admin.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      });
    }
  }

  void _onTabChanged(int index) async {
    await _checkUserData();
    if (mounted) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          AgentSetupScreen(
            name: widget.initialName ?? '',
            company: widget.initialCompany ?? '',
            phone: widget.initialPhone ?? '',
            deviceId: widget.deviceId,
          ),
          ProfilePage(
            deviceId: widget.deviceId,
            initialName: widget.initialName ?? '',
            initialPrefix: widget.initialPrefix ?? 'Mr.',
            initialCompany: widget.initialCompany ?? '',
            initialPhone: widget.initialPhone ?? '',
            initialProfileImageUrl: widget.initialProfileImageUrl,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTabChanged,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
