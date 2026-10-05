import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:squares/squares.dart';

class SettingsProvider with ChangeNotifier {
  // Default values
  BoardTheme _boardTheme = BoardTheme.brown;
  String _pieceSet = 'merida';
  bool _showLabels = true;
  bool _animatePieces = true;
  bool _ratingBasedSearch = false; // New preference for online play

  // Getters
  BoardTheme get boardTheme => _boardTheme;
  String get pieceSet => _pieceSet;
  bool get showLabels => _showLabels;
  bool get animatePieces => _animatePieces;
  bool get ratingBasedSearch => _ratingBasedSearch;

  SettingsProvider() {
    _loadPreferences();
  }

  // Load preferences from local storage
  void _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString('boardTheme') ?? 'brown';
    _boardTheme = _getThemeFromName(themeName);
    _pieceSet = prefs.getString('pieceSet') ?? 'merida';
    _showLabels = prefs.getBool('showLabels') ?? true;
    _animatePieces = prefs.getBool('animatePieces') ?? true;
    _ratingBasedSearch = prefs.getBool('ratingBasedSearch') ?? false;
    notifyListeners();
  }

  // Save preferences to local storage
  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('boardTheme', _getThemeName(_boardTheme));
    await prefs.setString('pieceSet', _pieceSet);
    await prefs.setBool('showLabels', _showLabels);
    await prefs.setBool('animatePieces', _animatePieces);
    await prefs.setBool('ratingBasedSearch', _ratingBasedSearch);
  }

  // Update methods
  void setBoardTheme(BoardTheme newTheme) {
    if (_boardTheme != newTheme) {
      _boardTheme = newTheme;
      _savePreferences();
      notifyListeners();
    }
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

  void setShowLabels(bool shouldShow) {
    if (_showLabels != shouldShow) {
      _showLabels = shouldShow;
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
  BoardTheme _getThemeFromName(String name) {
    switch (name) {
      case 'brown':
        return BoardTheme.brown;
      case 'blueGrey':
        return BoardTheme.blueGrey;
      case 'Pink':
        return BoardTheme.pink;
      case 'Dart':
        return BoardTheme.dart;
      default:
        return BoardTheme.brown;
    }
  }

  String _getThemeName(BoardTheme theme) {
    if (theme == BoardTheme.brown) return 'brown';
    if (theme == BoardTheme.blueGrey) return 'blueGrey';
    if (theme == BoardTheme.pink) return 'Pink';
    if (theme == BoardTheme.dart) return 'Dart';
    return 'brown';
  }

  PieceSet getPieceSet() {
    switch (_pieceSet) {
      case 'merida':
        return PieceSet.merida();
      case 'letters':
        return PieceSet.letters();
      default:
        return PieceSet.merida();
    }
  }
}
