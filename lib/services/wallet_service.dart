import 'package:cloud_firestore/cloud_firestore.dart';

class WalletService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _usersCollection = 'users';

  static Future<Map<String, dynamic>> getWallet(String deviceId) async {
    final doc = await _firestore.collection('users').doc(deviceId).get();
    if (doc.exists && doc.data()!.containsKey('wallet')) {
      return doc.data()!['wallet'] as Map<String, dynamic>;
    }
    // Return a default wallet structure if not found
    return {'walletBalance': 0.0};
  }

  static Future<void> updateWallet(String deviceId, Map<String, dynamic> wallet) async {
    await _firestore.collection(_usersCollection).doc(deviceId).set({
      'wallet': wallet,
    }, SetOptions(merge: true));
  }

  static Future<bool> canMakeCall(String deviceId) async {
    final wallet = await getWallet(deviceId);
    return (wallet['walletBalance'] ?? 0.0) > 0.0;
  }

  static Future<void> deductCall(String deviceId) async {
    final wallet = await getWallet(deviceId);
    if ((wallet['walletBalance'] ?? 0.0) > 0.0) {
      wallet['walletBalance'] = (wallet['walletBalance'] ?? 0.0) - 0.01; // Deduct a small amount
    }
    await updateWallet(deviceId, wallet);
  }

  static Future<void> addPaidPack(String deviceId) async {
    final wallet = await getWallet(deviceId);
    wallet['walletBalance'] = (wallet['walletBalance'] ?? 0.0) + 5.0; // Add 5 units
    await updateWallet(deviceId, wallet);
  }

  static Future<void> rechargeWallet(String deviceId, double amount) async {
    final wallet = await getWallet(deviceId);
    wallet['walletBalance'] = (wallet['walletBalance'] ?? 0.0) + amount;
    await updateWallet(deviceId, wallet);
  }

  static Future<void> addFreeCalls(String deviceId, int count) async {
    final wallet = await getWallet(deviceId);
    wallet['walletBalance'] = (wallet['walletBalance'] ?? 0.0) + count * 0.01; // Add 1 paisa per call
    await updateWallet(deviceId, wallet);
  }

  static Future<void> addCallMinutes(String deviceId, int minutes) async {
    final wallet = await getWallet(deviceId);
    wallet['walletBalance'] = (wallet['walletBalance'] ?? 0.0) + (minutes * 0.01); // Add 1 paisa per minute
    await updateWallet(deviceId, wallet);
  }

  static Future<bool> isCallPackExpired(String deviceId) async {
    final wallet = await getWallet(deviceId);
    return (wallet['walletBalance'] ?? 0.0) <= 0.0;
  }

  static Future<bool> hasActivePack(String deviceId) async {
    final wallet = await getWallet(deviceId);
    return (wallet['walletBalance'] ?? 0.0) > 0.0;
  }

  static Future<bool> buyPackFromWallet(String deviceId) async {
    final wallet = await getWallet(deviceId);
    if ((wallet['walletBalance'] ?? 0.0) > 0.0) {
      wallet['walletBalance'] = (wallet['walletBalance'] ?? 0.0) - 5.0; // Deduct 5 units
      await updateWallet(deviceId, wallet);
      return true;
    }
    return false;
  }

  static Future<void> addMoney(String deviceId, double amount, String upiRef) async {
    final docRef = _firestore.collection('users').doc(deviceId);

    await docRef.update({
      'wallet.walletBalance': FieldValue.increment(amount),
    });

    // Log the transaction
    await docRef.collection('transactions').add({
      'type': 'credit',
      'amount': amount,
      'upiRef': upiRef,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Deduct the cost of a call
  static Future<void> deductCallCost(String deviceId, double apiCost) async {
    final docRef = _firestore.collection('users').doc(deviceId);
    const profit = 0.10; // 10 paise profit
    final totalCost = apiCost + profit;
    
    await docRef.update({'wallet.walletBalance': FieldValue.increment(-totalCost)});

    // Log the transaction
    await docRef.collection('transactions').add({
      'type': 'debit',
      'amount': totalCost,
      'apiCost': apiCost,
      'profit': profit,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Get the price for a given provider
  static double _getPriceForProvider(String provider) {
    switch (provider) {
      case 'openai':
        return 0.5; // Best
      case 'gemini':
        return 0.3; // Medium
      case 'deepseek':
        return 0.2; // Normal
      default:
        return 0.2; // Default fallback price
    }
  }

  // Add purchased call time (in seconds) to the user's wallet
  static Future<void> addCallTime(String deviceId, int seconds, String upiRef) async {
    final docRef = _firestore.collection('users').doc(deviceId);

    await docRef.update({
      'wallet.walletBalance': FieldValue.increment(seconds * 0.01),
    });

    // Log the transaction
    await docRef.collection('transactions').add({
      'type': 'purchase',
      'secondsAdded': seconds,
      'upiRef': upiRef,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Deduct the used call time (in seconds)
  static Future<void> deductCallTime(String deviceId, int secondsUsed) async {
    final docRef = _firestore.collection('users').doc(deviceId);
    
    await docRef.update({'wallet.walletBalance': FieldValue.increment(-secondsUsed * 0.01)});

    // Log the transaction
    await docRef.collection('transactions').add({
      'type': 'usage',
      'secondsUsed': secondsUsed,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
} 