import 'dart:async';
import 'package:flutter/services.dart';

class RecoverXBridge {
  static const _methodChannel = MethodChannel('com.recoverx.app/native');
  static const _eventChannel = EventChannel('com.recoverx.app/scan_progress');

  static Stream<Map<String, dynamic>> get scanProgressStream {
    return _eventChannel.receiveBroadcastStream().map((event) {
      return Map<String, dynamic>.from(event as Map);
    });
  }

  static Future<String> getEngineVersion() async {
    return await _methodChannel.invokeMethod('getEngineVersion');
  }

  static Future<int> scanFile({
    required String sourcePath,
    required String outputDir,
  }) async {
    return await _methodChannel.invokeMethod('scanFile', {
      'sourcePath': sourcePath,
      'outputDir': outputDir,
    });
  }

  static Future<int> scanPartition({
    required String devicePath,
    required String outputDir,
    required int totalSizeBytes,
  }) async {
    return await _methodChannel.invokeMethod('scanPartition', {
      'devicePath': devicePath,
      'outputDir': outputDir,
      'totalSize': totalSizeBytes,
    });
  }
}