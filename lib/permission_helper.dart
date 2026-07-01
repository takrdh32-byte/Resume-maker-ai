import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  static Future<bool> requestStoragePermissions() async {
    if (!Platform.isAndroid) return false;
    if (await Permission.photos.isDenied) await Permission.photos.request();
    if (await Permission.videos.isDenied) await Permission.videos.request();
    if (await Permission.storage.isDenied) await Permission.storage.request();
    return await hasMinimumPermissions();
  }

  static Future<bool> hasMinimumPermissions() async {
    final photos = await Permission.photos.status;
    final storage = await Permission.storage.status;
    return photos.isGranted || storage.isGranted;
  }

  static Future<bool> isPermanentlyDenied() async {
    final photos = await Permission.photos.status;
    final storage = await Permission.storage.status;
    return photos.isPermanentlyDenied || storage.isPermanentlyDenied;
  }

  static Future<void> openSettings() async {
    await openAppSettings();
  }
}