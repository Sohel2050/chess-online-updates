import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Pure board geometry for drawing a move as an arrow (no Flutter widgets, so it
/// can be unit-tested). Board is [size] x [size] pixels, 8 x 8 squares.
class ArrowGeometry {
  /// "e2e4" / "e7e8q" -> from / to square names, or null if [uci] is not a move.
  static (String, String)? parseUci(String? uci) {
    if (uci == null || uci.length < 4) return null;
    final re = RegExp(r'^[a-h][1-8][a-h][1-8][qrbn]?$');
    if (!re.hasMatch(uci)) return null;
    return (uci.substring(0, 2), uci.substring(2, 4));
  }

  /// Centre of square [sq] ("e4") on the board. [flipped] = Black at the bottom.
  static Offset squareCenter(String sq, double size, {required bool flipped}) {
    final file = sq.codeUnitAt(0) - 'a'.codeUnitAt(0); // 0..7
    final rank = sq.codeUnitAt(1) - '1'.codeUnitAt(0); // 0..7 (0 = rank 1)
    final cell = size / 8;
    final col = flipped ? 7 - file : file;
    final row = flipped ? rank : 7 - rank;
    return Offset((col + 0.5) * cell, (row + 0.5) * cell);
  }
}

/// Draws an arrow for [uci] over the board. Put it in a Stack above the board,
/// inside an [IgnorePointer], with the same square size as the board.
class MoveArrowPainter extends CustomPainter {
  final String? uci;
  final bool flipped;
  final Color color;

  MoveArrowPainter({required this.uci, required this.flipped, this.color = const Color(0xCC2E9E4F)});

  @override
  void paint(Canvas canvas, Size size) {
    final move = ArrowGeometry.parseUci(uci);
    if (move == null) return;
    final side = math.min(size.width, size.height);
    final from = ArrowGeometry.squareCenter(move.$1, side, flipped: flipped);
    final to = ArrowGeometry.squareCenter(move.$2, side, flipped: flipped);
    final cell = side / 8;
    final delta = to - from;
    final len = delta.distance;
    if (len < 1) return;
    final dir = delta / len;

    final headLen = cell * 0.5;
    final headHalfWidth = cell * 0.27;
    final shaftWidth = cell * 0.18;
    // Start a little away from the piece's centre, stop where the head begins.
    final start = from + dir * (cell * 0.18);
    final neck = to - dir * headLen;
    final normal = Offset(-dir.dy, dir.dx);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final path = Path()
      ..moveTo((start + normal * (shaftWidth / 2)).dx, (start + normal * (shaftWidth / 2)).dy)
      ..lineTo((neck + normal * (shaftWidth / 2)).dx, (neck + normal * (shaftWidth / 2)).dy)
      ..lineTo((neck + normal * headHalfWidth).dx, (neck + normal * headHalfWidth).dy)
      ..lineTo(to.dx, to.dy)
      ..lineTo((neck - normal * headHalfWidth).dx, (neck - normal * headHalfWidth).dy)
      ..lineTo((neck - normal * (shaftWidth / 2)).dx, (neck - normal * (shaftWidth / 2)).dy)
      ..lineTo((start - normal * (shaftWidth / 2)).dx, (start - normal * (shaftWidth / 2)).dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant MoveArrowPainter old) =>
      old.uci != uci || old.flipped != flipped || old.color != color;
}


/// Hint arrow with a short intro: a small ripple (wave) pulses on the piece's
/// square first, then the arrow grows out of it. Restarts whenever [uci] changes.
class AnimatedMoveArrow extends StatefulWidget {
  final String? uci;
  final bool flipped;
  final Color color;

  const AnimatedMoveArrow({
    super.key,
    required this.uci,
    required this.flipped,
    this.color = const Color(0xCCFFB300),
  });

  @override
  State<AnimatedMoveArrow> createState() => _AnimatedMoveArrowState();
}

class _AnimatedMoveArrowState extends State<AnimatedMoveArrow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedMoveArrow old) {
    super.didUpdateWidget(old);
    if (old.uci != widget.uci) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        // 0..0.55 ripple on the from-square, 0.45..1 arrow fades/grows in.
        final arrowT = ((t - 0.45) / 0.55).clamp(0.0, 1.0);
        return CustomPaint(
          painter: _HintIntroPainter(
            uci: widget.uci,
            flipped: widget.flipped,
            color: widget.color,
            rippleT: (t / 0.55).clamp(0.0, 1.0),
            arrowT: Curves.easeOut.transform(arrowT),
          ),
        );
      },
    );
  }
}

class _HintIntroPainter extends CustomPainter {
  final String? uci;
  final bool flipped;
  final Color color;
  final double rippleT;
  final double arrowT;

  _HintIntroPainter({
    required this.uci,
    required this.flipped,
    required this.color,
    required this.rippleT,
    required this.arrowT,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final move = ArrowGeometry.parseUci(uci);
    if (move == null) return;
    final side = math.min(size.width, size.height);
    final cell = side / 8;
    final from = ArrowGeometry.squareCenter(move.$1, side, flipped: flipped);

    if (rippleT < 1) {
      for (var i = 0; i < 2; i++) {
        final p = (rippleT - i * 0.25).clamp(0.0, 1.0);
        if (p <= 0) continue;
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.07
          ..color = color.withValues(alpha: (1 - p) * 0.9);
        canvas.drawCircle(from, cell * (0.25 + 0.6 * p), paint);
      }
    }

    if (arrowT > 0) {
      canvas.saveLayer(
        Offset.zero & size,
        Paint()..color = Color.fromRGBO(255, 255, 255, arrowT),
      );
      MoveArrowPainter(uci: uci, flipped: flipped, color: color)
          .paint(canvas, size);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _HintIntroPainter old) =>
      old.uci != uci ||
      old.flipped != flipped ||
      old.rippleT != rippleT ||
      old.arrowT != arrowT ||
      old.color != color;
}
