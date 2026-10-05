import 'package:flutter/material.dart';

class Constants {
  static const String uid = 'uid';
  static const String email = 'email';
  static const String displayName = 'displayName';
  static const String photoUrl = 'photoUrl';
  static const String classicalRating = 'classicalRating';
  static const String blitzRating = 'blitzRating';
  static const String tempoRating = 'tempoRating';
  static const String gamesPlayed = 'gamesPlayed';
  static const String gamesWon = 'gamesWon';
  static const String gamesLost = 'gamesLost';
  static const String gamesDraw = 'gamesDraw';
  static const String achievements = 'achievements';
  static const String friends = 'friends';
  static const String friendRequestsSent = 'friendRequestsSent';
  static const String friendRequestsReceived = 'friendRequestsReceived';
  static const String blockedUsers = 'blockedUsers';
  static const String isOnline = 'isOnline';
  static const String lastSeen = 'lastSeen';
  static const String isGuest = 'isGuest';
  static const String winStreak = 'winStreak';
  static const String savedGames = 'savedGames';
  static const String preferences = 'preferences';
  static const String fcmToken = 'fcmToken';
  static const String countryCode = 'countryCode';
  static const String removeAds = 'removeAds';
  static const String emailVerified = 'emailVerified';

  static const String premiumStartDate = 'premiumStartDate';
  static const String premiumExpiryDate = 'premiumExpiryDate';

  // For the guest user's display name
  static const String guestDisplayName = 'Guest';

  static const String timeControl = 'timeControl';
  static const String title = 'title';
  static const String icon = 'icon';

  static const String white = 'White';
  static const String black = 'Black';
  static const name = 'name';
  static const level = 'level';
  static const description = 'description';
  static const String gameId = 'gameId';
  static const String gameMode = 'gameMode';
  static const String difficulty = 'difficulty';

  // Database collection names
  static const String usersCollection = 'users';
  static const String gamesCollection = 'games';
  static const String friendsCollection = 'friends';
  static const String achievementsCollection = 'achievements';
  static const String gameRoomsCollection =
      'gameRooms'; // Only for searchable games (waiting status)
  static const String activeGamesCollection =
      'activeGames'; // For currently playing games
  static const String archivedGamesCollection =
      'archivedGames'; // For completed/aborted games
  static const String gameHistoryCollection = 'gameHistory';
  static const String notificationsCollection = 'notifications';
  static const String invitesCollection = 'invites';
  static const String monetizationConfigCollection = 'monetization_config';
  static const String zegoConfigCollection = 'zego_config';
  static const String config = 'config';
  static const String adminsCollection = 'admins';

  static const String profileImagesCollection = 'profile_images';

  // LevelPlay Config fields (stored on backend under config key 'levelplayConfig')
  static const String levelplayConfigKey = 'levelplayConfig';
  static const String lpAndroidAppKey = 'androidAppKey';
  static const String lpIosAppKey = 'iosAppKey';
  static const String lpAndroidBannerId = 'androidBannerAdUnitId';
  static const String lpIosBannerId = 'iosBannerAdUnitId';
  static const String lpAndroidInterstitialId = 'androidInterstitialAdUnitId';
  static const String lpIosInterstitialId = 'iosInterstitialAdUnitId';
  static const String lpAndroidRewardedId = 'androidRewardedAdUnitId';
  static const String lpIosRewardedId = 'iosRewardedAdUnitId';
  static const String lpNativePlacement = 'nativePlacementName';
  static const String lpGdprEnabled = 'gdprEnabled';
  static const String lpChildDirected = 'childDirected';
  static const String lpTestSuite = 'testSuiteEnabled';
  static const String enabled = 'enabled';
  static const String lastUpdated = 'lastUpdated';

  // Monetization Config fields
  static const String monetizationProvider =
      'monetizationProvider'; // 'levelplay' or 'disabled'
  static const String adsEnabled = 'adsEnabled';
  static const String monetizationConfig = 'monetization_config';

  // Zego Config fields
  static const String zegoAppId = 'zegoAppId';
  static const String zegoAppSign = 'zegoAppSign';
  static const String audioFeatureEnabled = 'audioFeatureEnabled';

  // Firestore fields
  static const String fieldPlayer1Id = 'player1Id';
  static const String fieldPlayer2Id = 'player2Id';
  static const String fieldPlayer1DisplayName = 'player1DisplayName';
  static const String fieldPlayer2DisplayName = 'player2DisplayName';
  static const String fieldPlayer1PhotoUrl = 'player1PhotoUrl';
  static const String fieldPlayer2PhotoUrl = 'player2PhotoUrl';
  static const String fieldPlayer1Flag = 'player1Flag';
  static const String fieldPlayer2Flag = 'player2Flag';
  static const String fieldPlayer1Color = 'player1Color';
  static const String fieldPlayer2Color = 'player2Color';
  static const String fieldStatus = 'status';
  static const String fieldFen = 'fen';
  static const String fieldMoves = 'moves';
  static const String fieldCreatedAt = 'createdAt';
  static const String fieldLastMoveAt = 'lastMoveAt';
  static const String fieldPlayer1Rating = 'player1Rating';
  static const String fieldPlayer2Rating = 'player2Rating';
  static const String fieldRatingBasedSearch = 'ratingBasedSearch';
  static const String fieldInitialWhitesTime = 'initialWhitesTime';
  static const String fieldInitialBlacksTime = 'initialBlacksTime';
  static const String fieldWinnerId = 'winnerId';
  static const String fieldDrawOfferedBy = 'drawOfferedBy';
  static const String fieldDrawOfferStatus = 'drawOfferStatus';
  static const String fieldRematchOfferedBy = 'rematchOfferedBy';

  // Draw offer status values
  static const String drawOfferStatusPending = 'pending';
  static const String drawOfferStatusAccepted = 'accepted';
  static const String drawOfferStatusRejected = 'rejected';

  static const String fieldWhitesTimeRemaining = 'whitesTimeRemaining';
  static const String fieldBlacksTimeRemaining = 'blacksTimeRemaining';
  static const String fieldPlayer1Score = 'player1Score';
  static const String fieldPlayer2Score = 'player2Score';
  static const String fieldIsPrivate = 'isPrivate';
  static const String fieldSpectatorLink = 'spectatorLink';

  // Audio room fields
  static const String fieldAudioRoomStatus = 'audioRoomStatus';
  static const String fieldAudioRoomInvitedBy = 'audioRoomInvitedBy';
  static const String fieldAudioRoomParticipants = 'audioRoomParticipants';
  static const String fieldAudioRoomCreatedAt = 'audioRoomCreatedAt';
  static const String fieldAudioRoomUpdatedAt = 'audioRoomUpdatedAt';

  // Saved Game fields
  static const String fieldUserId = 'userId';
  static const String fieldOpponentId = 'opponentId';
  static const String fieldOpponentDisplayName = 'opponentDisplayName';
  static const String fieldInitialFen = 'initialFen';
  static const String fieldResult = 'result';
  static const String fieldWinnerColor = 'winnerColor';
  static const String fieldFinalWhitesTime = 'finalWhitesTime';
  static const String fieldFinalBlacksTime = 'finalBlacksTime';

  static const String fieldGameId = 'gameId';
  static const String fieldGameMode = 'gameMode';
  static const String fieldDifficulty = 'difficulty';

  // "waiting", "active", "completed", "aborted"
  static const String statusWaiting = 'waiting';
  static const String statusActive = 'active';
  static const String statusCompleted = 'completed';
  static const String statusAborted = 'aborted';
  static const String statusDeclined = 'declined';

  // Audio room statuses
  static const String audioStatusNone = 'none';
  static const String audioStatusInvitePending = 'invite_pending';
  static const String audioStatusActive = 'active';
  static const String audioStatusDeclined = 'declined';
  static const String audioStatusEnded = 'ended';

  // Game results
  static const String win = 'win';
  static const String loss = 'loss';
  static const String draw = 'draw';
  static const String none = 'none';

  static const String classical = 'Classical';
  static const String fast = 'Fast';
  static const String blitz3 = 'Blitz3';

  static const String chatRoomsCollections = 'chat_rooms';
  static const String messagesCollection = 'messages';
  static const String timestamp = 'timestamp';
  static const String text = 'text';
  static const String senderId = 'senderId';
  static const String isRead = 'isRead';

  // polls constants
  static const String pollsCollection = 'polls';
  static const String pollId = 'pollId';
  static const String question = 'question';
  static const String options = 'options';
  static const String votes = 'votes';
  static const String userVotes = 'userVotes';
  static const String userId = 'userId';
  static const String optionId = 'optionId';
  static const String votedAt = 'votedAt';
  static const String pollVotes = 'pollVotes';
  static const String id = 'id';
  static const String isActive = 'isActive';
  static const String createdAt = 'createdAt';

  // Map game modes to rating types
  static const Map<String, String> gameModeToRatingType = {
    '30 sec/move': tempoRating,
    '60 sec/move': classicalRating,
    '3 min + 5s bonus 3s': blitzRating,
  };

  static const List<Map<String, dynamic>> gameModes = [
    {'title': classical, 'timeControl': '60 sec/move', 'icon': Icons.timer},
    {'title': fast, 'timeControl': '30 sec/move', 'icon': Icons.speed},
    {
      'title': blitz3,
      'timeControl': '3 min + 5s bonus 3s',
      'icon': Icons.flash_on,
    },
  ];

  static const List<Map<String, dynamic>> difficulties = [
    {
      'name': 'Beginner',
      'level': 0,
      'description': 'Very easy - learns basics',
      'icon': Icons.sentiment_very_satisfied,
    },
    {
      'name': 'Easy',
      'level': 1,
      'description': 'Good for beginners',
      'icon': Icons.sentiment_satisfied,
    },
    {
      'name': 'Normal',
      'level': 2,
      'description': 'Balanced gameplay',
      'icon': Icons.sentiment_neutral,
    },
    {
      'name': 'Hard',
      'level': 3,
      'description': 'Challenging opponent',
      'icon': Icons.sentiment_very_dissatisfied,
    },
  ];

  static String formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}k';
    }
    return count.toString();
  }

  // List of countries with their codes and names
  static const List<Map<String, String>> countries = [
    {'code': 'AD', 'name': 'Andorra'},
    {'code': 'AE', 'name': 'United Arab Emirates'},
    {'code': 'AF', 'name': 'Afghanistan'},
    {'code': 'AG', 'name': 'Antigua and Barbuda'},
    {'code': 'AI', 'name': 'Anguilla'},
    {'code': 'AL', 'name': 'Albania'},
    {'code': 'AM', 'name': 'Armenia'},
    {'code': 'AO', 'name': 'Angola'},
    {'code': 'AR', 'name': 'Argentina'},
    {'code': 'AS', 'name': 'American Samoa'},
    {'code': 'AT', 'name': 'Austria'},
    {'code': 'AU', 'name': 'Australia'},
    {'code': 'AW', 'name': 'Aruba'},
    {'code': 'AZ', 'name': 'Azerbaijan'},
    {'code': 'BA', 'name': 'Bosnia and Herzegovina'},
    {'code': 'BB', 'name': 'Barbados'},
    {'code': 'BD', 'name': 'Bangladesh'},
    {'code': 'BE', 'name': 'Belgium'},
    {'code': 'BF', 'name': 'Burkina Faso'},
    {'code': 'BG', 'name': 'Bulgaria'},
    {'code': 'BH', 'name': 'Bahrain'},
    {'code': 'BI', 'name': 'Burundi'},
    {'code': 'BJ', 'name': 'Benin'},
    {'code': 'BM', 'name': 'Bermuda'},
    {'code': 'BN', 'name': 'Brunei'},
    {'code': 'BO', 'name': 'Bolivia'},
    {'code': 'BR', 'name': 'Brazil'},
    {'code': 'BS', 'name': 'Bahamas'},
    {'code': 'BT', 'name': 'Bhutan'},
    {'code': 'BW', 'name': 'Botswana'},
    {'code': 'BY', 'name': 'Belarus'},
    {'code': 'BZ', 'name': 'Belize'},
    {'code': 'CA', 'name': 'Canada'},
    {'code': 'CD', 'name': 'Democratic Republic of the Congo'},
    {'code': 'CF', 'name': 'Central African Republic'},
    {'code': 'CG', 'name': 'Republic of the Congo'},
    {'code': 'CH', 'name': 'Switzerland'},
    {'code': 'CI', 'name': 'Côte d\'Ivoire'},
    {'code': 'CL', 'name': 'Chile'},
    {'code': 'CM', 'name': 'Cameroon'},
    {'code': 'CN', 'name': 'China'},
    {'code': 'CO', 'name': 'Colombia'},
    {'code': 'CR', 'name': 'Costa Rica'},
    {'code': 'CU', 'name': 'Cuba'},
    {'code': 'CV', 'name': 'Cape Verde'},
    {'code': 'CW', 'name': 'Curaçao'},
    {'code': 'CY', 'name': 'Cyprus'},
    {'code': 'CZ', 'name': 'Czech Republic'},
    {'code': 'DE', 'name': 'Germany'},
    {'code': 'DJ', 'name': 'Djibouti'},
    {'code': 'DK', 'name': 'Denmark'},
    {'code': 'DM', 'name': 'Dominica'},
    {'code': 'DO', 'name': 'Dominican Republic'},
    {'code': 'DZ', 'name': 'Algeria'},
    {'code': 'EC', 'name': 'Ecuador'},
    {'code': 'EE', 'name': 'Estonia'},
    {'code': 'EG', 'name': 'Egypt'},
    {'code': 'EH', 'name': 'Western Sahara'},
    {'code': 'ER', 'name': 'Eritrea'},
    {'code': 'ES', 'name': 'Spain'},
    {'code': 'ET', 'name': 'Ethiopia'},
    {'code': 'FI', 'name': 'Finland'},
    {'code': 'FJ', 'name': 'Fiji'},
    {'code': 'FK', 'name': 'Falkland Islands'},
    {'code': 'FM', 'name': 'Micronesia'},
    {'code': 'FO', 'name': 'Faroe Islands'},
    {'code': 'FR', 'name': 'France'},
    {'code': 'GA', 'name': 'Gabon'},
    {'code': 'GB', 'name': 'United Kingdom'},
    {'code': 'GD', 'name': 'Grenada'},
    {'code': 'GE', 'name': 'Georgia'},
    {'code': 'GF', 'name': 'French Guiana'},
    {'code': 'GG', 'name': 'Guernsey'},
    {'code': 'GH', 'name': 'Ghana'},
    {'code': 'GI', 'name': 'Gibraltar'},
    {'code': 'GL', 'name': 'Greenland'},
    {'code': 'GM', 'name': 'Gambia'},
    {'code': 'GN', 'name': 'Guinea'},
    {'code': 'GP', 'name': 'Guadeloupe'},
    {'code': 'GQ', 'name': 'Equatorial Guinea'},
    {'code': 'GR', 'name': 'Greece'},
    {'code': 'GT', 'name': 'Guatemala'},
    {'code': 'GU', 'name': 'Guam'},
    {'code': 'GW', 'name': 'Guinea-Bissau'},
    {'code': 'GY', 'name': 'Guyana'},
    {'code': 'HK', 'name': 'Hong Kong'},
    {'code': 'HN', 'name': 'Honduras'},
    {'code': 'HR', 'name': 'Croatia'},
    {'code': 'HT', 'name': 'Haiti'},
    {'code': 'HU', 'name': 'Hungary'},
    {'code': 'ID', 'name': 'Indonesia'},
    {'code': 'IE', 'name': 'Ireland'},
    {'code': 'IL', 'name': 'Israel'},
    {'code': 'IM', 'name': 'Isle of Man'},
    {'code': 'IN', 'name': 'India'},
    {'code': 'IO', 'name': 'British Indian Ocean Territory'},
    {'code': 'IQ', 'name': 'Iraq'},
    {'code': 'IR', 'name': 'Iran'},
    {'code': 'IS', 'name': 'Iceland'},
    {'code': 'IT', 'name': 'Italy'},
    {'code': 'JE', 'name': 'Jersey'},
    {'code': 'JM', 'name': 'Jamaica'},
    {'code': 'JO', 'name': 'Jordan'},
    {'code': 'JP', 'name': 'Japan'},
    {'code': 'KE', 'name': 'Kenya'},
    {'code': 'KG', 'name': 'Kyrgyzstan'},
    {'code': 'KH', 'name': 'Cambodia'},
    {'code': 'KI', 'name': 'Kiribati'},
    {'code': 'KM', 'name': 'Comoros'},
    {'code': 'KN', 'name': 'Saint Kitts and Nevis'},
    {'code': 'KP', 'name': 'North Korea'},
    {'code': 'KR', 'name': 'South Korea'},
    {'code': 'KW', 'name': 'Kuwait'},
    {'code': 'KY', 'name': 'Cayman Islands'},
    {'code': 'KZ', 'name': 'Kazakhstan'},
    {'code': 'LA', 'name': 'Laos'},
    {'code': 'LB', 'name': 'Lebanon'},
    {'code': 'LC', 'name': 'Saint Lucia'},
    {'code': 'LI', 'name': 'Liechtenstein'},
    {'code': 'LK', 'name': 'Sri Lanka'},
    {'code': 'LR', 'name': 'Liberia'},
    {'code': 'LS', 'name': 'Lesotho'},
    {'code': 'LT', 'name': 'Lithuania'},
    {'code': 'LU', 'name': 'Luxembourg'},
    {'code': 'LV', 'name': 'Latvia'},
    {'code': 'LY', 'name': 'Libya'},
    {'code': 'MA', 'name': 'Morocco'},
    {'code': 'MC', 'name': 'Monaco'},
    {'code': 'MD', 'name': 'Moldova'},
    {'code': 'ME', 'name': 'Montenegro'},
    {'code': 'MF', 'name': 'Saint Martin'},
    {'code': 'MG', 'name': 'Madagascar'},
    {'code': 'MH', 'name': 'Marshall Islands'},
    {'code': 'MK', 'name': 'North Macedonia'},
    {'code': 'ML', 'name': 'Mali'},
    {'code': 'MM', 'name': 'Myanmar'},
    {'code': 'MN', 'name': 'Mongolia'},
    {'code': 'MO', 'name': 'Macao'},
    {'code': 'MP', 'name': 'Northern Mariana Islands'},
    {'code': 'MQ', 'name': 'Martinique'},
    {'code': 'MR', 'name': 'Mauritania'},
    {'code': 'MS', 'name': 'Montserrat'},
    {'code': 'MT', 'name': 'Malta'},
    {'code': 'MU', 'name': 'Mauritius'},
    {'code': 'MV', 'name': 'Maldives'},
    {'code': 'MW', 'name': 'Malawi'},
    {'code': 'MX', 'name': 'Mexico'},
    {'code': 'MY', 'name': 'Malaysia'},
    {'code': 'MZ', 'name': 'Mozambique'},
    {'code': 'NA', 'name': 'Namibia'},
    {'code': 'NC', 'name': 'New Caledonia'},
    {'code': 'NE', 'name': 'Niger'},
    {'code': 'NF', 'name': 'Norfolk Island'},
    {'code': 'NG', 'name': 'Nigeria'},
    {'code': 'NI', 'name': 'Nicaragua'},
    {'code': 'NL', 'name': 'Netherlands'},
    {'code': 'NO', 'name': 'Norway'},
    {'code': 'NP', 'name': 'Nepal'},
    {'code': 'NR', 'name': 'Nauru'},
    {'code': 'NU', 'name': 'Niue'},
    {'code': 'NZ', 'name': 'New Zealand'},
    {'code': 'OM', 'name': 'Oman'},
    {'code': 'PA', 'name': 'Panama'},
    {'code': 'PE', 'name': 'Peru'},
    {'code': 'PF', 'name': 'French Polynesia'},
    {'code': 'PG', 'name': 'Papua New Guinea'},
    {'code': 'PH', 'name': 'Philippines'},
    {'code': 'PK', 'name': 'Pakistan'},
    {'code': 'PL', 'name': 'Poland'},
    {'code': 'PM', 'name': 'Saint Pierre and Miquelon'},
    {'code': 'PN', 'name': 'Pitcairn'},
    {'code': 'PR', 'name': 'Puerto Rico'},
    {'code': 'PS', 'name': 'Palestine'},
    {'code': 'PT', 'name': 'Portugal'},
    {'code': 'PW', 'name': 'Palau'},
    {'code': 'PY', 'name': 'Paraguay'},
    {'code': 'QA', 'name': 'Qatar'},
    {'code': 'RE', 'name': 'Réunion'},
    {'code': 'RO', 'name': 'Romania'},
    {'code': 'RS', 'name': 'Serbia'},
    {'code': 'RU', 'name': 'Russia'},
    {'code': 'RW', 'name': 'Rwanda'},
    {'code': 'SA', 'name': 'Saudi Arabia'},
    {'code': 'SB', 'name': 'Solomon Islands'},
    {'code': 'SC', 'name': 'Seychelles'},
    {'code': 'SD', 'name': 'Sudan'},
    {'code': 'SE', 'name': 'Sweden'},
    {'code': 'SG', 'name': 'Singapore'},
    {'code': 'SH', 'name': 'Saint Helena'},
    {'code': 'SI', 'name': 'Slovenia'},
    {'code': 'SJ', 'name': 'Svalbard and Jan Mayen'},
    {'code': 'SK', 'name': 'Slovakia'},
    {'code': 'SL', 'name': 'Sierra Leone'},
    {'code': 'SM', 'name': 'San Marino'},
    {'code': 'SN', 'name': 'Senegal'},
    {'code': 'SO', 'name': 'Somalia'},
    {'code': 'SR', 'name': 'Suriname'},
    {'code': 'SS', 'name': 'South Sudan'},
    {'code': 'ST', 'name': 'São Tomé and Príncipe'},
    {'code': 'SV', 'name': 'El Salvador'},
    {'code': 'SX', 'name': 'Sint Maarten'},
    {'code': 'SY', 'name': 'Syria'},
    {'code': 'SZ', 'name': 'Eswatini'},
    {'code': 'TC', 'name': 'Turks and Caicos Islands'},
    {'code': 'TD', 'name': 'Chad'},
    {'code': 'TF', 'name': 'French Southern Territories'},
    {'code': 'TG', 'name': 'Togo'},
    {'code': 'TH', 'name': 'Thailand'},
    {'code': 'TJ', 'name': 'Tajikistan'},
    {'code': 'TK', 'name': 'Tokelau'},
    {'code': 'TL', 'name': 'East Timor'},
    {'code': 'TM', 'name': 'Turkmenistan'},
    {'code': 'TN', 'name': 'Tunisia'},
    {'code': 'TO', 'name': 'Tonga'},
    {'code': 'TR', 'name': 'Turkey'},
    {'code': 'TT', 'name': 'Trinidad and Tobago'},
    {'code': 'TV', 'name': 'Tuvalu'},
    {'code': 'TW', 'name': 'Taiwan'},
    {'code': 'TZ', 'name': 'Tanzania'},
    {'code': 'UA', 'name': 'Ukraine'},
    {'code': 'UG', 'name': 'Uganda'},
    {'code': 'UM', 'name': 'United States Minor Outlying Islands'},
    {'code': 'US', 'name': 'United States'},
    {'code': 'UY', 'name': 'Uruguay'},
    {'code': 'UZ', 'name': 'Uzbekistan'},
    {'code': 'VA', 'name': 'Vatican City'},
    {'code': 'VC', 'name': 'Saint Vincent and the Grenadines'},
    {'code': 'VE', 'name': 'Venezuela'},
    {'code': 'VG', 'name': 'British Virgin Islands'},
    {'code': 'VI', 'name': 'U.S. Virgin Islands'},
    {'code': 'VN', 'name': 'Vietnam'},
    {'code': 'VU', 'name': 'Vanuatu'},
    {'code': 'WF', 'name': 'Wallis and Futuna'},
    {'code': 'WS', 'name': 'Samoa'},
    {'code': 'XK', 'name': 'Kosovo'},
    {'code': 'YE', 'name': 'Yemen'},
    {'code': 'YT', 'name': 'Mayotte'},
    {'code': 'ZA', 'name': 'South Africa'},
    {'code': 'ZM', 'name': 'Zambia'},
    {'code': 'ZW', 'name': 'Zimbabwe'},
  ];
}
