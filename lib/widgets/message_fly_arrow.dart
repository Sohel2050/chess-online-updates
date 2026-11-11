import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A thin arrow that leaves [from], glides to [to] with a classic ease-in-out motion
/// (head first, the tail follows a moment later) and vanishes into the target.
/// Same idea as the puzzle hint arrow. Ignores touches, removes itself when done.
class MessageFlyArrow {
  static void show(
    OverlayState overlay, {
    required Offset from,
    required Offset to,
    Color color = const Color(0xFF22C55E),
  }) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: _FlyArrow(
          from: from,
          to: to,
          color: color,
          onDone: () {
            if (entry.mounted) entry.remove();
          },
        ),
      ),
    );
    overlay.insert(entry);
  }
}

class _FlyArrow extends StatefulWidget {
  final Offset from;
  final Offset to;
  final Color color;
  final VoidCallback onDone;
  const _FlyArrow({
    required this.from,
    required this.to,
    required this.color,
    required this.onDone,
  });

  @override
  State<_FlyArrow> createState() => _FlyArrowState();
}

class _FlyArrowState extends State<_FlyArrow> with SingleTickerProviderStateMixin {
  // 600 ms: a chat bubble pops up in the board centre, then it turns into the
  // arrow (1000 ms flight, unchanged) that glides to the chat icon and vanishes.
  static const int _introMs = 600;
  static const int _arrowMs = 1000;
  static const int _totalMs = _introMs + _arrowMs;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _totalMs),
  )
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    })
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => SizedBox.expand(
        child: CustomPaint(
          painter: _FlyArrowPainter(
            widget.from,
            widget.to,
            ((_c.value * _totalMs - _introMs) / _arrowMs).clamp(0.0, 1.0),
            widget.color,
            (_c.value * _totalMs / _introMs).clamp(0.0, 1.0),
          ),
        ),
      ),
    );
  }
}

class _FlyArrowPainter extends CustomPainter {
  final Offset from;
  final Offset to;
  final double t;
  final Color color;
  final double pop; // 0..1 after the arrow has arrived
  _FlyArrowPainter(this.from, this.to, this.t, this.color, this.pop);

  @override
  void paint(Canvas canvas, Size size) {
    final total = to - from;
    final dist = total.distance;
    if (pop > 0) _paintPop(canvas);
    if (dist < 1) return;
    final dir = total / dist;
    final normal = Offset(-dir.dy, dir.dx);

    // Head leads, tail starts a little later and arrives with it: the line grows out of
    // the centre, glides, then shrinks away into the icon.
    final headT = Curves.easeInOutCubic.transform(t);
    final tailT = Curves.easeInOutCubic.transform(((t - 0.3) / 0.7).clamp(0.0, 1.0));
    final head = from + total * headT;
    final tail = from + total * tailT;
    final len = (head - tail).distance;
    if (len < 1.5) return;

    final opacity = t < 0.85 ? 1.0 : ((1 - t) / 0.15).clamp(0.0, 1.0);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.9 * opacity)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    const shaftHalf = 2.0; // 4 px thin line
    const headHalf = 5.5;
    final headLen = math.min(12.0, len);
    final neck = head - dir * headLen;
    final k = headLen / 12.0; // the head shrinks together with a very short arrow

    final path = Path()
      ..moveTo((tail + normal * shaftHalf).dx, (tail + normal * shaftHalf).dy)
      ..lineTo((neck + normal * shaftHalf).dx, (neck + normal * shaftHalf).dy)
      ..lineTo((neck + normal * headHalf * k).dx, (neck + normal * headHalf * k).dy)
      ..lineTo(head.dx, head.dy)
      ..lineTo((neck - normal * headHalf * k).dx, (neck - normal * headHalf * k).dy)
      ..lineTo((neck - normal * shaftHalf).dx, (neck - normal * shaftHalf).dy)
      ..lineTo((tail - normal * shaftHalf).dx, (tail - normal * shaftHalf).dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  /// Chat bubble (with three dots) pops up at the start point with a small ripple,
  /// stays a moment, then shrinks away as the arrow grows out of it.
  void _paintPop(Canvas canvas) {
    // pop: 0..1 during the intro; t > 0 means the arrow phase has started.
    final shrink = t <= 0 ? 1.0 : (1 - t / 0.25).clamp(0.0, 1.0);
    if (shrink <= 0) return;

    final ripple = (pop * 1.2).clamp(0.0, 1.0);
    if (ripple > 0 && ripple < 1 && t <= 0) {
      canvas.drawCircle(
        from,
        14 + 30 * ripple,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = color.withValues(alpha: (1 - ripple) * 0.8),
      );
    }

    final scale = Curves.elasticOut.transform((pop / 0.7).clamp(0.0, 1.0)) * shrink;
    if (scale <= 0) return;
    canvas.save();
    canvas.translate(from.dx, from.dy);
    canvas.scale(scale);
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-30, -20, 60, 40),
      const Radius.circular(20),
    );
    final tail = Path()
      ..moveTo(-8, 18)
      ..lineTo(-14, 30)
      ..lineTo(4, 19)
      ..close();
    final fill = Paint()..color = color.withValues(alpha: 0.95);
    canvas.drawRRect(body, fill);
    canvas.drawPath(tail, fill);
    final dot = Paint()..color = Colors.white;
    for (var i = -1; i <= 1; i++) {
      canvas.drawCircle(Offset(i * 13.0, 0), 4, dot);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FlyArrowPainter old) => old.t != t || old.pop != pop;
}
