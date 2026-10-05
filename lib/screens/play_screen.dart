import 'dart:async';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/providers/game_provider.dart';
import 'package:flutter_chess_app/providers/settings_provider.dart';
import 'package:flutter_chess_app/providers/user_provider.dart';
import 'package:flutter_chess_app/screens/game_screen.dart';
import 'package:flutter_chess_app/widgets/monetization_ads_widget.dart'
    show MonetizationAdsWidget, MonetizationAdType;
import 'package:flutter_chess_app/utils/constants.dart';
import 'package:flutter_chess_app/widgets/animated_dialog.dart';
import 'package:flutter_chess_app/widgets/cpu_difficulty_dialog.dart';
import 'package:flutter_chess_app/widgets/loading_dialog.dart';
import 'package:flutter_chess_app/widgets/online_players_count_widget.dart';
import 'package:flutter_chess_app/services/admin_service.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../widgets/game_mode_card.dart';
import '../widgets/main_app_button.dart';
import '../widgets/play_option_tile.dart';

class PlayScreen extends StatefulWidget {
  final ChessUser user;
  final bool isVisible;

  const PlayScreen({super.key, required this.user, this.isVisible = false});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen>
    with AutomaticKeepAliveClientMixin {
  int _selectedGameMode = 0;
  final CarouselSliderController _carouselController =
      CarouselSliderController();
  bool _isInitializing = true;
  DateTime? _gameSearchStartTime;
  List<Map<String, dynamic>> _enabledGameModes = [];
  final AdminService _adminService = AdminService();
  Map<String, bool> _playFeatures = const {
    'onlineEnabled': true,
    'cpuEnabled': true,
    'localMultiplayerEnabled': true,
  };
  StreamSubscription<Map<String, bool>>? _playFeaturesSub;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    debugPrint('PlayScreen: initState called, isVisible: ${widget.isVisible}');
    debugPrint("PlayScreen initialized");

    // Fetch enabled game modes and initialize
    _loadEnabledGameModes();

    // Live-updating show/hide for the Play Online / Computer / Local
    // Multiplayer buttons — updates immediately if an admin toggles one,
    // no app restart needed.
    _playFeaturesSub = _adminService.watchPlayFeatures().listen((features) {
      if (mounted) setState(() => _playFeatures = features);
    });
  }

  Future<void> _loadEnabledGameModes() async {
    try {
      final modes = await _adminService.getEnabledGameModes();
      if (mounted) {
        setState(() {
          _enabledGameModes = modes;
          print('✅ Game modes loaded: ${modes.length} modes enabled');
          // Display the modes for debugging
          for (var mode in modes) {
            print(
              '  - ${mode[Constants.title]} (${mode[Constants.timeControl]})',
            );
          }
          // Reset selected mode if it's out of bounds
          if (_selectedGameMode >= _enabledGameModes.length) {
            _selectedGameMode = 0;
          }
          _isInitializing = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading enabled game modes: $e');
      if (mounted) {
        setState(() {
          // Fallback to all modes if there's an error
          _enabledGameModes = Constants.gameModes;
          print(
            '⚠️  Using fallback: All ${Constants.gameModes.length} modes enabled',
          );
          _isInitializing = false;
        });
      }
    }
  }

  @override
  void didUpdateWidget(PlayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    debugPrint(
      'PlayScreen: didUpdateWidget - old: ${oldWidget.isVisible}, new: ${widget.isVisible}',
    );
  }

  @override
  void dispose() {
    debugPrint('PlayScreen: Disposing PlayScreen');
    _playFeaturesSub?.cancel();
    // Native ads are now handled by MonetizationBannerWidget
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final gameProvider = context.read<GameProvider>();
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 700;
    final isVerySmallScreen = screenHeight < 600;

    print('enabledGameModes: $_enabledGameModes');

    // Show a subtle loading state during initialization or if modes are empty
    if (_isInitializing || _enabledGameModes.isEmpty) {
      return const Scaffold(
        body: SafeArea(
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Calculate dynamic heights based on available space
            final availableHeight = constraints.maxHeight;
            final onlineCountHeight = 40.0;
            final carouselHeight = isVerySmallScreen
                ? 140.0
                : (isSmallScreen ? 160.0 : 180.0);

            // Calculate button area to fit within remaining space
            // LevelPlay native (small template) needs ~175dp; smaller screens
            // fall back to an adaptive banner inside the same slot.
            final adContainerHeight = isVerySmallScreen
                ? 92.0
                : (isSmallScreen ? 108.0 : 190.0);
            final adSpacing = isVerySmallScreen ? 8.0 : 12.0;

            // Reserve space for buttons - ensure it fits
            final reservedHeight =
                onlineCountHeight +
                carouselHeight +
                adContainerHeight +
                adSpacing;
            final remainingHeight = availableHeight - reservedHeight;
            final buttonAreaHeight = remainingHeight.clamp(
              isVerySmallScreen ? 150.0 : 160.0,
              isVerySmallScreen ? 160.0 : (isSmallScreen ? 180.0 : 210.0),
            );

            return Column(
              children: [
                // Online players count - Fixed height
                SizedBox(
                  height: onlineCountHeight,
                  child: OnlinePlayersCountWidget(
                    selectedGameMode: _enabledGameModes.isEmpty
                        ? null
                        : _enabledGameModes[_selectedGameMode][Constants
                              .timeControl],
                  ),
                ),

                // Game Modes Carousel - Dynamic height
                SizedBox(
                  height: carouselHeight,
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios),
                              onPressed: () =>
                                  _carouselController.previousPage(),
                              padding: EdgeInsets.all(
                                isVerySmallScreen ? 8 : 12,
                              ),
                              constraints: BoxConstraints(
                                minWidth: isVerySmallScreen ? 32 : 40,
                                minHeight: isVerySmallScreen ? 32 : 40,
                              ),
                            ),
                            Expanded(
                              child: CarouselSlider.builder(
                                carouselController: _carouselController,
                                options: CarouselOptions(
                                  height:
                                      carouselHeight -
                                      40, // Account for indicators
                                  viewportFraction: screenWidth < 400
                                      ? 0.85
                                      : 0.8,
                                  enlargeCenterPage: true,
                                  onPageChanged: (index, reason) {
                                    setState(() {
                                      _selectedGameMode = index;
                                    });
                                  },
                                ),
                                itemCount: _enabledGameModes.length,
                                itemBuilder: (context, index, realIndex) {
                                  final mode = _enabledGameModes[index];
                                  return SizedBox(
                                    width:
                                        MediaQuery.of(context).size.width *
                                        (screenWidth < 400 ? 0.85 : 0.8),
                                    child: GameModeCard(
                                      title: mode[Constants.title],
                                      timeControl: mode[Constants.timeControl],
                                      isSelected: _selectedGameMode == index,
                                      onTap: () {
                                        setState(() {
                                          _selectedGameMode = index;
                                        });
                                        _carouselController.animateToPage(
                                          index,
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_forward_ios),
                              onPressed: () => _carouselController.nextPage(),
                              padding: EdgeInsets.all(
                                isVerySmallScreen ? 8 : 12,
                              ),
                              constraints: BoxConstraints(
                                minWidth: isVerySmallScreen ? 32 : 40,
                                minHeight: isVerySmallScreen ? 32 : 40,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Carousel indicators
                      SizedBox(
                        height: 24,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: _enabledGameModes.asMap().entries.map((
                            entry,
                          ) {
                            return GestureDetector(
                              onTap: () =>
                                  _carouselController.animateToPage(entry.key),
                              child: Container(
                                width: isVerySmallScreen ? 6.0 : 8.0,
                                height: isVerySmallScreen ? 6.0 : 8.0,
                                margin: EdgeInsets.symmetric(
                                  vertical: 4.0,
                                  horizontal: isVerySmallScreen ? 2.0 : 3.0,
                                ),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      (Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white
                                              : Colors.black)
                                          .withValues(
                                            alpha:
                                                _selectedGameMode == entry.key
                                                ? 0.9
                                                : 0.4,
                                          ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),

                // Native Ad Container - Responsive height with padding
                SizedBox(
                  height: adContainerHeight,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isVerySmallScreen
                          ? 12
                          : (isSmallScreen ? 16 : 20),
                      vertical: 6,
                    ),
                    child: Center(
                      child: MonetizationAdsWidget(
                        user: widget.user,
                        adType: MonetizationAdType.native,
                      ),
                    ),
                  ),
                ),

                // Spacing below ad - Clear separation
                SizedBox(height: adSpacing),

                // Flexible space - Pushes buttons to bottom (can shrink to 0 if needed)
                const Spacer(),

                // Play buttons - Always at bottom
                Container(
                  height: buttonAreaHeight,
                  padding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: isVerySmallScreen ? 6 : 8,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_playFeatures['onlineEnabled'] == true) ...[
                      PlayOptionTile(
                        title: 'Play Online',
                        subtitle: 'Play with players around the world',
                        icon: Icons.public,
                        accentColor: const Color(0xFF22C55E),
                        onPressed: () async {
                          if (_enabledGameModes.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('No game modes available'),
                              ),
                            );
                            return;
                          }
                          final selectedMode =
                              _enabledGameModes[_selectedGameMode];
                          final timeControl =
                              selectedMode[Constants.timeControl];
                          final title = selectedMode[Constants.title];
                          final userProvider = context.read<UserProvider>();
                          final currentUser = userProvider.user;
                          final currentClassicalRating =
                              currentUser!.classicalRating;
                          final currentUserTempoRating =
                              currentUser.tempoRating;
                          final currentUserBlitzRating =
                              currentUser.blitzRating;

                          var userRating = currentClassicalRating;

                          // Get the user rating according to the selected game mode
                          if (title == Constants.blitz3) {
                            userRating = currentUserBlitzRating;
                          } else if (title == Constants.fast) {
                            userRating = currentUserTempoRating;
                          } else if (title == Constants.classical) {
                            userRating = currentClassicalRating;
                          }

                          // Track search start time for cancel button delay
                          _gameSearchStartTime = DateTime.now();

                          LoadingDialog.show(
                            context,
                            message: 'Searching for opponent...',
                            barrierDismissible: false,
                            showOnlineCount: true,
                            showCancelButton: true,
                            onCancel: () {
                              if (_gameSearchStartTime != null) {
                                final elapsed = DateTime.now().difference(
                                  _gameSearchStartTime!,
                                );
                                if (elapsed.inMilliseconds < 2000) {
                                  final remainingSeconds =
                                      (2000 - elapsed.inMilliseconds) ~/ 1000 +
                                      1;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Please wait $remainingSeconds seconds before canceling...',
                                      ),
                                      duration: const Duration(
                                        milliseconds: 800,
                                      ),
                                    ),
                                  );
                                  return;
                                }
                              }
                              gameProvider.cancelOnlineGameSearch();
                            },
                          );

                          try {
                            await gameProvider.startOnlineGameSearch(
                              userId: currentUser.uid!,
                              displayName: currentUser.displayName,
                              photoUrl: currentUser.photoUrl,
                              playerFlag: currentUser.countryCode ?? '',
                              userRating: userRating,
                              gameMode: timeControl,
                              ratingBasedSearch: context
                                  .read<SettingsProvider>()
                                  .ratingBasedSearch,
                              context: context,
                            );

                            if (context.mounted) {
                              // Check if search was cancelled
                              if (!gameProvider.isOnlineGame) {
                                // Search was cancelled, just hide dialog and return
                                LoadingDialog.hide(context);
                                _gameSearchStartTime = null;
                                return;
                              }

                              // Wait for game to become active before navigating
                              await gameProvider.waitForGameToStart();

                              gameProvider.setLoading(false);
                              _gameSearchStartTime = null; // Clear search timer

                              if (context.mounted) {
                                // Hide loading dialog
                                LoadingDialog.hide(context);
                                // Lets have a small delay to ensure UI is updated
                                await Future.delayed(
                                  const Duration(milliseconds: 500),
                                );
                                // Navigate to GameScreen after game is ready
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        GameScreen(user: widget.user),
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            gameProvider.setLoading(false);
                            _gameSearchStartTime = null; // Clear search timer
                            if (context.mounted) {
                              LoadingDialog.hide(context);
                              // ScaffoldMessenger.of(context).showSnackBar(
                              //   SnackBar(
                              //     content: Text('Failed to start online game: $e'),
                              //     backgroundColor: Colors.red,
                              //   ),
                              // );
                            }
                          }
                        },
                      ),
                      SizedBox(height: isVerySmallScreen ? 6 : 10),
                      ],

                      if (_playFeatures['cpuEnabled'] == true) ...[
                      PlayOptionTile(
                        title: 'Computer',
                        subtitle: 'Play against the computer',
                        icon: Icons.computer,
                        accentColor: const Color(0xFF14B8A6),
                        onPressed: () async {
                          if (_enabledGameModes.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('No game modes available'),
                              ),
                            );
                            return;
                          }
                          final selectedMode =
                              _enabledGameModes[_selectedGameMode];
                          final timeControl =
                              selectedMode[Constants.timeControl];

                          // Will show loading while initializing Stockfish
                          gameProvider.setLoading(true);
                          LoadingDialog.show(
                            context,
                            message: 'Initializing Stockfish engine...',
                            barrierDismissible: false,
                          );

                          try {
                            // Save game settings to provider
                            await gameProvider.setVsCPU(true);

                            // Initialize Stockfish before showing dialog
                            await gameProvider.initializeStockfish();

                            gameProvider.setLoading(false);

                            if (context.mounted) {
                              // Hide loading dialog
                              LoadingDialog.hide(context);

                              // Show CPU difficulty selection dialog
                              final result = await AnimatedDialog.show(
                                context: context,
                                title: 'Play With Computer',
                                maxWidth: 400,
                                child: CPUDifficultyDialog(
                                  onConfirm: (difficulty, playerColor) {
                                    gameProvider.setGameLevel(difficulty);
                                    gameProvider.setPlayer(playerColor);
                                    gameProvider.setTimeControl(timeControl);

                                    // Return the values instead of navigating here
                                    Navigator.of(context).pop({
                                      'difficulty': difficulty,
                                      'playerColor': playerColor,
                                    });
                                  },
                                ),
                              );

                              // Navigate after dialog is closed with result
                              if (result != null && result is Map) {
                                if (context.mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          GameScreen(user: widget.user),
                                    ),
                                  );
                                }
                              }
                            }
                          } catch (e) {
                            gameProvider.setLoading(false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Failed to initialize chess engine: $e',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                      ),
                      SizedBox(height: isVerySmallScreen ? 6 : 10),
                      ],

                      if (_playFeatures['localMultiplayerEnabled'] == true) ...[
                      PlayOptionTile(
                        title: 'Local Multiplayer',
                        subtitle: 'Play with friends nearby',
                        icon: Icons.people,
                        accentColor: const Color(0xFF3B82F6),
                        onPressed: () {
                          if (_enabledGameModes.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('No game modes available'),
                              ),
                            );
                            return;
                          }
                          final selectedMode =
                              _enabledGameModes[_selectedGameMode];
                          final timeControl =
                              selectedMode[Constants.timeControl];

                          gameProvider.setVsCPU(false); // Ensure vsCPU is false
                          gameProvider.setLocalMultiplayer(true);
                          gameProvider.setTimeControl(timeControl);

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  GameScreen(user: widget.user),
                            ),
                          );
                        },
                      ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
