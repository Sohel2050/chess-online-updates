import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chess_app/services/daily_game_service.dart';

/// "Your turn" / "Waiting for X" / result banner of a daily game.
/// Your turn: green, glowing, pulsing bolt. Waiting: calm blue-grey, flipping
/// hourglass and moving dots. Under one hour left on my move: orange-red.
/// Finished: gold / red / grey with the result.
class DailyTurnBanner extends StatefulWidget {
  final DailyGame game;
  const DailyTurnBanner({super.key, required this.game});

  @override
  State<DailyTurnBanner> createState() => _DailyTurnBannerState();
}

class _DailyTurnBannerState extends State<DailyTurnBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant DailyTurnBanner old) {
    super.didUpdateWidget(old);
    final was = old.game.isActive && old.game.myTurn;
    final now = widget.game.isActive && widget.game.myTurn;
    if (!was && now) HapticFeedback.mediumImpact(); // it just became my turn
    _sync();
  }

  void _sync() {
    if (widget.game.isActive) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  bool get _low {
    final d = widget.game.turnDeadline;
    return widget.game.isActive && widget.game.myTurn && d != null && d.difference(DateTime.now()) < const Duration(hours: 1);
  }

  ({List<Color> colors, IconData icon, String title, String? sub, String key}) _look() {
    final g = widget.game;
    if (g.status == 'completed') {
      final w = g.winnerId;
      if (w == null || w.isEmpty) {
        return (colors: const [Color(0xFF607D8B), Color(0xFF37474F)], icon: Icons.handshake_rounded, title: 'Draw', sub: g.resultText, key: 'draw');
      }
      if (w == g.myId) {
        return (colors: const [Color(0xFFFFB300), Color(0xFFEF6C00)], icon: Icons.emoji_events_rounded, title: 'Victory!', sub: g.resultText, key: 'win');
      }
      return (colors: const [Color(0xFFE53935), Color(0xFF7F1D1D)], icon: Icons.heart_broken_rounded, title: 'Defeat', sub: g.resultText, key: 'lose');
    }
    if (g.isActive && g.myTurn) {
      if (_low) {
        return (colors: const [Color(0xFFFF7043), Color(0xFFB71C1C)], icon: Icons.bolt_rounded, title: 'Your turn', sub: 'Hurry, time is almost up', key: 'low');
      }
      return (colors: const [Color(0xFF43A047), Color(0xFF1B5E20)], icon: Icons.bolt_rounded, title: 'Your turn', sub: 'Make your move', key: 'mine');
    }
    if (g.isActive) {
      return (
        colors: const [Color(0xFF546E7A), Color(0xFF263238)],
        icon: Icons.hourglass_top_rounded,
        title: 'Waiting for ${g.opponentName}',
        sub: null,
        key: 'wait',
      );
    }
    return (colors: const [Color(0xFF78909C), Color(0xFF37474F)], icon: Icons.flag_rounded, title: 'Not started', sub: g.status, key: 'idle');
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    final look = _look();
    final mine = g.isActive && g.myTurn;
    final waiting = g.isActive && !g.myTurn;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final pulse = (math.sin(t * 2 * math.pi) + 1) / 2; // 0..1..0
        Widget icon = Icon(look.icon, color: Colors.white, size: 30);
        if (mine) {
          icon = Transform.scale(scale: 1 + 0.18 * pulse, child: icon);
        } else if (waiting) {
          final flips = (t * 2).floor();
          final phase = (t * 2) % 1;
          icon = Transform.rotate(angle: math.pi * (flips + Curves.easeInOutCubic.transform(phase)), child: icon);
        }
        final dots = waiting ? '.' * (1 + (t * 3).floor() % 3) : '';
        return AnimatedContainer(
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: look.colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: look.colors.first.withValues(alpha: mine ? 0.25 + 0.35 * pulse : 0.18),
                blurRadius: mine ? 10 + 16 * pulse : 8,
                spreadRadius: mine ? 2 * pulse : 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.2),
                border: Border.all(color: Colors.white.withValues(alpha: 0.45), width: 1.6),
              ),
              child: Center(child: icon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (c, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(a), child: c),
                ),
                layoutBuilder: (cur, prev) => Stack(alignment: Alignment.centerLeft, children: [...prev, if (cur != null) cur]),
                child: Column(
                  key: ValueKey(look.key),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(
                          look.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 0.3),
                        ),
                      ),
                      if (waiting)
                        SizedBox(
                          width: 22,
                          child: Text(dots, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                        ),
                    ]),
                    if (look.sub != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(look.sub!, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13)),
                      ),
                  ],
                ),
              ),
            ),
            if (g.isActive && g.timeLeftText.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.schedule_rounded, size: 15, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(g.timeLeftText, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
                ]),
              ),
            ],
          ]),
        );
      },
    );
  }
}

/// Rounded tonal action button with a press animation and an optional unread badge.
class DailyActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final int badge;

  const DailyActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    this.badge = 0,
  });

  @override
  State<DailyActionButton> createState() => _DailyActionButtonState();
}

class _DailyActionButtonState extends State<DailyActionButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final c = widget.color;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              widget.onPressed!();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? 0.94 : 1,
        duration: const Duration(milliseconds: 110),
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.45,
          duration: const Duration(milliseconds: 200),
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.withValues(alpha: 0.45), width: 1.4),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(widget.icon, color: c, size: 20),
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(widget.label, maxLines: 1, style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ]),
            ),
            if (widget.badge > 0)
              Positioned(
                top: -6,
                right: -4,
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(widget.badge),
                  tween: Tween(begin: 0.4, end: 1),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.elasticOut,
                  builder: (context, v, child) => Transform.scale(scale: v, child: child),
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      widget.badge > 9 ? '9+' : '${widget.badge}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
