class UCICommands {
  static const String isReady = 'isready';
  static const String goMoveTime = 'go movetime';
  static const String goInfinite = 'go infinite';
  static const String stop = 'stop';
  static const String position = 'position fen';
  static const String bestMove = 'bestmove';

  // UCI Options for skill configuration
  static const String setOption = 'setoption name';
  static const String skillLevel = 'Skill Level';
  static const String depth = 'Depth';
  static const String multiPV = 'MultiPV';
  static const String hash = 'Hash';
  static const String threads = 'Threads';
  static const String contempt = 'Contempt';

  // Helper to build setoption command
  static String buildSetOption(String optionName, dynamic value) {
    return '$setOption $optionName value $value';
  }
}
