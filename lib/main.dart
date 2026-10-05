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
import 'package:flutter_chess_app/services/monetization_service.dart';
import 'package:flutter_chess_app/services/consent_service.dart';
import 'package:flutter_chess_app/services/version_service.dart';
import 'package:flutter_chess_app/screens/home_screen.dart';
import 'package:flutter_chess_app/services/offline_service.dart';
import 'package:flutter_chess_app/services/user_service.dart';
import 'package:flutter_chess_app/services/auth_service.dart';
import 'package:flutter_chess_app/utils/constants.dart';
import 'package:flutter_chess_app/widgets/force_update_dialog.dart';
import 'package:get_it/get_it.dart';
import 'screens/login_screen.dart';
import 'package:provider/provider.dart';
import 'models/user_model.dart';

// Global navigator key for navigation management
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ConsentService.navigatorKey = navigatorKey;
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
      ],
      child: const MyApp(),
    ),
  );
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
            body: Center(child: CircularProgressIndicator()),
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
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Chess Master',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20),
          brightness: Brightness.light,
        ),
        // Custom theme adjustments
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
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
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
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
                    body: Center(child: CircularProgressIndicator()),
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
                return FutureBuilder<ChessUser>(
                  future: AuthService().signInAnonymously(),
                  builder: (context, guestSnapshot) {
                    if (guestSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (guestSnapshot.hasData) {
                      final guestUser = guestSnapshot.data!;
                      applyUser(guestUser);
                      return _buildHomeScreen(guestUser);
                    }

                    return const LoginScreen();
                  },
                );
              },
            );
          } else {
            return FutureBuilder<ChessUser?>(
              future: _offlineService.getCachedUser(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
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
