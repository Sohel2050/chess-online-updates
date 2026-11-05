/// XP -> level and what each level unlocks. Same curve as backend/services/levels.js
/// (backend/test/levels.test.js pins the numbers; change both or neither).
///
/// Going from level L to L+1 costs 50 + 50*L XP, so the XP needed to REACH level L is
/// 25 * (L - 1) * (L + 2): L2=100, L3=250, L4=450, L5=700, L10=2700, L30=23200.
const int maxLevel = 30;

int xpForLevel(int level) {
  final l = level.clamp(1, maxLevel);
  return 25 * (l - 1) * (l + 2);
}

class LevelInfo {
  final int level;
  final int xp;
  final int levelStartXp;
  final int? nextLevelXp; // null at max level

  const LevelInfo(this.level, this.xp, this.levelStartXp, this.nextLevelXp);

  bool get isMax => nextLevelXp == null;
  int get xpIntoLevel => xp - levelStartXp;
  int get xpToNext => isMax ? 0 : nextLevelXp! - xp;
  double get progress => isMax ? 1.0 : xpIntoLevel / (nextLevelXp! - levelStartXp);
}

LevelInfo levelForXp(int xp) {
  final total = xp < 0 ? 0 : xp;
  var level = 1;
  while (level < maxLevel && total >= xpForLevel(level + 1)) {
    level++;
  }
  return LevelInfo(
    level,
    total,
    xpForLevel(level),
    level >= maxLevel ? null : xpForLevel(level + 1),
  );
}

/// Level needed for each board theme / piece set id (ids match chess_styles.dart).
/// Anything not listed is free from level 1.
const Map<String, int> boardUnlockLevel = {
  'brown': 1,
  'blueGrey': 1,
  'green': 1,
  'Pink': 2,
  'Dart': 3,
  'ocean': 4,
  'sand': 6,
  'mint': 8,
  'coral': 10,
  'purple': 12,
  'graphite': 15,
  'midnight': 18,
};

const Map<String, int> pieceUnlockLevel = {
  'merida': 1,
  'letters': 1,
  'chessnut': 1,
  'fantasy': 3,
  'classic': 5,
  'spatial': 7,
  'gold': 9,
  'celtic': 11,
  'ice': 13,
  'ruby': 16,
  'neon': 20,
};

int boardLevelNeeded(String id) => boardUnlockLevel[id] ?? 1;
int pieceLevelNeeded(String id) => pieceUnlockLevel[id] ?? 1;

/// Human-readable names of everything that unlocks exactly at [level].
/// [boardLabel] / [pieceLabel] turn an id into the name shown in Options.
List<String> unlocksAtLevel(
  int level, {
  required String Function(String id) boardLabel,
  required String Function(String id) pieceLabel,
}) {
  return [
    for (final e in boardUnlockLevel.entries)
      if (e.value == level) '${boardLabel(e.key)} board',
    for (final e in pieceUnlockLevel.entries)
      if (e.value == level) '${pieceLabel(e.key)} pieces',
  ];
}

/// Titles shown next to the level number.
String levelTitle(int level) {
  if (level >= 25) return 'Grandmaster';
  if (level >= 20) return 'Master';
  if (level >= 15) return 'Expert';
  if (level >= 10) return 'Veteran';
  if (level >= 5) return 'Tactician';
  return 'Rookie';
}
