import 'package:flutter/material.dart';
import 'package:flutter_chess_app/services/analytics_service.dart';
import 'package:provider/provider.dart';
import '../models/puzzle_model.dart';
import '../providers/puzzle_provider.dart';
import '../providers/user_provider.dart';
import '../utils/puzzle_error_handler.dart';
import '../widgets/puzzle_loading_widget.dart';
import 'puzzle_board_screen.dart';
import 'puzzle_rated_screen.dart';
import 'my_blunders_screen.dart';

class PuzzlesScreen extends StatefulWidget {
  const PuzzlesScreen({super.key});

  @override
  State<PuzzlesScreen> createState() => _PuzzlesScreenState();
}

class _PuzzlesScreenState extends State<PuzzlesScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.screen('puzzles');
    // Use post-frame callback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializePuzzles();
      }
    });
  }

  void _initializePuzzles() async {
    try {
      final puzzleProvider = context.read<PuzzleProvider>();
      final userProvider = context.read<UserProvider>();

      // Initialize with user ID if available
      // Guests have no uid: use a fixed local id so their puzzle progress
      // is still saved on the device and survives closing the app.
      final rawUid = userProvider.user?.uid;
      final userId = (rawUid != null && rawUid.isNotEmpty)
          ? rawUid
          : 'guest_local';
      await puzzleProvider.initialize(userId: userId);
    } catch (e) {
      if (mounted) {
        PuzzleErrorHandler.handlePuzzleServiceError(
          context,
          e,
          onRetry: _initializePuzzles,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chess Puzzles'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _showResetConfirmationDialog(context),
            tooltip: 'Reset all puzzle progress',
          ),
        ],
      ),
      body: Consumer<PuzzleProvider>(
        builder: (context, puzzleProvider, child) {
          // Show loading state
          if (puzzleProvider.isLoading || puzzleProvider.isInitializing) {
            return PuzzleLoadingWidget(
              message: puzzleProvider.isInitializing
                  ? 'Initializing puzzles...'
                  : 'Loading puzzles...',
              showRetry: false,
            );
          }

          // Show error state
          if (puzzleProvider.errorMessage != null) {
            return PuzzleErrorWidget(
              title: 'Failed to Load Puzzles',
              message: puzzleProvider.errorMessage!,
              onRetry: () async {
                await puzzleProvider.retryInitialization();
              },
              onCancel: () => Navigator.of(context).pop(),
            );
          }

          // Check if puzzles are available
          if (!puzzleProvider.hasInitialized) {
            return PuzzleErrorWidget(
              title: 'Puzzles Not Available',
              message: 'Puzzles have not been initialized yet.',
              onRetry: _initializePuzzles,
              onCancel: () => Navigator.of(context).pop(),
            );
          }

          // Check if any puzzles exist
          final totalPuzzles = PuzzleDifficulty.values.fold<int>(
            0,
            (sum, difficulty) =>
                sum + puzzleProvider.getPuzzlesForDifficulty(difficulty).length,
          );

          if (totalPuzzles == 0) {
            return PuzzleEmptyWidget(
              title: 'No Puzzles Available',
              message:
                  'There are no puzzles available at the moment. Please try again later.',
              onRetry: _initializePuzzles,
              onBack: () => Navigator.of(context).pop(),
            );
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (puzzleProvider.usingOfflinePuzzles) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.cloud_off_rounded, color: Colors.orange),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Could not load puzzles from the server, showing offline puzzles. '
                              '${puzzleProvider.puzzleLoadError ?? ''}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          TextButton(
                            onPressed: () => puzzleProvider.retryInitialization(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Two compact shortcut tiles side by side
                  Row(
                    children: [
                      Expanded(
                        child: _buildShortcutTile(
                          context,
                          icon: Icons.emoji_events_outlined,
                          label: 'Rated',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PuzzleRatedScreen(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildShortcutTile(
                          context,
                          icon: Icons.psychology_alt_outlined,
                          label: 'My blunders',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const MyBlundersScreen(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Difficulty cards
                  Expanded(
                    child: ListView.builder(
                      itemCount: PuzzleDifficulty.values.length + 1,
                      itemBuilder: (context, index) {
                        if (index == PuzzleDifficulty.values.length) {
                          return _buildLoadMore(context, puzzleProvider);
                        }
                        final difficulty = PuzzleDifficulty.values[index];
                        return _buildDifficultyCard(
                          context,
                          difficulty,
                          puzzleProvider,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// "Load More" button below the difficulty cards: loads the next page of
  /// puzzles from the server. Hidden when there is nothing more to load.
  Widget _buildLoadMore(BuildContext context, PuzzleProvider puzzleProvider) {
    if (!puzzleProvider.hasMorePuzzles) return const SizedBox(height: 16);
    final loading = puzzleProvider.isLoadingMorePuzzles;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: OutlinedButton.icon(
        onPressed: loading
            ? null
            : () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final added = await puzzleProvider.loadMorePuzzles();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        added > 0
                            ? 'Loaded $added more puzzles'
                            : 'No more puzzles to load',
                      ),
                    ),
                  );
                } catch (_) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Could not load more puzzles. Please try again.'),
                    ),
                  );
                }
              },
        icon: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.expand_more),
        label: Text(loading ? 'Loading...' : 'Load More'),
      ),
    );
  }

  Widget _buildShortcutTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 22, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyCard(
    BuildContext context,
    PuzzleDifficulty difficulty,
    PuzzleProvider puzzleProvider,
  ) {
    final puzzles = puzzleProvider.getPuzzlesForDifficulty(difficulty);
    final progress = puzzleProvider.getProgressForDifficulty(difficulty);
    final completionPercentage = puzzleProvider.getCompletionPercentage(
      difficulty,
    );
    final completedCount = progress.where((p) => p.completed).length;
    final totalCount = puzzles.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () =>
              _onDifficultySelected(context, difficulty, puzzleProvider),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: _getDifficultyGradient(difficulty),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Difficulty info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            difficulty.displayName,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Rating: ${difficulty.ratingRange}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                          ),
                        ],
                      ),
                    ),

                    // Difficulty icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getDifficultyIcon(difficulty),
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Progress section
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$completedCount / $totalCount puzzles',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          const SizedBox(height: 8),

                          // Progress bar
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: totalCount > 0
                                  ? completedCount / totalCount
                                  : 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Completion percentage
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$completionPercentage%',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  LinearGradient _getDifficultyGradient(PuzzleDifficulty difficulty) {
    switch (difficulty) {
      case PuzzleDifficulty.beginner:
        return const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case PuzzleDifficulty.easy:
        return const LinearGradient(
          colors: [Color(0xFF2196F3), Color(0xFF42A5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case PuzzleDifficulty.medium:
        return const LinearGradient(
          colors: [Color(0xFFFF9800), Color(0xFFFFB74D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case PuzzleDifficulty.hard:
        return const LinearGradient(
          colors: [Color(0xFFE91E63), Color(0xFFF06292)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case PuzzleDifficulty.expert:
        return const LinearGradient(
          colors: [Color(0xFF9C27B0), Color(0xFFBA68C8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  IconData _getDifficultyIcon(PuzzleDifficulty difficulty) {
    switch (difficulty) {
      case PuzzleDifficulty.beginner:
        return Icons.school;
      case PuzzleDifficulty.easy:
        return Icons.thumb_up;
      case PuzzleDifficulty.medium:
        return Icons.trending_up;
      case PuzzleDifficulty.hard:
        return Icons.local_fire_department;
      case PuzzleDifficulty.expert:
        return Icons.emoji_events;
    }
  }

  void _onDifficultySelected(
    BuildContext context,
    PuzzleDifficulty difficulty,
    PuzzleProvider puzzleProvider,
  ) async {
    try {
      // Show loading indicator for puzzle selection
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator.adaptive(),
              SizedBox(height: 16),
              Text('Loading puzzle...'),
            ],
          ),
        ),
      );

      // Get the first unsolved puzzle for this difficulty
      final puzzle = await puzzleProvider.getFirstUnsolvedPuzzle(difficulty);

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (puzzle == null) {
        if (context.mounted) {
          PuzzleErrorHandler.showNoPuzzlesAvailable(
            context,
            difficulty: difficulty.displayName,
            onRetry: () =>
                _onDifficultySelected(context, difficulty, puzzleProvider),
          );
        }
        return;
      }

      // Navigate to puzzle board screen
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PuzzleBoardScreen(puzzle: puzzle),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (context.mounted) {
        Navigator.of(context).pop();
        PuzzleErrorHandler.handlePuzzleServiceError(
          context,
          e,
          onRetry: () =>
              _onDifficultySelected(context, difficulty, puzzleProvider),
        );
      }
    }
  }

  void _showResetConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFD32F2F),
            size: 36,
          ),
          title: const Text('Reset All Progress'),
          content: const Text(
            'Are you sure you want to reset and clear all saved puzzle progress? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    ).then((confirmed) {
      if (confirmed == true) {
        _resetAllPuzzles(context);
      }
    });
  }

  void _resetAllPuzzles(BuildContext context) async {
    try {
      final puzzleProvider = context.read<PuzzleProvider>();
      final userProvider = context.read<UserProvider>();

      // Check if user is logged in
      final userId = userProvider.user?.uid;
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to reset progress'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator.adaptive(),
              SizedBox(height: 16),
              Text('Resetting progress...'),
            ],
          ),
        ),
      );

      // Clear all puzzle progress
      await puzzleProvider.clearAllPuzzleProgress(userId);

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All puzzle progress has been reset'),
            backgroundColor: Colors.green,
          ),
        );

        // Reinitialize puzzles to reflect the reset
        _initializePuzzles();
      }
    } catch (e) {
      // Close loading dialog if still open
      if (context.mounted) {
        Navigator.of(context).pop();

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reset progress: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
