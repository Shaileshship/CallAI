import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class SecurityService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static const _storage = FlutterSecureStorage();
  static const _deviceIdKey = 'unique_device_id';
  static const _deviceFingerprintKey = 'device_fingerprint';
  static const _lastLoginKey = 'last_login_timestamp';

  // Get a stable, secure device identifier
  static Future<String> getSecureDeviceId() async {
    // 1. Try to get the stored ID first
    String? storedId = await _storage.read(key: _deviceIdKey);
    if (storedId != null && storedId.isNotEmpty) {
      // Verify device fingerprint before returning stored ID
      if (await _verifyDeviceFingerprint()) {
        return storedId;
      }
      // If fingerprint verification fails, clear stored data and generate new ID
      await _storage.deleteAll();
    }

    // 2. If not found or fingerprint verification failed, generate a new one
    try {
      String deviceIdentifier = await _generateDeviceIdentifier();
      String newId = _hashIdentifier(deviceIdentifier);

      // 3. Store the new ID and device fingerprint securely
      await _storage.write(key: _deviceIdKey, value: newId);
      await _storeDeviceFingerprint();
      await _updateLastLoginTimestamp();
      
      return newId;
    } catch (e) {
      print('Error getting secure device ID: $e');
      String fallbackId = DateTime.now().millisecondsSinceEpoch.toString();
      await _storage.write(key: _deviceIdKey, value: fallbackId);
      return fallbackId;
    }
  }

  // Generate device identifier using multiple device characteristics
  static Future<String> _generateDeviceIdentifier() async {
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      return '${androidInfo.id}_${androidInfo.fingerprint}_${androidInfo.model}_'
          '${androidInfo.brand}_${androidInfo.device}_${androidInfo.product}_'
          '${androidInfo.hardware}_${androidInfo.bootloader}';
    } else if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      return '${iosInfo.identifierForVendor}_${iosInfo.model}_${iosInfo.systemName}_'
          '${iosInfo.systemVersion}_${iosInfo.name}_${iosInfo.localizedModel}';
    }
    throw UnsupportedError('Unsupported platform');
  }

  // Hash the device identifier
  static String _hashIdentifier(String identifier) {
    final bytes = utf8.encode(identifier);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  // Store device fingerprint for verification
  static Future<void> _storeDeviceFingerprint() async {
    final fingerprint = await _generateDeviceFingerprint();
    await _storage.write(key: _deviceFingerprintKey, value: fingerprint);
  }

  // Generate device fingerprint using hardware and software characteristics
  static Future<String> _generateDeviceFingerprint() async {
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      return _hashIdentifier(
        '${androidInfo.brand}_${androidInfo.device}_${androidInfo.fingerprint}_'
        '${androidInfo.hardware}_${androidInfo.host}_${androidInfo.id}_'
        '${androidInfo.manufacturer}_${androidInfo.model}_${androidInfo.product}'
      );
    } else if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      return _hashIdentifier(
        '${iosInfo.model}_${iosInfo.systemName}_${iosInfo.systemVersion}_'
        '${iosInfo.name}_${iosInfo.localizedModel}'
      );
    }
    throw UnsupportedError('Unsupported platform');
  }

  // Verify device fingerprint
  static Future<bool> _verifyDeviceFingerprint() async {
    try {
      final storedFingerprint = await _storage.read(key: _deviceFingerprintKey);
      if (storedFingerprint == null) return false;
      
      final currentFingerprint = await _generateDeviceFingerprint();
      return storedFingerprint == currentFingerprint;
    } catch (e) {
      print('Error verifying device fingerprint: $e');
      return false;
    }
  }

  // Update last login timestamp
  static Future<void> _updateLastLoginTimestamp() async {
    await _storage.write(
      key: _lastLoginKey,
      value: DateTime.now().toIso8601String(),
    );
  }

  // Get last login timestamp
  static Future<DateTime?> getLastLoginTimestamp() async {
    final timestamp = await _storage.read(key: _lastLoginKey);
    return timestamp != null ? DateTime.parse(timestamp) : null;
  }

  // Check if device has been inactive for too long (e.g., more than 30 days)
  static Future<bool> isDeviceInactive() async {
    final lastLogin = await getLastLoginTimestamp();
    if (lastLogin == null) return true;
    
    final inactiveDuration = DateTime.now().difference(lastLogin);
    return inactiveDuration.inDays > 30;
  }

  // Helper method for logout
  static Future<void> clearSecureDeviceId() async {
    await _storage.deleteAll();
  }

  // Store device metadata securely
  static Future<void> storeDeviceMetadata() async {
    try {
      final metadata = await _generateDeviceMetadata();
      await _storage.write(key: 'device_metadata', value: jsonEncode(metadata));
    } catch (e) {
      print('Error storing device metadata: $e');
    }
  }

  // Generate device metadata
  static Future<Map<String, dynamic>> _generateDeviceMetadata() async {
    final metadata = <String, dynamic>{
      'platform': Platform.operatingSystem,
      'version': Platform.operatingSystemVersion,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      metadata.addAll({
        'manufacturer': androidInfo.manufacturer,
        'brand': androidInfo.brand,
        'model': androidInfo.model,
        'sdk': androidInfo.version.sdkInt,
        'security_patch': androidInfo.version.securityPatch,
      });
    } else if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      metadata.addAll({
        'model': iosInfo.model,
        'system_name': iosInfo.systemName,
        'system_version': iosInfo.systemVersion,
        'localized_model': iosInfo.localizedModel,
      });
    }

    return metadata;
  }

  // Get stored device metadata
  static Future<Map<String, dynamic>?> getDeviceMetadata() async {
    try {
      final metadata = await _storage.read(key: 'device_metadata');
      return metadata != null ? jsonDecode(metadata) : null;
    } catch (e) {
      print('Error getting device metadata: $e');
      return null;
    }
  }

  // Check if device is secure
  static Future<bool> isDeviceSecure() async {
    try {
      if (!await _verifyDeviceFingerprint()) {
        return false;
      }
      
      if (await isDeviceInactive()) {
        return false;
      }

      final metadata = await getDeviceMetadata();
      if (metadata == null) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
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

  // Clear stored device info (for logout)
  static Future<void> clearDeviceInfo() async {
    await _storage.delete(key: 'device_id');
  }
} 