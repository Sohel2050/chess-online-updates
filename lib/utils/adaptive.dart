import 'package:flutter/foundation.dart';

/// True on iPhone / iPad. Used to switch the look (buttons, dialogs, spinners,
/// switches, app bar) to iOS style; Android keeps the Material look.
bool get isIOS => defaultTargetPlatform == TargetPlatform.iOS;
