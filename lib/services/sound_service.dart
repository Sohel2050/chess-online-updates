import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../utils/move_sound_classifier.dart';

enum SoundEffect { move, capture, castle, check, gameEnd, lowTime }

/// Short game sound effects (assets/audio/*.wav, generated for this app, no licence needed).
///
/// The switches below are set by SettingsProvider, so every sound in the app can
/// ask `SoundService.instance.enabled` before it plays. A missing or broken
/// asset never throws: that effect is simply skipped.
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  /// Master switch ("Sound effects" in Options).
  bool enabled = true;

  /// 0.0 - 1.0.
  double volume = 0.8;

  /// Small vibration on moves ("Vibration" in Options).
  bool haptics = true;

  static const Map<SoundEffect, String> _assets = {
    SoundEffect.move: 'assets/audio/move.wav',
    SoundEffect.capture: 'assets/audio/capture.wav',
    SoundEffect.castle: 'assets/audio/castle.wav',
    SoundEffect.check: 'assets/audio/check.wav',
    SoundEffect.gameEnd: 'assets/audio/game_end.wav',
    SoundEffect.lowTime: 'assets/audio/low_time.wav',
  };

  final Map<SoundEffect, AudioPlayer> _players = {};
  final Set<SoundEffect> _broken = {};

  /// Called by SettingsProvider whenever a value changes.
  void configure({bool? enabled, double? volume, bool? haptics}) {
    if (enabled != null) this.enabled = enabled;
    if (haptics != null) this.haptics = haptics;
    if (volume != null) {
      this.volume = volume.clamp(0.0, 1.0).toDouble();
      for (final p in _players.values) {
        unawaited(p.setVolume(this.volume).catchError((_) {}));
      }
    }
  }

  /// True when a sound may actually be heard right now.
  bool get audible => enabled && volume > 0;

  Future<AudioPlayer?> _playerFor(SoundEffect effect) async {
    if (_broken.contains(effect)) return null;
    final existing = _players[effect];
    if (existing != null) return existing;
    try {
      final p = AudioPlayer();
      await p.setAsset(_assets[effect]!);
      await p.setVolume(volume);
      _players[effect] = p;
      return p;
    } catch (e) {
      debugPrint('SoundService: cannot load $effect: $e');
      _broken.add(effect);
      return null;
    }
  }

  /// Plays one effect. Never throws.
  Future<void> play(SoundEffect effect) async {
    if (!audible) return;
    try {
      final p = await _playerFor(effect);
      if (p == null || !audible) return;
      await p.seek(Duration.zero);
      unawaited(p.play().catchError((_) {}));
    } catch (e) {
      debugPrint('SoundService: play $effect failed: $e');
    }
  }

  /// Sound (and a small vibration) for the move that turned [fenBefore] into [fenAfter].
  void playMove(String fenBefore, String fenAfter) {
    final kind = classifyMoveSound(fenBefore, fenAfter);
    if (haptics) {
      try {
        if (kind == MoveSoundKind.move || kind == MoveSoundKind.castle) {
          unawaited(HapticFeedback.selectionClick());
        } else {
          unawaited(HapticFeedback.lightImpact());
        }
      } catch (_) {}
    }
    switch (kind) {
      case MoveSoundKind.check:
        unawaited(play(SoundEffect.check));
        break;
      case MoveSoundKind.capture:
        unawaited(play(SoundEffect.capture));
        break;
      case MoveSoundKind.castle:
        unawaited(play(SoundEffect.castle));
        break;
      case MoveSoundKind.move:
        unawaited(play(SoundEffect.move));
        break;
    }
  }
}
