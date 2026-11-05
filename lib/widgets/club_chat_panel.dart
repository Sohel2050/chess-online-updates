import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/services/api_client.dart';
import 'package:flutter_chess_app/services/club_service.dart';
import 'package:flutter_chess_app/services/game_socket_service.dart';
import 'package:flutter_chess_app/widgets/report_dialog.dart';

/// The chat tab of a club: newest messages at the bottom, "Earlier messages" at the top,
/// live updates from the socket, long-press a message to delete (rules by role) or report it.
class ClubChatPanel extends StatefulWidget {
  final String clubId;
  final String myId;
  final String? myRole; // owner | admin | member
  final DateTime? mutedUntil; // I am muted until then (reading still works)
  const ClubChatPanel({super.key, required this.clubId, required this.myId, required this.myRole, this.mutedUntil});

  @override
  State<ClubChatPanel> createState() => _ClubChatPanelState();
}

class _ClubChatPanelState extends State<ClubChatPanel> {
  final ClubService _service = ClubService();
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<ClubChatMessage> _messages = []; // oldest first
  StreamSubscription<Map<String, dynamic>>? _sub;
  bool _loading = true;
  bool _hasMore = false;
  bool _loadingMore = false;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sub = GameSocketService.instance.onClubEvent.listen(_onLive);
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _err(Object e) => e is ApiException ? e.message : 'Request failed. Check your connection.';
  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _load() async {
    try {
      final page = await _service.messages(widget.clubId);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(page.messages);
        _hasMore = page.hasMore;
        _loading = false;
        _error = null;
      });
      _jumpToEnd();
      unawaited(_service.markChatRead(widget.clubId));
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _err(e);
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _messages.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _service.messages(widget.clubId, before: _messages.first.id);
      if (!mounted) return;
      setState(() {
        _messages.insertAll(0, page.messages.where((m) => !_messages.any((x) => x.id == m.id)));
        _hasMore = page.hasMore;
      });
    } catch (e) {
      if (mounted) _toast(_err(e));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  /// The same message can arrive twice (my own send + the live push): ids are unique, so duplicates are ignored.
  void _onLive(Map<String, dynamic> e) {
    if (!mounted || e['clubId']?.toString() != widget.clubId) return;
    if (e['event'] == 'message' && e['message'] is Map) {
      final m = ClubChatMessage.fromJson(Map<String, dynamic>.from(e['message'] as Map));
      if (_messages.any((x) => x.id == m.id)) return;
      final atBottom = !_scroll.hasClients || _scroll.position.maxScrollExtent - _scroll.offset < 80;
      setState(() => _messages.add(m));
      if (atBottom || m.authorId == widget.myId) _jumpToEnd();
      // The chat is open, so a message from someone else is read at once.
      if (m.authorId != widget.myId) unawaited(_service.markChatRead(widget.clubId));
    } else if (e['event'] == 'deleted') {
      final id = e['id']?.toString();
      setState(() => _messages.removeWhere((m) => m.id == id));
    }
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final m = await _service.sendMessage(widget.clubId, text);
      _input.clear();
      if (mounted && !_messages.any((x) => x.id == m.id)) setState(() => _messages.add(m));
      _jumpToEnd();
    } catch (e) {
      if (mounted) _toast(_err(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // Same rule as the server (clubRules.canDeleteMessage): own message, owner any, admin only plain members' ones.
  bool _canDelete(ClubChatMessage m) {
    if (m.authorId == widget.myId) return true;
    if (widget.myRole == 'owner') return true;
    return widget.myRole == 'admin' && m.authorRole != 'owner' && m.authorRole != 'admin';
  }

  Future<void> _messageMenu(ClubChatMessage m) async {
    final canDelete = _canDelete(m);
    final canReport = m.authorId != widget.myId;
    if (!canDelete && !canReport) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (canDelete) ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Delete'), onTap: () => Navigator.pop(ctx, 'delete')),
          if (canReport) ListTile(leading: const Icon(Icons.flag_outlined), title: const Text('Report'), onTap: () => Navigator.pop(ctx, 'report')),
        ]),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'delete') {
      try {
        await _service.deleteMessage(widget.clubId, m.id);
        if (mounted) setState(() => _messages.removeWhere((x) => x.id == m.id));
      } catch (e) {
        if (mounted) _toast(_err(e));
      }
    } else {
      await showReportDialog(context, kind: 'club_message', targetId: m.id, title: 'Report this message');
    }
  }

  DateTime? get _muteEnd {
    final m = widget.mutedUntil;
    return m != null && m.isAfter(DateTime.now()) ? m.toLocal() : null;
  }

  String _time(DateTime? t) => t == null ? '' : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(children: [
      Expanded(
        child: _error != null
            ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(controller: _scroll, padding: const EdgeInsets.all(12), children: [
                  if (_hasMore)
                    TextButton(onPressed: _loadingMore ? null : _loadMore, child: Text(_loadingMore ? 'Loading...' : 'Earlier messages')),
                  if (_messages.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('No messages yet. Say hello!', textAlign: TextAlign.center)),
                  for (final m in _messages) _bubble(m),
                ]),
              ),
      ),
      if (_muteEnd != null)
        Container(
          width: double.infinity,
          color: Theme.of(context).colorScheme.errorContainer,
          padding: const EdgeInsets.all(8),
          child: Text('You are muted in this chat until ${_time(_muteEnd)}${_muteEnd!.difference(DateTime.now()).inHours >= 24 ? ' (${_muteEnd!.day}/${_muteEnd!.month})' : ''}.', textAlign: TextAlign.center),
        ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _input,
                enabled: _muteEnd == null,
                maxLength: 300,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Message the club', counterText: '', border: OutlineInputBorder(), isDense: true),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: _sending || _muteEnd != null ? null : _send, icon: const Icon(Icons.send)),
          ]),
        ),
      ),
    ]);
  }

  Widget _bubble(ClubChatMessage m) {
    final mine = m.authorId == widget.myId;
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _messageMenu(m),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          decoration: BoxDecoration(color: mine ? scheme.primaryContainer : scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (!mine)
              Text(m.authorName + (m.authorRole == 'owner' ? ' ★' : m.authorRole == 'admin' ? ' ◆' : ''), style: Theme.of(context).textTheme.labelSmall),
            Text(m.text),
            Align(alignment: Alignment.centerRight, child: Text(_time(m.createdAt), style: Theme.of(context).textTheme.labelSmall)),
          ]),
        ),
      ),
    );
  }
}
