import 'dart:async';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chess_app/models/chat_message_model.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/providers/game_provider.dart';
import 'package:flutter_chess_app/screens/game_screen.dart';
import 'package:flutter_chess_app/screens/spectator_screen.dart';
import 'package:flutter_chess_app/services/admin_service.dart';
import 'package:flutter_chess_app/services/chat_service.dart';
import 'package:flutter_chess_app/services/friend_service.dart';
import 'package:flutter_chess_app/services/game_invite_service.dart';
import 'package:flutter_chess_app/services/game_socket_service.dart';
import 'package:flutter_chess_app/widgets/loading_dialog.dart';
import 'package:flutter_chess_app/widgets/profile_image_widget.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Big "sticker" messages. The server only accepts these ids.
class ChatStickers {
  static const Map<String, ({String glyph, String label})> all = {
    'checkmate': (glyph: '\u{265A}', label: 'Checkmate!'),
    'gg': (glyph: '\u{1F91D}', label: 'GG'),
    'knight': (glyph: '\u{265E}', label: 'Knight'),
    'queen': (glyph: '\u{265B}', label: 'Queen'),
    'king': (glyph: '\u{1F451}', label: 'King'),
    'rook': (glyph: '\u{265C}', label: 'Rook'),
    'bishop': (glyph: '\u{265D}', label: 'Bishop'),
    'pawn': (glyph: '\u{265F}\u{FE0F}', label: 'Pawn'),
    'thinking': (glyph: '\u{1F914}', label: 'Hmm...'),
    'wow': (glyph: '\u{1F62E}', label: 'Wow!'),
    'rematch': (glyph: '\u{1F501}', label: 'Rematch?'),
    'oops': (glyph: '\u{1F605}', label: 'Oops'),
  };
}

/// Reactions the server accepts.
const List<String> kChatReactions = [
  '\u{1F44D}',
  '\u{2764}\u{FE0F}',
  '\u{1F602}',
  '\u{1F62E}',
  '\u{1F622}',
  '\u{1F525}',
];

class ChatScreen extends StatefulWidget {
  final ChessUser currentUser;
  final ChessUser otherUser;

  /// Show the "invite to a game" action. Turn off where it makes no sense
  /// (e.g. the chat that is opened from inside a running game).
  final bool showInvite;

  const ChatScreen({
    super.key,
    required this.currentUser,
    required this.otherUser,
    this.showInvite = true,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late final String _chatRoomId;

  bool _sending = false;
  bool _showEmoji = false;
  ChatMessage? _replyTo;

  // typing indicator
  bool _otherTyping = false;
  Timer? _otherTypingTimer;
  StreamSubscription<Map<String, dynamic>>? _typingSub;
  DateTime _lastTypingSent = DateTime.fromMillisecondsSinceEpoch(0);
  bool _iSentTyping = false;

  /// One-tap messages. Edit this list to change the suggestions.
  static const List<String> _quickReplies = [
    'Hi \u{1F44B}',
    'Good game! \u{1F91D}',
    'Nice move! \u{1F44F}',
    'Rematch? \u{265F}\u{FE0F}',
    'Ready to play?',
    'Wait a minute \u{23F3}',
    'Your turn!',
    'Thanks! \u{1F64F}',
    'Well played \u{1F525}',
    'Oops, my mistake \u{1F605}',
    'Good luck! \u{1F340}',
    'Call me \u{1F4DE}',
    'Where are you from?',
    'How old are you?',
    'What is your rating?',
    'What is your favorite opening?',
    'Do you want to play a game?',
    'How are you?',
    'What do you do?',
    'Nice to meet you \u{1F60A}',
  ];

  @override
  void initState() {
    super.initState();
    _chatRoomId = _chatService.getChatRoomId(
      widget.currentUser.uid!,
      widget.otherUser.uid!,
    );
    () async {
      final otherId = widget.otherUser.uid!;
      debugPrint('[chat/read] start otherId=$otherId');
      try {
        final result = await _chatService.markMessagesAsRead(_chatRoomId, otherId);
        debugPrint('[chat/read] response=$result');
      } catch (e, st) {
        debugPrint('[chat/read] FAILED: $e');
        debugPrintStack(stackTrace: st);
      }
    }();

    _messageController.addListener(_onTextChanged);
    _typingSub = GameSocketService.instance.onChatTyping.listen((e) {
      if (e['fromUserId'] != widget.otherUser.uid || !mounted) return;
      final typing = e['isTyping'] == true;
      _otherTypingTimer?.cancel();
      setState(() => _otherTyping = typing);
      if (typing) {
        // Safety net in case the "stopped typing" event is lost.
        _otherTypingTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) setState(() => _otherTyping = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _setTyping(false);
    _otherTypingTimer?.cancel();
    _typingSub?.cancel();
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- typing

  void _setTyping(bool typing) {
    final otherId = widget.otherUser.uid;
    if (otherId == null) return;
    if (!typing && !_iSentTyping) return;
    _iSentTyping = typing;
    _lastTypingSent = DateTime.now();
    GameSocketService.instance.sendTyping(otherId, typing);
  }

  void _onTextChanged() {
    if (_messageController.text.trim().isEmpty) {
      _setTyping(false);
    } else if (DateTime.now().difference(_lastTypingSent) >
        const Duration(milliseconds: 2500)) {
      _setTyping(true);
    }
  }

  // --------------------------------------------------------------- sending

  void _toggleEmoji() {
    if (_showEmoji) {
      setState(() => _showEmoji = false);
      _focusNode.requestFocus();
    } else {
      FocusScope.of(context).unfocus();
      setState(() => _showEmoji = true);
    }
  }

  /// Sends the typed text (and clears the field only after the server
  /// accepted it, so a failed send doesn't eat what the person typed).
  Future<void> _sendMessage() async {
    final ok = await _send(_messageController.text, withReply: true);
    if (ok && mounted) {
      _messageController.clear();
      _setTyping(false);
    }
  }

  /// One-tap suggestion: sent immediately, the typed draft is left untouched.
  Future<void> _sendQuick(String text) => _send(text);

  Future<void> _sendSticker(String id) => _send(id, sticker: true);

  Future<bool> _send(
    String raw, {
    bool sticker = false,
    bool withReply = false,
  }) async {
    final text = raw.trim();
    if (text.isEmpty || _sending) return false;

    setState(() => _sending = true);
    final message = ChatMessage(
      id: '', // backend generates the real ID
      senderId: widget.currentUser.uid!,
      text: text,
      timestamp: DateTime.now(),
      isRead: false,
    );

    try {
      await _chatService.sendMessage(
        _chatRoomId,
        message,
        sticker: sticker,
        replyToId: withReply && _replyTo != null && _replyTo!.id.isNotEmpty
            ? _replyTo!.id
            : null,
      );
      if (mounted && withReply) setState(() => _replyTo = null);
      return true;
    } catch (_) {
      _toast("Message couldn't be sent. Please try again.");
      return false;
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _toast(String text, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: color),
    );
  }

  // --------------------------------------------------- attach: stickers etc.

  void _showAttachSheet() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showInvite)
              ListTile(
                leading: const Icon(Icons.sports_esports),
                title: const Text('Invite to a game'),
                subtitle: const Text('Pick a game mode and send an invite'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickModeAndInvite();
                },
              ),
            ListTile(
              leading: const Icon(Icons.emoji_symbols),
              title: const Text('Stickers'),
              subtitle: const Text('Big chess stickers, one tap to send'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showStickerSheet();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showStickerSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: ChatStickers.all.entries.map((e) {
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _sendSticker(e.key);
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(e.value.glyph, style: const TextStyle(fontSize: 38)),
                    const SizedBox(height: 4),
                    Text(
                      e.value.label,
                      style: const TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------- game invite

  /// Shows the game modes the admin has switched ON and sends the invite for
  /// the one the person picks.
  Future<void> _pickModeAndInvite() async {
    final friendOk = await FriendService().isFriend(
      widget.currentUser.uid!,
      widget.otherUser.uid!,
    );
    if (!friendOk) {
      _toast('You can only invite a friend to a game.');
      return;
    }

    final modes = await AdminService().getEnabledGameModes();
    if (!mounted) return;
    if (modes.isEmpty) {
      _toast('No game modes are available right now.');
      return;
    }

    bool training = false;
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: StatefulBuilder(
          builder: (context, setLocal) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Invite ${widget.otherUser.displayName}',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
              SwitchListTile(
                title: const Text('Training mode'),
                subtitle: const Text(
                  'Engine move warnings for both of you. Unrated. Your friend agrees by joining.',
                ),
                value: training,
                onChanged: (v) => setLocal(() => training = v),
              ),
              for (final mode in modes)
                if (mode['timeControl'] != null)
                  ListTile(
                    leading: const Icon(Icons.timer_outlined),
                    title: Text('${mode['title'] ?? mode['mode']}'),
                    subtitle: Text('${mode['timeControl']}'),
                    onTap: () => Navigator.pop(sheetContext, mode),
                  ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    await _startInvite(picked['timeControl'] as String, trainingMode: training);
  }

  Future<void> _startInvite(String gameMode, {bool trainingMode = false}) async {
    final gameProvider = context.read<GameProvider>();
    final me = widget.currentUser;
    final friend = widget.otherUser;

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
        player1Id: me.uid!,
        player2Id: friend.uid!,
        player1DisplayName: me.displayName,
        player1PhotoUrl: me.photoUrl,
        playerFlag: me.countryCode ?? '',
        player1Rating: me.classicalRating,
        fromChat: true,
        trainingMode: trainingMode,
      );

      if (mounted) {
        LoadingDialog.updateMessage(
          context,
          'Waiting for ${friend.displayName} to join...',
          showCancelButton: true,
          onCancel: () => gameProvider.cancelOnlineGameSearch(isFriend: true),
        );
      }

      await gameProvider.waitForGameToStart();
      gameProvider.setLoading(false);
      if (mounted) LoadingDialog.hide(context);

      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GameScreen(user: me)),
        );
      }
    } catch (e) {
      gameProvider.setLoading(false);
      if (mounted) LoadingDialog.hide(context);
      _toast('Failed to start online game: $e', color: Colors.red);
    }
  }

  /// The other person tapped "Join" on an invite bubble.
  Future<void> _joinInvite(ChatMessage message) async {
    final gameProvider = context.read<GameProvider>();
    final me = widget.currentUser;
    try {
      final invites = await GameInviteService().fetchInvites();
      final matches = invites.where((i) => i.gameId == message.inviteGameId);
      if (matches.isEmpty) {
        _toast('This invite has expired or was cancelled.');
        return;
      }
      final invite = matches.first;
      if (!mounted) return;

      LoadingDialog.show(
        context,
        message: 'Joining game...',
        barrierDismissible: false,
      );
      final ok = await gameProvider.joinPrivateGameRoom(
        userId: me.uid!,
        displayName: me.displayName,
        photoUrl: me.photoUrl,
        playerFlag: me.countryCode ?? '',
        userRating: me.classicalRating,
        gameMode: invite.gameMode,
        roomCode: invite.spectatorLink ?? invite.gameId,
      );
      if (!mounted) return;
      LoadingDialog.hide(context);
      if (!ok) {
        _toast('Game not found or is no longer available.',
            color: Colors.orange);
        return;
      }
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GameScreen(user: me)),
        );
      }
    } catch (e) {
      if (mounted) LoadingDialog.hide(context);
      _toast('Failed to join game: $e', color: Colors.red);
    }
  }

  // ------------------------------------------- long-press: react/reply/etc.

  void _showMessageActions(ChatMessage m) {
    final myId = widget.currentUser.uid!;
    final isMe = m.senderId == myId;
    final myReaction = m.reactions[myId];
    FocusScope.of(context).unfocus();

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (m.id.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: kChatReactions.map((emoji) {
                    final selected = emoji == myReaction;
                    return InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _react(m, selected ? null : emoji);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected
                              ? Theme.of(sheetContext)
                                  .colorScheme
                                  .primaryContainer
                              : null,
                        ),
                        child: Text(emoji, style: const TextStyle(fontSize: 26)),
                      ),
                    );
                  }).toList(),
                ),
              ),
            if (!m.isInvite && !m.isWatch)
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  setState(() => _replyTo = m);
                  _focusNode.requestFocus();
                },
              ),
            if (!m.isSticker && !m.isInvite && !m.isWatch)
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Clipboard.setData(ClipboardData(text: m.text));
                  _toast('Copied');
                },
              ),
            if (isMe && m.id.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDelete(m);
                },
              ),
            if (!isMe && !m.isInvite && !m.isWatch && m.id.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Report this message'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showReportDialog(messageId: m.id);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _react(ChatMessage m, String? emoji) async {
    try {
      await _chatService.reactToMessage(m.id, emoji);
    } catch (_) {
      _toast("Couldn't add the reaction.");
    }
  }

  Future<void> _confirmDelete(ChatMessage m) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('It will be removed for both of you.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await _chatService.deleteMessage(m.id);
      if (_replyTo?.id == m.id && mounted) setState(() => _replyTo = null);
    } catch (_) {
      _toast("Couldn't delete the message.");
    }
  }

  // ---------------------------------------------------- report / block menu

  static const Map<String, String> _reportReasons = {
    'spam': 'Spam',
    'harassment': 'Harassment or bullying',
    'inappropriate': 'Inappropriate content',
    'scam': 'Scam or fraud',
    'other': 'Something else',
  };

  Future<void> _showReportDialog({String? messageId}) async {
    String reason = 'harassment';
    final detailsController = TextEditingController();
    final send = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('Report ${widget.otherUser.displayName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final e in _reportReasons.entries)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(e.value),
                    trailing: reason == e.key
                        ? Icon(Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary)
                        : const Icon(Icons.radio_button_unchecked),
                    onTap: () => setLocal(() => reason = e.key),
                  ),
                TextField(
                  controller: detailsController,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'More details (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Report'),
            ),
          ],
        ),
      ),
    );
    final details = detailsController.text.trim();
    detailsController.dispose();
    if (send != true) return;

    try {
      await _chatService.reportUser(
        chatRoomId: _chatRoomId,
        reason: reason,
        details: details,
        messageId: messageId,
      );
      _toast('Thanks, your report was sent.');
    } catch (_) {
      _toast("Couldn't send the report. Please try again.");
    }
  }

  Future<void> _confirmBlock() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Block ${widget.otherUser.displayName}?'),
        content: const Text(
          "You won't be able to message each other, and you'll stop being friends.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await FriendService().blockUser(
        currentUserId: widget.currentUser.uid!,
        userIdToBlock: widget.otherUser.uid!,
      );
      if (!mounted) return;
      _toast('${widget.otherUser.displayName} was blocked.');
      Navigator.of(context).maybePop();
    } catch (_) {
      _toast("Couldn't block this user. Please try again.");
    }
  }

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_showEmoji,
      onPopInvokedWithResult: (didPop, _) {
        // Back closes the emoji panel first.
        if (!didPop && _showEmoji) setState(() => _showEmoji = false);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              ProfileImageWidget(imageUrl: widget.otherUser.photoUrl, radius: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.otherUser.displayName,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_otherTyping)
                      Text(
                        'typing...',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'report') _showReportDialog();
                if (value == 'block') _confirmBlock();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'report', child: Text('Report user')),
                PopupMenuItem(value: 'block', child: Text('Block user')),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<ChatMessage>>(
                stream: _chatService.getMessages(_chatRoomId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator.adaptive());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No messages yet.'));
                  }
                  final messages = snapshot.data!;
                  return ListView.builder(
                    reverse: true,
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      // List is newest-first, so the "previous" message is index + 1.
                      final older =
                          index + 1 < messages.length ? messages[index + 1] : null;
                      final showDate = older == null ||
                          !_sameDay(older.timestamp, message.timestamp);
                      final isMe = message.senderId == widget.currentUser.uid;
                      return Column(
                        children: [
                          if (showDate) _DateDivider(date: message.timestamp),
                          _SwipeToReply(
                            enabled: !message.isInvite && !message.isWatch && message.id.isNotEmpty,
                            onReply: () {
                              setState(() => _replyTo = message);
                              _focusNode.requestFocus();
                            },
                            child: ChatBubble(
                              isMe: isMe,
                              message: message,
                              myId: widget.currentUser.uid!,
                              otherName: widget.otherUser.displayName,
                              onLongPress: () => _showMessageActions(message),
                              onJoinInvite: () => _joinInvite(message),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildQuickReplies() {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: _quickReplies.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final text = _quickReplies[i];
          return ActionChip(
            label: Text(text),
            labelStyle: TextStyle(color: cs.onSecondaryContainer, fontSize: 13),
            backgroundColor: cs.secondaryContainer.withValues(alpha: 0.6),
            side: BorderSide.none,
            shape: const StadiumBorder(),
            visualDensity: VisualDensity.compact,
            onPressed: _sending ? null : () => _sendQuick(text),
          );
        },
      ),
    );
  }

  Widget _buildReplyPreview() {
    final reply = _replyTo;
    if (reply == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final mine = reply.senderId == widget.currentUser.uid;
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: cs.primary, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mine ? 'You' : widget.otherUser.displayName,
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  reply.isSticker ? 'Sticker' : reply.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _replyTo = null),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildQuickReplies(),
          _buildReplyPreview(),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(
                            _showEmoji
                                ? Icons.keyboard_alt_outlined
                                : Icons.emoji_emotions_outlined,
                          ),
                          color: cs.onSurfaceVariant,
                          onPressed: _toggleEmoji,
                        ),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            focusNode: _focusNode,
                            minLines: 1,
                            maxLines: 5,
                            maxLength: 1000,
                            textCapitalization: TextCapitalization.sentences,
                            keyboardType: TextInputType.multiline,
                            onTap: () {
                              if (_showEmoji) setState(() => _showEmoji = false);
                            },
                            decoration: const InputDecoration(
                              hintText: 'Type a message...',
                              border: InputBorder.none,
                              counterText: '',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.attach_file),
                          color: cs.onSurfaceVariant,
                          onPressed: _showAttachSheet,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _messageController,
                  builder: (context, value, _) {
                    final canSend = value.text.trim().isNotEmpty && !_sending;
                    return AnimatedScale(
                      scale: canSend ? 1 : 0.9,
                      duration: const Duration(milliseconds: 150),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor:
                            canSend ? cs.primary : cs.surfaceContainerHighest,
                        child: IconButton(
                          icon: Icon(
                            Icons.send_rounded,
                            color: canSend ? cs.onPrimary : cs.outline,
                          ),
                          onPressed: canSend ? _sendMessage : null,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          if (_showEmoji)
            SizedBox(
              height: 280,
              child: EmojiPicker(
                textEditingController: _messageController,
                config: Config(
                  height: 280,
                  emojiViewConfig: EmojiViewConfig(
                    emojiSizeMax: 28,
                    backgroundColor: cs.surface,
                  ),
                  categoryViewConfig: CategoryViewConfig(
                    backgroundColor: cs.surface,
                    indicatorColor: cs.primary,
                    iconColorSelected: cs.primary,
                  ),
                  bottomActionBarConfig: BottomActionBarConfig(
                    backgroundColor: cs.surface,
                    buttonColor: cs.surface,
                    buttonIconColor: cs.onSurfaceVariant,
                  ),
                  searchViewConfig: SearchViewConfig(
                    backgroundColor: cs.surface,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Telegram-style: drag a message to the left and let go to reply to it.
class _SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  final bool enabled;

  const _SwipeToReply({
    required this.child,
    required this.onReply,
    this.enabled = true,
  });

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply> {
  static const double _trigger = 56;
  static const double _max = 80;
  double _dx = 0;
  bool _dragging = false;
  bool _reached = false;

  void _reset() {
    setState(() {
      _dx = 0;
      _dragging = false;
      _reached = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final cs = Theme.of(context).colorScheme;
    final progress = (-_dx / _trigger).clamp(0.0, 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (d) {
        setState(() {
          _dragging = true;
          _dx = (_dx + d.delta.dx).clamp(-_max, 0.0);
        });
        if (-_dx >= _trigger && !_reached) {
          _reached = true;
          HapticFeedback.lightImpact();
        }
      },
      onHorizontalDragEnd: (_) {
        if (_reached) widget.onReply();
        _reset();
      },
      onHorizontalDragCancel: _reset,
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          Positioned(
            right: 16,
            child: Opacity(
              opacity: progress,
              child: Transform.scale(
                scale: 0.6 + 0.4 * progress,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: cs.surfaceContainerHighest,
                  child: Icon(Icons.reply, size: 18, color: cs.primary),
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: _dragging ? Duration.zero : const Duration(milliseconds: 150),
            transform: Matrix4.translationValues(_dx, 0, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

/// "Today" / "Yesterday" / "12 Oct 2026" separator between days.
class _DateDivider extends StatelessWidget {
  final DateTime date;
  const _DateDivider({required this.date});

  String _label() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (date.year == now.year) return DateFormat('d MMM').format(date);
    return DateFormat('d MMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _label(),
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final bool isMe;
  final ChatMessage message;
  final String myId;
  final String otherName;
  final VoidCallback? onLongPress;
  final VoidCallback? onJoinInvite;

  const ChatBubble({
    super.key,
    required this.isMe,
    required this.message,
    this.myId = '',
    this.otherName = '',
    this.onLongPress,
    this.onJoinInvite,
  });

  Widget _meta(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          DateFormat('HH:mm').format(message.timestamp),
          style: TextStyle(fontSize: 10, color: cs.outline),
        ),
        if (isMe)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(
              message.isRead ? Icons.done_all : Icons.done,
              size: 14,
              color: message.isRead ? cs.primary : cs.outline,
            ),
          ),
      ],
    );
  }

  Widget _quote(BuildContext context, ChatReply reply) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: cs.primary, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reply.senderId == myId ? 'You' : otherName,
            style: TextStyle(
              color: cs.primary,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
          Text(
            reply.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _watchCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility, color: cs.primary),
            const SizedBox(width: 8),
            Text(
              isMe ? 'You invited a friend to watch' : 'Watch my game',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(message.inviteGameMode ?? '', style: const TextStyle(fontSize: 13)),
        if (!isMe && (message.inviteGameId ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FilledButton.icon(
              icon: const Icon(Icons.visibility),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SpectatorScreen(gameId: message.inviteGameId!),
                ),
              ),
              label: const Text('Watch live'),
            ),
          ),
      ],
    );
  }

  Widget _inviteCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sports_esports, color: cs.primary),
            const SizedBox(width: 8),
            Text(
              isMe ? 'You sent a game invite' : 'Game invite',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(message.inviteGameMode ?? '', style: const TextStyle(fontSize: 13)),
        if (!isMe && onJoinInvite != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FilledButton(
              onPressed: onJoinInvite,
              child: const Text('Join game'),
            ),
          ),
      ],
    );
  }

  Widget _content(BuildContext context) {
    if (message.isSticker) {
      final sticker = ChatStickers.all[message.text];
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(sticker?.glyph ?? '\u{2753}', style: const TextStyle(fontSize: 64)),
          if (sticker != null)
            Text(sticker.label, style: const TextStyle(fontSize: 12)),
        ],
      );
    }
    if (message.isInvite) return _inviteCard(context);
    if (message.isWatch) return _watchCard(context);
    return Text(message.text);
  }

  Widget _reactions(BuildContext context) {
    final counts = <String, int>{};
    for (final e in message.reactions.values) {
      counts[e] = (counts[e] ?? 0) + 1;
    }
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(
        counts.entries
            .map((e) => e.value > 1 ? '${e.key}${e.value}' : e.key)
            .join(' '),
        style: const TextStyle(fontSize: 13),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final plain = message.isSticker; // stickers have no bubble background
    final maxWidth = MediaQuery.of(context).size.width * 0.78;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: plain
                    ? const EdgeInsets.symmetric(horizontal: 4)
                    : const EdgeInsets.fromLTRB(12, 8, 12, 6),
                decoration: plain
                    ? null
                    : BoxDecoration(
                        color: isMe
                            ? cs.primaryContainer
                            : cs.secondaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.replyTo != null)
                      _quote(context, message.replyTo!),
                    _content(context),
                    const SizedBox(height: 2),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _meta(context),
                    ),
                  ],
                ),
              ),
              if (message.reactions.isNotEmpty)
                Transform.translate(
                  offset: const Offset(0, -6),
                  child: _reactions(context),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
