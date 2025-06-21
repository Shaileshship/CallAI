import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../services/firebase_service.dart';
import 'agent_setup_screen.dart';
import '../widgets/callai_logo.dart';
import 'profile_page.dart';
import '../main.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserInfoScreen extends StatefulWidget {
  final bool isNewUser;
  final String deviceId;
  const UserInfoScreen({Key? key, required this.isNewUser, required this.deviceId}) : super(key: key);

  @override
  State<UserInfoScreen> createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends State<UserInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _prefix = 'Mr.';
  String? _name, _company, _phone;
  bool _loading = false;
  String? _verificationId;
  int _otpSentCount = 0;
  bool _phoneVerified = false;

  final List<String> _prefixes = ['Mr.', 'Mrs.', 'Miss', 'Ms.', 'Dr.', 'Prof.'];

  @override
  void initState() {
    super.initState();
    if (!widget.isNewUser) {
      _fetchPreviousData();
    }
  }

  Future<void> _fetchPreviousData() async {
    setState(() => _loading = true);
    final data = await FirebaseService.getUserData(widget.deviceId);
    setState(() {
      _prefix = data?['prefix'] as String? ?? 'Mr.';
      _name = data?['name'] as String?;
      _company = data?['company'] as String?;
      _phone = data?['phone'] as String?;
      _loading = false;
    });
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
                    const CallAILogo(size: 150),
                    Text(
                      'Tell us about yourself',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 24),
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
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Prefix + Name
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _prefix,
                                      dropdownColor: Colors.white,
                                      style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.w500),
                                      items: _prefixes.map((String value) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Text(value),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        setState(() {
                                          _prefix = val;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    decoration: InputDecoration(
                                      labelText: 'Name',
                                      labelStyle: GoogleFonts.poppins(color: Colors.white70),
                                      filled: true,
                                      fillColor: Colors.white.withOpacity(0.18),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    style: GoogleFonts.poppins(color: Colors.white),
                                    validator: (v) => v == null || v.isEmpty ? 'Enter your name' : null,
                                    onSaved: (v) => _name = v,
                                    initialValue: _name,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            // Company Name
                            TextFormField(
                              decoration: InputDecoration(
                                labelText: 'Company Name',
                                labelStyle: GoogleFonts.poppins(color: Colors.white70),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.18),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              style: GoogleFonts.poppins(color: Colors.white),
                              validator: (v) => v == null || v.isEmpty ? 'Enter your company name' : null,
                              onSaved: (v) => _company = v,
                              initialValue: _company,
                            ),
                            const SizedBox(height: 18),
                            // Phone Number
                            IntlPhoneField(
                              decoration: InputDecoration(
                                labelText: 'Phone Number (for AI agent)',
                                labelStyle: GoogleFonts.poppins(color: Colors.white70),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.18),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              style: GoogleFonts.poppins(color: Colors.white),
                              initialValue: _phone,
                              onChanged: (phone) {
                                _phone = phone.completeNumber;
                              },
                              onSaved: (phone) => _phone = phone?.completeNumber,
                              dropdownIcon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                              flagsButtonPadding: const EdgeInsets.only(left: 8, right: 8),
                              showCountryFlag: true,
                              disableLengthCheck: true,
                              initialCountryCode: 'IN',
                              validator: (phone) {
                                if (phone == null || phone.number.isEmpty) {
                                  return 'Enter your phone number';
                                }
                                if (phone.number.length != 10) {
                                  return 'Phone number must be 10 digits';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Verify with the number you want your cold calling agent to use for calling your customers.',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            const SizedBox(height: 32),
                            // Custom Button
                            GestureDetector(
                              onTap: _loading
                                  ? null
                                  : () async {
                                      if (_formKey.currentState!.validate()) {
                                        _formKey.currentState!.save();
                                        setState(() => _loading = true);
                                        try {
                                          await FirebaseService.updateUserInfo(
                                            widget.deviceId,
                                            prefix: _prefix,
                                            name: _name,
                                            company: _company,
                                            phone: _phone,
                                          );
                                          setState(() => _loading = false);
                                          if (mounted) {
                                            Navigator.of(context).pushReplacement(
                                              MaterialPageRoute(
                                                builder: (context) => MainTabScreen(
                                                  deviceId: widget.deviceId,
                                                  initialName: _name,
                                                  initialPrefix: _prefix,
                                                  initialCompany: _company,
                                                  initialPhone: _phone,
                                                ),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          setState(() => _loading = false);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Error: ${e.toString()}')),
                                          );
                                        }
                                      }
                                    },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                height: 56,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  gradient: LinearGradient(
                                    colors: _loading
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
                                  child: _loading
                                      ? const CircularProgressIndicator(color: Colors.white)
                                      : Text(
                                          'Next',
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
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone verified!')));
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
} 