import 'package:flutter/services.dart';
import 'dart:async';

class CallStateService {
  static const MethodChannel _channel = MethodChannel('com.shailesh.callai/call');
  static const EventChannel _callStateChannel = EventChannel('com.shailesh.callai/callstate');
  
  static final CallStateService _instance = CallStateService._internal();
  factory CallStateService() => _instance;
  CallStateService._internal();

  StreamController<CallState>? _callStateController;
  StreamSubscription? _callStateSubscription;

  /// Start monitoring call states
  Future<void> startCallStateMonitoring() async {
    try {
      await _channel.invokeMethod('startCallStateMonitoring');
      _logDebug('Call state monitoring started');
    } catch (e) {
      _logError('Failed to start call state monitoring: $e');
    }
  }

  /// Stop monitoring call states
  Future<void> stopCallStateMonitoring() async {
    try {
      await _channel.invokeMethod('stopCallStateMonitoring');
      _callStateSubscription?.cancel();
      _callStateController?.close();
      _logDebug('Call state monitoring stopped');
    } catch (e) {
      _logError('Failed to stop call state monitoring: $e');
    }
  }

  /// Get current call state
  Future<CallState> getCurrentCallState() async {
    try {
      final result = await _channel.invokeMethod('getCurrentCallState');
      return CallState.fromMap(Map<String, dynamic>.from(result));
    } catch (e) {
      _logError('Failed to get current call state: $e');
      return CallState(state: 'UNKNOWN', stateCode: -1, timestamp: DateTime.now());
    }
  }

  /// Stream of call state changes
  Stream<CallState> get callStateStream {
    if (_callStateController == null) {
      _callStateController = StreamController<CallState>.broadcast();
      _setupCallStateListener();
    }
    return _callStateController!.stream;
  }

  void _setupCallStateListener() {
    _callStateSubscription = _callStateChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        try {
          final callState = CallState.fromMap(Map<String, dynamic>.from(event));
          _logDebug('Call state changed: ${callState.state} (${callState.stateCode})');
          _callStateController?.add(callState);
        } catch (e) {
          _logError('Error parsing call state: $e');
        }
      },
      onError: (error) {
        _logError('Call state stream error: $error');
      },
    );
  }

  /// Start a call using the native dialer
  Future<bool> startCall(String phoneNumber) async {
    try {
      final result = await _channel.invokeMethod('startCall', {'number': phoneNumber});
      _logDebug('Call initiated: $phoneNumber');
      return result == 'Call initiation process started';
    } catch (e) {
      _logError('Failed to start call: $e');
      return false;
    }
  }

  /// Set speakerphone on/off
  Future<bool> setSpeakerphoneOn(bool on) async {
    try {
      await _channel.invokeMethod('setSpeakerphoneOn', {'on': on});
      _logDebug('Speakerphone set to: $on');
      return true;
    } catch (e) {
      _logError('Failed to set speakerphone: $e');
      return false;
    }
  }

  void _logDebug(String message) {
    print('[DEBUG] CallStateService: $message');
  }

  void _logError(String message) {
    print('[ERROR] CallStateService: $message');
  }

  void dispose() {
    stopCallStateMonitoring();
  }
}

class CallState {
  final String state;
  final int stateCode;
  final DateTime timestamp;

  CallState({
    required this.state,
    required this.stateCode,
    required this.timestamp,
  });

  factory CallState.fromMap(Map<String, dynamic> map) {
    return CallState(
      state: map['state'] ?? 'UNKNOWN',
      stateCode: map['stateCode'] ?? -1,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'state': state,
      'stateCode': stateCode,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  bool get isIdle => state == 'IDLE';
  bool get isRinging => state == 'RINGING';
  bool get isOffHook => state == 'OFFHOOK';
  bool get isConnected => state == 'OFFHOOK'; // OFFHOOK means call is active

  @override
  String toString() {
    return 'CallState(state: $state, stateCode: $stateCode, timestamp: $timestamp)';
  }
} 