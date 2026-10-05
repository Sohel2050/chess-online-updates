import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Service for handling runtime permissions with user-friendly explanations
///
/// Usage example:
/// ```dart
/// final permissionService = PermissionService();
///
/// // Check if microphone permission is granted
/// final hasPermission = await permissionService.isMicrophonePermissionGranted();
///
/// // Request microphone permission with explanation
/// final result = await permissionService.requestMicrophonePermission(context);
/// if (result == PermissionResult.permanentlyDenied) {
///   await permissionService.handlePermanentlyDeniedPermission(context, 'Microphone');
/// }
/// ```
class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  /// Check if microphone permission is granted
  Future<bool> isMicrophonePermissionGranted() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Check if camera permission is granted
  Future<bool> isCameraPermissionGranted() async {
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  /// Check if storage permission is granted (for older Android versions)
  Future<bool> isStoragePermissionGranted() async {
    if (Platform.isAndroid) {
      // For Android 13+ (API 33+), we use photos permission instead
      if (await _isAndroid13OrHigher()) {
        final status = await Permission.photos.status;
        return status.isGranted;
      } else {
        final status = await Permission.storage.status;
        return status.isGranted;
      }
    } else if (Platform.isIOS) {
      final status = await Permission.photos.status;
      return status.isGranted;
    }
    return true; // For other platforms, assume granted
  }

  /// Request microphone permission with explanation
  Future<PermissionResult> requestMicrophonePermission(
    BuildContext context,
  ) async {
    final status = await Permission.microphone.status;

    if (status.isGranted) {
      return PermissionResult.granted;
    }

    if (status.isPermanentlyDenied) {
      return PermissionResult.permanentlyDenied;
    }

    // Check if context is still mounted before showing dialog
    if (!context.mounted) {
      return PermissionResult.denied;
    }

    // Show explanation dialog before requesting permission
    final shouldRequest = await _showPermissionExplanationDialog(
      context,
      'Microphone Access',
      'This app needs microphone access to enable voice chat during games. '
          'You can communicate with your opponent using voice instead of text chat.',
      Icons.mic,
    );

    if (!shouldRequest) {
      return PermissionResult.denied;
    }

    final result = await Permission.microphone.request();

    if (result.isGranted) {
      return PermissionResult.granted;
    } else if (result.isPermanentlyDenied) {
      return PermissionResult.permanentlyDenied;
    } else {
      return PermissionResult.denied;
    }
  }

  /// Request camera permission with explanation
  Future<PermissionResult> requestCameraPermission(BuildContext context) async {
    final status = await Permission.camera.status;

    if (status.isGranted) {
      return PermissionResult.granted;
    }

    if (status.isPermanentlyDenied) {
      return PermissionResult.permanentlyDenied;
    }

    // Check if context is still mounted before showing dialog
    if (!context.mounted) {
      return PermissionResult.denied;
    }

    // Show explanation dialog before requesting permission
    final shouldRequest = await _showPermissionExplanationDialog(
      context,
      'Camera Access',
      'This app needs camera access to let you take photos for your profile picture. '
          'You can also choose existing photos from your gallery.',
      Icons.camera_alt,
    );

    if (!shouldRequest) {
      return PermissionResult.denied;
    }

    final result = await Permission.camera.request();

    if (result.isGranted) {
      return PermissionResult.granted;
    } else if (result.isPermanentlyDenied) {
      return PermissionResult.permanentlyDenied;
    } else {
      return PermissionResult.denied;
    }
  }

  /// Request storage/photos permission with explanation
  Future<PermissionResult> requestStoragePermission(
    BuildContext context,
  ) async {
    Permission permission;
    String title;
    String message;

    if (Platform.isAndroid) {
      if (await _isAndroid13OrHigher()) {
        permission = Permission.photos;
        title = 'Photos Access';
        message =
            'This app needs access to your photos to let you select images for your profile picture.';
      } else {
        permission = Permission.storage;
        title = 'Storage Access';
        message =
            'This app needs storage access to save and access images for your profile picture.';
      }
    } else {
      permission = Permission.photos;
      title = 'Photos Access';
      message =
          'This app needs access to your photos to let you select images for your profile picture.';
    }

    final status = await permission.status;

    if (status.isGranted) {
      return PermissionResult.granted;
    }

    if (status.isPermanentlyDenied) {
      return PermissionResult.permanentlyDenied;
    }

    // Check if context is still mounted before showing dialog
    if (!context.mounted) {
      return PermissionResult.denied;
    }

    // Show explanation dialog before requesting permission
    final shouldRequest = await _showPermissionExplanationDialog(
      context,
      title,
      message,
      Icons.photo_library,
    );

    if (!shouldRequest) {
      return PermissionResult.denied;
    }

    final result = await permission.request();

    if (result.isGranted) {
      return PermissionResult.granted;
    } else if (result.isPermanentlyDenied) {
      return PermissionResult.permanentlyDenied;
    } else {
      return PermissionResult.denied;
    }
  }

  /// Handle permanently denied permissions by showing settings dialog
  Future<void> handlePermanentlyDeniedPermission(
    BuildContext context,
    String permissionName,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$permissionName Permission Required'),
          content: Text(
            '$permissionName permission is required for this feature to work. '
            'Please enable it in your device settings.\n\n'
            'Go to Settings > Apps > Chess App > Permissions and enable $permissionName.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  /// Show permission explanation dialog
  Future<bool> _showPermissionExplanationDialog(
    BuildContext context,
    String title,
    String message,
    IconData icon,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(icon, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              Text(title),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not Now'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Allow'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  /// Check if device is running Android 13 or higher
  Future<bool> _isAndroid13OrHigher() async {
    if (!Platform.isAndroid) return false;

    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      // Android 13 is API level 33
      return androidInfo.version.sdkInt >= 33;
    } catch (e) {
      // Fallback to assuming modern Android if detection fails
      return true;
    }
  }

  /// Open app settings
  Future<void> _openAppSettings() async {
    await openAppSettings();
  }

  /// Check multiple permissions at once
  Future<Map<String, bool>> checkMultiplePermissions({
    bool microphone = false,
    bool camera = false,
    bool storage = false,
  }) async {
    final results = <String, bool>{};

    if (microphone) {
      results['microphone'] = await isMicrophonePermissionGranted();
    }
    if (camera) {
      results['camera'] = await isCameraPermissionGranted();
    }
    if (storage) {
      results['storage'] = await isStoragePermissionGranted();
    }

    return results;
  }

  /// Request multiple permissions with explanations
  Future<Map<String, PermissionResult>> requestMultiplePermissions(
    BuildContext context, {
    bool microphone = false,
    bool camera = false,
    bool storage = false,
  }) async {
    final results = <String, PermissionResult>{};

    if (microphone) {
      results['microphone'] = await requestMicrophonePermission(context);
    }
    if (camera && context.mounted) {
      results['camera'] = await requestCameraPermission(context);
    }
    if (storage && context.mounted) {
      results['storage'] = await requestStoragePermission(context);
    }

    return results;
  }
}

/// Result of permission request
enum PermissionResult { granted, denied, permanentlyDenied }
