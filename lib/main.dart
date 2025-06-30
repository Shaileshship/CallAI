import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';
import './services/device_service.dart';
import './services/firebase_service.dart';
import './services/security_service.dart';
import 'screens/login_screen.dart';
import 'screens/user_info_screen.dart';
import 'screens/agent_setup_screen.dart';
import 'screens/profile_page.dart';
import 'screens/phone_dialer_screen.dart';
import 'services/analytic_service.dart';
import 'services/audio_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'widgets/wallet_widget.dart';

final getIt = GetIt.instance;

void setupLocator() {
  getIt.registerSingletonAsync<SharedPreferences>(() => SharedPreferences.getInstance());
  getIt.registerSingleton<DeviceService>(DeviceService());
  getIt.registerSingletonAsync<FirebaseService>(() async {
    await FirebaseService.initialize();
    return FirebaseService();
  });
  AudioService.register(); // Use the new static registration method
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Initialize Firebase
  setupLocator();
  await getIt.allReady(); // Ensure all async singletons are ready

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Call AI',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkPersistentLogin();
  }

  Future<void> _checkPersistentLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final localDeviceId = prefs.getString('deviceId');
    if (localDeviceId == null) {
      _goToLogin();
      return;
    }
    try {
      final doc = await FirebaseService.getUserData(localDeviceId);
      final remoteDeviceId = doc != null ? (doc['deviceId'] ?? '') : '';
      if (doc == null || remoteDeviceId != localDeviceId) {
        await prefs.remove('deviceId');
        _goToLogin();
      } else {
        _goToMain(localDeviceId, doc);
      }
    } catch (e) {
      // On error, go to login
      await prefs.remove('deviceId');
      _goToLogin();
    }
  }

  void _goToLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void _goToMain(String deviceId, Map<String, dynamic> doc) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => MainTabScreen(
          deviceId: deviceId,
          initialName: doc['name'],
          initialPrefix: doc['prefix'],
          initialCompany: doc['company'],
          initialPhone: doc['phone'],
          initialProfileImageUrl: doc['profileImageUrl'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
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
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _checkUserData();
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _checkUserData() async {
    final generatedDeviceId = await SecurityService.getSecureDeviceId();
    final data = await FirebaseService.getUserData(generatedDeviceId);
    final firebaseDeviceId = data != null ? (data['deviceId'] ?? '') : '';
    if (data == null || generatedDeviceId.isEmpty || firebaseDeviceId.isEmpty || firebaseDeviceId != generatedDeviceId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Session Expired'),
            content: const Text('Your session has expired or your device ID does not match. Please log in again.'),
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
    } else if (data['isBlocked'] == true) {
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

  void _onTabChanged(int index) {
    _checkUserData();
    setState(() {
      _selectedIndex = index;
    });
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
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
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? 'Agent Setup' : 'Profile'),
        backgroundColor: Colors.blue.shade900,
        actions: [
          WalletWidget(deviceId: widget.deviceId),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: screens,
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
