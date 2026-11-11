import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_chess_app/services/api_client.dart';
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
  StreamSubscription<Map<String, dynamic>>? _answerSub;

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
    // Declined: the switches go back to off (the game screen shows the message).
    _answerSub = GameSocketService.instance.onLiveAnswer.listen((e) {
      if (!mounted || e['gameId']?.toString() != widget.room.gameId || e['accepted'] == true) return;
      setState(() {
        _public = false;
        _friendsOn = false;
      });
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _answerSub?.cancel();
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
    if (value && !widget.room.liveConsent) _askedNotice();
  }

  /// Live needs the opponent's agreement the first time: tell the user why it is not on yet.
  void _askedNotice() => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('Your opponent was asked. Live starts when they accept.')));

  Future<void> _setFriendsOn(bool value) async {
    setState(() => _friendsOn = value);
    final ok = await _invites.setWatchFriends(widget.room.gameId, enabled: value, friendIds: _picked.toList());
    if (!ok && mounted) {
      setState(() => _friendsOn = false);
      _failed();
    } else if (value && mounted && !widget.room.liveConsent) {
      _askedNotice();
    }
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

  /// Public watch link. Opens the app if it is installed, otherwise a web page
  /// (see LIVE_WEB_SERVER_SPEC.md). Only works while Public is ON.
  String get _liveUrl =>
      '${ApiClient.baseUrl}/live/${widget.room.spectatorLink ?? widget.room.gameId}';

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _liveUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Link copied')));
  }

  Future<void> _shareLink() async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: 'Watch my chess game live: $_liveUrl',
          subject: 'Watch my chess game live',
        ),
      );
    } catch (_) {
      _copyLink(); // the share sheet could not open: at least copy the link
    }
  }

  /// A rounded card with an icon, a title/subtitle and a switch. Text is
  /// allowed to wrap, so nothing overflows on a narrow screen.
  Widget _optionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: value ? Colors.red.withValues(alpha: 0.08) : cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: value ? Colors.red.withValues(alpha: 0.45) : cs.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: value ? Colors.red : cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: value ? Colors.white : cs.onSurfaceVariant, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _shareCard() {
    final cs = Theme.of(context).colorScheme;
    final enabled = _public;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.55,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [cs.primary.withValues(alpha: 0.14), cs.tertiary.withValues(alpha: 0.10)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.link_rounded, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Share watch link',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _liveUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: enabled ? _shareLink : null,
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Share', maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: enabled ? _copyLink : null,
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy', maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              enabled
                  ? 'Anyone with this link can watch in the app or on the web.'
                  : 'Turn Public ON to share the link.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _friendsSection() {
    final visible = _visible;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _search,
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.search),
            hintText: 'Search friends',
            filled: true,
            fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
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
        const SizedBox(height: 4),
        // Wrap (not Row): on a narrow screen the buttons drop to the next line.
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 8),
              child: Text('${_picked.length} selected', style: Theme.of(context).textTheme.bodySmall),
            ),
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
        if (_loadingFriends)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator.adaptive()))
        else if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                _friends.isEmpty ? 'No friends yet. Add friends first.' : 'No friend matches your search.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          for (final f in visible)
            CheckboxListTile(
              value: _picked.contains(f.uid),
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              controlAffinity: ListTileControlAffinity.trailing,
              secondary: ProfileImageWidget(imageUrl: f.photoUrl, radius: 18),
              title: Text(f.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('Rating: ${f.classicalRating}'),
              onChanged: (v) {
                setState(() => v == true ? _picked.add(f.uid!) : _picked.remove(f.uid!));
                _savePickedSoon();
              },
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header: LIVE pill + title + viewer count (never overflows: title is Expanded).
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFB91C1C)]),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 8, color: Colors.white),
                          SizedBox(width: 5),
                          Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Let others watch',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    WatchingCountBadge(gameId: widget.room.gameId),
                  ],
                ),
              ),
              // Everything below scrolls together, so a small screen or the
              // keyboard can never cause an overflow.
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  children: [
                    _optionCard(
                      icon: Icons.public,
                      title: 'Public',
                      subtitle: _public
                          ? 'ON: everyone can watch and send reactions.'
                          : 'OFF: not open to everyone.',
                      value: _public,
                      onChanged: _setPublic,
                    ),
                    _shareCard(),
                    _optionCard(
                      icon: Icons.people,
                      title: 'Friends',
                      subtitle: _friendsOn
                          ? 'ON: the friends you pick can watch and react.'
                          : 'OFF: no friend can watch (unless Public is ON).',
                      value: _friendsOn,
                      onChanged: _setFriendsOn,
                    ),
                    if (_friendsOn) _friendsSection(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
