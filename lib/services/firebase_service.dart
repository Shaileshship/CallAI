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

  // Store user device information, marking if it's a new user
  static Future<void> storeUserDeviceInfo(String deviceId, bool isNew) async {
    final docRef = _firestore.collection('users').doc(deviceId);
    final doc = await docRef.get();

    if (!doc.exists) {
      // Document doesn't exist, this is a new user. Create the document.
      await docRef.set({
        'deviceId': deviceId,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        'isBlocked': false,
        'wallet': {
          'walletBalance': 5.0, // 5 INR starting balance
        },
        'apiKeys': {
          'openai': '',
          'gemini': '',
          'deepseek': '',
        }
      });
    } else {
      // Document exists, this is a returning user. Only update the last login time.
      await docRef.update({
        'lastLogin': FieldValue.serverTimestamp(),
      });
    }
  }

  // Get all available API keys for a user
  static Future<Map<String, String>> getUserApiKeys(String deviceId) async {
    if (deviceId.isEmpty) {
      print('[ERROR] getUserApiKeys called with empty deviceId!');
      throw Exception('Device ID is empty when fetching API keys.');
    }
    try {
      final doc = await _firestore.collection(_usersCollection).doc(deviceId).get();
      if (!doc.exists) return {};
      final data = doc.data();
      if (data == null || !data.containsKey('apiKeys')) return {};
      final apiKeys = data['apiKeys'] as Map<String, dynamic>;
      return {
        'gemini': apiKeys['gemini'] ?? '',
        'chatgpt': apiKeys['chatgpt'] ?? '',
        'deepseek': apiKeys['deepseek'] ?? '',
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
    // Order of preference: GPT-4 > Gemini > DeepSeek
    final preferenceOrder = ['chatgpt', 'gemini', 'deepseek'];
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

  static Future<String> refineColdCallPrompt(String userPrompt, String apiKey) async {
    const systemPrompt = '''
You are an AI assistant designed to help users prepare for cold calls.
Your task is to analyze the user's description of the cold call's purpose.
If the description is clear and sufficient to start a cold call, respond with the exact string "READY".
If the description is vague or incomplete, ask clarifying questions to help the user provide more detail.
Ask all your questions in a single response. Do not ask more than 3 questions.
Be polite and concise.
''';

    final url = Uri.parse('https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key=$apiKey');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'contents': [
        {'role': 'user', 'parts': [{'text': systemPrompt}]},
        {'role': 'model', 'parts': [{'text': 'Understood. I will analyze the user\'s prompt and either respond with "READY" or ask for clarification.'}]},
        {'role': 'user', 'parts': [{'text': userPrompt}]},
      ]
    });

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final aiResponse = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
      if (aiResponse is String && aiResponse.isNotEmpty) {
        return aiResponse;
      } else {
        throw Exception('Gemini API did not return a valid response for prompt refinement.');
      }
    } else {
      throw Exception('Gemini API error for prompt refinement: \\n${response.statusCode} ${response.body}');
    }
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

  // New method for summarizing conversation
  static Future<String> summarizeConversation(String history, String apiKey) async {
    final prompt = 'Summarize the following conversation history concisely:\n\n$history';
    // We can reuse the improvePromptWithGemini function as it's a general text-generation call
    return await improvePromptWithGemini(prompt, apiKey);
  }

  // Unified AI response generator
  static Future<String> generateAIResponse(String prompt, String provider, String apiKey) async {
    switch (provider) {
      case 'gemini':
        return await generateResponseWithGemini(prompt, apiKey);
      case 'deepseek':
        return await generateResponseWithDeepSeek(prompt, apiKey);
      case 'chatgpt':
        return await generateResponseWithOpenAI(prompt, apiKey);
      default:
        throw Exception('Unsupported AI provider: $provider');
    }
  }

  // DeepSeek API call (OpenAI compatible)
  static Future<String> generateResponseWithDeepSeek(String prompt, String apiKey) async {
    final url = Uri.parse('https://api.deepseek.com/v1/chat/completions');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };
    final body = jsonEncode({
      'model': 'deepseek-chat',
      'messages': [
        {'role': 'user', 'content': prompt}
      ]
    });
    final response = await http.post(url, headers: headers, body: body);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final responseText = data['choices']?[0]?['message']?['content'];
      if (responseText is String && responseText.isNotEmpty) {
        return responseText;
      } else {
        throw Exception('DeepSeek API did not return a valid response.');
      }
    } else {
      throw Exception('DeepSeek API error: \\n${response.statusCode} ${response.body}');
    }
  }

  // OpenAI API call (chatgpt)
  static Future<String> generateResponseWithOpenAI(String prompt, String apiKey) async {
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };
    final body = jsonEncode({
      'model': 'gpt-3.5-turbo',
      'messages': [
        {'role': 'user', 'content': prompt}
      ]
    });
    final response = await http.post(url, headers: headers, body: body);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final responseText = data['choices']?[0]?['message']?['content'];
      if (responseText is String && responseText.isNotEmpty) {
        return responseText;
      } else {
        throw Exception('OpenAI API did not return a valid response.');
      }
    } else {
      throw Exception('OpenAI API error: \\n${response.statusCode} ${response.body}');
    }
  }

  // Generate the opening line for a cold call
  static Future<String> generateOpeningLine(String prompt, String provider) async {
    final deviceId = await SecurityService.getSecureDeviceId() ?? '';
    print('[DEBUG] generateOpeningLine using deviceId: "$deviceId"');
    if (deviceId.isEmpty) {
      throw Exception('Device ID is empty in generateOpeningLine');
    }
    final userApiKeys = await getUserApiKeys(deviceId);
    final apiKey = userApiKeys[provider];

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('$provider API Key not found');
    }

    switch (provider) {
      case 'openai':
        return _generateWithOpenAI(prompt, apiKey);
      case 'gemini':
        return _generateWithGemini(prompt, apiKey);
      case 'deepseek':
      default:
        return _generateWithDeepSeek(prompt, apiKey);
    }
  }

  static Future<String> _generateWithDeepSeek(String prompt, String apiKey) async {
    final url = Uri.parse('https://api.deepseek.com/v1/chat/completions');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'deepseek-chat',
        'messages': [
          {'role': 'system', 'content': 'You are a helpful assistant.'},
          {'role': 'user', 'content': 'Based on the following context, create a very short, engaging opening line for a cold call. Just the line, no extra text. Context: $prompt'},
        ],
        'max_tokens': 50,
      }),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['choices'][0]['message']['content'].trim();
    } else {
      throw Exception('Failed to generate opening line with DeepSeek: ${response.body}');
    }
  }

  static Future<String> _generateWithOpenAI(String prompt, String apiKey) async {
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4o',
        'messages': [
          {'role': 'system', 'content': 'You are a helpful assistant.'},
          {'role': 'user', 'content': 'Based on the following context, create a very short, engaging opening line for a cold call. Just the line, no extra text. Context: $prompt'},
        ],
        'max_tokens': 50,
      }),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['choices'][0]['message']['content'].trim();
    } else {
      throw Exception('Failed to generate opening line with OpenAI: ${response.body}');
    }
  }
  
  static Future<String> _generateWithGemini(String prompt, String apiKey) async {
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=$apiKey');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': 'Based on the following context, create a very short, engaging opening line for a cold call. Just the line, no extra text. Context: $prompt'}
            ]
          }
        ]
      }),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['candidates'][0]['content']['parts'][0]['text'].trim();
    } else {
      throw Exception('Failed to generate opening line with Gemini: ${response.body}');
    }
  }

  // Generate a response during a conversation
  static Future<String> generateResponse(
      String prompt, List<Map<String, String>> conversationHistory) async {
    // Implementation of generateResponse method
    throw Exception('Method not implemented');
  }

  static Future<double> calculateCostForConversation(List<Map<String, String>> conversation, String provider) async {
    int totalTokens = 0;
    for (var message in conversation) {
      // Simple approximation: 1 token per 4 characters
      totalTokens += (message['text']!.length / 4).ceil();
    }

    // Pricing per 1000 tokens (adjust based on actuals)
    double pricePer1000Tokens;
    switch (provider) {
      case 'openai':
        pricePer1000Tokens = 0.002; // Example: GPT-4o pricing
        break;
      case 'gemini':
        pricePer1000Tokens = 0.00015; // Example: Gemini 1.5 Flash input
        break;
      case 'deepseek':
        pricePer1000Tokens = 0.00014; // Example: DeepSeek Coder
        break;
      default:
        pricePer1000Tokens = 0.00015;
    }
    
    // Convert from USD to INR (example rate)
    const usdToInrRate = 83.5;
    final costInUsd = (totalTokens / 1000) * pricePer1000Tokens;
    return costInUsd * usdToInrRate;
  }
} 