import 'package:flutter/material.dart';

/// An icon button with soft ripple waves spreading out behind the icon, so the
/// button looks alive and people notice it is tappable (used for the ⚡ quick
/// messages button in chat). While [animate] is false it is a plain icon button.
class WavePulseIconButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String? tooltip;
  final VoidCallback onPressed;
  final bool animate;

  const WavePulseIconButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.tooltip,
    this.animate = true,
  });

  @override
  State<WavePulseIconButton> createState() => _WavePulseIconButtonState();
}

class _WavePulseIconButtonState extends State<WavePulseIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant WavePulseIconButton old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.animate && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (widget.animate)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, __) => CustomPaint(
                  painter: _WavePainter(_c.value, widget.color),
                ),
              ),
            ),
          ),
        IconButton(
          tooltip: widget.tooltip,
          icon: Icon(widget.icon, color: widget.color),
          onPressed: widget.onPressed,
        ),
      ],
    );
  }
}

class _WavePainter extends CustomPainter {
  final double t;
  final Color color;
  _WavePainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;
    // Two waves, the second one starts half a cycle later.
    for (var i = 0; i < 2; i++) {
      final p = (t + i * 0.5) % 1.0;
      canvas.drawCircle(
        center,
        maxR * (0.35 + 0.65 * p),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: (1 - p) * 0.55),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => old.t != t || old.color != color;
}
