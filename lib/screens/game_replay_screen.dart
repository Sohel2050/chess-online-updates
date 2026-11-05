import 'package:flutter/material.dart';
import 'package:flutter_chess_app/services/sound_service.dart';
import 'package:flutter_chess_app/models/saved_game_model.dart';
import 'package:squares/squares.dart';
import 'package:bishop/bishop.dart' as bishop;
import 'package:square_bishop/square_bishop.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_chess_app/services/game_analyzer.dart';
import 'package:flutter_chess_app/services/game_review.dart';
import 'package:flutter_chess_app/services/saved_game_service.dart';
import 'package:flutter_chess_app/services/crash_reporter.dart';
import 'package:flutter_chess_app/widgets/move_arrow_overlay.dart';
import 'package:flutter_chess_app/utils/pgn_export.dart';
import 'package:share_plus/share_plus.dart';

class GameReplayScreen extends StatefulWidget {
  final SavedGame game;

  const GameReplayScreen({super.key, required this.game});

  @override
  State<GameReplayScreen> createState() => _GameReplayScreenState();
}

class _GameReplayScreenState extends State<GameReplayScreen> {
  late bishop.Game _game;
  late List<bishop.Move> _moves;
  int _currentMoveIndex = -1;
  // Show the board from the side YOU played (like during the game); the button flips it.
  late bool _flipped;

  // ---- engine review ----
  GameReviewResult? _review;
  GameReviewer? _reviewer;
  bool _reviewing = false;
  double _progress = 0;
  String? _reviewError;
  // Arrow for the engine's best move in the position on the board.
  bool _showArrow = true;

  String get _cacheKey => 'review_v1_${widget.game.gameId}_${widget.game.moves.length}';

  @override
  void initState() {
    super.initState();
    _flipped = widget.game.playerColor == 'black';
    _loadGame();
    _loadCachedReview();
  }

  @override
  void dispose() {
    _reviewer?.cancel();
    super.dispose();
  }

  Future<void> _loadCachedReview() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final r = GameReviewResult.decode(prefs.getString(_cacheKey));
      if (r != null && mounted && r.moves.length == _moves.length) {
        setState(() => _review = r);
        return;
      }
    } catch (_) {}
    await _loadServerReview();
  }

  /// No review on this device: maybe it was made earlier on another device / before a reinstall.
  Future<void> _loadServerReview() async {
    final raw = await SavedGameService().getReview(widget.game.gameId);
    final r = GameReviewResult.decode(raw);
    if (r == null || !mounted || _reviewing || _review != null) return;
    if (r.moves.length != _moves.length) return; // belongs to a different move list
    setState(() => _review = r);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, raw!);
    } catch (_) {}
  }

  Future<void> _startReview() async {
    if (_reviewing || _moves.isEmpty) return;
    setState(() {
      _reviewing = true;
      _progress = 0;
      _reviewError = null;
    });
    final reviewer = GameReviewer();
    _reviewer = reviewer;
    GameReviewResult? result;
    try {
      result = await reviewer.review(
        initialFen: widget.game.initialFen,
        moves: _moves,
        uciMoves: widget.game.moves,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
    } catch (e, st) {
      CrashReporter.recordError(e, st, reason: 'game review failed');
      result = null;
    }
    if (!mounted) return;
    if (result != null) {
      final encoded = result.encode();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cacheKey, encoded);
      } catch (_) {}
      // Keep a copy on the server too (fire and forget: the review works without it).
      // ignore: unawaited_futures
      SavedGameService().saveReview(widget.game.gameId, encoded);
    }
    setState(() {
      _reviewing = false;
      _review = result;
      if (result == null) {
        _reviewError = 'Could not run the engine. Close other games and try again.';
      }
    });
  }

  /// Shares the game as PGN text (opens the phone's share sheet: copy, mail, chess sites...).
  Future<void> _sharePgn() async {
    final g = widget.game;
    final replay = bishop.Game(fen: g.initialFen);
    final san = <String>[];
    for (var i = 0; i < _moves.length; i++) {
      String text;
      try {
        text = replay.toSan(_moves[i]);
      } catch (_) {
        text = g.moves[i];
      }
      san.add(text);
      replay.makeMove(_moves[i]);
    }
    final pgn = PgnExport.build(
      sanMoves: san,
      myName: 'Me',
      opponentName: g.opponentDisplayName.isEmpty ? 'Opponent' : g.opponentDisplayName,
      playerColor: g.playerColor,
      result: g.result,
      date: g.createdAt,
      initialFen: g.initialFen,
    );
    try {
      await SharePlus.instance.share(ShareParams(text: pgn, subject: 'Chess game (PGN)'));
    } catch (e, st) {
      CrashReporter.recordError(e, st, reason: 'pgn share failed');
    }
  }

  /// Makes a public link for this game (a web page anyone can open) and opens the share sheet.
  Future<void> _shareLink() async {
    final messenger = ScaffoldMessenger.of(context);
    final url = await SavedGameService().createShareLink(widget.game.gameId);
    if (url == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not create the link. Check your connection and try again.')));
      return;
    }
    try {
      await SharePlus.instance.share(ShareParams(text: url, subject: 'Chess game'));
    } catch (e, st) {
      CrashReporter.recordError(e, st, reason: 'share link failed');
    }
  }

  void _loadGame() {
    final initialGame = bishop.Game(fen: widget.game.initialFen);
    _moves = <bishop.Move>[];
    var currentGame = bishop.Game(fen: initialGame.fen);

    for (int i = 0; i < widget.game.moves.length; i++) {
      String moveStr = widget.game.moves[i];

      // Accept the usual spellings of the same move (e7e8Q, e2-e4, Nf3+ ...).
      var move = currentGame.getMove(moveStr);
      move ??= currentGame.getMove(moveStr.toLowerCase().replaceAll(RegExp(r'[-+#x=]'), ''));
      if (move == null) break; // never skip a move: later ones would no longer fit the board
      _moves.add(move);
      currentGame.makeMove(move);
    }

    _game = initialGame;
    // Start the game at last move position
    setState(() {
      _goToMove(_moves.length - 1);
    });
  }

  void _goToMove(int index) {
    if (index < -1 || index >= _moves.length) return;

    final previousIndex = _currentMoveIndex;
    var fenBeforeLast = '';
    setState(() {
      _currentMoveIndex = index;
      _game = bishop.Game(fen: widget.game.initialFen);
      for (int i = 0; i <= index; i++) {
        if (i == index) fenBeforeLast = _game.fen;
        _game.makeMove(_moves[i]);
      }
    });
    // Sound only when stepping forward one move (not for jumps or going back).
    if (index == previousIndex + 1 && fenBeforeLast.isNotEmpty) {
      SoundService.instance.playMove(fenBeforeLast, _game.fen);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Replay: vs ${widget.game.opponentDisplayName}'),
        actions: [
          if (_review != null)
            IconButton(
              tooltip: _showArrow ? 'Hide best-move arrow' : 'Show best-move arrow',
              icon: Icon(_showArrow ? Icons.arrow_outward : Icons.arrow_outward_outlined,
                  color: _showArrow ? Colors.greenAccent : null),
              onPressed: () => setState(() => _showArrow = !_showArrow),
            ),
          IconButton(
            tooltip: 'Share a link to this game',
            icon: const Icon(Icons.link),
            onPressed: _moves.isEmpty ? null : _shareLink,
          ),
          IconButton(
            tooltip: 'Share game (PGN)',
            icon: const Icon(Icons.ios_share),
            onPressed: _moves.isEmpty ? null : _sharePgn,
          ),
          IconButton(
            tooltip: 'Flip board',
            icon: const Icon(Icons.flip),
            onPressed: () => setState(() => _flipped = !_flipped),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_moves.length < widget.game.moves.length)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.orange,
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Warning: Only ${_moves.length} of ${widget.game.moves.length} moves could be loaded',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Row(
              children: [
                if (_review != null) _buildEvalBar(),
                Expanded(
                  child: Center(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final side = box.biggest.shortestSide.isFinite
                            ? box.biggest.shortestSide
                            : MediaQuery.of(context).size.width;
                        return SizedBox(
                          width: side,
                          height: side,
                          child: Stack(
                            children: [
                              BoardController(
                                state: _flipped
                                    ? _game.squaresState(Squares.white).board.flipped()
                                    : _game.squaresState(Squares.white).board,
                                playState: PlayState.theirTurn,
                                pieceSet: PieceSet.merida(),
                              ),
                              if (_arrowUci != null)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: CustomPaint(
                                      painter: MoveArrowPainter(uci: _arrowUci, flipped: _flipped),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildReviewPanel(),
          _buildControls(),
        ],
      ),
    );
  }

  /// The engine's best move in the position on the board (= the best reply to the
  /// move shown), or null (no review, arrow off, last position, no best move known).
  /// To see what should have been played instead of a mistake, step one move back.
  String? get _arrowUci {
    final r = _review;
    if (r == null || !_showArrow) return null;
    final next = _currentMoveIndex + 1; // the move that follows the one on the board
    if (next < 0 || next >= r.moves.length) return null;
    final u = r.moves[next].bestUci;
    return ArrowGeometry.parseUci(u) == null ? null : u;
  }

  // Evaluation after the move currently shown (index 0 of evals = start position).
  int? get _currentEval {
    final r = _review;
    if (r == null) return null;
    final i = _currentMoveIndex + 1;
    return i >= 0 && i < r.evals.length ? r.evals[i] : null;
  }

  Widget _buildEvalBar() {
    final white = ReviewRules.barWhite(_currentEval);
    final whiteOnBottom = !_flipped;
    final whitePart = Expanded(
      flex: (white * 1000).round().clamp(1, 999),
      child: Container(color: Colors.white),
    );
    final blackPart = Expanded(
      flex: (1000 - (white * 1000).round()).clamp(1, 999),
      child: Container(color: Colors.grey.shade800),
    );
    return Container(
      width: 18,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black38),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Column(
          // top -> bottom
          children: whiteOnBottom ? [blackPart, whitePart] : [whitePart, blackPart],
        ),
      ),
    );
  }

  Color _qualityColor(MoveQuality q) {
    switch (q) {
      case MoveQuality.best:
        return Colors.green;
      case MoveQuality.good:
        return Colors.lightGreen;
      case MoveQuality.inaccuracy:
        return Colors.amber.shade800;
      case MoveQuality.mistake:
        return Colors.orange.shade800;
      case MoveQuality.blunder:
        return Colors.red;
    }
  }

  Widget _buildReviewPanel() {
    if (_reviewing) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: _progress == 0 ? null : _progress),
            const SizedBox(height: 4),
            Text('Analysing game... ${(_progress * 100).round()}%'),
          ],
        ),
      );
    }
    final r = _review;
    if (r == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_reviewError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(_reviewError!, style: const TextStyle(color: Colors.red)),
              ),
            FilledButton.icon(
              onPressed: _moves.isEmpty ? null : _startReview,
              icon: const Icon(Icons.analytics_outlined),
              label: const Text('Analyse game'),
            ),
          ],
        ),
      );
    }

    final idx = _currentMoveIndex;
    ReviewedMove? cur = (idx >= 0 && idx < r.moves.length) ? r.moves[idx] : null;
    final w = r.summary(white: true);
    final b = r.summary(white: false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: _sideCard('White', w)),
              const SizedBox(width: 8),
              Expanded(child: _sideCard('Black', b)),
            ],
          ),
          const SizedBox(height: 6),
          if (cur != null) _currentMoveInfo(cur) else const Text('Use the arrows to step through the game'),
          const SizedBox(height: 6),
          _buildMoveStrip(r),
        ],
      ),
    );
  }

  Widget _sideCard(String name, SideSummary s) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$name  ${s.accuracy.toStringAsFixed(0)}%',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('?? ${s.blunders}   ? ${s.mistakes}   ?! ${s.inaccuracies}',
              style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _currentMoveInfo(ReviewedMove m) {
    final played = m.ply < widget.game.moves.length ? widget.game.moves[m.ply] : '';
    final number = (m.ply ~/ 2) + 1;
    final prefix = m.white ? '$number.' : '$number...';
    final bestKnown = m.bestUci != null && m.bestUci!.length >= 4;
    final showBetter = bestKnown && m.quality.index >= MoveQuality.inaccuracy.index;
    return Column(
      children: [
        Text(
          '$prefix $played  ${m.quality.mark}  ${m.quality.label}  (${ReviewRules.scoreText(m.cpAfter)})',
          style: TextStyle(fontWeight: FontWeight.bold, color: _qualityColor(m.quality)),
        ),
        if (showBetter)
          Text('Best was ${CoachRules.fmtUci(m.bestUci!)}  (lost ${(m.loss / 100).toStringAsFixed(1)} pawns)'),
      ],
    );
  }

  Widget _buildMoveStrip(GameReviewResult r) {
    return SizedBox(
      height: 34,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: r.moves.length,
        itemBuilder: (context, i) {
          final m = r.moves[i];
          final selected = i == _currentMoveIndex;
          final label = i < widget.game.moves.length ? widget.game.moves[i] : '';
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: ChoiceChip(
              selected: selected,
              visualDensity: VisualDensity.compact,
              label: Text('$label${m.quality.mark}', style: TextStyle(color: _qualityColor(m.quality))),
              onSelected: (_) => _goToMove(i),
            ),
          );
        },
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.first_page),
            onPressed: _currentMoveIndex > -1 ? () => _goToMove(-1) : null,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentMoveIndex > -1
                ? () => _goToMove(_currentMoveIndex - 1)
                : null,
          ),
          Text(
            'Move ${_currentMoveIndex + 1}/${_moves.length}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentMoveIndex < _moves.length - 1
                ? () => _goToMove(_currentMoveIndex + 1)
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.last_page),
            onPressed: _currentMoveIndex < _moves.length - 1
                ? () => _goToMove(_moves.length - 1)
                : null,
          ),
        ],
      ),
    );
  }
}
