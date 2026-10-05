import 'package:flutter/material.dart';
import '../services/permission_service.dart';

/// Example demonstrating how to use PermissionService
class PermissionServiceExample {
  final PermissionService _permissionService = PermissionService();

  /// Example: Request microphone permission for audio chat
  Future<bool> requestMicrophoneForAudioChat(BuildContext context) async {
    // First check if permission is already granted
    if (await _permissionService.isMicrophonePermissionGranted()) {
      return true;
    }

    // Request permission with explanation
    final result = await _permissionService.requestMicrophonePermission(
      context,
    );

    switch (result) {
      case PermissionResult.granted:
        return true;
      case PermissionResult.denied:
        // User denied permission, show a message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission is needed for voice chat'),
            ),
          );
        }
        return false;
      case PermissionResult.permanentlyDenied:
        // Permission permanently denied, guide user to settings
        if (context.mounted) {
          await _permissionService.handlePermanentlyDeniedPermission(
            context,
            'Microphone',
          );
        }
        return false;
    }
  }

  /// Example: Request camera permission for profile picture
  Future<bool> requestCameraForProfilePicture(BuildContext context) async {
    // Check if permission is already granted
    if (await _permissionService.isCameraPermissionGranted()) {
      return true;
    }

    // Request permission with explanation
    final result = await _permissionService.requestCameraPermission(context);

    switch (result) {
      case PermissionResult.granted:
        return true;
      case PermissionResult.denied:
        // User denied permission, offer alternative
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You can still select photos from your gallery'),
            ),
          );
        }
        return false;
      case PermissionResult.permanentlyDenied:
        // Permission permanently denied, guide user to settings
        if (context.mounted) {
          await _permissionService.handlePermanentlyDeniedPermission(
            context,
            'Camera',
          );
        }
        return false;
    }
  }

  /// Example: Check multiple permissions at once
  Future<void> checkAllPermissions() async {
    final results = await _permissionService.checkMultiplePermissions(
      microphone: true,
      camera: true,
      storage: true,
    );

    print('Permission status:');
    results.forEach((permission, granted) {
      print('$permission: ${granted ? "granted" : "not granted"}');
    });
  }

  /// Example: Request multiple permissions for a feature that needs them all
  Future<bool> requestPermissionsForFullFeature(BuildContext context) async {
    final results = await _permissionService.requestMultiplePermissions(
      context,
      microphone: true,
      camera: true,
      storage: true,
    );

    // Check if all permissions were granted
    final allGranted = results.values.every(
      (result) => result == PermissionResult.granted,
    );

    if (!allGranted && context.mounted) {
      // Handle any permanently denied permissions
      for (final entry in results.entries) {
        if (entry.value == PermissionResult.permanentlyDenied) {
          await _permissionService.handlePermanentlyDeniedPermission(
            context,
            entry.key.capitalize(),
          );
          break; // Only show one dialog at a time
        }
      }
    }

    return allGranted;
  }
}

/// Extension to capitalize strings
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
