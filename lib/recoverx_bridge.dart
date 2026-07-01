import 'dart:async';
import 'package:flutter/services.dart';

class RecoverXBridge {
  static const _methodChannel = MethodChannel('com.recoverx.app/native');
  static const _eventChannel = EventChannel('com.recoverx.app/scan_progress');

  /// रियल-टाइम स्कैन अपडेट (हर रिकवर फ़ाइल, प्रोग्रेस, एरर)
  static Stream<Map<String, dynamic>> get scanProgressStream {
    return _eventChannel.receiveBroadcastStream().map((event) {
      return Map<String, dynamic>.from(event as Map);
    });
  }

  /// इंजन वर्ज़न
  static Future<String> getEngineVersion() async {
    return await _methodChannel.invokeMethod('getEngineVersion');
  }

  /// सेशन शुरू — एक ही C++ इंजन बनाता है
  static Future<bool> startScanSession({required String outputDir}) async {
    return await _methodChannel.invokeMethod('startScanSession', {
      'outputDir': outputDir,
    });
  }

  /// एक फ़ाइल को उसी सत्र में स्कैन करो
  static Future<int> scanFileInSession({required String sourcePath}) async {
    return await _methodChannel.invokeMethod('scanFileInSession', {
      'sourcePath': sourcePath,
    });
  }

  /// सेशन खत्म — इंजन हटाओ
  static Future<bool> endScanSession() async {
    return await _methodChannel.invokeMethod('endScanSession');
  }
}