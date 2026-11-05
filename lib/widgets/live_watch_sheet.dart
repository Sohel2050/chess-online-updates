import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/models/game_room_model.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/services/friend_service.dart';
import 'package:flutter_chess_app/services/game_invite_service.dart';
import 'package:flutter_chess_app/services/game_socket_service.dart';
import 'package:flutter_chess_app/widgets/profile_image_widget.dart';
import 'package:flutter_chess_app/widgets/reaction_widgets.dart';

/// Opened from the TV icon in a running online game. Two switches:
///  * Public    - everyone in the app can watch and react.
///  * Friends   - only the friends picked below can watch and react (works with Public off).
/// Turning a switch off, or un-picking a friend, removes that viewer straight away.
class LiveWatchSheet extends StatefulWidget {
  final GameRoom room;
  final String myId;

  const LiveWatchSheet({super.key, required this.room, required this.myId});

  @override
  State<LiveWatchSheet> createState() => _LiveWatchSheetState();
}

class _LiveWatchSheetState extends State<LiveWatchSheet> {
  final _search = TextEditingController();
  final _invites = GameInviteService();
  Timer? _saveTimer;

  late bool _public = widget.room.publicWatch;
  late bool _friendsOn = widget.room.friendsWatch;
  late final Set<String> _picked = {...widget.room.spectatorInvitedIds};
  List<ChessUser> _friends = [];
  bool _loadingFriends = true;
  String _query = '';

  String? get _opponentId =>
      widget.room.player1Id == widget.myId ? widget.room.player2Id : widget.room.player1Id;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    List<ChessUser> list = [];
    try {
      list = await FriendService().getFriends(widget.myId).first;
    } catch (_) {}
    list = list.where((f) => f.uid != null && f.uid != _opponentId).toList()
      ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    if (!mounted) return;
    setState(() {
      _friends = list;
      _loadingFriends = false;
    });
  }

  void _setPublic(bool value) {
    setState(() => _public = value);
    GameSocketService().setPublicWatch(widget.room.gameId, value);
  }

  Future<void> _setFriendsOn(bool value) async {
    setState(() => _friendsOn = value);
    final ok = await _invites.setWatchFriends(widget.room.gameId, enabled: value, friendIds: _picked.toList());
    if (!ok && mounted) _failed();
  }

  /// Saves the picked list shortly after the last tap (one request, not one per tap).
  void _savePickedSoon() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () async {
      final ok = await _invites.setWatchFriends(widget.room.gameId, friendIds: _picked.toList());
      if (!ok && mounted) _failed();
    });
  }

  void _failed() => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save. Check your connection and try again.')),
      );

  List<ChessUser> get _visible {
    final q = _query.trim().toLowerCase();
    return q.isEmpty ? _friends : _friends.where((f) => f.displayName.toLowerCase().contains(q)).toList();
  }

  void _selectAllVisible(bool select) {
    setState(() {
      for (final f in _visible) {
        select ? _picked.add(f.uid!) : _picked.remove(f.uid!);
      }
    });
    _savePickedSoon();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                secondary: Icon(Icons.public, color: _public ? Colors.red : null),
                title: const Text('Public'),
                subtitle: Text(_public
                    ? 'ON: everyone in the app can watch and send reactions.'
                    : 'OFF: not open to everyone.'),
                value: _public,
                onChanged: _setPublic,
              ),
              SwitchListTile(
                secondary: Icon(Icons.people, color: _friendsOn ? Colors.red : null),
                title: const Text('Friends'),
                subtitle: Text(_friendsOn
                    ? 'ON: the friends you pick below can watch and send reactions.'
                    : 'OFF: no friend can watch (unless Public is ON).'),
                value: _friendsOn,
                onChanged: _setFriendsOn,
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: WatchingCountBadge(gameId: widget.room.gameId),
              ),
              if (_friendsOn) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Search friends',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() {
                                _search.clear();
                                _query = '';
                              }),
                            ),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text('${_picked.length} selected', style: Theme.of(context).textTheme.bodySmall),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: visible.isEmpty ? null : () => _selectAllVisible(true),
                        child: Text(_query.isEmpty ? 'Select all' : 'Select shown'),
                      ),
                      TextButton(
                        onPressed: visible.isEmpty ? null : () => _selectAllVisible(false),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: _loadingFriends
                      ? const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator.adaptive())
                      : visible.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(_friends.isEmpty ? 'No friends yet. Add friends first.' : 'No friend matches your search.'),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: visible.length,
                              itemBuilder: (context, i) {
                                final f = visible[i];
                                final on = _picked.contains(f.uid);
                                return CheckboxListTile(
                                  value: on,
                                  secondary: ProfileImageWidget(imageUrl: f.photoUrl, radius: 18),
                                  title: Text(f.displayName),
                                  subtitle: Text('Rating: ${f.classicalRating}'),
                                  onChanged: (v) {
                                    setState(() => v == true ? _picked.add(f.uid!) : _picked.remove(f.uid!));
                                    _savePickedSoon();
                                  },
                                );
                              },
                            ),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
