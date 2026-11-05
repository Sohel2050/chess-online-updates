import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:squares/squares.dart';
import '../services/sound_service.dart';
import '../utils/chess_styles.dart';

class SettingsProvider with ChangeNotifier {
  // Default values
  BoardTheme _boardTheme = BoardTheme.brown;
  String _pieceSet = 'merida';
  int? _whitePieceColor;
  int? _blackPieceColor;
  bool _darkMode = false;
  bool _showLabels = true;
  bool _animatePieces = true;
  bool _confirmMoves = false; // v94: ask "Confirm / Cancel" before a move is played
  bool _ratingBasedSearch = false; // New preference for online play
  // Sound / feedback (v83)
  bool _soundEnabled = true;
  double _soundVolume = 0.8;
  bool _hapticsEnabled = true;
  // Accessibility (v83)
  bool _colorBlindMode = false;
  // Online modes the player does NOT want to be matched in. Empty = all modes (default).
  Set<String> _excludedMatchModes = {};

  // Getters
  BoardTheme get boardTheme => _boardTheme;
  String get pieceSet => _pieceSet;
  Color? get whitePieceColor => _whitePieceColor == null ? null : Color(_whitePieceColor!);
  Color? get blackPieceColor => _blackPieceColor == null ? null : Color(_blackPieceColor!);
  bool get darkMode => _darkMode;
  ThemeMode get themeMode => _darkMode ? ThemeMode.dark : ThemeMode.light;
  bool get showLabels => _showLabels;
  bool get animatePieces => _animatePieces;
  bool get confirmMoves => _confirmMoves;
  bool get ratingBasedSearch => _ratingBasedSearch;
  bool get soundEnabled => _soundEnabled;
  double get soundVolume => _soundVolume;
  bool get hapticsEnabled => _hapticsEnabled;
  bool get colorBlindMode => _colorBlindMode;

  /// The theme the boards must actually use: the chosen one, or the colour-blind
  /// safe one while colour-blind mode is on. Boards use this, not [boardTheme].
  BoardTheme get effectiveBoardTheme =>
      _colorBlindMode ? colorBlindBoardTheme : _boardTheme;
  Set<String> get excludedMatchModes => Set.unmodifiable(_excludedMatchModes);
  bool isMatchModeIncluded(String timeControl) => !_excludedMatchModes.contains(timeControl);

  SettingsProvider() {
    _loadPreferences();
  }

  // Load preferences from local storage
  void _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString('boardTheme') ?? 'brown';
    _boardTheme = _getThemeFromName(themeName);
    _pieceSet = prefs.getString('pieceSet') ?? 'merida';
    _whitePieceColor = prefs.getInt('whitePieceColor');
    _blackPieceColor = prefs.getInt('blackPieceColor');
    _darkMode = prefs.getBool('darkMode') ?? false;
    _showLabels = prefs.getBool('showLabels') ?? true;
    _animatePieces = prefs.getBool('animatePieces') ?? true;
    _confirmMoves = prefs.getBool('confirmMoves') ?? false;
    _ratingBasedSearch = prefs.getBool('ratingBasedSearch') ?? false;
    _soundEnabled = prefs.getBool('soundEnabled') ?? true;
    _soundVolume = (prefs.getDouble('soundVolume') ?? 0.8).clamp(0.0, 1.0).toDouble();
    _hapticsEnabled = prefs.getBool('hapticsEnabled') ?? true;
    _colorBlindMode = prefs.getBool('colorBlindMode') ?? false;
    _syncSound();
    _excludedMatchModes = (prefs.getStringList('excludedMatchModes') ?? <String>[]).toSet();
    notifyListeners();
  }

  // Save preferences to local storage
  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('boardTheme', _getThemeName(_boardTheme));
    await prefs.setString('pieceSet', _pieceSet);
    if (_whitePieceColor == null) {
      await prefs.remove('whitePieceColor');
    } else {
      await prefs.setInt('whitePieceColor', _whitePieceColor!);
    }
    if (_blackPieceColor == null) {
      await prefs.remove('blackPieceColor');
    } else {
      await prefs.setInt('blackPieceColor', _blackPieceColor!);
    }
    await prefs.setBool('darkMode', _darkMode);
    await prefs.setBool('showLabels', _showLabels);
    await prefs.setBool('animatePieces', _animatePieces);
    await prefs.setBool('confirmMoves', _confirmMoves);
    await prefs.setBool('ratingBasedSearch', _ratingBasedSearch);
    await prefs.setBool('soundEnabled', _soundEnabled);
    await prefs.setDouble('soundVolume', _soundVolume);
    await prefs.setBool('hapticsEnabled', _hapticsEnabled);
    await prefs.setBool('colorBlindMode', _colorBlindMode);
    await prefs.setStringList('excludedMatchModes', _excludedMatchModes.toList());
  }

  // Update methods
  void setBoardTheme(BoardTheme newTheme) {
    if (_boardTheme != newTheme) {
      _boardTheme = newTheme;
      _savePreferences();
      notifyListeners();
    }
  }

  /// Turns one online mode on/off for matchmaking. At least one of [allModes] stays on.
  void setMatchModeIncluded(String timeControl, bool included, List<String> allModes) {
    final next = {..._excludedMatchModes};
    if (included) {
      next.remove(timeControl);
    } else {
      next.add(timeControl);
      if (allModes.every(next.contains)) return; // never leave zero modes
    }
    if (next.length == _excludedMatchModes.length && next.containsAll(_excludedMatchModes)) return;
    _excludedMatchModes = next;
    _savePreferences();
    notifyListeners();
  }

  void _syncSound() => SoundService.instance
      .configure(enabled: _soundEnabled, volume: _soundVolume, haptics: _hapticsEnabled);

  void setSoundEnabled(bool value) {
    if (_soundEnabled == value) return;
    _soundEnabled = value;
    _syncSound();
    _savePreferences();
    notifyListeners();
  }

  void setSoundVolume(double value) {
    final v = value.clamp(0.0, 1.0).toDouble();
    if (_soundVolume == v) return;
    _soundVolume = v;
    _syncSound();
    _savePreferences();
    notifyListeners();
  }

  void setHapticsEnabled(bool value) {
    if (_hapticsEnabled == value) return;
    _hapticsEnabled = value;
    _syncSound();
    _savePreferences();
    notifyListeners();
  }

  void setColorBlindMode(bool value) {
    if (_colorBlindMode == value) return;
    _colorBlindMode = value;
    _savePreferences();
    notifyListeners();
  }

  void setRatingBasedSearch(bool value) {
    if (_ratingBasedSearch != value) {
      _ratingBasedSearch = value;
      _savePreferences();
      notifyListeners();
    }
  }

  void setPieceSet(String newPieceSet) {
    if (_pieceSet != newPieceSet) {
      _pieceSet = newPieceSet;
      _savePreferences();
      notifyListeners();
    }
  }

  void setWhitePieceColor(Color? c) {
    _whitePieceColor = c?.toARGB32();
    _savePreferences();
    notifyListeners();
  }

  void setBlackPieceColor(Color? c) {
    _blackPieceColor = c?.toARGB32();
    _savePreferences();
    notifyListeners();
  }

  void setDarkMode(bool value) {
    if (_darkMode != value) {
      _darkMode = value;
      _savePreferences();
      notifyListeners();
    }
  }

  void setShowLabels(bool shouldShow) {
    if (_showLabels != shouldShow) {
      _showLabels = shouldShow;
      _savePreferences();
      notifyListeners();
    }
  }

  void setConfirmMoves(bool value) {
    if (_confirmMoves != value) {
      _confirmMoves = value;
      _savePreferences();
      notifyListeners();
    }
  }

  void setAnimatePieces(bool shouldAnimate) {
    if (_animatePieces != shouldAnimate) {
      _animatePieces = shouldAnimate;
      _savePreferences();
      notifyListeners();
    }
  }

  // Helper methods to convert theme to/from a string for storage
  BoardTheme _getThemeFromName(String name) => boardStyleById(name).theme;

  String _getThemeName(BoardTheme theme) => boardStyleOfTheme(theme).id;

  PieceSet _basePieceSet() => _baseFor(_pieceSet);

  PieceSet _baseFor(String id) {
    switch (id) {
      case 'merida':
        return PieceSet.merida();
      case 'letters':
        return PieceSet.letters();
      default:
        return imagePieceSetById(id) ?? glyphPieceSetById(id) ?? PieceSet.merida();
    }
  }

  /// Piece set with the player's optional white/black colours applied.
  /// The code-drawn glyph sets already have their own colours, so they are left alone.
  PieceSet getPieceSet() {
    final base = _basePieceSet();
    if (glyphPieceSetById(_pieceSet) != null) return base;
    return tintedPieceSet(base, whitePieceColor, blackPieceColor);
  }

  /// Builds a piece set for any choice (used by the Options preview before Apply).
  PieceSet pieceSetFor(String id, Color? white, Color? black) {
    final base = _baseFor(id);
    if (glyphPieceSetById(id) != null) return base;
    return tintedPieceSet(base, white, black);
  }

  /// Saves board theme, piece set and piece colours together (Apply button).
  void applyAppearance({
    required BoardTheme boardTheme,
    required String pieceSet,
    Color? white,
    Color? black,
  }) {
    _boardTheme = boardTheme;
    _pieceSet = pieceSet;
    _whitePieceColor = white?.toARGB32();
    _blackPieceColor = black?.toARGB32();
    _savePreferences();
    notifyListeners();
  }
}
