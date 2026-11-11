import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/providers/game_provider.dart';
import 'package:flutter_chess_app/screens/daily_game_screen.dart';
import 'package:flutter_chess_app/screens/game_screen.dart';
import 'package:flutter_chess_app/utils/constants.dart';
import 'package:flutter_chess_app/widgets/loading_dialog.dart';
import 'package:provider/provider.dart';
import 'package:flutter_chess_app/services/api_client.dart';
import 'package:flutter_chess_app/services/club_service.dart';
import 'package:flutter_chess_app/services/daily_game_service.dart';
import 'package:flutter_chess_app/services/friend_service.dart';
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

  // daily-game challenges to members: status shown beside each member
  final DailyGameService _daily = DailyGameService();
  DailyGameList? _dailyData;
  final Map<String, ClubMember> _sentGames = {}; // gameId -> member I challenged (waiting for an answer)
  final Set<String> _declinedIds = {}; // member ids who declined my last challenge
  StreamSubscription<Map<String, dynamic>>? _dailySub;

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
    // The opponent accepted / declined / moved: refresh the status icons at once.
    _dailySub = GameSocketService.instance.onDailyUpdate.listen((_) => _refreshDaily());
    _load();
    _refreshDaily();
  }

  @override
  void dispose() {
    _dailySub?.cancel();
    _liveSub?.cancel();
    super.dispose();
  }

  String _err(Object e) => e is ApiException ? e.message : 'Request failed. Check your connection.';
  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  String get _myId => widget.user.uid ?? '';

  DailyGame? _gameWith(List<DailyGame>? list, String userId) {
    if (list == null) return null;
    for (final g in list) {
      if (g.opponentId == userId) return g;
    }
    return null;
  }

  /// Fetches my daily games. A challenge I sent that is no longer "waiting" was either accepted
  /// or declined: look it up, tell the user, and update the icon beside that member.
  Future<void> _refreshDaily() async {
    if (widget.user.isGuest) return;
    try {
      final d = await _daily.list();
      if (!mounted) return;
      final waiting = d.sent.map((g) => g.id).toSet();
      final gone = _sentGames.keys.where((id) => !waiting.contains(id)).toList();
      setState(() => _dailyData = d);
      for (final id in gone) {
        final m = _sentGames[id];
        if (m == null) continue;
        try {
          final g = await _daily.get(id);
          if (!mounted) return;
          if (g.status == 'declined' || g.status == 'expired') {
            _sentGames.remove(id);
            setState(() => _declinedIds.add(m.userId));
            _toast('${m.name} declined your daily game challenge.');
          } else if (g.status == 'active' || g.status == 'completed') {
            _sentGames.remove(id);
            setState(() => _declinedIds.remove(m.userId));
            if (g.status == 'active') _toast('${m.name} accepted your challenge. Tap Continue Play.');
          }
          // still "pending": the list was just not up to date yet, keep waiting
        } catch (_) {}
      }
    } catch (_) {/* icons keep their last state */}
  }

  Future<void> _openDaily(DailyGame g) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DailyGameScreen(gameId: g.id)));
    _refreshDaily();
  }

  Future<void> _cancelChallenge(DailyGame g) async {
    try {
      _sentGames.remove(g.id);
      await _daily.decline(g.id);
      await _refreshDaily();
    } catch (e) {
      _toast(_err(e));
    }
  }

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
    _disposeLater(ctrl);
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
    _disposeLater(ctrl);
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
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (m.userId != _myId && !widget.user.isGuest) _playButton(m),
            if (_memberMenu(c, m, myRole) != null) _memberMenu(c, m, myRole)!,
          ]),
          // Tap another member: add them as a friend, or challenge a friend to a daily game.
          onTap: m.userId == _myId ? null : () => _memberSheet(m),
        ),
    ]);
  }


  // ------------------------------------------------------------ play with a member
  /// The play icon beside a member: challenge, waiting, declined or Continue Play.
  Widget _playButton(ClubMember m) {
    final active = _gameWith(_dailyData?.active, m.userId);
    if (active != null) {
      return TextButton.icon(
        icon: const Icon(Icons.play_circle_fill_rounded),
        label: const Text('Continue Play'),
        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
        onPressed: () => _openDaily(active),
      );
    }
    if (_gameWith(_dailyData?.sent, m.userId) != null) {
      return IconButton(icon: const Icon(Icons.hourglass_empty), tooltip: 'Waiting for ${m.name}', onPressed: () => _memberSheet(m));
    }
    if (_declinedIds.contains(m.userId)) {
      return IconButton(icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent), tooltip: '${m.name} declined', onPressed: () => _memberSheet(m));
    }
    return IconButton(icon: const Icon(Icons.play_circle_fill_rounded), tooltip: 'Challenge ${m.name}', onPressed: () => _memberSheet(m));
  }

  Future<void> _memberSheet(ClubMember m) async {
    if (widget.user.isGuest) {
      _toast('Create an account to add friends and play.');
      return;
    }
    final friendFuture = FriendService().isFriend(_myId, m.userId);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: FutureBuilder<bool>(
          future: friendFuture,
          builder: (ctx, snap) {
            final done = snap.connectionState == ConnectionState.done;
            final isFriend = snap.data == true;
            final btn = FilledButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)));
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  CircleAvatar(radius: 24, child: Text(m.name.trim().isEmpty ? '?' : m.name.trim().characters.first.toUpperCase(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      Text('${m.role} · rating ${m.rating}', style: Theme.of(ctx).textTheme.bodySmall),
                    ]),
                  ),
                ]),
                const SizedBox(height: 16),
                if (!done)
                  const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()))
                else if (isFriend) ...[
                  if (_gameWith(_dailyData?.active, m.userId) != null)
                    FilledButton.icon(
                      style: btn,
                      icon: const Icon(Icons.play_circle_fill_rounded),
                      label: const Text('Continue Play'),
                      onPressed: () {
                        final g = _gameWith(_dailyData?.active, m.userId)!;
                        Navigator.pop(ctx);
                        _openDaily(g);
                      },
                    )
                  else if (_gameWith(_dailyData?.sent, m.userId) != null) ...[
                    Text('Waiting for ${m.name} to accept your daily game challenge.', textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel challenge'),
                      onPressed: () {
                        final g = _gameWith(_dailyData?.sent, m.userId)!;
                        Navigator.pop(ctx);
                        _cancelChallenge(g);
                      },
                    ),
                  ] else ...[
                    if (_declinedIds.contains(m.userId)) ...[
                      Text('${m.name} declined your last daily game challenge.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
                      const SizedBox(height: 10),
                    ],
                    FilledButton.icon(
                      style: btn,
                      icon: const Icon(Icons.bolt_rounded),
                      label: const Text('Challenge to a game'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _challengeLive(m);
                      },
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      style: btn,
                      icon: const Icon(Icons.sports_esports_rounded),
                      label: const Text('Challenge to a daily game'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _challengeMember(m);
                      },
                    ),
                  ],
                ]
                else ...[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Add friend'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _addFriend(m);
                    },
                  ),
                  const SizedBox(height: 8),
                  Text('You can challenge ${m.name} to a game once you are friends.', textAlign: TextAlign.center, style: Theme.of(ctx).textTheme.bodySmall),
                ],
              ]),
            );
          },
        ),
      ),
    );
  }

  Future<void> _addFriend(ClubMember m) async {
    try {
      await FriendService().sendFriendRequest(currentUserId: _myId, friendUserId: m.userId);
      if (mounted) _toast('Friend request sent to ${m.name}.');
    } catch (e) {
      if (mounted) _toast(_err(e));
    }
  }

  Future<void> _challengeMember(ClubMember m) async {
    int days = 3;
    String color = 'random';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Challenge ${m.name}'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Time per move'),
              Wrap(spacing: 8, children: [
                for (final d in const [1, 2, 3, 5, 7]) ChoiceChip(label: Text('$d day${d > 1 ? 's' : ''}'), selected: days == d, onSelected: (_) => setLocal(() => days = d)),
              ]),
              const SizedBox(height: 12),
              const Text('Your color'),
              Wrap(spacing: 8, children: [
                for (final c in const ['random', 'white', 'black']) ChoiceChip(label: Text(c), selected: color == c, onSelected: (_) => setLocal(() => color = c)),
              ]),
              const SizedBox(height: 8),
              const Text('Daily games are unrated.', style: TextStyle(fontSize: 12)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send challenge')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      final g = await _daily.challenge(m.userId, days, color: color);
      _sentGames[g.id] = m;
      if (mounted) setState(() => _declinedIds.remove(m.userId));
      if (mounted) _toast('Challenge sent to ${m.name}. Waiting for an answer.');
      await _refreshDaily();
    } catch (e) {
      if (mounted) _toast(_err(e));
    }
  }

  // ------------------------------------------------------------ live challenge
  Future<void> _challengeLive(ClubMember m) async {
    bool training = false;
    final mode = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Challenge ${m.name}'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Training mode'),
                subtitle: const Text('Unrated, with engine move warnings.'),
                value: training,
                onChanged: (v) => setLocal(() => training = v),
              ),
              for (final mode in Constants.gameModes)
                ListTile(
                  leading: Icon(mode['icon'] as IconData),
                  title: Text(mode['title'] as String),
                  subtitle: Text(mode['timeControl'] as String),
                  onTap: () => Navigator.pop(ctx, mode['timeControl'] as String),
                ),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))],
        ),
      ),
    );
    if (mode == null || !mounted) return;
    await _createPrivateGame(m, mode, trainingMode: training);
  }

  Future<void> _createPrivateGame(ClubMember m, String gameMode, {bool trainingMode = false}) async {
    final gameProvider = context.read<GameProvider>();
    gameProvider.setLoading(true);
    LoadingDialog.show(
      context,
      message: 'Sending challenge...',
      barrierDismissible: false,
      showCancelButton: true,
      onCancel: () => gameProvider.cancelOnlineGameSearch(isFriend: true),
    );
    try {
      await gameProvider.createPrivateGameRoom(
        gameMode: gameMode,
        player1Id: widget.user.uid!,
        player2Id: m.userId,
        player1DisplayName: widget.user.displayName,
        player1PhotoUrl: widget.user.photoUrl,
        playerFlag: widget.user.countryCode ?? '',
        player1Rating: widget.user.classicalRating,
        trainingMode: trainingMode,
      );
      if (mounted) {
        LoadingDialog.updateMessage(
          context,
          'Waiting for ${m.name} to accept...',
          showCancelButton: true,
          onCancel: () => gameProvider.cancelOnlineGameSearch(isFriend: true),
        );
      }
      // Accepted = the game becomes active and the board opens. Declined = InviteDeclinedException.
      await gameProvider.waitForGameToStart();
      if (gameProvider.searchCancelled) {
        gameProvider.setLoading(false);
        if (mounted) LoadingDialog.hide(context);
        return;
      }
      gameProvider.setLoading(false);
      if (mounted) LoadingDialog.hide(context);
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        _toast('${m.name} accepted your challenge.');
        Navigator.push(context, MaterialPageRoute(builder: (_) => GameScreen(user: widget.user)));
      }
    } on InviteDeclinedException {
      await gameProvider.cancelOnlineGameSearch(isFriend: true);
      if (mounted) {
        LoadingDialog.hide(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${m.name} declined your challenge.'), backgroundColor: Colors.orange));
      }
    } catch (e) {
      gameProvider.setLoading(false);
      if (mounted) {
        LoadingDialog.hide(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send challenge: $e'), backgroundColor: Colors.red));
      }
    }
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

/// Disposes a dialog's controller only after the dialog's closing animation is over.
/// Disposing right after `await showDialog(...)` while the TextField is still on
/// screen triggers the "_dependents.isEmpty" red-screen assertion.
void _disposeLater(TextEditingController c) {
  Future<void>.delayed(const Duration(milliseconds: 600), c.dispose);
}
