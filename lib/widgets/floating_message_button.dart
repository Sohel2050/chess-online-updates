import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/models/app_message_model.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/screens/chat_screen.dart';
import 'package:flutter_chess_app/screens/messages_screen.dart';
import 'package:flutter_chess_app/services/api_client.dart';
import 'package:flutter_chess_app/services/chat_service.dart';
import 'package:flutter_chess_app/services/friend_service.dart';
import 'package:flutter_chess_app/services/game_socket_service.dart';
import 'package:flutter_chess_app/services/message_service.dart';
import 'package:flutter_chess_app/services/push_service.dart';

/// Screens where the bubble must not show (live game, puzzle board, spectator)
/// call hide() in initState and show() in dispose.
class FloatingMessageController {
  static final ValueNotifier<int> hiddenCount = ValueNotifier<int>(0);
  static void hide() => Future.microtask(() => hiddenCount.value++);
  static void show() => Future.microtask(() {
        if (hiddenCount.value > 0) hiddenCount.value--;
      });
}

/// Floating message bubble, shown on every screen except the ones above.
/// - Shows only while there is something unread (admin message or friend chat).
/// - Drag it anywhere; tap the small X to hide it. It comes back by itself
///   when a NEW unread message arrives.
/// - Tap it to see the unread admin messages and friend chats, and open them.
class FloatingMessageButton extends StatefulWidget {
  final ChessUser user;
  const FloatingMessageButton({super.key, required this.user});

  @override
  State<FloatingMessageButton> createState() => _FloatingMessageButtonState();
}

class _FloatingMessageButtonState extends State<FloatingMessageButton>
    with WidgetsBindingObserver {
  final MessageService _messages = MessageService();
  Timer? _poll;
  StreamSubscription<Map<String, dynamic>>? _chatSub;

  int _adminUnread = 0;
  int _chatUnread = 0;
  int _dismissedAt = 0; // total unread when the person pressed X
  Offset? _pos; // null = default spot (right side, above the nav bar)

  int get _total => _adminUnread + _chatUnread;
  bool get _visible => _total > 0 && _total > _dismissedAt;
  BuildContext? get _navContext => PushService.navigatorKey?.currentContext;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 20), (_) => _refresh());
    // A friend message arriving over the socket shows up immediately.
    _chatSub = GameSocketService.instance.onChatMessage.listen((_) => _refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _chatSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    if (widget.user.isGuest || widget.user.uid == null) return;
    try {
      final admin = await _messages.getUnreadCount();
      int chat = 0;
      try {
        final r = await ApiClient.instance.get('/chat/unread-count');
        chat = (r['count'] as num?)?.toInt() ?? 0;
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _adminUnread = admin;
        _chatUnread = chat;
        if (_total == 0) _dismissedAt = 0; // all read: next message shows again
      });
    } catch (_) {/* keep the old numbers */}
  }

  Future<void> _openSheet() async {
    final ctx = _navContext;
    if (ctx == null) return;
    await showModalBottomSheet(
      context: ctx,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _UnreadSheet(user: widget.user),
    );
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: FloatingMessageController.hiddenCount,
      builder: (context, hidden, _) =>
          (hidden > 0 || !_visible) ? const SizedBox.shrink() : _bubble(),
    );
  }

  Widget _bubble() {
    return LayoutBuilder(builder: (context, c) {
      const size = 56.0;
      final pos = _pos ?? Offset(c.maxWidth - size - 16, c.maxHeight - size - 24);
      final dx = pos.dx.clamp(0.0, (c.maxWidth - size).clamp(0.0, double.infinity));
      final dy = pos.dy.clamp(0.0, (c.maxHeight - size).clamp(0.0, double.infinity));
      return Stack(children: [
        Positioned(
          left: dx,
          top: dy,
          child: GestureDetector(
            onPanUpdate: (d) => setState(() => _pos = Offset(dx, dy) + d.delta),
            child: SizedBox(
              width: size + 12,
              height: size + 12,
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: Badge(
                    label: Text(_total > 99 ? '99+' : '$_total'),
                    child: Material(
                      color: const Color(0xFF22C55E),
                      shape: const CircleBorder(),
                      elevation: 6,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _openSheet,
                        child: const SizedBox(
                          width: size,
                          height: size,
                          child: Icon(Icons.chat_bubble, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: GestureDetector(
                    onTap: () => setState(() => _dismissedAt = _total),
                    child: const CircleAvatar(
                      radius: 11,
                      backgroundColor: Colors.black87,
                      child: Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]);
    });
  }
}

/// Bottom sheet: unread admin messages + friends who wrote to you.
class _UnreadSheet extends StatefulWidget {
  final ChessUser user;
  const _UnreadSheet({required this.user});

  @override
  State<_UnreadSheet> createState() => _UnreadSheetState();
}

class _UnreadSheetState extends State<_UnreadSheet> {
  final MessageService _messages = MessageService();
  final ChatService _chat = ChatService();
  List<AppMessage> _admin = [];
  final List<({ChessUser friend, int unread})> _friends = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final page = await _messages.getMessages();
      _admin = page.messages.where((m) => !m.isRead).toList();
    } catch (_) {}
    try {
      final friends = await FriendService().getFriends(widget.user.uid!).first;
      final found = <({ChessUser friend, int unread})>[];
      await Future.wait(friends.map((f) async {
        try {
          final r = await ApiClient.instance.get('/chat/${f.uid}/unread-count');
          final n = (r['count'] as num?)?.toInt() ?? 0;
          if (n > 0) found.add((friend: f, unread: n));
        } catch (_) {}
      }));
      _friends
        ..clear()
        ..addAll(found);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openAdmin(AppMessage m) async {
    unawaited(_messages.trackClick(m.id));
    final nav = Navigator.of(context); // grab it before the sheet closes
    nav.pop();
    await nav.push(MaterialPageRoute(
      builder: (_) => MessageDetailScreen(messageId: m.id, title: m.title),
    ));
  }

  Future<void> _openChat(ChessUser friend) async {
    final nav = Navigator.of(context); // grab it before the sheet closes
    nav.pop();
    await nav.push(MaterialPageRoute(
      builder: (_) => ChatScreen(currentUser: widget.user, otherUser: friend),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator.adaptive()),
              )
            : (_admin.isEmpty && _friends.isEmpty)
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No new messages')),
                  )
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final m in _admin)
                        ListTile(
                          leading: const Icon(Icons.campaign, color: Color(0xFF22C55E)),
                          title: Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(m.preview, maxLines: 2, overflow: TextOverflow.ellipsis),
                          onTap: () => _openAdmin(m),
                        ),
                      for (final f in _friends)
                        ListTile(
                          leading: const Icon(Icons.person),
                          title: Text(f.friend.displayName),
                          subtitle: Text('${f.unread} new message${f.unread > 1 ? 's' : ''}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openChat(f.friend),
                        ),
                    ],
                  ),
      ),
    );
  }
}
