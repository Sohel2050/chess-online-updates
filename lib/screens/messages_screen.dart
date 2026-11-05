import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_message_model.dart';
import '../services/message_service.dart';

final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');

/// Settings -> Messages: the list of messages sent by the admin.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final MessageService _service = MessageService();
  final ScrollController _scroll = ScrollController();
  List<AppMessage> _messages = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _cursor;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 300) _loadMore();
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) setState(() => _loading = true);
    try {
      final page = await _service.getMessages();
      if (!mounted) return;
      setState(() {
        _messages = page.messages;
        _hasMore = page.hasMore;
        _cursor = page.nextCursor;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load messages. Check your connection and try again.';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _cursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _service.getMessages(before: _cursor);
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, ...page.messages];
        _hasMore = page.hasMore;
        _cursor = page.nextCursor;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false); // next scroll will retry
    }
  }

  Future<void> _open(AppMessage message) async {
    // Tap in the list = "click". Fire and forget, it must never delay opening.
    unawaited(_service.trackClick(message.id));
    final wasRead = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MessageDetailScreen(messageId: message.id, title: message.title),
      ),
    );
    if (!mounted || wasRead != true) return;
    // Mark it read locally; reloading page 1 would throw away pages already scrolled in.
    setState(() {
      _messages = [
        for (final m in _messages)
          m.id == message.id
              ? AppMessage(
                  id: m.id,
                  title: m.title,
                  preview: m.preview,
                  body: m.body,
                  createdAt: m.createdAt,
                  isRead: true,
                  isClicked: true,
                )
              : m,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator.adaptive());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(showSpinner: false),
      child: _messages.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 160),
                Center(child: Text('No messages yet')),
              ],
            )
          : ListView.separated(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _messages.length + (_loadingMore ? 1 : 0),
              separatorBuilder: (_, _) => const Divider(height: 0),
              itemBuilder: (context, index) {
                if (index >= _messages.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator.adaptive()),
                  );
                }
                final m = _messages[index];
                return ListTile(
                  leading: Icon(
                    m.isRead ? Icons.drafts_outlined : Icons.mark_email_unread,
                    color: m.isRead ? Colors.grey : Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(
                    m.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: m.isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.preview, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(
                        _dateTimeFormat.format(m.createdAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: m.isRead
                      ? null
                      : Icon(Icons.circle, size: 10, color: Theme.of(context).colorScheme.primary),
                  onTap: () => _open(m),
                );
              },
            ),
    );
  }
}

/// Full text of one message. It counts as "read" once it has been on screen
/// for a couple of seconds (so an accidental tap-and-back isn't a read).
class MessageDetailScreen extends StatefulWidget {
  final String messageId;
  final String title;

  const MessageDetailScreen({super.key, required this.messageId, required this.title});

  @override
  State<MessageDetailScreen> createState() => _MessageDetailScreenState();
}

class _MessageDetailScreenState extends State<MessageDetailScreen> {
  final MessageService _service = MessageService();
  AppMessage? _message;
  String? _error;
  Timer? _readTimer;
  bool _readSent = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _readTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final message = await _service.getMessage(widget.messageId);
      if (!mounted) return;
      setState(() => _message = message);
      _readTimer = Timer(const Duration(seconds: 2), () {
        _readSent = true;
        _service.trackRead(widget.messageId);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load this message.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = _message;
    // Tell the list whether this message really counted as read.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_readSent);
      },
      child: _buildScaffold(message),
    );
  }

  Widget _buildScaffold(AppMessage? message) {
    return Scaffold(
      appBar: AppBar(title: const Text('Message')),
      body: _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          : message == null
          ? const Center(child: CircularProgressIndicator.adaptive())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _dateTimeFormat.format(message.createdAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Divider(height: 28),
                  SelectableText(message.body, style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            ),
    );
  }
}

/// "Messages" row for the Options screen, with an unread-count badge.
class MessagesListTile extends StatefulWidget {
  const MessagesListTile({super.key});

  @override
  State<MessagesListTile> createState() => _MessagesListTileState();
}

class _MessagesListTileState extends State<MessagesListTile> {
  final MessageService _service = MessageService();
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _loadUnread();
  }

  Future<void> _loadUnread() async {
    final count = await _service.getUnreadCount();
    if (mounted) setState(() => _unread = count);
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.mail_outline),
      title: const Text('Messages'),
      trailing: _unread > 0
          ? Badge(label: Text(_unread > 99 ? '99+' : '$_unread'))
          : null,
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MessagesScreen()),
        );
        if (mounted) _loadUnread();
      },
    );
  }
}
