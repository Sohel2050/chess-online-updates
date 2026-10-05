import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_chess_app/models/user_model.dart';

class UserProvider with ChangeNotifier {
  ChessUser? _user;

  ChessUser? get user => _user;

  void setUser(ChessUser? newUser) {
    log(
      'UserProvider: setUser called - uid: ${newUser?.uid}, displayName: ${newUser?.displayName}, countryCode: ${newUser?.countryCode}, photoUrl: ${newUser?.photoUrl}',
    );
    _user = newUser;
    notifyListeners();
  }

  void updateUserPhoto(String? photoUrl) {
    if (_user != null) {
      log(
        'UserProvider: updateUserPhoto to ${photoUrl != null ? 'new image' : 'null'}',
      );
      _user = _user!.copyWith(photoUrl: photoUrl);
      notifyListeners();
    }
  }

  void updateUserRating(String ratingTypeField, int newRating) {
    if (_user != null) {
      log('UserProvider: updateUserRating - $ratingTypeField: $newRating');
      _user = _user!.copyWith(
        classicalRating: ratingTypeField == 'classicalRating'
            ? newRating
            : _user!.classicalRating,
        blitzRating: ratingTypeField == 'blitzRating'
            ? newRating
            : _user!.blitzRating,
        tempoRating: ratingTypeField == 'tempoRating'
            ? newRating
            : _user!.tempoRating,
      );
      notifyListeners();
    }
  }

  void updateRemoveAds(bool removeAds) {
    if (_user != null) {
      log('UserProvider: updateRemoveAds to $removeAds');
      _user = _user!.copyWith(removeAds: removeAds);
      notifyListeners();
    }
  }

  void updateCountryCode(String? countryCode) {
    if (_user != null) {
      log(
        'UserProvider: updateCountryCode from ${_user!.countryCode} to $countryCode',
      );
      _user = _user!.copyWith(countryCode: countryCode);
      notifyListeners();
    }
  }

  void updateUserProfile({
    String? displayName,
    String? photoUrl,
    String? countryCode,
    bool? removeAds,
  }) {
    if (_user != null) {
      log(
        'UserProvider: updateUserProfile - displayName: $displayName, countryCode: $countryCode, removeAds: $removeAds',
      );
      _user = _user!.copyWith(
        displayName: displayName,
        photoUrl: photoUrl,
        countryCode: countryCode,
        removeAds: removeAds,
      );
      notifyListeners();
    }
  }
}
