import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Helper class for managing app permissions
class PermissionHelper {
  /// Request camera permission
  /// Returns true if granted, false otherwise
  static Future<bool> requestCameraPermission(BuildContext context) async {
    final status = await Permission.camera.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      final result = await Permission.camera.request();
      return result.isGranted;
    }

    if (status.isPermanentlyDenied) {
      if (context.mounted) {
        _showPermissionDialog(
          context,
          'Camera Permission Required',
          'Camera access is needed for eye tests. Please enable it in app settings.',
        );
      }
      return false;
    }

    return false;
  }

  /// Show permission dialog
  static void _showPermissionDialog(
    BuildContext context,
    String title,
    String message,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Check if camera permission is granted
  static Future<bool> hasCameraPermission() async {
    return await Permission.camera.isGranted;
  }
}
