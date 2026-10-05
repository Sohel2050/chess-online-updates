import 'package:flutter_chess_app/services/version_service.dart';

/// Helper functions for manual version synchronization to the backend
///
/// Run these from the app to update version configs without a database console
/// Usage: Call these functions from a debug screen or admin panel
class VersionSyncHelper {
  /// Run once to initialize Firestore with current app version
  /// Safe to call multiple times - only creates if missing
  static Future<void> setupVersionConfigOnce() async {
    print('📲 Setting up version config in Firestore...');
    final success = await VersionService.initializeVersionConfigIfNeeded();
    if (success) {
      print('✅ Version config initialized successfully!');
      print('   - minimumVersion: current app version');
      print('   - latestVersion: current app version');
      print('   - forceUpdate: false');
    } else {
      print('❌ Failed to initialize version config');
    }
  }

  /// Update the latest available version (non-forcing update)
  /// Use this when releasing a new version that users can optionally install
  static Future<void> releaseNewVersion(String newVersion) async {
    print('📦 Releasing new version: $newVersion');
    final success = await VersionService.updateLatestVersion(
      newVersion: newVersion,
      changelogText: '• New features\n• Bug fixes\n• Performance improvements',
      forceUpdate: false,
    );
    if (success) {
      print('✅ Version updated successfully!');
      print('   Users with older versions will see an optional update');
    } else {
      print('❌ Failed to update version');
    }
  }

  /// Force users to update to a specific version (emergency/security update)
  /// Use sparingly - this will block users from using the app
  static Future<void> forceUpdateToVersion(String requiredVersion) async {
    print('🚨 FORCING update to version: $requiredVersion');
    final success = await VersionService.setMinimumRequiredVersion(
      minVersion: requiredVersion,
      updateMessage:
          '⚠️ A critical security update is required. Please update immediately.',
      changelogText:
          '• CRITICAL: Security patches\n• CRITICAL: Bug fixes\n• System stability improvements',
    );
    if (success) {
      print('✅ Force update configured!');
      print(
        '   All users will be blocked until they update to $requiredVersion',
      );
      print(
        '   IMPORTANT: Make sure $requiredVersion is available in app stores!',
      );
    } else {
      print('❌ Failed to configure force update');
    }
  }

  /// Example: Simulate a release workflow
  static Future<void> simulateReleaseWorkflow() async {
    print('\n🔄 === VERSION SYNC WORKFLOW EXAMPLE ===\n');

    // Step 1: Initialize if needed
    print('Step 1: Initialize Firestore config');
    await setupVersionConfigOnce();

    // Step 2: Release new optional version
    print('\nStep 2: Release new version v1.0.3 (optional)');
    // await releaseNewVersion('1.0.3');

    // Step 3: Force critical update if needed
    print('\nStep 3: Force update to critical version (if needed)');
    // await forceUpdateToVersion('1.0.5');

    print('\n✅ Workflow complete!');
  }
}

/* USAGE INSTRUCTIONS:

1. ON FIRST APP LAUNCH (auto-runs):
   - VersionService.initializeVersionConfigIfNeeded() is called automatically
   - Creates Firestore document with current app version
   - No manual action needed!

2. WHEN RELEASING A NEW VERSION:
   a) Build and upload new version to Play Store / App Store
   b) Update pubspec.yaml version: version: 1.0.3+3
   c) From Flutter console or admin screen, call:
      await VersionSyncHelper.releaseNewVersion('1.0.3');
   d) Users will see optional update notification

3. FOR CRITICAL SECURITY UPDATES:
   a) Build and upload new version to app stores FIRST
   b) Wait for stores to approve (1-2 hours)
   c) From admin panel, call:
      await VersionSyncHelper.forceUpdateToVersion('1.0.5');
   d) All users will be blocked until they update
   ⚠️ ONLY USE FOR SECURITY/CRITICAL FIXES!

4. MANUAL FIRESTORE DOCUMENT FORMAT:
   {
     "minimumVersion": "1.0.2",      // Users below this are blocked
     "latestVersion": "1.0.3",       // Latest available version
     "updateMessage": "Update text",
     "changelog": "What's new...",
     "forceUpdate": true/false,      // true = blocks app
     "createdAt": timestamp,
     "lastUpdated": timestamp
   }

5. PROGRAMMATIC METHODS IN VersionService:
   - initializeVersionConfigIfNeeded()   // Auto-called on startup
   - updateLatestVersion()               // Release optional update
   - setMinimumRequiredVersion()         // Force critical update
   - getVersionConfig()                  // Read current config
   - compareVersions()                   // Compare version numbers
*/
