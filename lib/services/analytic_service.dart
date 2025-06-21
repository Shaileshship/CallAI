import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AnalyticService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> logEvent(String eventName, Map<String, dynamic> parameters) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('analytics').add({
          'userId': user.uid,
          'eventName': eventName,
          'parameters': parameters,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error logging analytics event: $e');
    }
  }
} 