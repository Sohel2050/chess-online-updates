import 'package:flutter/material.dart';
import 'package:flutter_chess_app/services/assets_manager.dart';

class GameModeCard extends StatelessWidget {
  final String title;
  final String timeControl;
  final bool isSelected;
  final VoidCallback onTap;

  const GameModeCard({
    super.key,
    required this.title,
    required this.timeControl,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;
    const glowColor = Color(0xFF22C55E);

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
          image: DecorationImage(
            image: AssetImage(AssetsManager.appLogo),
            fit: BoxFit.cover,
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
                Colors.black.withValues(alpha: 0.7),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: isSmallScreen ? 18 : null,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 2 : 4),
                Text(
                  timeControl,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: isSmallScreen ? 12 : null,
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
