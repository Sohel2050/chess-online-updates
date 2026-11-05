import 'dart:async';
import 'package:flutter_chess_app/services/analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/providers/game_provider.dart';
import 'package:flutter_chess_app/providers/settings_provider.dart';
import 'package:flutter_chess_app/providers/user_provider.dart';
import 'package:flutter_chess_app/providers/levelplay_provider.dart';
import 'package:flutter_chess_app/providers/monetization_provider.dart';
import 'package:flutter_chess_app/providers/connectivity_provider.dart';
import 'package:flutter_chess_app/providers/puzzle_provider.dart';
import 'package:flutter_chess_app/providers/premium_provider.dart';
import 'package:flutter_chess_app/providers/poll_provider.dart';
import 'package:flutter_chess_app/providers/streak_provider.dart';
import 'package:flutter_chess_app/providers/mission_provider.dart';
import 'package:flutter_chess_app/providers/badge_provider.dart';
import 'package:flutter_chess_app/services/monetization_service.dart';
import 'package:flutter_chess_app/services/consent_service.dart';
import 'package:flutter_chess_app/services/push_service.dart';
import 'package:flutter_chess_app/services/deep_link_service.dart';
import 'package:flutter_chess_app/services/crash_reporter.dart';
import 'package:flutter_chess_app/utils/adaptive.dart';
import 'package:flutter_chess_app/services/version_service.dart';
import 'package:flutter_chess_app/screens/home_screen.dart';
import 'package:flutter_chess_app/services/offline_service.dart';
import 'package:flutter_chess_app/services/user_service.dart';
import 'package:flutter_chess_app/services/auth_service.dart';
import 'package:flutter_chess_app/utils/constants.dart';
import 'package:flutter_chess_app/widgets/force_update_dialog.dart';
import 'package:get_it/get_it.dart';
import 'screens/login_screen.dart';
import 'screens/age_gate_screen.dart';
import 'package:provider/provider.dart';
import 'models/user_model.dart';
import 'widgets/floating_message_button.dart';

// Global navigator key for navigation management
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  // Last line of defence: an error nobody caught must be logged, never kill the app.
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    // Installs the Flutter / platform error handlers and sends crashes to Crashlytics
    // (does nothing, quietly, until Firebase is configured).
    await CrashReporter.init();
    await AnalyticsService.instance.init();
    AnalyticsService.instance.track('app_open');
    ConsentService.navigatorKey = navigatorKey;
    PushService.navigatorKey = navigatorKey;
    // Game links (https://<host>/g/<code>) tapped outside the app open the import screen.
    unawaited(DeepLinkService.instance.init(navigatorKey));
    // Quietly does nothing until android/app/google-services.json exists.
    unawaited(PushService.instance.init());
    setupServiceLocator();

    // Initialize version config on the backend (creates it if missing with
    // current app version).
    await VersionService.initializeVersionConfigIfNeeded();

    // TODO: Remove this - TEST MODE for force update dialog
    //VersionService.useTestMode = true;

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => GameProvider()),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => UserProvider()),
          ChangeNotifierProvider(create: (_) => LevelPlayProvider()),
          ChangeNotifierProvider(create: (_) => MonetizationProvider()),
          ChangeNotifierProvider(create: (_) => PuzzleProvider()),
          ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
          ChangeNotifierProvider(create: (_) => PremiumProvider()),
          ChangeNotifierProvider(create: (_) => PollProvider()),
          ChangeNotifierProvider(create: (_) => StreakProvider()),
          ChangeNotifierProvider(create: (_) => MissionProvider()),
          ChangeNotifierProvider(create: (_) => BadgeProvider()),
        ],
        child: const MyApp(),
      ),
    );
  }, (error, stack) {
    CrashReporter.recordZoneError(error, stack);
  });
}

void setupServiceLocator() {
  GetIt.instance.registerSingleton<UserProvider>(UserProvider());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final UserService _userService = UserService();
  final OfflineService _offlineService = OfflineService();
  bool _isMonetizationInitialized = false;
  bool _hasShownAppLaunchAd = false;

  // Version check state
  bool _versionCheckPassed = true;
  bool _versionCheckStarted = false;
  late Future<void> _versionCheckFuture;
  String? _currentVersion;
  String? _requiredVersion;
  String? _updateMessage;
  String? _updateChangelog;
  bool _isForceUpdate = true; // Whether update is forced or optional
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    // Initialize consent first, then monetization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeConsentAndMonetization();
    });
  }

  /// Initialize consent and monetization system once
  Future<void> _initializeConsentAndMonetization() async {
    if (_isMonetizationInitialized) return;

    try {
      // Consent + LevelPlay init both happen inside MonetizationService.
      debugPrint('Initializing monetization system...');
      await MonetizationService.initialize(context);

      if (mounted) {
        setState(() {
          _isMonetizationInitialized = true;
        });
      }
      debugPrint('Monetization system initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize monetization: $e');
    }
  }

  /// Check app version and set state for update dialog
  Future<void> _checkVersionAndSetState() async {
    debugPrint('======== VERSION CHECK STARTED ========');
    try {
      final currentVersion = await VersionService.getCurrentVersion();
      debugPrint('✓ Got current version: $currentVersion');

      final versionConfig = await VersionService.getVersionConfig();
      debugPrint('✓ Got version config: $versionConfig');

      if (versionConfig == null) {
        debugPrint('❌ No version config found, allowing app to proceed');
        if (mounted) setState(() => _versionCheckPassed = true);
        return;
      }

      debugPrint(
        'Version config details: min=${versionConfig.minimumVersion}, latest=${versionConfig.latestVersion}, force=${versionConfig.forceUpdate}',
      );

      // Check if force update is required (minimumVersion)
      final minComparison = VersionService.compareVersions(
        currentVersion,
        versionConfig.minimumVersion,
      );
      debugPrint(
        'Version comparison (min): $currentVersion vs ${versionConfig.minimumVersion} = $minComparison (< 0 means update needed)',
      );

      // Check if optional update is available (latestVersion)
      final latestComparison = VersionService.compareVersions(
        currentVersion,
        versionConfig.latestVersion,
      );
      debugPrint(
        'Version comparison (latest): $currentVersion vs ${versionConfig.latestVersion} = $latestComparison (< 0 means update available)',
      );

      if (minComparison < 0) {
        // Force update required
        debugPrint(
          '⚠️ FORCE UPDATE REQUIRED: current=$currentVersion, required=${versionConfig.minimumVersion}',
        );

        if (mounted) {
          debugPrint('Storing version info for force update dialog');
          _currentVersion = currentVersion;
          _requiredVersion = versionConfig.minimumVersion;
          _updateMessage = versionConfig.updateMessage;
          _updateChangelog = versionConfig.changelog;
          _isForceUpdate = true;
          setState(() => _versionCheckPassed = false);
        }
      } else if (latestComparison < 0 && !versionConfig.forceUpdate) {
        // Optional update available
        debugPrint(
          '📱 OPTIONAL UPDATE AVAILABLE: current=$currentVersion, latest=${versionConfig.latestVersion}',
        );

        if (mounted) {
          debugPrint('Storing version info for optional update dialog');
          _currentVersion = currentVersion;
          _requiredVersion = versionConfig.latestVersion;
          _updateMessage = versionConfig.updateMessage;
          _updateChangelog = versionConfig.changelog;
          _isForceUpdate = false;
          setState(() => _versionCheckPassed = false);
        }
      } else {
        debugPrint('✓ App is up to date');
        if (mounted) setState(() => _versionCheckPassed = true);
      }
    } catch (e) {
      debugPrint('❌ Error checking version: $e');
      if (mounted) setState(() => _versionCheckPassed = true);
    }
    debugPrint('======== VERSION CHECK COMPLETED ========');
  }

  /// Build HomeScreen with version check
  Widget _buildHomeScreen(ChessUser user) {
    debugPrint(
      '_buildHomeScreen() called - _versionCheckStarted=$_versionCheckStarted',
    );

    // Initialize the version check future only once
    if (!_versionCheckStarted) {
      debugPrint('Initializing version check future...');
      _versionCheckStarted = true;
      _versionCheckFuture = _checkVersionAndSetState();
    }

    return FutureBuilder<void>(
      future: _versionCheckFuture,
      builder: (context, snapshot) {
        debugPrint(
          'FutureBuilder state: ${snapshot.connectionState}, _versionCheckPassed=$_versionCheckPassed',
        );

        if (snapshot.connectionState == ConnectionState.waiting) {
          debugPrint('Showing loading screen...');
          return const Scaffold(
            body: Center(child: CircularProgressIndicator.adaptive()),
          );
        }

        // After version check completes, show dialog if update required (on top of HomeScreen)
        if (!_versionCheckPassed &&
            _currentVersion != null &&
            _requiredVersion != null) {
          debugPrint(
            'Version check failed, will show force update dialog on top of HomeScreen',
          );
          // Show dialog after this frame using context from builder
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_dialogShown) {
              _dialogShown = true;
              debugPrint('Showing force update dialog with builder context...');
              showForceUpdateDialog(
                context: context,
                currentVersion: _currentVersion!,
                requiredVersion: _requiredVersion!,
                message: _updateMessage,
                changelog: _updateChangelog,
                isForced: _isForceUpdate,
              );
            }
          });
        }

        debugPrint('Version check passed, showing HomeScreen');
        return HomeScreen(user: user);
      },
    );
  }

  /// Show app launch ad for non-premium users and guest users (only once per app session)
  void _showAppLaunchAd(ChessUser user) async {
    // Prevent showing multiple app launch ads
    if (_hasShownAppLaunchAd) {
      debugPrint('App launch ad already shown, skipping');
      return;
    }

    _hasShownAppLaunchAd = true;
    debugPrint('Attempting to show app launch ad for user: ${user.uid}');

    // Ensure monetization is initialized before showing ad
    if (!_isMonetizationInitialized) {
      await _initializeConsentAndMonetization();
    }

    if (!mounted) return;

    await MonetizationService.showAppLaunchAd(
      context: context,
      user: user,
      onAdClosed: () {
        debugPrint('App launch ad closed.');
      },
      onAdFailedToLoad: () {
        debugPrint('App launch ad failed to load.');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<SettingsProvider, ThemeMode>((s) => s.themeMode);
    return MaterialApp(
      navigatorKey: navigatorKey,
      // App-wide draggable message bubble (hidden in game / puzzle / spectator).
      builder: (context, child) {
        final user = context.watch<UserProvider>().user;
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            if (user != null && !user.isGuest)
              Positioned.fill(child: FloatingMessageButton(user: user)),
          ],
        );
      },
      title: 'Chess Master',
      themeMode: themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20),
          brightness: Brightness.light,
        ),
        // Custom theme adjustments
        appBarTheme: AppBarTheme(centerTitle: isIOS, elevation: 0, scrolledUnderElevation: 0),
        // iOS: no Material ripple, floating rounded snack bars.
        splashFactory: isIOS ? NoSplash.splashFactory : null,
        snackBarTheme: isIOS
            ? SnackBarThemeData(
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              )
            : null,

        // Shared look: rounded pop-ups and pill buttons everywhere (AlertDialog, ElevatedButton...).
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isIOS ? 14 : 24)),
          elevation: isIOS ? 0 : 12,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isIOS ? 10 : 14)),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            elevation: isIOS ? 0 : null,
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isIOS ? 10 : 14)),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isIOS ? 10 : 14)),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          elevation: 8,
          backgroundColor: Colors.white,
          shadowColor: Colors.black.withValues(alpha: 0.1),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20),
          brightness: Brightness.dark,
        ),
        appBarTheme: AppBarTheme(centerTitle: isIOS, elevation: 0, scrolledUnderElevation: 0),
        // iOS: no Material ripple, floating rounded snack bars.
        splashFactory: isIOS ? NoSplash.splashFactory : null,
        snackBarTheme: isIOS
            ? SnackBarThemeData(
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              )
            : null,

        // Shared look: rounded pop-ups and pill buttons everywhere (AlertDialog, ElevatedButton...).
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isIOS ? 14 : 24)),
          elevation: isIOS ? 0 : 12,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isIOS ? 10 : 14)),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            elevation: isIOS ? 0 : null,
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isIOS ? 10 : 14)),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isIOS ? 10 : 14)),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      home: Consumer<ConnectivityProvider>(
        builder: (context, connectivity, child) {
          if (connectivity.isOnline) {
            // Session bootstrap: try to restore a saved JWT session first
            // (replaces FirebaseAuth.instance.authStateChanges() + the old
            // Firestore user-doc lookup). If there's no valid session,
            // fall back to an automatic guest login, same as before.
            return FutureBuilder<ChessUser?>(
              future: AuthService().restoreSession(),
              builder: (context, sessionSnapshot) {
                if (sessionSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator.adaptive()),
                  );
                }

                void applyUser(ChessUser resolvedUser) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) {
                      Provider.of<UserProvider>(
                        context,
                        listen: false,
                      ).setUser(resolvedUser);

                      Provider.of<PremiumProvider>(
                        context,
                        listen: false,
                      ).init(resolvedUser);

                      if (!resolvedUser.isGuest) {
                        UserService().cleanupOnlineStatus(resolvedUser.uid!);
                      }

                      _showAppLaunchAd(resolvedUser);
                    }
                  });
                }

                if (sessionSnapshot.hasData && sessionSnapshot.data != null) {
                  final restoredUser = sessionSnapshot.data!;
                  applyUser(restoredUser);
                  return _buildHomeScreen(restoredUser);
                }

                // No valid saved session — automatically continue as guest,
                // same behavior as the old "no authenticated user" branch.
                return AgeGate(
                  builder: (_) => FutureBuilder<ChessUser>(
                  future: AuthService().signInAnonymously(),
                  builder: (context, guestSnapshot) {
                    if (guestSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator.adaptive()),
                      );
                    }

                    if (guestSnapshot.hasData) {
                      final guestUser = guestSnapshot.data!;
                      applyUser(guestUser);
                      return _buildHomeScreen(guestUser);
                    }

                    return const LoginScreen();
                  },
                  ),
                );
              },
            );
          } else {
            return FutureBuilder<ChessUser?>(
              future: _offlineService.getCachedUser(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator.adaptive()),
                  );
                }

                if (snapshot.hasData) {
                  final chessUser = snapshot.data!;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) {
                      Provider.of<UserProvider>(
                        context,
                        listen: false,
                      ).setUser(chessUser);

                      // Initialize PremiumProvider
                      Provider.of<PremiumProvider>(
                        context,
                        listen: false,
                      ).init(chessUser);
                    }
                  });
                  return _buildHomeScreen(chessUser);
                } else {
                  // No cached user, create a default guest user
                  final guestUser = ChessUser.guest();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) {
                      Provider.of<UserProvider>(
                        context,
                        listen: false,
                      ).setUser(guestUser);

                      // Initialize PremiumProvider
                      Provider.of<PremiumProvider>(
                        context,
                        listen: false,
                      ).init(guestUser);
                    }
                  });
                  return _buildHomeScreen(guestUser);
                }
              },
            );
          }
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
