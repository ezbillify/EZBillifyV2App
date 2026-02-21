import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class PermissionService {
  static Future<void> requestStartupPermissions() async {
    if (!Platform.isAndroid) return;

    try {
      // List of permissions required for external functionality
      final statuses = await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
        Permission.camera,
        // Storage is tricky on Android 13+, usually handled by specific pickers or media permissions
      ].request();

      if (kDebugMode) {
        statuses.forEach((permission, status) {
          print('Permission: $permission, Status: $status');
        });
      }
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
    }
  }
}
