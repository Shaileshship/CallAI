import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Privacy Policy', style: GoogleFonts.poppins()),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Privacy Policy', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('Introduction', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('CallAI is committed to protecting your privacy. This policy explains how we collect, use, and safeguard your information when you use our app.'),
            const SizedBox(height: 12),
            Text('Data Collection', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('We do not collect personal information such as your name, phone number, or email address. We generate a unique device identifier (not your IMEI or phone number) for user management purposes.'),
            const SizedBox(height: 12),
            Text('Data Usage', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('The generated device identifier is stored securely in Firebase and is used solely to manage your access and experience within the app.'),
            const SizedBox(height: 12),
            Text('Data Security', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('We implement industry-standard security measures to protect your data. The device identifier is not shared with third parties.'),
            const SizedBox(height: 12),
            Text('User Rights', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('You have the right to request deletion of your device identifier from our records. Contact us at the email below.'),
            const SizedBox(height: 12),
            Text('Consent', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('By using CallAI, you consent to this privacy policy and the collection and use of your device identifier as described.'),
            const SizedBox(height: 12),
            Text('Changes to This Policy', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('We may update this policy from time to time. Changes will be posted in the app.'),
            const SizedBox(height: 12),
            Text('Contact', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('If you have any questions or requests, please contact us at: support@callai.app'),
            const SizedBox(height: 24),
            Text('Specific Disclosure', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('By using this app, you agree that a unique device identifier (not your IMEI or phone number) will be generated and stored securely in Firebase for user management purposes. No personal or immutable hardware information is collected.'),
          ],
        ),
      ),
    );
  }
} 