import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

/// Utility class for handling puzzle-related errors with user-friendly messages
class PuzzleErrorHandler {
  static final Logger _logger = Logger();

  /// Show a user-friendly error message for puzzle loading failures
  static void showPuzzleLoadError(
    BuildContext context, {
    String? customMessage,
    VoidCallback? onRetry,
  }) {
    final message =
        customMessage ?? 'Failed to load puzzles. Please try again.';

    _logger.e('Puzzle load error: $message');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        duration: const Duration(seconds: 4),
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  /// Show error for puzzle data corruption or parsing issues
  static void showPuzzleDataError(
    BuildContext context, {
    String? puzzleId,
    VoidCallback? onRetry,
  }) {
    final message = puzzleId != null
        ? 'Puzzle $puzzleId has invalid data'
        : 'Puzzle data is corrupted or invalid';

    _logger.e('Puzzle data error: $message');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange[600],
        duration: const Duration(seconds: 3),
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  /// Show error for network or storage issues
  static void showStorageError(
    BuildContext context, {
    String? operation,
    VoidCallback? onRetry,
  }) {
    final message = operation != null
        ? 'Failed to $operation. Check your connection.'
        : 'Storage error occurred. Please try again.';

    _logger.e('Storage error: $message');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.cloud_off, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue[600],
        duration: const Duration(seconds: 4),
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  /// Show error dialog for critical puzzle failures
  static Future<void> showCriticalErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    VoidCallback? onRetry,
    VoidCallback? onCancel,
  }) async {
    _logger.e('Critical puzzle error: $title - $message');

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: Icon(Icons.error_outline, color: Colors.red[600], size: 48),
          title: Text(title),
          content: Text(message),
          actions: [
            if (onCancel != null)
              TextButton(onPressed: onCancel, child: const Text('Cancel')),
            if (onRetry != null)
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            if (onRetry == null && onCancel == null)
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
          ],
        );
      },
    );
  }

  /// Show loading indicator with error handling
  static void showLoadingWithErrorHandling(
    BuildContext context, {
    required String message,
    required Future<void> operation,
    VoidCallback? onSuccess,
    VoidCallback? onError,
  }) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );

    try {
      await operation;
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        onSuccess?.call();
      }
    } catch (e) {
      _logger.e('Operation failed: $e');
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        showPuzzleLoadError(context, customMessage: e.toString());
        onError?.call();
      }
    }
  }

  /// Get user-friendly error message from exception
  static String getErrorMessage(dynamic error) {
    if (error == null) return 'Unknown error occurred';

    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'Network connection error. Please check your internet connection.';
    } else if (errorString.contains('timeout')) {
      return 'Operation timed out. Please try again.';
    } else if (errorString.contains('permission')) {
      return 'Permission denied. Please check app permissions.';
    } else if (errorString.contains('storage') ||
        errorString.contains('file')) {
      return 'Storage error. Please check available space.';
    } else if (errorString.contains('json') || errorString.contains('parse')) {
      return 'Data format error. Puzzle data may be corrupted.';
    } else if (errorString.contains('fen') ||
        errorString.contains('position')) {
      return 'Invalid chess position. Puzzle data may be corrupted.';
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Handle specific puzzle service errors
  static void handlePuzzleServiceError(
    BuildContext context,
    dynamic error, {
    VoidCallback? onRetry,
  }) {
    final userFriendlyMessage = getErrorMessage(error);
    showPuzzleLoadError(
      context,
      customMessage: userFriendlyMessage,
      onRetry: onRetry,
    );
  }

  /// Show fallback message when no puzzles are available
  static void showNoPuzzlesAvailable(
    BuildContext context, {
    String? difficulty,
    VoidCallback? onRetry,
  }) {
    final message = difficulty != null
        ? 'No puzzles available for $difficulty difficulty'
        : 'No puzzles available at the moment';

    _logger.w('No puzzles available: $message');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue[600],
        duration: const Duration(seconds: 3),
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }
}
