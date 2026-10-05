import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/models/game_room_model.dart';
import 'package:flutter_chess_app/providers/game_provider.dart';
import 'package:flutter_chess_app/providers/connectivity_provider.dart';
import 'package:flutter_chess_app/providers/user_provider.dart';
import 'package:flutter_chess_app/providers/premium_provider.dart';
import 'package:flutter_chess_app/screens/admin_screen.dart';
import 'package:flutter_chess_app/screens/game_screen.dart';
import 'package:flutter_chess_app/screens/profile_screen.dart';
import 'package:flutter_chess_app/screens/ranking_screen.dart';
import 'package:flutter_chess_app/screens/saved_games_screen.dart';
import 'package:flutter_chess_app/screens/statistics_screen.dart';
import 'package:flutter_chess_app/services/user_service.dart';
import 'package:flutter_chess_app/services/game_socket_service.dart';
import 'package:flutter_chess_app/widgets/animated_dialog.dart';
import 'package:flutter_chess_app/widgets/loading_dialog.dart';
import 'package:flutter_chess_app/widgets/offline_indicator.dart';
import 'package:flutter_chess_app/widgets/profile_image_widget.dart';
import 'package:flutter_chess_app/widgets/unread_badge_widget.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import 'friends_screen.dart';
import 'options_screen.dart';
import 'play_screen.dart';
import 'puzzles_screen.dart';
import 'rules_info_screen.dart';
import 'package:flutter_chess_app/services/game_invite_service.dart';

class HomeScreen extends StatefulWidget {
  final ChessUser user;

  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedTab = 0;
  bool _isAdmin = false;
  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    // Set user online immediately when home screen loads
    _setUserOnline();
    _startHeartbeat();

    // Connect the shared game socket globally (not just when a game
    // starts) so chat/friend-request/game-invite push events work
    // anywhere in the app, not only during an active game.
    GameSocketService.instance.connect();

    // Initialize premium provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final premiumProvider = Provider.of<PremiumProvider>(
          context,
          listen: false,
        );
        premiumProvider.init(widget.user);
      }
    });

    _checkAdminStatus();
  }

  void _checkAdminStatus() async {
    if (widget.user.email != null) {
      final userService = UserService();
      final isAdmin = await userService.isAdmin(widget.user.email!);
      if (mounted) {
        setState(() {
          _isAdmin = isAdmin;
        });
      }
    }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    // Set user offline when home screen is disposed
    _setUserOffline();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Keep lastSeen fresh so server-side stale detection works correctly.
  // Fires every 5 minutes while the home screen is in the foreground.
  void _startHeartbeat() {
    if (widget.user.isGuest || widget.user.uid == null) return;
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      final userService = UserService();
      userService.updateUserStatusOnline(widget.user.uid!, true);
    });
  }

  // Set user online status
  void _setUserOnline() {
    if (!widget.user.isGuest && widget.user.uid != null) {
      final userService = UserService();
      userService.updateUserStatusOnline(widget.user.uid!, true);
    }
  }

  // Set user offline status
  void _setUserOffline() {
    if (!widget.user.isGuest && widget.user.uid != null) {
      final userService = UserService();
      userService.forceSetUserOffline(widget.user.uid!);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    final userService = UserService();

    switch (state) {
      case AppLifecycleState.resumed:
        log('App resumed');
        if (!widget.user.isGuest && widget.user.uid != null) {
          userService.updateUserStatusOnline(widget.user.uid!, true);
          _startHeartbeat();
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        log('App Hidden');
        _heartbeatTimer?.cancel();
        if (!widget.user.isGuest && widget.user.uid != null) {
          userService.forceSetUserOffline(widget.user.uid!);
        }
        break;
    }
  }

  Widget _buildInviteCard(BuildContext context, GameRoom invite) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProfileImageWidget(
                  imageUrl: invite.player1PhotoUrl,
                  radius: 20,
                  isEditable: false,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invite.player1DisplayName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Rating: ${invite.player1Rating}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Game Mode: ${invite.gameMode}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _declineInvite(context, invite),
                  child: const Text('Decline'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _acceptInvite(context, invite),
                  child: const Text('Accept'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _acceptInvite(BuildContext context, GameRoom invite) async {
    final gameProvider = context.read<GameProvider>();

    try {
      Navigator.of(context).pop(); // Close dialog

      // Show loading
      LoadingDialog.show(
        context,
        message: 'Joining game...',
        barrierDismissible: false,
      );

      // Set up the game
      // Real roomCode from the invite (backend's GameRoom.roomCode, mapped
      // to `spectatorLink` by GameRoom.fromSocketJson).
      bool isAvailable = await gameProvider.joinPrivateGameRoom(
        userId: widget.user.uid!,
        displayName: widget.user.displayName,
        photoUrl: widget.user.photoUrl,
        playerFlag: widget.user.countryCode ?? '',
        userRating: widget.user.classicalRating,
        gameMode: invite.gameMode,
        roomCode: invite.spectatorLink ?? invite.gameId,
      );

      if (context.mounted) {
        LoadingDialog.updateMessage(context, 'Game ready! Starting...');
      }

      if (isAvailable) {
        // Lets have a small delay to ensure UI is updated
        await Future.delayed(const Duration(milliseconds: 500));

        if (context.mounted) {
          LoadingDialog.hide(context);
          // Navigate to game
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GameScreen(user: widget.user),
            ),
          );
        }
      } else {
        if (context.mounted) {
          LoadingDialog.hide(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Game not found or is no longer available.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        LoadingDialog.hide(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join game: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _declineInvite(BuildContext context, GameRoom invite) async {
    try {
      Navigator.of(context).pop(); // Close dialog

      await GameInviteService().declineInvite(invite.gameId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invite declined'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to decline invite: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameInviteService = GameInviteService();
    final connectivityProvider = Provider.of<ConnectivityProvider>(context);
    final isOnline = connectivityProvider.isOnline;

    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        // Use the current user from the provider, fallback to widget.user if null
        final currentUser = userProvider.user ?? widget.user;

        return Scaffold(
          backgroundColor: const Color(0xFF0B0F0D),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0B0F0D),
            elevation: 0,
            title: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ProfileScreen(user: currentUser),
                      ),
                    );
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF22C55E),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF22C55E).withValues(alpha: 0.5),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: ProfileImageWidget(
                          imageUrl: currentUser.photoUrl,
                          radius: 24,
                          isEditable: false,
                          countryCode: currentUser.countryCode,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                        ),
                      ),
                      if (currentUser.removeAds == true)
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF0B0F0D),
                            ),
                            child: const Icon(
                              Icons.verified,
                              color: Color(0xFFFACC15),
                              size: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currentUser.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Color(0xFFFACC15), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Rating: ',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${currentUser.classicalRating}',
                          style: const TextStyle(
                            color: Color(0xFF22C55E),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              // Friends count pill
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people, color: Color(0xFF22C55E), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${currentUser.friends.length}',
                        style: const TextStyle(
                          color: Color(0xFF22C55E),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // check if is admin we show the admin icon
              // for admins to access the admob admin screen
              if (_isAdmin)
                IconButton(
                  icon: const Icon(Icons.admin_panel_settings, color: Colors.white),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => AdminScreen(user: currentUser),
                      ),
                    );
                  },
                ),

              // Game Invites Icon
              if (!currentUser.isGuest && isOnline)
                StreamBuilder<List<GameRoom>>(
                  stream: gameInviteService.streamGameInvites(currentUser.uid!),
                  builder: (context, snapshot) {
                    final invites = snapshot.data ?? [];
                    final hasInvites = invites.isNotEmpty;

                    if (!hasInvites) {
                      return const SizedBox();
                    }

                    return UnreadBadgeWidget(
                      count: invites.length,
                      child: GestureDetector(
                        onTap: () {
                          AnimatedDialog.show(
                            context: context,
                            title: 'Game Invites',
                            maxWidth: 400,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (invites.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(32.0),
                                    child: Text(
                                      'No pending invites',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  )
                                else
                                  ...invites.map(
                                    (invite) =>
                                        _buildInviteCard(context, invite),
                                  ),
                              ],
                            ),
                          );
                        },
                        child: Icon(Icons.mail_outline),
                      ),
                    );
                  },
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'rules') {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const RulesInfoScreen(),
                      ),
                    );
                  } else if (value == 'stats') {
                    if (!currentUser.isGuest) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              StatisticsScreen(user: currentUser),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('This feature requires an account.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  } else if (value == 'saved') {
                    if (!currentUser.isGuest) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              SavedGamesScreen(user: currentUser),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('This feature requires an account.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  } else if (value == 'ranking') {
                    if (!currentUser.isGuest) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const RankingScreen(),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('This feature requires an account.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'rules',
                    child: Text('Game Rules'),
                  ),
                  const PopupMenuItem(
                    value: 'stats',
                    child: Text('Statistics'),
                  ),
                  const PopupMenuItem(
                    value: 'saved',
                    child: Text('Saved Games'),
                  ),
                  PopupMenuItem(
                    value: 'ranking',
                    enabled: isOnline,
                    child: const Text('Rankings'),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              if (!isOnline) const OfflineIndicator(),
              Expanded(
                child: IndexedStack(
                  index: _selectedTab,
                  children: [
                    PlayScreen(user: currentUser, isVisible: _selectedTab == 0),
                    const PuzzlesScreen(),
                    FriendsScreen(
                      user: currentUser,
                      isVisible: _selectedTab == 2,
                    ),
                    OptionsScreen(user: currentUser),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            backgroundColor: const Color(0xFF0B0F0D),
            indicatorColor: const Color(0xFF22C55E).withValues(alpha: 0.2),
            selectedIndex: _selectedTab,
            onDestinationSelected: (index) {
              if (!isOnline && index == 2) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Friends tab is disabled while you are offline.',
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              setState(() {
                _selectedTab = index;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.sports_esports),
                label: 'Play',
              ),
              NavigationDestination(
                icon: Icon(Icons.extension),
                label: 'Puzzles',
              ),
              NavigationDestination(icon: Icon(Icons.people), label: 'Friends'),
              NavigationDestination(
                icon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        );
      },
    );
  }
}
