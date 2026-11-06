import 'package:flutter/material.dart';
import '../models/puzzle_model.dart';
import '../providers/puzzle_provider.dart';
import 'animated_dialog.dart';

/// Dialog shown when a puzzle is successfully completed.
///
/// Header with an animated check badge and a 1-3 star rating (based on the
/// hints used), three stat tiles (time, hints, puzzle rating), achievement
/// pills and a gradient primary button. Same public API as before.
class PuzzleCompletionDialog extends StatelessWidget {
  final PuzzleSession session;
  final VoidCallback onRetry;
  final VoidCallback onNextPuzzle;
  final bool hasNextPuzzle;

  const PuzzleCompletionDialog({
    super.key,
    required this.session,
    required this.onRetry,
    required this.onNextPuzzle,
    required this.hasNextPuzzle,
  });

  static const Color _greenDark = Color(0xFF1B5E20);
  static const Color _greenMid = Color(0xFF2E7D32);
  static const Color _greenLight = Color(0xFF66BB6A);
  static const Color _gold = Color(0xFFFFC107);

  /// Show the puzzle completion dialog
  static Future<PuzzleCompletionAction?> show({
    required BuildContext context,
    required PuzzleSession session,
    required bool hasNextPuzzle,
  }) {
    return AnimatedDialog.show<PuzzleCompletionAction>(
      context: context,
      barrierDismissible: false,
      showCloseButton: false,
      contentPadding: EdgeInsets.zero,
      maxWidth: 420,
      child: PuzzleCompletionDialog(
        session: session,
        hasNextPuzzle: hasNextPuzzle,
        onRetry: () => Navigator.of(context).pop(PuzzleCompletionAction.retry),
        onNextPuzzle: () =>
            Navigator.of(context).pop(PuzzleCompletionAction.nextPuzzle),
      ),
    );
  }

  int get _stars {
    if (session.hintsUsed == 0) return 3;
    if (session.hintsUsed == 1) return 2;
    return 1;
  }

  String get _headline {
    switch (_stars) {
      case 3:
        return 'Flawless! No hints needed.';
      case 2:
        return 'Nice work! Just one hint.';
      default:
        return 'Solved! Try with fewer hints next time.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.88),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            _buildBody(context),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- header

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final puzzle = session.puzzle;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_greenDark, _greenMid, _greenLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Soft decorative circles
          Positioned(
            top: -40,
            right: -30,
            child: _circle(130, Colors.white.withValues(alpha: 0.08)),
          ),
          Positioned(
            bottom: -50,
            left: -40,
            child: _circle(150, Colors.white.withValues(alpha: 0.07)),
          ),
          Positioned(
            top: 30,
            left: 24,
            child: _circle(14, Colors.white.withValues(alpha: 0.18)),
          ),
          Positioned(
            top: 60,
            right: 40,
            child: _circle(10, Colors.white.withValues(alpha: 0.2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
            child: Column(
              children: [
                // Animated check badge
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) =>
                      Transform.scale(scale: value, child: child),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: _greenMid,
                        size: 52,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Stars
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    final filled = i < _stars;
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 500 + i * 250),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) =>
                          Transform.scale(scale: value, child: child),
                      child: Padding(
                        padding: EdgeInsets.only(top: i == 1 ? 0 : 6),
                        child: Icon(
                          filled
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: i == 1 ? 44 : 36,
                          color: filled
                              ? _gold
                              : Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 6),

                Text(
                  'Puzzle Solved!',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _headline,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _headerChip(Icons.flag_rounded, puzzle.difficulty.displayName),
                    _headerChip(Icons.trending_up_rounded, '${puzzle.rating}'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circle(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );

  Widget _headerChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ body

  Widget _buildBody(BuildContext context) {
    final puzzle = session.puzzle;
    final hintsTotal = puzzle.effectiveHintCount;
    final fast = session.solveTime.inSeconds < 30;
    final perfect = session.hintsUsed == 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _statTile(
                  context,
                  icon: Icons.timer_rounded,
                  value: _formatDuration(session.solveTime),
                  label: 'Time',
                  color: const Color(0xFF1E88E5),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statTile(
                  context,
                  icon: Icons.lightbulb_rounded,
                  value: '${session.hintsUsed}/$hintsTotal',
                  label: 'Hints',
                  color: perfect ? const Color(0xFF43A047) : const Color(0xFFFFA000),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statTile(
                  context,
                  icon: Icons.emoji_events_rounded,
                  value: '${puzzle.rating}',
                  label: 'Rating',
                  color: const Color(0xFF8E24AA),
                ),
              ),
            ],
          ),
          if (perfect || fast) ...[
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (perfect)
                  _pill(
                    Icons.workspace_premium_rounded,
                    'Perfect solution',
                    const Color(0xFF2E7D32),
                  ),
                if (fast)
                  _pill(
                    Icons.bolt_rounded,
                    'Lightning fast',
                    const Color(0xFFEF6C00),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statTile(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- actions

  Widget _buildActions(BuildContext context) {
    final theme = Theme.of(context);
    final primaryLabel = hasNextPuzzle ? 'Next Puzzle' : 'Try Again';
    final primaryIcon =
        hasNextPuzzle ? Icons.arrow_forward_rounded : Icons.refresh_rounded;
    final primaryAction = hasNextPuzzle ? onNextPuzzle : onRetry;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Gradient primary button
          Material(
            color: Colors.transparent,
            child: Ink(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_greenMid, _greenLight],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _greenMid.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: InkWell(
                onTap: primaryAction,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        primaryLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(primaryIcon, color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Retry is a secondary action only when "Next" is the primary one.
          if (hasNextPuzzle) ...[
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry this puzzle'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurfaceVariant,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;

    if (minutes > 0) {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${seconds}s';
    }
  }
}

/// Actions that can be taken from the puzzle completion dialog
enum PuzzleCompletionAction { retry, nextPuzzle }
