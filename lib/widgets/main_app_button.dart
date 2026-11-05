import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/utils/adaptive.dart';

class MainAppButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback onPressed;
  final bool isPrimary;
  final bool isFullWidth;
  final Widget? topChild;

  const MainAppButton({
    super.key,
    required this.text,
    this.icon,
    required this.onPressed,
    this.isPrimary = true,
    this.isFullWidth = false,
    this.topChild,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;
    final isVerySmallScreen = screenHeight < 600;
    final cs = Theme.of(context).colorScheme;

    final background = isPrimary ? cs.primary : cs.secondaryContainer;
    final foreground = isPrimary ? cs.onPrimary : cs.onSecondaryContainer;
    final padding = EdgeInsets.symmetric(
      horizontal: isVerySmallScreen ? 16 : (isSmallScreen ? 20 : 24),
      vertical: isVerySmallScreen ? 10 : (isSmallScreen ? 12 : 16),
    );
    final minHeight = isVerySmallScreen ? 40.0 : (isSmallScreen ? 44.0 : 48.0);

    final label = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: isVerySmallScreen ? 18 : (isSmallScreen ? 20 : 24),
            color: isIOS ? foreground : null,
          ),
          SizedBox(width: isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8)),
        ],
        Flexible(
          child: Text(
            text,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: isIOS ? FontWeight.w600 : FontWeight.bold,
              fontSize: isVerySmallScreen ? 13 : (isSmallScreen ? 14 : null),
              color: foreground,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
    final content = topChild == null
        ? label
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [topChild!, const SizedBox(height: 8), label],
          );

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      child: isIOS
          // iOS: flat filled button that fades when pressed.
          ? CupertinoButton(
              onPressed: onPressed,
              color: background,
              disabledColor: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              padding: padding,
              minimumSize: Size(0, minHeight),
              child: content,
            )
          : ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: background,
                foregroundColor: foreground,
                padding: padding,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: Size(0, minHeight),
              ),
              child: content,
            ),
    );
  }
}
