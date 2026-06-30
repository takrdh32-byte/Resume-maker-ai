import 'dart:async';
import 'package:flutter/services.dart';

class RecoverXBridge {
  static const _methodChannel = MethodChannel('com.recoverx.app/native');
  static const _eventChannel = EventChannel('com.recoverx.app/scan_progress');

  /// रियल-टाइम स्कैन अपडेट
  static Stream<Map<String, dynamic>> get scanProgressStream {
    return _eventChannel.receiveBroadcastStream().map((event) {
      return Map<String, dynamic>.from(event as Map);
    });
  }

  /// इंजन वर्जन
  static Future<String> getEngineVersion() async {
    return await _methodChannel.invokeMethod('getEngineVersion');
  }

  /// सेशन शुरू — एक ही JpegCarver बनाता है
  static Future<bool> startScanSession({required String outputDir}) async {
    return await _methodChannel.invokeMethod('startScanSession', {
      'outputDir': outputDir,
    });
  }

  /// एक फ़ाइल को उसी JpegCarver से स्कैन करता है
  static Future<int> scanFileInSession({required String sourcePath}) async {
    return await _methodChannel.invokeMethod('scanFileInSession', {
      'sourcePath': sourcePath,
    });
  }

  /// सेशन खत्म — JpegCarver को हटाता है
  static Future<bool> endScanSession() async {
    return await _methodChannel.invokeMethod('endScanSession');
  }
}