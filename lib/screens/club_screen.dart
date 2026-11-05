import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/services/api_client.dart';
import 'package:flutter_chess_app/services/club_service.dart';
import 'package:flutter_chess_app/services/game_socket_service.dart';
import 'package:flutter_chess_app/widgets/club_chat_panel.dart';
import 'package:flutter_chess_app/widgets/report_dialog.dart';

/// One club: members (with owner / admin tools), weekly leaderboard and announcements.
class ClubScreen extends StatefulWidget {
  final String clubId;
  final ChessUser user;
  const ClubScreen({super.key, required this.clubId, required this.user});

  @override
  State<ClubScreen> createState() => _ClubScreenState();
}

class _ClubScreenState extends State<ClubScreen> {
  final ClubService _service = ClubService();
  ClubDetail? _club;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  int _tab = 0; // 0 announcements, 1 chat, 2 leaderboard, 3 members

  // chat badge: messages from others that arrived while the Chat tab was not open
  int _unread = 0;
  StreamSubscription<Map<String, dynamic>>? _liveSub;

  // announcements
  ClubPosts? _posts;
  // leaderboard
  ClubBoard? _board;
  String _by = 'weekly';

  @override
  void initState() {
    super.initState();
    _liveSub = GameSocketService.instance.onClubEvent.listen((e) {
      if (!mounted || _tab == 1 || e['event'] != 'message' || e['clubId']?.toString() != widget.clubId) return;
      final from = (e['message'] is Map) ? (e['message'] as Map)['authorId']?.toString() : null;
      if (from != null && from != _myId) setState(() => _unread = _unread >= 100 ? 100 : _unread + 1);
    });
    _load();
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    super.dispose();
  }

  String _err(Object e) => e is ApiException ? e.message : 'Request failed. Check your connection.';
  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  String get _myId => widget.user.uid ?? '';

  Future<void> _load() async {
    try {
      final c = await _service.get(widget.clubId);
      if (!mounted) return;
      setState(() {
        _club = c;
        _unread = _tab == 1 ? 0 : c.info.unreadChat;
        _loading = false;
        _error = null;
      });
      if (c.info.isMember) {
        await Future.wait([_loadPosts(), _loadBoard()]);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _err(e);
      });
    }
  }

  Future<void> _loadPosts() async {
    try {
      final p = await _service.posts(widget.clubId);
      if (mounted) setState(() => _posts = p);
    } catch (_) {/* the tab shows what it has */}
  }

  Future<void> _loadBoard() async {
    try {
      final b = await _service.leaderboard(widget.clubId, by: _by);
      if (mounted) setState(() => _board = b);
    } catch (_) {}
  }

  Future<void> _run(Future<ClubDetail> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final c = await action();
      if (mounted) setState(() => _club = c);
      await _loadBoard();
    } catch (e) {
      _toast(_err(e));
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _ask(String title, String text) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _leave() async {
    if (!await _ask('Leave this club?', 'You can join again later if the club is not full.')) return;
    try {
      await _service.leave(widget.clubId);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _toast(_err(e));
    }
  }

  Future<void> _deleteClub() async {
    if (!await _ask('Delete this club?', 'The members, announcements and chat are removed. This cannot be undone.')) return;
    try {
      await _service.deleteClub(widget.clubId);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _toast(_err(e));
    }
  }

  Future<void> _editDescription(ClubDetail c) async {
    final ctrl = TextEditingController(text: c.info.description);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Description'),
        content: TextField(controller: ctrl, maxLength: 300, maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    final text = ctrl.text.trim();
    ctrl.dispose();
    if (ok == true) await _run(() => _service.updateDescription(widget.clubId, text));
  }

  Future<void> _newPost() async {
    final ctrl = TextEditingController();
    bool notify = false;
    bool pinned = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('New announcement'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: ctrl, maxLength: 500, maxLines: 4, autofocus: true),
              CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero, title: const Text('Notify members'), subtitle: const Text('At most once an hour'), value: notify, onChanged: (v) => setLocal(() => notify = v == true)),
              CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero, title: const Text('Pin to the top'), value: pinned, onChanged: (v) => setLocal(() => pinned = v == true)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Post')),
          ],
        ),
      ),
    );
    final text = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true) return;
    try {
      final notified = await _service.post(widget.clubId, text, notify: notify, pinned: pinned);
      if (notify && !notified) _toast('Posted. Members were not notified: one notification per hour.');
      await _loadPosts();
    } catch (e) {
      _toast(_err(e));
    }
  }

  Future<void> _postAction(ClubPost p, String action) async {
    try {
      if (action == 'delete') {
        if (!await _ask('Delete announcement?', 'It disappears for everybody.')) return;
        await _service.deletePost(widget.clubId, p.id);
      } else if (action == 'pin' || action == 'unpin') {
        await _service.pinPost(widget.clubId, p.id, action == 'pin');
      } else if (action == 'report') {
        await showReportDialog(context, kind: 'club_post', targetId: p.id, title: 'Report this announcement');
        return;
      }
      await _loadPosts();
    } catch (e) {
      _toast(_err(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _club;
    final member = c?.info.isMember == true;
    return Scaffold(
      appBar: AppBar(
        title: Text(c == null ? 'Club' : c.info.name),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _busy ? null : _load),
          if (c != null)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'leave') _leave();
                if (v == 'delete') _deleteClub();
                if (v == 'desc') _editDescription(c);
                if (v == 'report') showReportDialog(context, kind: 'club', targetId: c.info.id, title: 'Report this club');
              },
              itemBuilder: (_) => [
                if (c.info.isManager) const PopupMenuItem(value: 'desc', child: Text('Edit description')),
                if (member && !c.info.isOwner) const PopupMenuItem(value: 'leave', child: Text('Leave club')),
                if (c.info.isOwner) const PopupMenuItem(value: 'delete', child: Text('Delete club')),
                if (!c.info.isOwner) const PopupMenuItem(value: 'report', child: Text('Report club')),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : c == null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error ?? 'Club not found', textAlign: TextAlign.center)))
              : Column(children: [
                  _header(c),
                  if (member)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: SegmentedButton<int>(
                        segments: [
                          const ButtonSegment(value: 0, label: Text('News'), icon: Icon(Icons.campaign)),
                          ButtonSegment(
                            value: 1,
                            label: const Text('Chat'),
                            icon: Badge(
                              isLabelVisible: _unread > 0,
                              label: Text(_unread >= 100 ? '99+' : '$_unread'),
                              child: const Icon(Icons.chat_bubble_outline),
                            ),
                          ),
                          const ButtonSegment(value: 2, label: Text('Ranking'), icon: Icon(Icons.leaderboard)),
                          const ButtonSegment(value: 3, label: Text('Members'), icon: Icon(Icons.people)),
                        ],
                        selected: {_tab},
                        onSelectionChanged: (s) => setState(() {
                          _tab = s.first;
                          if (_tab == 1) _unread = 0; // the chat panel tells the server it was read
                        }),
                      ),
                    ),
                  Expanded(child: member ? _tabBody(c) : const SizedBox.shrink()),
                ]),
    );
  }

  Widget _header(ClubDetail c) {
    final info = c.info;
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (info.description.isNotEmpty) ...[Text(info.description), const SizedBox(height: 6)],
          Text('${info.memberCount}/${info.maxMembers} members · owner ${info.ownerName}', style: Theme.of(context).textTheme.bodySmall),
          if (!info.isMember) ...[
            const SizedBox(height: 8),
            if (widget.user.isGuest)
              const Text('Create an account to join clubs.')
            else
              FilledButton.icon(
                icon: const Icon(Icons.login),
                label: const Text('Join club'),
                onPressed: _busy ? null : () => _run(() => _service.join(widget.clubId)),
              ),
            const SizedBox(height: 4),
            const Text('Members see the ranking, announcements and each other.', style: TextStyle(fontSize: 12)),
          ],
        ]),
      ),
    );
  }

  Widget _tabBody(ClubDetail c) {
    switch (_tab) {
      case 0:
        return _newsTab(c);
      case 1:
        return ClubChatPanel(key: ValueKey('chat-${widget.clubId}'), clubId: widget.clubId, myId: _myId, myRole: c.info.myRole, mutedUntil: c.info.myMutedUntil);
      case 2:
        return _rankingTab();
      default:
        return _membersTab(c);
    }
  }

  // ------------------------------------------------------------ announcements
  Widget _newsTab(ClubDetail c) {
    final p = _posts;
    if (p == null) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: ListView(padding: const EdgeInsets.all(12), children: [
        if (p.canPost) FilledButton.tonalIcon(icon: const Icon(Icons.add), label: const Text('New announcement'), onPressed: _newPost),
        if (p.posts.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('No announcements yet.', textAlign: TextAlign.center)),
        for (final post in p.posts)
          Card(
            child: ListTile(
              leading: post.pinned ? const Icon(Icons.push_pin) : null,
              title: Text(post.text),
              subtitle: Text('${post.authorName}${post.createdAt == null ? '' : ' · ${post.createdAt!.toString().substring(0, 10)}'}'),
              trailing: PopupMenuButton<String>(
                onSelected: (v) => _postAction(post, v),
                itemBuilder: (_) => [
                  if (c.info.isManager) PopupMenuItem(value: post.pinned ? 'unpin' : 'pin', child: Text(post.pinned ? 'Unpin' : 'Pin')),
                  if (c.info.isManager) const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  if (post.authorId != _myId) const PopupMenuItem(value: 'report', child: Text('Report')),
                ],
              ),
            ),
          ),
      ]),
    );
  }

  // ------------------------------------------------------------ leaderboard
  Widget _rankingTab() {
    final b = _board;
    return RefreshIndicator(
      onRefresh: _loadBoard,
      child: ListView(padding: const EdgeInsets.all(12), children: [
        Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
          ChoiceChip(label: const Text('This week'), selected: _by == 'weekly', onSelected: (_) async { setState(() => _by = 'weekly'); await _loadBoard(); }),
          ChoiceChip(label: const Text('Rating'), selected: _by == 'rating', onSelected: (_) async { setState(() => _by = 'rating'); await _loadBoard(); }),
        ]),
        if (b == null) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
        if (b != null && b.by == 'weekly')
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Club total: ${b.totalPoints} points this week${b.resetsAt == null ? '' : ' · resets ${b.resetsAt!.toString().substring(0, 10)}'}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          ),
        if (b != null)
          for (final r in b.rows)
            ListTile(
              dense: true,
              selected: r.userId == _myId,
              leading: CircleAvatar(radius: 14, child: Text('${r.rank}', style: const TextStyle(fontSize: 12))),
              title: Text(r.name),
              trailing: Text(b.by == 'weekly' ? '${r.points} pts' : '${r.rating}'),
              subtitle: b.by == 'weekly' ? Text('rating ${r.rating}') : null,
            ),
      ]),
    );
  }

  // ------------------------------------------------------------ members
  Widget _membersTab(ClubDetail c) {
    final myRole = c.info.myRole;
    return ListView(padding: const EdgeInsets.all(12), children: [
      for (final m in c.members)
        ListTile(
          dense: true,
          leading: Icon(m.role == 'owner' ? Icons.star : m.role == 'admin' ? Icons.shield : Icons.person),
          title: Text(m.name + (m.userId == _myId ? ' (you)' : '')),
          subtitle: Text('${m.role} · rating ${m.rating}${m.mutedUntil != null ? ' · muted' : ''}'),
          trailing: _memberMenu(c, m, myRole),
        ),
    ]);
  }

  Widget? _memberMenu(ClubDetail c, ClubMember m, String? myRole) {
    if (m.userId == _myId) return null;
    final canRemove = myRole == 'owner' || (myRole == 'admin' && m.role == 'member');
    final items = <PopupMenuEntry<String>>[
      if (myRole == 'owner' && m.role == 'member') const PopupMenuItem(value: 'admin', child: Text('Make admin')),
      if (myRole == 'owner' && m.role == 'admin') const PopupMenuItem(value: 'member', child: Text('Make plain member')),
      if (myRole == 'owner') const PopupMenuItem(value: 'transfer', child: Text('Hand the club over')),
      // Chat mute: same people as "Remove" (the owner: admins and members; an admin: plain members).
      if (canRemove && m.mutedUntil == null) ...const [
        PopupMenuItem(value: 'mute:10', child: Text('Mute chat 10 min')),
        PopupMenuItem(value: 'mute:60', child: Text('Mute chat 1 hour')),
        PopupMenuItem(value: 'mute:1440', child: Text('Mute chat 1 day')),
        PopupMenuItem(value: 'mute:10080', child: Text('Mute chat 1 week')),
      ],
      if (canRemove && m.mutedUntil != null) const PopupMenuItem(value: 'mute:0', child: Text('Unmute chat')),
      if (canRemove) const PopupMenuItem(value: 'remove', child: Text('Remove')),
      if (canRemove) const PopupMenuItem(value: 'ban', child: Text('Remove and ban')),
    ];
    if (items.isEmpty) return null;
    return PopupMenuButton<String>(
      onSelected: (v) async {
        final id = widget.clubId;
        if (v == 'admin' || v == 'member') {
          await _run(() => _service.setRole(id, m.userId, v));
        } else if (v.startsWith('mute:')) {
          await _run(() => _service.muteMember(id, m.userId, int.tryParse(v.substring(5)) ?? 0));
        } else if (v == 'transfer') {
          if (await _ask('Hand the club over?', '${m.name} becomes the owner. You stay as an admin.')) await _run(() => _service.transfer(id, m.userId));
        } else if (v == 'remove' || v == 'ban') {
          if (await _ask(v == 'ban' ? 'Remove and ban ${m.name}?' : 'Remove ${m.name}?', v == 'ban' ? 'They cannot join again.' : 'They can join again.')) {
            await _run(() => _service.removeMember(id, m.userId, ban: v == 'ban'));
          }
        }
      },
      itemBuilder: (_) => items,
    );
  }
}
