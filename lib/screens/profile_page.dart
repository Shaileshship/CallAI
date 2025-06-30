import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/callai_logo.dart';
import '../services/security_service.dart';
import '../services/firebase_service.dart';
import 'login_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

class ProfilePage extends StatefulWidget {
  final String deviceId;
  final String initialName;
  final String initialPrefix;
  final String initialCompany;
  final String initialPhone;
  final String? initialProfileImageUrl;
  const ProfilePage({Key? key, required this.deviceId, required this.initialName, required this.initialPrefix, required this.initialCompany, required this.initialPhone, this.initialProfileImageUrl}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late String _prefix;
  late String _company;
  late String _phone;
  int _otpAttempts = 0;
  bool _loading = false;
  bool _editMode = false;
  String? _verificationId;
  int _otpSentCount = 0;
  bool _phoneVerified = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _loading = true);
    final data = await FirebaseService.getUserData(widget.deviceId);
    setState(() {
      _name = data?['name'] ?? widget.initialName;
      _prefix = data?['prefix'] ?? widget.initialPrefix;
      _company = data?['company'] ?? widget.initialCompany;
      _phone = data?['phone'] ?? widget.initialPhone;
      _loading = false;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _loading = true);
    // If phone changed, require OTP auth (max 2 attempts)
    if (_phone != widget.initialPhone) {
      if (_otpSentCount >= 2) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OTP limit reached. Try again later.')));
        return;
      }
      _phoneVerified = false;
      await _verifyPhoneNumber(_phone);
      setState(() => _loading = false);
      return;
    }
    await FirebaseService.updateUserInfo(widget.deviceId, prefix: _prefix, name: _name, company: _company, phone: _phone);
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!')));
  }

  Future<void> _verifyPhoneNumber(String phone) async {
    _otpSentCount++;
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        setState(() => _phoneVerified = true);
        await FirebaseService.updateUserInfo(widget.deviceId, prefix: _prefix, name: _name, company: _company, phone: _phone);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone verified and profile updated!')));
      },
      verificationFailed: (FirebaseAuthException e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Phone verification failed: \\${e.message}')));
      },
      codeSent: (String verificationId, int? resendToken) async {
        _verificationId = verificationId;
        _showOtpDialog();
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  void _showOtpDialog() {
    final otpController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enter OTP'),
        content: TextField(
          controller: otpController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'OTP'),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (_verificationId != null) {
                final credential = PhoneAuthProvider.credential(
                  verificationId: _verificationId!,
                  smsCode: otpController.text.trim(),
                );
                try {
                  await FirebaseAuth.instance.signInWithCredential(credential);
                  setState(() => _phoneVerified = true);
                  await FirebaseService.updateUserInfo(widget.deviceId, prefix: _prefix, name: _name, company: _company, phone: _phone);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone verified and profile updated!')));
                } catch (e) {
                  setState(() => _phoneVerified = false);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid OTP.')));
                }
              }
            },
            child: const Text('Verify'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await SecurityService.clearDeviceInfo();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade900,
      body: Stack(
        children: [
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
                    const CallAILogo(size: 100),
                    const SizedBox(height: 24),
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
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Center(
                                    child: Stack(
                                      alignment: Alignment.bottomRight,
                                      children: [
                                        CircleAvatar(
                                          radius: 48,
                                          backgroundColor: Colors.blueGrey.shade200,
                                          child: ClipOval(
                                            child: Image.asset(
                                              'assets/images/logo.png',
                                              width: 80,
                                              height: 80,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Profile',
                                        style: GoogleFonts.poppins(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(_editMode ? Icons.close : Icons.edit, color: Colors.white),
                                        onPressed: () {
                                          setState(() {
                                            _editMode = !_editMode;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _editMode
                                      ? Column(
                                          children: [
                                            TextFormField(
                                              initialValue: _prefix,
                                              onSaved: (value) => _prefix = value!,
                                              decoration: const InputDecoration(labelText: 'Prefix'),
                                            ),
                                            TextFormField(
                                              initialValue: _name,
                                              onSaved: (value) => _name = value!,
                                              decoration: const InputDecoration(labelText: 'Name'),
                                            ),
                                            TextFormField(
                                              initialValue: _company,
                                              onSaved: (value) => _company = value!,
                                              decoration: const InputDecoration(labelText: 'Company'),
                                            ),
                                            TextFormField(
                                              initialValue: _phone,
                                              onSaved: (value) => _phone = value!,
                                              decoration: const InputDecoration(labelText: 'Phone'),
                                            ),
                                            const SizedBox(height: 32),
                                            GestureDetector(
                                              onTap: _saveProfile,
                                              child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 200),
                                                height: 56,
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(18),
                                                  gradient: const LinearGradient(
                                                    colors: [
                                                      Colors.blueAccent,
                                                      Colors.lightBlue,
                                                    ],
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.blueAccent.withOpacity(0.18),
                                                      blurRadius: 16,
                                                      offset: const Offset(0, 8),
                                                    ),
                                                  ],
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    'Save',
                                                    style: GoogleFonts.poppins(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 18,
                                                      letterSpacing: 1.1,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Prefix: $_prefix', style: GoogleFonts.poppins(color: Colors.white, fontSize: 16)),
                                            const SizedBox(height: 8),
                                            Text('Name: $_name', style: GoogleFonts.poppins(color: Colors.white, fontSize: 16)),
                                            const SizedBox(height: 8),
                                            Text('Company: $_company', style: GoogleFonts.poppins(color: Colors.white, fontSize: 16)),
                                            const SizedBox(height: 8),
                                            Text('Phone: $_phone', style: GoogleFonts.poppins(color: Colors.white, fontSize: 16)),
                                          ],
                                        ),
                                  const SizedBox(height: 32),
                                  GestureDetector(
                                    onTap: _logout,
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      height: 56,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        gradient: const LinearGradient(
                                          colors: [
                                            Colors.redAccent,
                                            Colors.deepOrange,
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.redAccent.withOpacity(0.18),
                                            blurRadius: 16,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Logout',
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            letterSpacing: 1.1,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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