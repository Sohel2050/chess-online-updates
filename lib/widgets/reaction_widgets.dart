import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/models/game_room_model.dart';
import 'package:flutter_chess_app/services/game_socket_service.dart';

/// Reaction key (sent to the server) -> emoji shown in the app.
const Map<String, String> kReactions = {
  'like': '👍',
  'love': '❤️',
  'happy': '😊',
  'omg': '😳',
  'laugh': '😂',
  'clap': '👏',
  'sad': '😢',
  'fire': '🔥',
};

/// Emoji row + live per-player reaction counts for one game.
///
/// * Players: tap an emoji to send it to the opponent.
/// * Spectators ([isSpectator]): tap a player's count box to choose who gets the
///   reaction, then tap an emoji.
/// Everyone in the game sees each reaction pop up and the counts go up.
class GameReactionPanel extends StatefulWidget {
  final GameRoom room;
  final String myId;
  final bool isSpectator;

  const GameReactionPanel({
    super.key,
    required this.room,
    required this.myId,
    this.isSpectator = false,
  });

  @override
  State<GameReactionPanel> createState() => _GameReactionPanelState();
}

class _GameReactionPanelState extends State<GameReactionPanel> {
  final _socket = GameSocketService.instance;
  StreamSubscription<Map<String, dynamic>>? _sub;
  Timer? _bannerTimer;
  late Map<String, Map<String, int>> _counts;
  String? _target; // spectators: who receives my reactions (null until they pick a player)
  String? _bannerEmoji;
  String? _bannerText;
  int _bannerSeq = 0;
  DateTime _lastSend = DateTime.fromMillisecondsSinceEpoch(0);

  String get _p1 => widget.room.player1Id;
  String get _p2 => widget.room.player2Id ?? '';

  Set<String> get _muted => widget.room.reactionsMuted.toSet();
  String get _oppId => widget.room.player1Id == widget.myId ? _p2 : _p1;

  /// The spectator's chosen player, or null if none chosen yet or that player turned emoji off.
  String? get _effectiveTarget => (_target != null && !_muted.contains(_target)) ? _target : null;

  @override
  void initState() {
    super.initState();
    _counts = widget.room.reactionCounts;
    _sub = _socket.onReaction.listen(_onReaction);
  }

  @override
  void didUpdateWidget(covariant GameReactionPanel old) {
    super.didUpdateWidget(old);
    // A fresh room snapshot (e.g. after a reconnect) carries the latest totals.
    if (widget.room.gameId == old.room.gameId && widget.room.reactionCounts != old.room.reactionCounts) {
      _counts = widget.room.reactionCounts;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _bannerTimer?.cancel();
    super.dispose();
  }

  String _nameOf(String id) {
    if (id == widget.myId) return 'You';
    if (id == _p1) return widget.room.player1DisplayName;
    if (id == _p2) return widget.room.player2DisplayName ?? 'Opponent';
    return 'Someone';
  }

  void _onReaction(Map<String, dynamic> d) {
    if (d['gameId'] != widget.room.gameId || !mounted) return;
    final emoji = kReactions[d['emoji']];
    if (emoji == null) return;
    final from = d['fromUserId']?.toString() ?? '';
    final fromName = from == widget.myId ? 'You' : (d['fromName']?.toString() ?? _nameOf(from));
    final target = d['targetId']?.toString() ?? '';
    setState(() {
      _counts = GameRoom.parseReactionCounts(d['counts']);
      _bannerEmoji = emoji;
      _bannerText = '$fromName → ${_nameOf(target)}';
      _bannerSeq++;
    });
    _bannerTimer?.cancel();
    _bannerTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _bannerEmoji = null);
    });
  }

  void _send(String key) {
    final now = DateTime.now();
    if (now.difference(_lastSend) < const Duration(milliseconds: 700)) return; // server also rate-limits
    if (!widget.isSpectator && (_muted.contains(widget.myId) || _muted.contains(_oppId))) return;
    if (widget.isSpectator && _effectiveTarget == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tap a player first to choose who gets your emoji.'), duration: Duration(seconds: 2)),
      );
      return;
    }
    _lastSend = now;
    _socket.sendReaction(
      gameId: widget.room.gameId,
      emoji: key,
      targetId: widget.isSpectator ? _effectiveTarget : null,
    );
  }

  Widget _countBox(BuildContext context, String playerId) {
    final scheme = Theme.of(context).colorScheme;
    final counts = _counts[playerId] ?? const <String, int>{};
    final muted = _muted.contains(playerId);
    final selected = widget.isSpectator && !muted && _target == playerId;
    final shown = kReactions.entries.where((e) => (counts[e.key] ?? 0) > 0).toList();
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: widget.isSpectator && !muted ? () => setState(() => _target = playerId) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _nameOf(playerId),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              muted
                  ? const Text('Emoji off', style: TextStyle(fontSize: 12, color: Colors.grey))
                  : shown.isEmpty
                  ? const Text('–', style: TextStyle(fontSize: 13))
                  : Wrap(
                      spacing: 6,
                      children: [
                        for (final e in shown)
                          Text('${e.value}${counts[e.key]}', style: const TextStyle(fontSize: 13)),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myMuted = !widget.isSpectator && _muted.contains(widget.myId);
    final oppMuted = !widget.isSpectator && _muted.contains(_oppId);
    final target = _effectiveTarget;

    // I switched emoji OFF: show only a way to turn it back on.
    if (myMuted) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            const Icon(Icons.notifications_off_outlined, size: 18),
            const SizedBox(width: 6),
            const Expanded(child: Text('Emoji reactions are off')),
            TextButton(
              onPressed: () => _socket.setReactionsEnabled(widget.room.gameId, true),
              child: const Text('Turn on'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 34,
            child: Row(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
                    child: _bannerEmoji == null
                        ? const SizedBox.shrink(key: ValueKey('none'))
                        : Row(
                            key: ValueKey(_bannerSeq),
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_bannerEmoji!, style: const TextStyle(fontSize: 26)),
                              const SizedBox(width: 6),
                              Flexible(child: Text(_bannerText ?? '', maxLines: 1, overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                  ),
                ),
                if (!widget.isSpectator)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    iconSize: 20,
                    tooltip: 'Turn emoji off',
                    icon: const Icon(Icons.notifications_off_outlined),
                    onPressed: () => _socket.setReactionsEnabled(widget.room.gameId, false),
                  ),
              ],
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _countBox(context, _p1)),
              const SizedBox(width: 8),
              Expanded(child: _countBox(context, _p2)),
            ],
          ),
          if (widget.isSpectator)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                target == null
                    ? 'Tap a player above to choose who gets your emoji'
                    : 'Sending to: ${_nameOf(target)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: target == null ? Colors.orange : Theme.of(context).colorScheme.primary,
                ),
              ),
            )
          else if (oppMuted)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Your opponent turned emoji off', style: TextStyle(fontSize: 12, color: Colors.orange)),
            ),
          const SizedBox(height: 2),
          Opacity(
            opacity: oppMuted ? 0.35 : 1,
            child: Row(
              children: [
                for (final e in kReactions.entries)
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _send(e.key),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Center(child: Text(e.value, style: const TextStyle(fontSize: 23))),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "👁 3 watching" — updates live as people join or leave.
class WatchingCountBadge extends StatelessWidget {
  final String gameId;
  const WatchingCountBadge({super.key, required this.gameId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: GameSocketService.instance.onSpectatorCount.where((d) => d['gameId'] == gameId),
      builder: (context, snap) {
        final count = (snap.data?['count'] as num?)?.toInt() ?? 0;
        if (count <= 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('LIVE · 👁 $count', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        );
      },
    );
  }
}
