import 'package:flutter/material.dart';

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

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.secondaryContainer,
          foregroundColor: isPrimary
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSecondaryContainer,
          padding: EdgeInsets.symmetric(
            horizontal: isVerySmallScreen ? 16 : (isSmallScreen ? 20 : 24),
            vertical: isVerySmallScreen ? 10 : (isSmallScreen ? 12 : 16),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: Size(
            0,
            isVerySmallScreen ? 40 : (isSmallScreen ? 44 : 48),
          ),
        ),
        child: topChild == null
            ? Row(
                mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: isVerySmallScreen ? 18 : (isSmallScreen ? 20 : 24),
                    ),
                    SizedBox(
                      width: isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8),
                    ),
                  ],
                  Flexible(
                    child: Text(
                      text,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: isVerySmallScreen
                            ? 13
                            : (isSmallScreen ? 14 : null),
                        color: isPrimary
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(
                                context,
                              ).colorScheme.onSecondaryContainer,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (topChild != null) ...[
                    topChild!,
                    const SizedBox(height: 8),
                  ],
                  Row(
                    mainAxisSize: isFullWidth
                        ? MainAxisSize.max
                        : MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(
                          icon,
                          size: isVerySmallScreen
                              ? 18
                              : (isSmallScreen ? 20 : 24),
                        ),
                        SizedBox(
                          width: isVerySmallScreen
                              ? 4
                              : (isSmallScreen ? 6 : 8),
                        ),
                      ],
                      Flexible(
                        child: Text(
                          text,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: isVerySmallScreen
                                    ? 13
                                    : (isSmallScreen ? 14 : null),
                                color: isPrimary
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSecondaryContainer,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
