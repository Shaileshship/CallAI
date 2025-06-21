import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class DeviceService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static const String _deviceIdKey = 'device_id';

  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? storedDeviceId = prefs.getString(_deviceIdKey);

    if (storedDeviceId != null) {
      return storedDeviceId;
    }

    // Generate a unique device identifier based on hardware-specific info
    String deviceId = '';
    
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        // Use a combination of hardware-specific identifiers
        final rawId = '${androidInfo.fingerprint}_${androidInfo.board}_${androidInfo.bootloader}_${androidInfo.device}_${androidInfo.hardware}_${androidInfo.host}_${androidInfo.id}_${androidInfo.manufacturer}_${androidInfo.model}_${androidInfo.product}';
        // Hash the identifier to make it consistent length and format
        deviceId = sha256.convert(utf8.encode(rawId)).toString();
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        // Use identifierForVendor which is consistent for app reinstalls
        final rawId = '${iosInfo.identifierForVendor}_${iosInfo.model}_${iosInfo.systemName}_${iosInfo.name}';
        deviceId = sha256.convert(utf8.encode(rawId)).toString();
      } else {
        throw Exception('Unsupported platform');
      }
    } catch (e) {
      // If device info fails, create a unique ID and store it
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final random = DateTime.now().microsecondsSinceEpoch.toString();
      deviceId = sha256.convert(utf8.encode('${timestamp}_$random')).toString();
    }

    // Store the device ID
    await prefs.setString(_deviceIdKey, deviceId);
    return deviceId;
  }

  static Future<bool> isExistingUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_existing_user') ?? false;
  }

  static Future<void> markAsExistingUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_existing_user', true);
  }

  /// Ensure the CallAI folder exists and return its path
  static Future<String> ensureCallAIFolder() async {
    final dir = Directory('/storage/emulated/0/CallAI');
    if (!(await dir.exists())) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  /// Create a log file for a call session
  static Future<File> createLogFile(String contactName, String contactNumber) async {
    final folder = await ensureCallAIFolder();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'log_${contactName}_$contactNumber".$timestamp.txt"';
    return File('$folder/$fileName').create();
  }

  /// Create an audio file for call recording
  static Future<File> createAudioFile(String contactName, String contactNumber) async {
    final folder = await ensureCallAIFolder();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'rec_${contactName}_$contactNumber".$timestamp.m4a"';
    return File('$folder/$fileName').create();
  }
} 