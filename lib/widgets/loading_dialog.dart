import 'package:flutter_chess_app/utils/debug_log.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/services/user_service.dart';
import 'package:flutter_chess_app/widgets/animated_dialog.dart';

class LoadingDialog {
  static bool _isShowing = false;
  static bool get isShowing => _isShowing;
  static StreamSubscription? _onlineCountSubscription;
  static Timer? _cancelButtonDelayTimer;
  static late ValueNotifier<String> _messageNotifier;
  static late ValueNotifier<Widget?> _topWidgetNotifier;
  static late ValueNotifier<bool> _showOnlineCountNotifier;
  static late ValueNotifier<bool> _showCancelButtonNotifier;
  static VoidCallback? _onCancel;

  /// Optional countdown (seconds left) drawn as a ring with the number inside the spinner.
  /// Null = plain spinner. Reset automatically when the dialog is hidden.
  static final ValueNotifier<int?> countdown = ValueNotifier<int?>(null);
  static int countdownTotal = 30;
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

    dlog(
      '🔵 LoadingDialog.show() called - showCancelButton=$showCancelButton',
    );
    dlog(
      '🔵 Cancel button notifier set to: ${_showCancelButtonNotifier.value}',
    );

    // If cancel button should be shown, delay it
    if (showCancelButton) {
      dlog('🔵 Starting 4-second timer for cancel button...');
      dlog('🔵 Timer duration: $cancelButtonDelay');
      _isCancelButtonDelayActive = true; // Mark that we're in delay period
      _cancelButtonDelayTimer = Timer(cancelButtonDelay, () {
        dlog('🟢 Timer fired! Setting cancel button to visible');
        _isCancelButtonDelayActive = false; // Delay period is over
        if (_isShowing) {
          _showCancelButtonNotifier.value = true;
          dlog(
            '🟢 Cancel button notifier set to: ${_showCancelButtonNotifier.value}',
          );
        } else {
          dlog(
            '🟡 Dialog is no longer showing, skipping cancel button update',
          );
        }
      });
      dlog('🔵 Timer object created: $_cancelButtonDelayTimer');
    } else {
      dlog('🔵 showCancelButton is false, no timer scheduled');
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
                        dlog(
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
                            ValueListenableBuilder<int?>(
                              valueListenable: countdown,
                              builder: (context, left, _) {
                                if (left == null) {
                                  return const CircularProgressIndicator.adaptive();
                                }
                                return _SearchRing(left: left, total: countdownTotal);
                              },
                            ),
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
                              OutlinedButton.icon(
                                onPressed: () {
                                  _onCancel?.call();
                                  hide(context);
                                },
                                icon: const Icon(Icons.close, size: 18),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: BorderSide(
                                    color: Colors.red.withValues(alpha: 0.5),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 28,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                label: const Text('Cancel'),
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

    dlog(
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
      dlog(
        '🟠 Cancel button updated to: $showCancelButton (not in delay period)',
      );
    } else {
      dlog('🟠 Cancel button NOT updated (still in 4-second delay period)');
    }

    _onCancel = onCancel;
  }

  /// Hides the currently showing loading dialog
  static void hide(BuildContext context) {
    if (!_isShowing) return;
    _isShowing = false;
    countdown.value = null;
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
        final color = count > 0 ? Colors.green : Colors.grey;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                '$count players online',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


/// Pulsing countdown ring used while searching for an opponent.
class _SearchRing extends StatefulWidget {
  final int left;
  final int total;
  const _SearchRing({required this.left, required this.total});

  @override
  State<_SearchRing> createState() => _SearchRingState();
}

class _SearchRingState extends State<_SearchRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final urgent = widget.left <= 5;
    final color = urgent ? Colors.orange : cs.primary;
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Expanding radar-like wave
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final t = _pulse.value;
              return Container(
                width: 84 + 36 * t,
                height: 84 + 36 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withValues(alpha: 0.35 * (1 - t)),
                    width: 3,
                  ),
                ),
              );
            },
          ),
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.08),
            ),
          ),
          SizedBox(
            width: 84,
            height: 84,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: (widget.left / widget.total).clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 900),
              builder: (context, v, _) => CircularProgressIndicator(
                value: v,
                strokeWidth: 6,
                strokeCap: StrokeCap.round,
                color: color,
                backgroundColor: color.withValues(alpha: 0.15),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${widget.left}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1,
                ),
              ),
              Text(
                'sec',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
