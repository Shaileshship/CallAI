import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../services/security_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _usersCollection = 'users';

  // Initialize Firebase
  static Future<void> initialize() async {
    await Firebase.initializeApp();
  }

  // Store user device info in Firebase
  static Future<void> storeUserDeviceInfo(String deviceId, bool isNewUser) async {
    try {
      await _firestore.collection(_usersCollection).doc(deviceId).set({
        'deviceId': deviceId,
        'isNewUser': isNewUser,
        'lastLogin': FieldValue.serverTimestamp(),
        'createdAt': isNewUser ? FieldValue.serverTimestamp() : null,
        'apiKeys': isNewUser ? {
          'gemini': null,
          'chatgpt': null,
          'grok': null,
          'deepseek': null,
          'custom': null,
        } : FieldValue.delete(),
        'isBlocked': false,
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to store user data: $e');
    }
  }

  // Get all available API keys for a user
  static Future<Map<String, String?>> getUserApiKeys(String deviceId) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(deviceId).get();
      if (!doc.exists) return {};
      
      final data = doc.data();
      if (data == null || !data.containsKey('apiKeys')) return {};
      
      final apiKeys = data['apiKeys'] as Map<String, dynamic>;
      return {
        'gemini': apiKeys['gemini'] as String?,
        'chatgpt': apiKeys['chatgpt'] as String?,
        'grok': apiKeys['grok'] as String?,
        'deepseek': apiKeys['deepseek'] as String?,
        'custom': apiKeys['custom'] as String?,
      };
    } catch (e) {
      print('Error getting API keys: $e');
      return {};
    }
  }

  // Check if user has any API key available
  static Future<bool> hasAnyApiKey(String deviceId) async {
    final apiKeys = await getUserApiKeys(deviceId);
    return apiKeys.values.any((key) => key != null && key.isNotEmpty);
  }

  // Get the first available API key in order of preference
  static Future<String?> getPreferredApiKey(String deviceId) async {
    final apiKeys = await getUserApiKeys(deviceId);
    
    // Order of preference: GPT-4 > Gemini > Grok > DeepSeek > Custom
    final preferenceOrder = ['chatgpt', 'gemini', 'grok', 'deepseek', 'custom'];
    
    for (final api in preferenceOrder) {
      if (apiKeys[api] != null && apiKeys[api]!.isNotEmpty) {
        return apiKeys[api];
      }
    }
    return null;
  }

  // Get specific API key
  static Future<String?> getSpecificApiKey(String deviceId, String apiName) async {
    final apiKeys = await getUserApiKeys(deviceId);
    return apiKeys[apiName.toLowerCase()];
  }

  // Check if user exists in Firebase
  static Future<bool> isExistingUser(String deviceId) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(deviceId).get();
      return doc.exists;
    } catch (e) {
      throw Exception('Failed to check user existence: $e');
    }
  }

  // Get user data from Firebase
  static Future<Map<String, dynamic>?> getUserData(String deviceId) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(deviceId).get();
      if (!doc.exists) return null;
      final data = doc.data();
      return data;
    } catch (e) {
      throw Exception('Failed to get user data: $e');
    }
  }

  // Upload profile image to Firebase Storage and return the download URL
  static Future<String> uploadProfileImage(String deviceId, String filePath) async {
    try {
      final ref = FirebaseStorage.instance.ref().child('profile_images').child('$deviceId.jpg');
      await ref.putFile(File(filePath));
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload profile image: $e');
    }
  }

  // Update user info in Firestore
  static Future<void> updateUserInfo(String deviceId, {String? prefix, String? name, String? company, String? phone, String? profileImageUrl}) async {
    try {
      await _firestore.collection(_usersCollection).doc(deviceId).set({
        if (prefix != null) 'prefix': prefix,
        if (name != null) 'name': name,
        if (company != null) 'company': company,
        if (phone != null) 'phone': phone,
        if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to update user info: $e');
    }
  }

  // Save session data for the user
  static Future<void> saveSessionData({
    required String name,
    required String company,
    required String phone,
    required String excelFilePath,
    required String personality,
    required String talkAbout,
  }) async {
    try {
      final sessionsRef = _firestore.collection(_usersCollection).doc(phone).collection('sessions');
      await sessionsRef.add({
        'name': name,
        'company': company,
        'phone': phone,
        'excelFilePath': excelFilePath,
        'personality': personality,
        'talkAbout': talkAbout,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to save session data: $e');
    }
  }

  // Call Gemini API to improve prompt
  static Future<String> improvePromptWithGemini(String prompt, String apiKey) async {
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key=$apiKey');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ]
    });
    final response = await http.post(url, headers: headers, body: body);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final improved = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
      if (improved is String && improved.isNotEmpty) {
        return improved;
      } else {
        throw Exception('Gemini API did not return improved prompt.');
      }
    } else {
      throw Exception('Gemini API error: \\n${response.statusCode} ${response.body}');
    }
  }

  // Analyze call log and return a summary/conclusion for the result column using Gemini
  static Future<String> analyzeCallLogWithGemini(String log, String apiKey) async {
    final prompt = 'Based on this call log, summarize what happened and give a clear, concise conclusion/result for the call (e.g., interested, not interested, call dropped, requested callback, etc.):\n\n$log';
    return await improvePromptWithGemini(prompt, apiKey);
  }

  // Store call result in Firebase
  static Future<void> storeCallResult({
    required String deviceId,
    required String contactName,
    required String contactNumber,
    required String log,
    required String result,
  }) async {
    try {
      final callResultsRef = _firestore.collection(_usersCollection).doc(deviceId).collection('call_results');
      await callResultsRef.add({
        'contactName': contactName,
        'contactNumber': contactNumber,
        'log': log,
        'result': result,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to store call result: $e');
    }
  }

  // Generate AI response using Gemini
  static Future<String> generateResponseWithGemini(String prompt, String apiKey) async {
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key=$apiKey');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ]
    });
    
    final response = await http.post(url, headers: headers, body: body);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final responseText = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
      if (responseText is String && responseText.isNotEmpty) {
        return responseText;
      } else {
        throw Exception('Gemini API did not return a valid response.');
      }
    } else {
      throw Exception('Gemini API error: ${response.statusCode} ${response.body}');
    }
  }

  // Save call result to Firebase
  static Future<void> saveCallResult(String deviceId, String contactName, String conversationLog, String summary) async {
    try {
      final callResultsRef = _firestore.collection(_usersCollection).doc(deviceId).collection('call_results');
      await callResultsRef.add({
        'contactName': contactName,
        'conversationLog': conversationLog,
        'summary': summary,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to save call result: $e');
    }
  }

  // Get all call results for a user
  static Future<List<Map<String, dynamic>>> getUserCallResults(String deviceId) async {
    try {
      final callResultsRef = _firestore.collection(_usersCollection).doc(deviceId).collection('call_results');
      final querySnapshot = await callResultsRef.orderBy('timestamp', descending: true).get();
      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      throw Exception('Failed to get call results: $e');
    }
  }

  // Get call results for a specific Excel file
  static Future<List<Map<String, dynamic>>> getCallResultsForFile(String deviceId, String excelFilePath) async {
    try {
      final callResultsRef = _firestore.collection(_usersCollection).doc(deviceId).collection('call_results');
      final querySnapshot = await callResultsRef
          .where('excelFilePath', isEqualTo: excelFilePath)
          .orderBy('timestamp', descending: true)
          .get();
      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      throw Exception('Failed to get call results for file: $e');
    }
  }
} 