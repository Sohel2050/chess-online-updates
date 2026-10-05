import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/services/user_service.dart';
import 'package:flutter_chess_app/widgets/animated_dialog.dart';

class LoadingDialog {
  static bool _isShowing = false;
  static StreamSubscription? _onlineCountSubscription;
  static Timer? _cancelButtonDelayTimer;
  static late ValueNotifier<String> _messageNotifier;
  static late ValueNotifier<Widget?> _topWidgetNotifier;
  static late ValueNotifier<bool> _showOnlineCountNotifier;
  static late ValueNotifier<bool> _showCancelButtonNotifier;
  static VoidCallback? _onCancel;
  static bool _isCancelButtonDelayActive =
      false; // Track if we're in delay period

  /// Initialize fresh notifiers for each new dialog
  static void _initializeNotifiers() {
    _messageNotifier = ValueNotifier<String>('Loading...');
    _topWidgetNotifier = ValueNotifier<Widget?>(null);
    _showOnlineCountNotifier = ValueNotifier<bool>(false);
    _showCancelButtonNotifier = ValueNotifier<bool>(false);
  }

  /// Shows a loading dialog with a spinner, optional message, and optional widget
  static void show(
    BuildContext context, {
    String message = 'Loading...',
    bool barrierDismissible = false,
    double? maxWidth,
    Widget? topWidget,
    bool showOnlineCount = false,
    bool showCancelButton = false,
    Duration cancelButtonDelay = const Duration(seconds: 4),
    VoidCallback? onCancel,
  }) {
    if (_isShowing) return;
    _isShowing = true;

    // Cancel any existing delay timer
    _cancelButtonDelayTimer?.cancel();

    // Initialize fresh notifiers for this dialog
    _initializeNotifiers();

    // Set initial values
    _messageNotifier.value = message;
    _topWidgetNotifier.value = topWidget;
    _showOnlineCountNotifier.value = showOnlineCount;
    _showCancelButtonNotifier.value = false; // Always start hidden
    _onCancel = onCancel;

    print(
      '🔵 LoadingDialog.show() called - showCancelButton=$showCancelButton',
    );
    print(
      '🔵 Cancel button notifier set to: ${_showCancelButtonNotifier.value}',
    );

    // If cancel button should be shown, delay it
    if (showCancelButton) {
      print('🔵 Starting 4-second timer for cancel button...');
      print('🔵 Timer duration: $cancelButtonDelay');
      _isCancelButtonDelayActive = true; // Mark that we're in delay period
      _cancelButtonDelayTimer = Timer(cancelButtonDelay, () {
        print('🟢 Timer fired! Setting cancel button to visible');
        _isCancelButtonDelayActive = false; // Delay period is over
        if (_isShowing) {
          _showCancelButtonNotifier.value = true;
          print(
            '🟢 Cancel button notifier set to: ${_showCancelButtonNotifier.value}',
          );
        } else {
          print(
            '🟡 Dialog is no longer showing, skipping cancel button update',
          );
        }
      });
      print('🔵 Timer object created: $_cancelButtonDelayTimer');
    } else {
      print('🔵 showCancelButton is false, no timer scheduled');
      _isCancelButtonDelayActive = false;
    }

    AnimatedDialog.show(
      context: context,
      maxWidth: maxWidth,
      barrierDismissible: barrierDismissible,
      child: PopScope(
        canPop: false,
        child: ValueListenableBuilder<String>(
          valueListenable: _messageNotifier,
          builder: (context, message, child) {
            return ValueListenableBuilder<Widget?>(
              valueListenable: _topWidgetNotifier,
              builder: (context, topWidget, child) {
                return ValueListenableBuilder<bool>(
                  valueListenable: _showOnlineCountNotifier,
                  builder: (context, showOnlineCount, child) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: _showCancelButtonNotifier,
                      builder: (context, isCancelButtonVisible, child) {
                        print(
                          '🔴 Cancel button builder rebuild - isCancelButtonVisible=$isCancelButtonVisible',
                        );
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Show custom widget if provided
                            if (topWidget != null) ...[
                              topWidget,
                              const SizedBox(height: 16),
                            ],
                            // Show online players count if enabled
                            if (showOnlineCount) ...[
                              _OnlinePlayersWidget(),
                              const SizedBox(height: 16),
                            ],
                            // Loading spinner and message
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Text(
                                message,
                                key: ValueKey(message),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            // Cancel button if enabled
                            if (isCancelButtonVisible) ...[
                              const SizedBox(height: 20),
                              TextButton(
                                onPressed: () {
                                  _onCancel?.call();
                                  hide(context);
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('Cancel'),
                              ),
                            ],
                          ],
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
    );
  }

  /// Updates the message of the currently showing dialog
  static void updateMessage(
    BuildContext context,
    String message, {
    Widget? topWidget,
    bool showOnlineCount = false,
    bool showCancelButton = false,
    VoidCallback? onCancel,
  }) {
    if (!_isShowing) return;

    print(
      '🟠 updateMessage called - showCancelButton=$showCancelButton, _isCancelButtonDelayActive=$_isCancelButtonDelayActive',
    );

    // Update the notifiers to smoothly change the content
    _messageNotifier.value = message;
    if (topWidget != null) {
      _topWidgetNotifier.value = topWidget;
    }
    _showOnlineCountNotifier.value = showOnlineCount;

    // Only update cancel button if NOT in delay period
    if (!_isCancelButtonDelayActive) {
      _showCancelButtonNotifier.value = showCancelButton;
      print(
        '🟠 Cancel button updated to: $showCancelButton (not in delay period)',
      );
    } else {
      print('🟠 Cancel button NOT updated (still in 4-second delay period)');
    }

    _onCancel = onCancel;
  }

  /// Hides the currently showing loading dialog
  static void hide(BuildContext context) {
    if (!_isShowing) return;
    _isShowing = false;
    _isCancelButtonDelayActive = false;
    _onlineCountSubscription?.cancel();
    _onlineCountSubscription = null;
    _cancelButtonDelayTimer?.cancel();
    _cancelButtonDelayTimer = null;
    _onCancel = null;
    Navigator.of(context, rootNavigator: true).pop();
  }

  /// Shows a loading dialog that automatically dismisses after specified duration
  static Future<void> showWithTimeout(
    BuildContext context, {
    String message = 'Loading...',
    Duration timeout = const Duration(seconds: 10),
    Widget? topWidget,
    bool showOnlineCount = false,
    bool showCancelButton = false,
    Duration cancelButtonDelay = const Duration(seconds: 4),
    VoidCallback? onCancel,
  }) async {
    show(
      context,
      message: message,
      topWidget: topWidget,
      showOnlineCount: showOnlineCount,
      showCancelButton: showCancelButton,
      cancelButtonDelay: cancelButtonDelay,
      onCancel: onCancel,
    );
    await Future.delayed(timeout);
    if (_isShowing && context.mounted) {
      hide(context);
    }
  }
}

class _OnlinePlayersWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final userService = UserService();

    return StreamBuilder<int>(
      stream: userService.getOnlinePlayersCountStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Error loading online count');
        }

        final count = snapshot.data ?? 0;
        return Column(
          children: [
            Icon(
              Icons.people,
              size: 32,
              color: count > 0 ? Colors.green : Colors.grey,
            ),
            const SizedBox(height: 8),
            Text(
              '$count players online',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        );
      },
    );
  }
}
