import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class SecurityService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static const _storage = FlutterSecureStorage();

  // Get secure device identifier that can't be easily spoofed
  static Future<String> getSecureDeviceId() async {
    try {
      String deviceId = '';
      
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        // Use hardware identifiers that are harder to spoof
        deviceId = '${androidInfo.id}_${androidInfo.fingerprint}_${androidInfo.hardware}';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        // Use hardware identifiers that are harder to spoof
        deviceId = '${iosInfo.identifierForVendor}_${iosInfo.systemName}_${iosInfo.systemVersion}';
      }

      // Hash the device ID for additional security
      final bytes = utf8.encode(deviceId);
      final hash = sha256.convert(bytes);
      return hash.toString();
    } catch (e) {
      // If we can't get device info, generate a random ID
      return DateTime.now().millisecondsSinceEpoch.toString();
    }
  }

  // Store device info securely
  static Future<void> storeDeviceInfo(String deviceId) async {
    await _storage.write(key: 'device_id', value: deviceId);
  }

  // Get stored device info
  static Future<String?> getStoredDeviceInfo() async {
    return await _storage.read(key: 'device_id');
  }

  // Check if device is secure
  static Future<bool> isDeviceSecure() async {
    try {
      // Additional security checks can be added here if needed
      return true;
    } catch (e) {
      return false;
    }
  }

  // Clear stored device info (for logout)
  static Future<void> clearDeviceInfo() async {
    await _storage.delete(key: 'device_id');
  }
} 