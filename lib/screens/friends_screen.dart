import 'package:flutter/material.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/providers/game_provider.dart';
import 'package:flutter_chess_app/screens/chat_screen.dart';
import 'package:flutter_chess_app/screens/game_screen.dart';
import 'package:flutter_chess_app/widgets/monetization_ads_widget.dart'
    show MonetizationAdsWidget, MonetizationAdType;
import 'package:flutter_chess_app/services/chat_service.dart';
import 'package:flutter_chess_app/services/friend_service.dart';
import 'package:flutter_chess_app/utils/constants.dart';
import 'package:flutter_chess_app/widgets/animated_dialog.dart';
import 'package:flutter_chess_app/widgets/guest_widget.dart';
import 'package:flutter_chess_app/widgets/loading_dialog.dart';
import 'package:flutter_chess_app/widgets/profile_image_widget.dart';
import 'package:flutter_chess_app/widgets/unread_badge_widget.dart';

import 'package:provider/provider.dart';

class FriendsScreen extends StatefulWidget {
  final ChessUser user;
  final int initialTabIndex;
  final bool isVisible;

  const FriendsScreen({
    super.key,
    required this.user,
    this.initialTabIndex = 0,
    this.isVisible = false,
  });

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  final FriendService _friendService = FriendService();
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  List<ChessUser> _searchResults = [];
  bool _isSearching = false;
  //BannerAd? _bannerAd;
  //bool _hasLoadedAd = false;

  @override
  bool get wantKeepAlive => true;

  // Native ads replaced with MonetizationBannerWidget

  @override
  void initState() {
    super.initState();
    print("FriendsScreen initialized");
    _tabController = TabController(
      initialIndex: widget.initialTabIndex,
      length: 4,
      vsync: this,
    );

    // Only load ad if screen is initially visible
    if (widget.isVisible) {
      // Native ads replaced with MonetizationBannerWidget
    }
  }

  @override
  void didUpdateWidget(FriendsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Load ad when screen becomes visible
    if (widget.isVisible && !oldWidget.isVisible) {
      // Native ads replaced with MonetizationBannerWidget
    }
    // Dispose ad when screen becomes invisible
    else if (!widget.isVisible && oldWidget.isVisible) {
      // Native ads replaced with MonetizationBannerWidget
    }
  }

  // void _createBannerAd() {
  //   // Don't load if ads shouldn't be shown
  //   if (!AdMobService.shouldShowAds(context, widget.user.removeAds)) {
  //     return;
  //   }

  //   final bannerAdId = AdMobService.getBannerAdUnitId(context);
  //   if (bannerAdId == null) {
  //     return;
  //   }

  //   // Dispose existing ad if any
  //   if (_bannerAd != null) {
  //     _bannerAd!.dispose();
  //     _bannerAd = null;
  //   }

  //   _bannerAd = BannerAd(
  //     adUnitId: bannerAdId,
  //     request: const AdRequest(),
  //     size: AdSize.banner,
  //     listener: BannerAdListener(
  //       onAdLoaded: (ad) {
  //         print('Banner ad loaded.');
  //         _hasLoadedAd = true;
  //       },
  //       onAdFailedToLoad: (ad, error) {
  //         ad.dispose();
  //         print('Banner ad failed to load: $error');
  //       },
  //       onAdOpened: (ad) => print('Banner ad opened.'),
  //       onAdClosed: (ad) {
  //         ad.dispose();
  //         print('Banner ad closed.');
  //       },
  //       onAdImpression: (ad) => print('Banner ad impression.'),
  //     ),
  //   )..load();
  // }

  // void _disposeBannerAd() {
  //   _bannerAd?.dispose();
  //   _bannerAd = null;
  //   _hasLoadedAd = false; // Reset flag so ad can load again
  // }

  // Native ads replaced with MonetizationBannerWidget

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    //_disposeBannerAd();
    // Native ads replaced with MonetizationBannerWidget
    super.dispose();
  }

  void _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    setState(() {
      _isSearching = true;
    });
    final results = await _friendService.searchUsers(query, widget.user.uid!);
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  // show firendRequest Dialog
  void showAcceptRequestDialog({required ChessUser friend}) async {
    await AnimatedDialog.show(
      context: context,
      title: 'Accept Friend Request',
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Decline'),
        ),

        ElevatedButton(
          onPressed: () {
            _friendService.acceptFriendRequest(
              currentUserId: widget.user.uid!,
              friendUserId: friend.uid!,
            );
            // pop the dialog
            Navigator.pop(context);
          },
          child: const Text('Accept'),
        ),
      ],
      child: Text(
        'Do you want to accept the friend request from ${friend.displayName}?',
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: 'Friends'),
            Tab(
              child: StreamBuilder<List<ChessUser>>(
                stream: widget.user.isGuest
                    ? Stream.value([])
                    : _friendService.getFriendRequests(widget.user.uid!),
                builder: (context, snapshot) {
                  final requestCount = snapshot.data?.length ?? 0;
                  return UnreadBadgeWidget(
                    count: requestCount,
                    child: Builder(
                      builder: (context) {
                        return Text(
                          'Requests',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            const Tab(text: 'Find Players'),
            const Tab(text: 'Blocked'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFriendsList(),
          _buildRequestsList(),
          _buildFindPlayersTab(),
          _buildBlockedUsersList(),
        ],
      ),
      bottomNavigationBar: Container(
        child: MonetizationAdsWidget(
          user: widget.user,
          adType: MonetizationAdType.banner,
        ),
      ),
    );
  }

  Widget _buildFriendsList() {
    if (widget.user.isGuest) {
      return GuestWidget(context: context);
    } else {
      return StreamBuilder<List<ChessUser>>(
        stream: _friendService.getFriends(widget.user.uid!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('You have no friends yet.'));
          }
          final friends = snapshot.data!;
          return ListView.builder(
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final friend = friends[index];
              return ListTile(
                leading: ProfileImageWidget(
                  imageUrl: friend.photoUrl,
                  radius: 20,
                ),
                title: Text(friend.displayName),
                subtitle: Text(friend.isOnline ? 'Online' : 'Offline'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.videogame_asset),
                      onPressed: () => _showInviteDialog(friend),
                    ),
                    StreamBuilder<int>(
                      stream: _chatService.getUnreadMessageCount(
                        _chatService.getChatRoomId(
                          widget.user.uid!,
                          friend.uid!,
                        ),
                        widget.user.uid!,
                      ),
                      builder: (context, snapshot) {
                        final unreadCount = snapshot.data ?? 0;
                        return UnreadBadgeWidget(
                          count: unreadCount,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(
                                    currentUser: widget.user,
                                    otherUser: friend,
                                  ),
                                ),
                              );
                            },
                            child: Icon(Icons.message),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => _showRemoveFriendDialog(friend),
                    ),
                    IconButton(
                      icon: const Icon(Icons.block),
                      onPressed: () => _showBlockUserDialog(friend),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    }
  }

  Widget _buildRequestsList() {
    if (widget.user.isGuest) {
      return GuestWidget(context: context);
    } else {
      return StreamBuilder<List<ChessUser>>(
        stream: _friendService.getFriendRequests(widget.user.uid!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No new friend requests.'));
          }
          final requests = snapshot.data!;
          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final requestUser = requests[index];
              return ListTile(
                leading: ProfileImageWidget(
                  imageUrl: requestUser.photoUrl,
                  radius: 20,
                ),
                title: Text(requestUser.displayName),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () async {
                        // show friend request dialog'
                        showAcceptRequestDialog(friend: requestUser);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () {
                        _friendService.declineFriendRequest(
                          currentUserId: widget.user.uid!,
                          friendUserId: requestUser.uid!,
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    }
  }

  Widget _buildFindPlayersTab() {
    if (widget.user.isGuest) {
      return GuestWidget(context: context);
    } else {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search for players',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _searchUsers('');
                        },
                      )
                    : null,
              ),
              onChanged: _searchUsers,
            ),
            const SizedBox(height: 10),
            if (_isSearching)
              const CircularProgressIndicator()
            else if (_searchResults.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];

                    return ListTile(
                      leading: ProfileImageWidget(
                        imageUrl: user.photoUrl,
                        radius: 20,
                      ),
                      title: Text(user.displayName),
                      trailing: IconButton(
                        icon: Icon(Icons.person_add),
                        onPressed: () {
                          showFriendRequestDialog(
                            currentUserId: widget.user.uid!,
                            friendUserId: user.uid!,
                            friendName: user.displayName,
                          );
                        },
                      ),
                    );
                  },
                ),
              )
            else if (_searchController.text.isNotEmpty)
              const Text('No users found.'),
          ],
        ),
      );
    }
  }

  void showFriendRequestDialog({
    required String currentUserId,
    required String friendUserId,
    required String friendName,
  }) async {
    await AnimatedDialog.show(
      context: context,
      title: 'Send Friend Request',
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),

          child: const Text('Cancel'),
        ),

        ElevatedButton(
          onPressed: () {
            _friendService.sendFriendRequest(
              currentUserId: widget.user.uid!,
              friendUserId: friendUserId,
            );
            // pop the dialog
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Send'),
        ),
      ],
      child: Text(
        'Send a friend request to $friendName',
        textAlign: TextAlign.center,
      ),
    );
  }

  void _showInviteDialog(ChessUser friend) async {
    await AnimatedDialog.show(
      context: context,
      title: 'Invite ${friend.displayName} to a game',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: Constants.gameModes.map((mode) {
          return ListTile(
            title: Text(mode['title'] as String),
            onTap: () {
              Navigator.of(context).pop();
              _createPrivateGame(friend, mode['timeControl'] as String);
            },
          );
        }).toList(),
      ),
    );
  }

  void _showRemoveFriendDialog(ChessUser friend) async {
    await AnimatedDialog.show(
      context: context,
      title: 'Remove ${friend.displayName}?',
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            _friendService.removeFriend(
              currentUserId: widget.user.uid!,
              friendUserId: friend.uid!,
            );
          },
          child: const Text('Remove'),
        ),
      ],
      child: Text(
        'Are you sure you want to remove ${friend.displayName} from your friends list?',
      ),
    );
  }

  void _showBlockUserDialog(ChessUser friend) async {
    await AnimatedDialog.show(
      context: context,
      title: 'Block ${friend.displayName}?',
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            _friendService.blockUser(
              currentUserId: widget.user.uid!,
              userIdToBlock: friend.uid!,
            );
          },
          child: const Text('Block'),
        ),
      ],
      child: Text(
        'Are you sure you want to block ${friend.displayName} from your friends list?',
      ),
    );
  }

  Widget _buildBlockedUsersList() {
    if (widget.user.isGuest) {
      return GuestWidget(context: context);
    } else {
      return StreamBuilder<List<ChessUser>>(
        stream: _friendService.getBlockedUsers(widget.user.uid!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('You have no blocked users.'));
          }
          final blockedUsers = snapshot.data!;
          return ListView.builder(
            itemCount: blockedUsers.length,
            itemBuilder: (context, index) {
              final blockedUser = blockedUsers[index];
              return ListTile(
                leading: ProfileImageWidget(
                  imageUrl: blockedUser.photoUrl,
                  radius: 20,
                ),
                title: Text(blockedUser.displayName),
                trailing: IconButton(
                  icon: const Icon(Icons.check_circle_outline),
                  onPressed: () => _showUnblockUserDialog(blockedUser),
                ),
              );
            },
          );
        },
      );
    }
  }

  void _showUnblockUserDialog(ChessUser blockedUser) async {
    await AnimatedDialog.show(
      context: context,
      title: 'Unblock ${blockedUser.displayName}?',
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            _friendService.unblockUser(
              currentUserId: widget.user.uid!,
              userIdToUnblock: blockedUser.uid!,
            );
          },
          child: const Text('Unblock'),
        ),
      ],
      child: Text(
        'Are you sure you want to unblock ${blockedUser.displayName}?',
      ),
    );
  }

  void _createPrivateGame(ChessUser friend, String gameMode) async {
    final gameProvider = context.read<GameProvider>();

    gameProvider.setLoading(true);
    LoadingDialog.show(
      context,
      message: 'Sending invite...',
      barrierDismissible: false,
      showCancelButton: true,
      onCancel: () => gameProvider.cancelOnlineGameSearch(isFriend: true),
    );
    try {
      await gameProvider.createPrivateGameRoom(
        gameMode: gameMode,
        player1Id: widget.user.uid!,
        player2Id: friend.uid!,
        player1DisplayName: widget.user.displayName,
        player1PhotoUrl: widget.user.photoUrl,
        playerFlag: widget.user.countryCode ?? '',
        player1Rating: widget.user.classicalRating,
      );

      if (mounted) {
        LoadingDialog.updateMessage(
          context,
          'Waiting for ${friend.displayName} to join...',
          showCancelButton: true,
          onCancel: () => gameProvider.cancelOnlineGameSearch(isFriend: true),
        );
      }

      // Wait for game to become active before navigating
      await gameProvider.waitForGameToStart();

      gameProvider.setLoading(false);

      if (mounted) {
        // Hide loading dialog
        LoadingDialog.hide(context);
      }

      // Lets have a small delay to ensure UI is updated
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        // Navigate to GameScreen after game is ready
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GameScreen(user: widget.user),
          ),
        );
      }
    } catch (e) {
      gameProvider.setLoading(false);
      if (mounted) {
        LoadingDialog.hide(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start online game: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
