import 'package:flutter_chess_app/utils/constants.dart';

class ChessUser {
  final String? uid;
  final String? email;
  final String displayName;
  final String? photoUrl;
  final int classicalRating;
  final int blitzRating;
  final int tempoRating;
  final int gamesPlayed;
  final int gamesWon;
  final int gamesLost;
  final int gamesDraw;
  final List<String> achievements;
  final List<String> friends;
  final List<String> friendRequestsSent;
  final List<String> friendRequestsReceived;
  final List<String> blockedUsers;
  final bool isOnline;
  final DateTime lastSeen;
  final bool isGuest;
  final Map<String, int> winStreak;
  final List<String> savedGames;
  final Map<String, String> preferences;
  final String fcmToken;
  final String? countryCode;
  final bool? removeAds;
  final DateTime? premiumStartDate;
  final DateTime? premiumExpiryDate;
  final bool? emailVerified;

  ChessUser({
    this.uid,
    this.email,
    required this.displayName,
    this.photoUrl,
    this.classicalRating = 1200,
    this.blitzRating = 1200,
    this.tempoRating = 1200,
    this.gamesPlayed = 0,
    this.gamesWon = 0,
    this.gamesLost = 0,
    this.gamesDraw = 0,
    this.achievements = const [],
    this.friends = const [],
    this.friendRequestsSent = const [],
    this.friendRequestsReceived = const [],
    this.blockedUsers = const [],
    this.isOnline = false,
    DateTime? lastSeen,
    this.isGuest = false,
    this.winStreak = const {},
    this.savedGames = const [],
    this.preferences = const {},
    this.fcmToken = '',
    this.countryCode,
    this.removeAds = false,
    this.premiumStartDate,
    this.premiumExpiryDate,
    this.emailVerified,
  }) : lastSeen = lastSeen ?? DateTime.now();

  ChessUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    int? classicalRating,
    int? blitzRating,
    int? tempoRating,
    int? gamesPlayed,
    int? gamesWon,
    int? gamesLost,
    int? gamesDraw,
    List<String>? achievements,
    List<String>? friends,
    List<String>? friendRequestsSent,
    List<String>? friendRequestsReceived,
    List<String>? blockedUsers,
    bool? isOnline,
    DateTime? lastSeen,
    bool? isGuest,
    Map<String, int>? winStreak,
    List<String>? savedGames,
    Map<String, String>? preferences,
    String? fcmToken,
    String? countryCode,
    bool? removeAds,
    DateTime? premiumStartDate,
    DateTime? premiumExpiryDate,
    bool? emailVerified,
  }) {
    return ChessUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      classicalRating: classicalRating ?? this.classicalRating,
      blitzRating: blitzRating ?? this.blitzRating,
      tempoRating: tempoRating ?? this.tempoRating,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      gamesWon: gamesWon ?? this.gamesWon,
      gamesLost: gamesLost ?? this.gamesLost,
      gamesDraw: gamesDraw ?? this.gamesDraw,
      achievements: achievements ?? this.achievements,
      friends: friends ?? this.friends,
      friendRequestsSent: friendRequestsSent ?? this.friendRequestsSent,
      friendRequestsReceived:
          friendRequestsReceived ?? this.friendRequestsReceived,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      isGuest: isGuest ?? this.isGuest,
      winStreak: winStreak ?? this.winStreak,
      savedGames: savedGames ?? this.savedGames,
      preferences: preferences ?? this.preferences,
      fcmToken: fcmToken ?? this.fcmToken,
      countryCode: countryCode ?? this.countryCode,
      removeAds: removeAds ?? this.removeAds,
      premiumStartDate: premiumStartDate ?? this.premiumStartDate,
      premiumExpiryDate: premiumExpiryDate ?? this.premiumExpiryDate,
      emailVerified: emailVerified ?? this.emailVerified,
    );
  }

  factory ChessUser.guest() {
    return ChessUser(displayName: Constants.guestDisplayName, isGuest: true);
  }

  Map<String, dynamic> toMap() {
    return {
      Constants.uid: uid,
      Constants.email: email,
      Constants.displayName: displayName,
      Constants.photoUrl: photoUrl,
      Constants.classicalRating: classicalRating,
      Constants.blitzRating: blitzRating,
      Constants.tempoRating: tempoRating,
      Constants.gamesPlayed: gamesPlayed,
      Constants.gamesWon: gamesWon,
      Constants.gamesLost: gamesLost,
      Constants.gamesDraw: gamesDraw,
      Constants.achievements: achievements,
      Constants.friends: friends,
      Constants.friendRequestsSent: friendRequestsSent,
      Constants.friendRequestsReceived: friendRequestsReceived,
      Constants.blockedUsers: blockedUsers,
      Constants.isOnline: isOnline,
      Constants.lastSeen: lastSeen.toIso8601String(),
      Constants.isGuest: isGuest,
      Constants.winStreak: winStreak,
      Constants.savedGames: savedGames,
      Constants.preferences: preferences,
      Constants.fcmToken: fcmToken,
      Constants.countryCode: countryCode,
      Constants.removeAds: removeAds,
      Constants.premiumStartDate: premiumStartDate?.toIso8601String(),
      Constants.premiumExpiryDate: premiumExpiryDate?.toIso8601String(),
      Constants.emailVerified: emailVerified,
    };
  }

  factory ChessUser.fromMap(Map<String, dynamic> map) {
    return ChessUser(
      uid: map[Constants.uid] ?? '',
      email: map[Constants.email] ?? '',
      displayName: map[Constants.displayName] ?? '',
      photoUrl: map[Constants.photoUrl] ?? '',
      classicalRating: map[Constants.classicalRating] ?? 1200,
      blitzRating: map[Constants.blitzRating] ?? 1200,
      tempoRating: map[Constants.tempoRating] ?? 1200,
      gamesPlayed: map[Constants.gamesPlayed] ?? 0,
      gamesWon: map[Constants.gamesWon] ?? 0,
      gamesLost: map[Constants.gamesLost] ?? 0,
      gamesDraw: map[Constants.gamesDraw] ?? 0,
      achievements: List<String>.from(map[Constants.achievements] ?? []),
      friends: List<String>.from(map[Constants.friends] ?? []),
      friendRequestsSent: List<String>.from(
        map[Constants.friendRequestsSent] ?? [],
      ),
      friendRequestsReceived: List<String>.from(
        map[Constants.friendRequestsReceived] ?? [],
      ),
      blockedUsers: List<String>.from(map[Constants.blockedUsers] ?? []),
      isOnline: map[Constants.isOnline] ?? false,
      lastSeen: _convertToDateTime(map[Constants.lastSeen]),
      isGuest: map[Constants.isGuest] ?? false,
      winStreak: Map<String, int>.from(map[Constants.winStreak] ?? {}),
      savedGames: List<String>.from(map[Constants.savedGames] ?? []),
      preferences: Map<String, String>.from(map[Constants.preferences] ?? {}),
      fcmToken: map[Constants.fcmToken] ?? '',
      countryCode: map[Constants.countryCode],
      removeAds: map[Constants.removeAds] ?? false,
      premiumStartDate: _convertToDateTime(map[Constants.premiumStartDate]),
      premiumExpiryDate: _convertToDateTime(map[Constants.premiumExpiryDate]),
      emailVerified: map[Constants.emailVerified],
    );
  }

  static DateTime _convertToDateTime(dynamic value) {
    if (value is DateTime) {
      return value;
    } else if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    } else {
      return DateTime.now();
    }
  }

  // Copy with method to update only specific fields
  ChessUser update({
    String? displayName,
    String? photoUrl,
    int? classicalRating,
    int? blitzRating,
    int? tempoRating,
    int? gamesPlayed,
    int? gamesWon,
    int? gamesLost,
    int? gamesDraw,
    List<String>? achievements,
    List<String>? friends,
    List<String>? friendRequestsSent,
    List<String>? friendRequestsReceived,
    List<String>? blockedUsers,
    bool? isOnline,
    DateTime? lastSeen,
    bool? isGuest,
    Map<String, int>? winStreak,
    List<String>? savedGames,
    Map<String, String>? preferences,
    String? fcmToken,
    String? countryCode,
    bool? removeAds,
    DateTime? premiumStartDate,
    DateTime? premiumExpiryDate,
    bool? emailVerified,
  }) {
    return ChessUser(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      classicalRating: classicalRating ?? this.classicalRating,
      blitzRating: blitzRating ?? this.blitzRating,
      tempoRating: tempoRating ?? this.tempoRating,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      gamesWon: gamesWon ?? this.gamesWon,
      gamesLost: gamesLost ?? this.gamesLost,
      gamesDraw: gamesDraw ?? this.gamesDraw,
      achievements: achievements ?? this.achievements,
      friends: friends ?? this.friends,
      friendRequestsSent: friendRequestsSent ?? this.friendRequestsSent,
      friendRequestsReceived:
          friendRequestsReceived ?? this.friendRequestsReceived,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      isGuest: isGuest ?? this.isGuest,
      winStreak: winStreak ?? this.winStreak,
      savedGames: savedGames ?? this.savedGames,
      preferences: preferences ?? this.preferences,
      fcmToken: fcmToken ?? this.fcmToken,
      countryCode: countryCode ?? this.countryCode,
      removeAds: removeAds ?? this.removeAds,
      premiumStartDate: premiumStartDate ?? this.premiumStartDate,
      premiumExpiryDate: premiumExpiryDate ?? this.premiumExpiryDate,
      emailVerified: emailVerified ?? this.emailVerified,
    );
  }
}
