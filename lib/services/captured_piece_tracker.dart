class CapturedPiecesTracker {
  // Standard chess starting position in FEN format
  static const String standardStartingFEN =
      "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";

  // Map to convert FEN notation to piece symbols
  static const Map<String, String> fenToPieceSymbol = {
    'p': 'p', 'r': 'r', 'n': 'n', 'b': 'b', 'q': 'q', 'k': 'k', // Black pieces
    'P': 'P', 'R': 'R', 'N': 'N', 'B': 'B', 'Q': 'Q', 'K': 'K', // White pieces
  };

  // Material values for calculating advantage
  static const Map<String, int> pieceValues = {
    'p': 1, 'P': 1, // Pawns
    'n': 3, 'N': 3, // Knights
    'b': 3, 'B': 3, // Bishops
    'r': 5, 'R': 5, // Rooks
    'q': 9, 'Q': 9, // Queens
    'k': 0, 'K': 0, // Kings (no value for capture)
  };

  static Map<String, int> _countPiecesFromFEN(String fen) {
    Map<String, int> pieces = {};

    // Extract just the board part of the FEN (before the first space)
    String boardFEN = fen.split(' ')[0];

    for (String char in boardFEN.split('')) {
      if (fenToPieceSymbol.containsKey(char)) {
        String pieceSymbol = fenToPieceSymbol[char]!;
        pieces[pieceSymbol] = (pieces[pieceSymbol] ?? 0) + 1;
      }
      // Skip numbers (empty squares) and slashes (rank separators)
    }

    return pieces;
  }

  static Map<String, List<String>> getCapturedPieces(String currentFEN) {
    Map<String, int> startingPieces = _countPiecesFromFEN(standardStartingFEN);
    Map<String, int> currentPieces = _countPiecesFromFEN(currentFEN);

    List<String> whiteCaptured = []; // Pieces captured by white (black pieces)
    List<String> blackCaptured = []; // Pieces captured by black (white pieces)

    // Check for captured black pieces (captured by white)
    for (String piece in ['p', 'r', 'n', 'b', 'q', 'k']) {
      int starting = startingPieces[piece] ?? 0;
      int current = currentPieces[piece] ?? 0;
      int captured = starting - current;

      for (int i = 0; i < captured; i++) {
        whiteCaptured.add(piece);
      }
    }

    // Check for captured white pieces (captured by black)
    for (String piece in ['P', 'R', 'N', 'B', 'Q', 'K']) {
      int starting = startingPieces[piece] ?? 0;
      int current = currentPieces[piece] ?? 0;
      int captured = starting - current;

      for (int i = 0; i < captured; i++) {
        blackCaptured.add(piece);
      }
    }

    return {'whiteCaptured': whiteCaptured, 'blackCaptured': blackCaptured};
  }

  static int getMaterialAdvantage(String currentFEN, bool forWhite) {
    Map<String, List<String>> captured = getCapturedPieces(currentFEN);

    int whiteAdvantage = 0;
    int blackAdvantage = 0;

    // Calculate value of pieces captured by white
    for (String piece in captured['whiteCaptured']!) {
      whiteAdvantage += pieceValues[piece] ?? 0;
    }

    // Calculate value of pieces captured by black
    for (String piece in captured['blackCaptured']!) {
      blackAdvantage += pieceValues[piece] ?? 0;
    }

    if (forWhite) {
      return whiteAdvantage - blackAdvantage;
    } else {
      return blackAdvantage - whiteAdvantage;
    }
  }
}
