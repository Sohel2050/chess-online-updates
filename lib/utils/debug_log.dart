import 'package:flutter/foundation.dart';

/// Debug-only console output. Unlike `print`, this prints NOTHING in release builds
/// (kDebugMode is a compile-time constant, so the calls are removed entirely).
void dlog(Object? message) {
  if (kDebugMode) debugPrint('$message');
}
