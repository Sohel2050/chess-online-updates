import 'package:flutter/material.dart';
import 'package:flutter_chess_app/utils/constants.dart';
import 'package:flutter_chess_app/widgets/mode_live_stats.dart';

class GameModeCard extends StatelessWidget {
  final String title;
  final String timeControl;
  final bool isSelected;
  final VoidCallback onTap;

  /// Show this mode's live waiting / running-games counters on the card.
  final bool showLiveStats;

  const GameModeCard({
    super.key,
    required this.title,
    required this.timeControl,
    this.isSelected = false,
    required this.onTap,
    this.showLiveStats = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;
    // Per-mode look (no image assets needed)
    late final Color c1;
    late final Color c2;
    late final IconData icon;
    switch (title) {
      case Constants.fast:
        c1 = const Color(0xFFB45309);
        c2 = const Color(0xFFF59E0B);
        icon = Icons.bolt_rounded;
        break;
      case Constants.blitz3:
        c1 = const Color(0xFF991B1B);
        c2 = const Color(0xFFEF4444);
        icon = Icons.local_fire_department_rounded;
        break;
      default: // Classical and anything else
        c1 = const Color(0xFF14532D);
        c2 = const Color(0xFF22C55E);
        icon = Icons.hourglass_bottom_rounded;
    }
    final glowColor = c2;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.all(isSmallScreen ? 6.0 : 8.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: isSelected ? glowColor.withValues(alpha: 0.8) : Colors.transparent,
            width: 1.5,
          ),
          gradient: LinearGradient(
            colors: [c1, c2.withValues(alpha: 0.55)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? glowColor.withValues(alpha: 0.45)
                  : Colors.black.withValues(alpha: 0.2),
              blurRadius: isSelected ? 20 : 8,
              spreadRadius: isSelected ? 1 : 0,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.0),
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.1),
                Colors.black.withValues(alpha: 0.45),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20.0),
            child: Stack(
            children: [
              Positioned(
                right: -10,
                top: -6,
                child: Icon(
                  icon,
                  size: isSmallScreen ? 90 : 120,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
              ),
              if (showLiveStats)
                Positioned(
                  left: 8,
                  top: 8,
                  child: ModeLiveStats(gameMode: timeControl),
                ),
              Positioned.fill(
                child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  Constants.modeLabel(title),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: isSmallScreen ? 18 : null,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 2 : 4),
                Text(
                  Constants.modeSubtitle(timeControl),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: isSmallScreen ? 12 : null,
                  ),
                ),
              ],
            ),
          ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}
