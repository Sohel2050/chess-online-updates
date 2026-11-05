import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chess_app/screens/game_replay_screen.dart';
import 'package:flutter_chess_app/services/api_client.dart';
import 'package:flutter_chess_app/services/crash_reporter.dart';
import 'package:flutter_chess_app/services/saved_game_service.dart';
import 'package:flutter_chess_app/utils/share_link.dart';

/// Paste a PGN (or a game share link). The server checks every move with its own rules engine,
/// saves the game(s) to My Saved Games and the replay opens.
class ImportPgnScreen extends StatefulWidget {
  /// Text to start with (a tapped game link) and whether to import it at once without pressing the button.
  final String? initialText;
  final bool autoImport;
  const ImportPgnScreen({super.key, this.initialText, this.autoImport = false});

  @override
  State<ImportPgnScreen> createState() => _ImportPgnScreenState();
}

class _ImportPgnScreenState extends State<ImportPgnScreen> {
  final TextEditingController _text = TextEditingController();
  final SavedGameService _service = SavedGameService();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final t = widget.initialText;
    if (t != null) _text.text = t;
    if (widget.autoImport && t != null && t.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _import();
      });
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final t = data?.text;
    if (t != null && t.isNotEmpty) setState(() => _text.text = t);
  }

  Future<void> _import() async {
    final input = _text.text.trim();
    if (input.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final code = ShareLink.extractCode(input);
      final games = code != null ? [await _service.importSharedCode(code)] : await _service.importPgn(input);
      if (!mounted) return;
      if (games.length > 1) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${games.length} games saved to My Saved Games.')));
      }
      // One game: open it straight away. Several: go back to the list.
      if (games.length == 1) {
        await Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => GameReplayScreen(game: games.first)));
      } else {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.statusCode == 404 ? 'This link does not exist or was removed.' : e.message);
    } catch (e, st) {
      CrashReporter.recordError(e, st, reason: 'pgn import failed');
      if (mounted) setState(() => _error = 'Could not import. Check your internet connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import a game')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Paste a PGN from any chess site, or a game link someone shared with you.'),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _text,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: '[Event "..."]\n\n1. e4 e5 2. Nf3 Nc6 ...',
                  errorText: _error,
                  errorMaxLines: 3,
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(onPressed: _busy ? null : _paste, icon: const Icon(Icons.content_paste), label: const Text('Paste')),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _import,
                    child: _busy
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Import'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
