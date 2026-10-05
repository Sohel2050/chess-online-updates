import 'package:flutter/material.dart';

/// A single row-style option on the Play screen: a colored icon square,
/// a title + subtitle, and a chevron in a matching-colored circle —
/// e.g. "Play Online / Play with players around the world / >".
class PlayOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onPressed;

  const PlayOptionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isVerySmallScreen = screenHeight < 600;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: isVerySmallScreen ? 10 : 14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: accentColor.withValues(alpha: 0.10),
            border: Border.all(color: accentColor.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: isVerySmallScreen ? 40 : 48,
                height: isVerySmallScreen ? 40 : 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accentColor.withValues(alpha: 0.9),
                      accentColor.withValues(alpha: 0.55),
                    ],
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: isVerySmallScreen ? 20 : 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: isVerySmallScreen ? 15 : 17,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: isVerySmallScreen ? 11 : 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: isVerySmallScreen ? 30 : 34,
                height: isVerySmallScreen ? 30 : 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.18),
                  border: Border.all(color: accentColor.withValues(alpha: 0.6)),
                ),
                child: Icon(
                  Icons.chevron_right,
                  color: accentColor,
                  size: isVerySmallScreen ? 18 : 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
