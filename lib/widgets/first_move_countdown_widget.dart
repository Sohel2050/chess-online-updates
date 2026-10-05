import 'dart:async';
import 'package:flutter/material.dart';
import 'package:squares/squares.dart';

class FirstMoveCountdownWidget extends StatefulWidget {
  final bool isVisible;
  final VoidCallback? onTimeout;
  final int initialSeconds;
  final int playerToMove;
  final VoidCallback? onTimerTick;

  const FirstMoveCountdownWidget({
    super.key,
    required this.isVisible,
    this.onTimeout,
    this.initialSeconds = 30,
    required this.playerToMove,
    this.onTimerTick,
  });

  @override
  State<FirstMoveCountdownWidget> createState() =>
      _FirstMoveCountdownWidgetState();
}

class _FirstMoveCountdownWidgetState extends State<FirstMoveCountdownWidget> {
  Timer? _timer;
  int _remainingSeconds = 30;
  Set<int> _playedTimerSounds = {};

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.initialSeconds;
    if (widget.isVisible) {
      _startCountdown();
    }
  }

  @override
  void didUpdateWidget(FirstMoveCountdownWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reset countdown if visibility becomes true (from false or same) or player changes
    if (widget.isVisible) {
      // Restart if:
      // 1. Visibility changed from false to true
      // 2. Player to move changed
      // 3. Timer has ended but widget is still visible (need to show again)
      if (!oldWidget.isVisible ||
          widget.playerToMove != oldWidget.playerToMove ||
          _remainingSeconds <= 0) {
        _remainingSeconds = widget.initialSeconds;
        _startCountdown();
      }
    } else if (oldWidget.isVisible) {
      // Stop countdown when visibility becomes false
      _stopCountdown();
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    _playedTimerSounds.clear(); // Clear played sounds for new countdown
    final playerName = widget.playerToMove == Squares.white ? 'White' : 'Black';
    print('⏱️ COUNTDOWN START: $playerName player - 30 seconds');
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _remainingSeconds--;
        });

        // Play timer tick sound for last 10 seconds (once per second)
        if (_remainingSeconds <= 10 && _remainingSeconds > 0) {
          if (!_playedTimerSounds.contains(_remainingSeconds)) {
            _playedTimerSounds.add(_remainingSeconds);
            widget.onTimerTick?.call();
          }
        }

        if (_remainingSeconds <= 0) {
          _stopCountdown();
          print('⏱️ COUNTDOWN TIMEOUT: $playerName - timeout triggered');
          widget.onTimeout?.call();
        }
      }
    });
  }

  void _stopCountdown() {
    _timer?.cancel();
    _timer = null;
    _playedTimerSounds.clear();
    print('⏱️ COUNTDOWN STOP');
  }

  @override
  void dispose() {
    _stopCountdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible || _remainingSeconds <= 0) {
      if (widget.isVisible) {
        print(
          '⏱️ COUNTDOWN WIDGET: Hidden (remainingSeconds=$_remainingSeconds)',
        );
      }
      return const SizedBox.shrink();
    }

    final playerName = widget.playerToMove == Squares.white ? 'White' : 'Black';
    final color = widget.playerToMove == Squares.white
        ? Colors.orange
        : Colors.red;

    print(
      '⏱️ COUNTDOWN WIDGET: Showing for $playerName - $_remainingSeconds seconds remaining',
    );

    return Container(
      margin: const EdgeInsets.all(8.0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, size: 16, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            '$playerName must move in $_remainingSeconds seconds',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
