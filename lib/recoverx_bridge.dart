import 'dart:async';
import 'package:flutter/services.dart';

class RecoverXBridge {
  static const _methodChannel = MethodChannel('com.recoverx.app/native');
  static const _eventChannel = EventChannel('com.recoverx.app/scan_progress');

  static Stream<Map<String, dynamic>> get scanProgressStream {
    return _eventChannel.receiveBroadcastStream().map((event) => Map<String, dynamic>.from(event as Map));
  }

  static Future<String> getEngineVersion() async => await _methodChannel.invokeMethod('getEngineVersion');

  static Future<bool> startScanSession({required String outputDir}) async =>
      await _methodChannel.invokeMethod('startScanSession', {'outputDir': outputDir});

  static Future<int> scanFileInSession({required String sourcePath}) async =>
      await _methodChannel.invokeMethod('scanFileInSession', {'sourcePath': sourcePath});

  static Future<bool> endScanSession() async => await _methodChannel.invokeMethod('endScanSession');
}