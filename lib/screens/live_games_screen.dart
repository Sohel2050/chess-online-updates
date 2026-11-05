import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/screens/spectator_screen.dart';
import 'package:flutter_chess_app/services/api_client.dart';
import 'package:flutter_chess_app/widgets/profile_image_widget.dart';

/// Games whose players switched "Live" ON — anyone in the app can open and watch them.
///
/// Used as the "Live" tab of the bottom bar ([embedded] = no app bar of its own; [isVisible] pauses
/// refreshing while another tab is open) and still usable as a full page.
class LiveGamesScreen extends StatefulWidget {
  final bool embedded;
  final bool isVisible;

  const LiveGamesScreen({super.key, this.embedded = false, this.isVisible = true});

  @override
  State<LiveGamesScreen> createState() => _LiveGamesScreenState();
}

class _LiveGamesScreenState extends State<LiveGamesScreen> {
  List<Map<String, dynamic>> _games = [];
  bool _loading = true;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (widget.isVisible) _load(silent: true);
    });
  }

  @override
  void didUpdateWidget(covariant LiveGamesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh the moment the Live tab is opened.
    if (widget.isVisible && !oldWidget.isVisible) _load(silent: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final result = await ApiClient.instance.get('/games/live');
      final list = (result['games'] as List? ?? []).map((g) => Map<String, dynamic>.from(g)).toList();
      if (!mounted) return;
      setState(() {
        _games = list;
        _error = null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load live games.';
        _loading = false;
      });
    }
  }

  int _reactionTotal(Map<String, dynamic> g) {
    var total = 0;
    final raw = g['reactionCounts'];
    if (raw is Map) {
      for (final player in raw.values) {
        if (player is Map) {
          for (final n in player.values) {
            if (n is num) total += n.toInt();
          }
        }
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final list = RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator.adaptive())
            : _games.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      Center(child: Text(_error ?? 'No live games right now.\nPull down to refresh.', textAlign: TextAlign.center)),
                    ],
                  )
                : ListView.separated(
                    itemCount: _games.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final g = _games[i];
                      final reactions = _reactionTotal(g);
                      final moves = (g['moves'] as List?)?.length ?? 0;
                      return ListTile(
                        leading: ProfileImageWidget(imageUrl: g['player1PhotoUrl'] as String?, radius: 20),
                        title: Text('${g['player1DisplayName'] ?? 'Player 1'} vs ${g['player2DisplayName'] ?? 'Player 2'}'),
                        subtitle: Text(
                          '${g['gameMode'] ?? ''} · ${g['player1Rating'] ?? '?'} vs ${g['player2Rating'] ?? '?'} · $moves moves'
                          '${reactions > 0 ? ' · $reactions 😊' : ''}',
                        ),
                        trailing: const Icon(Icons.visibility),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => SpectatorScreen(gameId: g['_id'].toString())),
                        ),
                      );
                    },
                  ),
    );

    if (widget.embedded) return list;
    return Scaffold(appBar: AppBar(title: const Text('Watch Live')), body: list);
  }
}
