import 'package:flutter/material.dart';
import '../models/puzzle_model.dart';
import '../providers/puzzle_provider.dart';
import 'animated_dialog.dart';

/// Dialog shown when a puzzle is successfully completed
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

  /// Show the puzzle completion dialog
  static Future<PuzzleCompletionAction?> show({
    required BuildContext context,
    required PuzzleSession session,
    required bool hasNextPuzzle,
  }) {
    return AnimatedDialog.show<PuzzleCompletionAction>(
      context: context,
      barrierDismissible: false,
      child: PuzzleCompletionDialog(
        session: session,
        hasNextPuzzle: hasNextPuzzle,
        onRetry: () => Navigator.of(context).pop(PuzzleCompletionAction.retry),
        onNextPuzzle: () =>
            Navigator.of(context).pop(PuzzleCompletionAction.nextPuzzle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final isSmallScreen = screenHeight < 700;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.85, // Limit dialog to 85% of screen height
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success header with icon
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade400, Colors.green.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: isSmallScreen ? 36 : 48,
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  Text(
                    'Puzzle Solved!',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isSmallScreen ? 20 : null,
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 6 : 8),
                  Text(
                    'Congratulations! You successfully solved this ${session.puzzle.difficulty.displayName.toLowerCase()} puzzle.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: isSmallScreen ? 13 : null,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Statistics section
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Performance',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: isSmallScreen ? 16 : null,
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),

                  // Statistics cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          context: context,
                          icon: Icons.timer,
                          label: 'Solve Time',
                          value: _formatDuration(session.solveTime),
                          color: Colors.blue,
                          isSmallScreen: isSmallScreen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          context: context,
                          icon: Icons.lightbulb,
                          label: 'Hints Used',
                          value:
                              '${session.hintsUsed}/${session.puzzle.hints.length}',
                          color: session.hintsUsed == 0
                              ? Colors.green
                              : Colors.amber,
                          isSmallScreen: isSmallScreen,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: isSmallScreen ? 12 : 16),

                  // Achievement badges - only show if not small screen or limit to one
                  if (session.hintsUsed == 0) ...[
                    _buildAchievementBadge(
                      context: context,
                      icon: Icons.star,
                      title: 'Perfect Solution!',
                      description:
                          'You solved this puzzle without using any hints.',
                      color: Colors.green,
                      isSmallScreen: isSmallScreen,
                    ),
                    SizedBox(height: isSmallScreen ? 8 : 16),
                  ],

                  // Fast solve achievement - only show if no perfect solution or not small screen
                  if (session.solveTime.inSeconds < 30 &&
                      (!isSmallScreen || session.hintsUsed > 0)) ...[
                    _buildAchievementBadge(
                      context: context,
                      icon: Icons.flash_on,
                      title: 'Lightning Fast!',
                      description:
                          'You solved this puzzle in under 30 seconds.',
                      color: Colors.orange,
                      isSmallScreen: isSmallScreen,
                    ),
                    SizedBox(height: isSmallScreen ? 8 : 16),
                  ],
                ],
              ),
            ),

            // Action buttons
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                isSmallScreen ? 16 : 24,
                0,
                isSmallScreen ? 16 : 24,
                isSmallScreen ? 16 : 24,
              ),
              child: Column(
                children: [
                  // Primary action button (Next Puzzle or Retry)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: hasNextPuzzle ? onNextPuzzle : onRetry,
                      icon: Icon(
                        hasNextPuzzle ? Icons.arrow_forward : Icons.refresh,
                        size: isSmallScreen ? 18 : null,
                      ),
                      label: Text(
                        hasNextPuzzle ? 'Next Puzzle' : 'Try Another Puzzle',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: EdgeInsets.symmetric(
                          vertical: isSmallScreen ? 12 : 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: isSmallScreen ? 8 : 12),

                  // Secondary actions row
                  Row(
                    children: [
                      // Retry button (always available)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Retry'),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: isSmallScreen ? 8 : 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      // Next puzzle button (if available and not primary action)
                      if (hasNextPuzzle) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onNextPuzzle,
                            icon: const Icon(Icons.arrow_forward, size: 18),
                            label: const Text('Next'),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                vertical: isSmallScreen ? 8 : 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementBadge({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required bool isSmallScreen,
  }) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: isSmallScreen ? 16 : 20),
          ),
          SizedBox(width: isSmallScreen ? 8 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: color.withValues(alpha: 0.85),
                    fontWeight: FontWeight.bold,
                    fontSize: isSmallScreen ? 12 : null,
                  ),
                ),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color.withValues(alpha: 0.7),
                    fontSize: isSmallScreen ? 11 : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isSmallScreen,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: isSmallScreen ? 16 : 20),
          ),
          SizedBox(height: isSmallScreen ? 6 : 8),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color.withValues(alpha: 0.8),
              fontSize: isSmallScreen ? 14 : null,
            ),
          ),
          SizedBox(height: isSmallScreen ? 2 : 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: isSmallScreen ? 10 : null,
            ),
            textAlign: TextAlign.center,
          ),
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
