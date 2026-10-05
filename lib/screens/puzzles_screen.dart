import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/puzzle_model.dart';
import '../providers/puzzle_provider.dart';
import '../providers/user_provider.dart';
import '../utils/puzzle_error_handler.dart';
import '../widgets/puzzle_loading_widget.dart';
import 'puzzle_board_screen.dart';

class PuzzlesScreen extends StatefulWidget {
  const PuzzlesScreen({super.key});

  @override
  State<PuzzlesScreen> createState() => _PuzzlesScreenState();
}

class _PuzzlesScreenState extends State<PuzzlesScreen> {
  @override
  void initState() {
    super.initState();
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
      final userId = userProvider.user?.isGuest == false
          ? userProvider.user?.uid
          : null;
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
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header section
                  Text(
                    'Choose Difficulty',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Practice tactical chess problems to improve your skills',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Difficulty cards
                  Expanded(
                    child: ListView.builder(
                      itemCount: PuzzleDifficulty.values.length,
                      itemBuilder: (context, index) {
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
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () =>
              _onDifficultySelected(context, difficulty, puzzleProvider),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getDifficultyIcon(difficulty),
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

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
                        horizontal: 12,
                        vertical: 6,
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
              CircularProgressIndicator(),
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
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
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
              CircularProgressIndicator(),
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
