import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  static Future<bool> requestStoragePermissions() async {
    if (!Platform.isAndroid) return false;

    final mediaImages = await Permission.photos.status;
    if (mediaImages.isDenied) await Permission.photos.request();
    final mediaVideos = await Permission.videos.status;
    if (mediaVideos.isDenied) await Permission.videos.request();

    final storage = await Permission.storage.status;
    if (storage.isDenied) await Permission.storage.request();

    final manageStorage = await Permission.manageExternalStorage.status;
    if (manageStorage.isDenied) await Permission.manageExternalStorage.request();

    return await hasMinimumPermissions();
  }

  static Future<bool> hasMinimumPermissions() async {
    final photos = await Permission.photos.status;
    final storage = await Permission.storage.status;
    final manageStorage = await Permission.manageExternalStorage.status;
    return photos.isGranted || storage.isGranted || manageStorage.isGranted;
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