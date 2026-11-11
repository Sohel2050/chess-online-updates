import 'package:flutter/material.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/screens/club_screen.dart';
import 'package:flutter_chess_app/services/api_client.dart';
import 'package:flutter_chess_app/services/club_service.dart';

/// Clubs: my clubs, search / discover, start a new one.
class ClubsScreen extends StatefulWidget {
  final ChessUser user;
  /// Inside the Friends tab: no app bar of its own.
  final bool embedded;
  const ClubsScreen({super.key, required this.user, this.embedded = false});

  @override
  State<ClubsScreen> createState() => _ClubsScreenState();
}

class _ClubsScreenState extends State<ClubsScreen> {
  final ClubService _service = ClubService();
  final TextEditingController _search = TextEditingController();
  ClubList? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _err(Object e) => e is ApiException ? e.message : 'Request failed. Check your connection.';
  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _load() async {
    try {
      final d = await _service.list(query: _search.text.trim());
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _err(e);
      });
    }
  }

  Future<void> _open(String id) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClubScreen(clubId: id, user: widget.user)));
    _load();
  }

  Future<void> _create() async {
    final name = TextEditingController();
    final desc = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New club'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, maxLength: 40, decoration: const InputDecoration(labelText: 'Club name')),
            TextField(controller: desc, maxLength: 300, maxLines: 2, decoration: const InputDecoration(labelText: 'Description (optional)')),
            const SizedBox(height: 4),
            const Text('Anybody can join. You can own one club and be in up to 3.', style: TextStyle(fontSize: 12)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      ),
    );
    final n = name.text.trim();
    final d = desc.text.trim();
    _disposeLater(name);
    _disposeLater(desc);
    if (ok != true) return;
    try {
      final c = await _service.create(name: n, description: d);
      if (mounted) _open(c.info.id);
    } catch (e) {
      _toast(_err(e));
    }
  }

  Widget _tile(ClubSummary c) => ListTile(
        leading: const CircleAvatar(child: Icon(Icons.groups)),
        title: Text(c.name),
        subtitle: Text('${c.memberCount} member${c.memberCount == 1 ? '' : 's'} · ${c.ownerName}${c.description.isEmpty ? '' : '\n${c.description}'}', maxLines: 3, overflow: TextOverflow.ellipsis),
        isThreeLine: c.description.isNotEmpty,
        trailing: c.myRole == null
            ? const Icon(Icons.chevron_right)
            : Row(mainAxisSize: MainAxisSize.min, children: [
                if (c.unreadChat > 0) ...[
                  Badge(label: Text(c.unreadChat >= 100 ? '99+' : '${c.unreadChat}'), child: const Icon(Icons.chat_bubble_outline)),
                  const SizedBox(width: 12),
                ],
                Chip(label: Text(c.myRole!), visualDensity: VisualDensity.compact),
              ]),
        onTap: () => _open(c.id),
      );

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      backgroundColor: widget.embedded ? Colors.transparent : null,
      appBar: widget.embedded
          ? null
          : AppBar(title: const Text('Clubs'), actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)]),
      floatingActionButton: widget.user.isGuest ? null : FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.add), label: const Text('New club')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : d == null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error ?? 'Could not load', textAlign: TextAlign.center)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.only(bottom: 96), children: [
                    if (widget.user.isGuest) const Padding(padding: EdgeInsets.all(16), child: Text('Create an account to join or start a club.', textAlign: TextAlign.center)),
                    if (d.mine.isNotEmpty) const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 4), child: Text('My clubs', style: TextStyle(fontWeight: FontWeight.bold))),
                    for (final c in d.mine) _tile(c),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: TextField(
                        controller: _search,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _load(),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: 'Find a club',
                          suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _load),
                        ),
                      ),
                    ),
                    if (d.discover.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('No clubs found.', textAlign: TextAlign.center)),
                    for (final c in d.discover) _tile(c),
                  ]),
                ),
    );
  }
}

/// Disposes a dialog's controller only after the dialog's closing animation is over.
/// Disposing right after `await showDialog(...)` while the TextField is still on
/// screen triggers the "_dependents.isEmpty" red-screen assertion.
void _disposeLater(TextEditingController c) {
  Future<void>.delayed(const Duration(milliseconds: 600), c.dispose);
}
