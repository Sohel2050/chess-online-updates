import 'package:flutter/material.dart';

/// Forces a dark Material theme for a subtree.
///
/// Some screens (Home, Daily Missions) use a fixed dark background
/// (0xFF0B0F0D). In light mode the app theme gives them dark text and icons,
/// which are unreadable on that background. Wrapping them in this widget makes
/// all default text, icons, app bar and navigation bar light-coloured.
class DarkSurface extends StatelessWidget {
  final Widget child;
  const DarkSurface({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final dark = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1B5E20),
        brightness: Brightness.dark,
      ),
      appBarTheme: base.appBarTheme,
      splashFactory: base.splashFactory,
      snackBarTheme: base.snackBarTheme,
      dialogTheme: base.dialogTheme,
      elevatedButtonTheme: base.elevatedButtonTheme,
      filledButtonTheme: base.filledButtonTheme,
      outlinedButtonTheme: base.outlinedButtonTheme,
      textButtonTheme: base.textButtonTheme,
    );
    return Theme(data: dark, child: child);
  }
}
