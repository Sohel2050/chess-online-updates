import 'package:flutter/material.dart';
import 'package:squares/squares.dart';

/// Extra free board colours + piece styles for the Options screen.
/// Board themes are plain colour sets; piece sets are drawn with text glyphs
/// so no image assets are needed.
class BoardStyle {
  final String id;
  final String label;
  final BoardTheme theme;
  final Color light;
  final Color dark;
  const BoardStyle(this.id, this.label, this.theme, this.light, this.dark);
}

BoardTheme _custom(Color light, Color dark) => BoardTheme(
      lightSquare: light,
      darkSquare: dark,
      check: const Color(0xFFE53935),
      checkmate: const Color(0xFFB71C1C),
      previous: const Color(0x669CCC65),
      selected: const Color(0x99FFEB3B),
      premove: const Color(0x66AB47BC),
    );

/// Colour-blind friendly board (Okabe-Ito palette). The two square colours differ
/// strongly in BRIGHTNESS (not only hue), and the highlights sit on the blue/orange
/// axis that stays distinguishable with red-green and most other colour-vision types.
/// Last move = blue, selected piece = orange, check = vermillion, premove = pink-purple.
final BoardTheme colorBlindBoardTheme = BoardTheme(
  lightSquare: const Color(0xFFF2F2F2),
  darkSquare: const Color(0xFF56789C),
  check: const Color(0xFFD55E00),
  checkmate: const Color(0xFF8C2F00),
  previous: const Color(0x990072B2),
  selected: const Color(0xCCE69F00),
  premove: const Color(0x99CC79A7),
);

final List<BoardStyle> boardStyles = [
  BoardStyle('brown', 'Classic Brown', BoardTheme.brown,
      const Color(0xFFF0D9B5), const Color(0xFFB58863)),
  BoardStyle('blueGrey', 'Blue Grey', BoardTheme.blueGrey,
      const Color(0xFFDEE3E6), const Color(0xFF8CA2AD)),
  BoardStyle('Pink', 'Pink', BoardTheme.pink,
      const Color(0xFFFCE4EC), const Color(0xFFF06292)),
  BoardStyle('Dart', 'Dart', BoardTheme.dart,
      const Color(0xFFE0E0E0), const Color(0xFF616161)),
  BoardStyle('green', 'Tournament Green',
      _custom(const Color(0xFFEEEED2), const Color(0xFF769656)),
      const Color(0xFFEEEED2), const Color(0xFF769656)),
  BoardStyle('ocean', 'Ocean Blue',
      _custom(const Color(0xFFD6E6F5), const Color(0xFF3F7CAC)),
      const Color(0xFFD6E6F5), const Color(0xFF3F7CAC)),
  BoardStyle('purple', 'Royal Purple',
      _custom(const Color(0xFFE8DDF3), const Color(0xFF7E57C2)),
      const Color(0xFFE8DDF3), const Color(0xFF7E57C2)),
  BoardStyle('sand', 'Desert Sand',
      _custom(const Color(0xFFF7EBD1), const Color(0xFFD2A55E)),
      const Color(0xFFF7EBD1), const Color(0xFFD2A55E)),
  BoardStyle('midnight', 'Midnight',
      _custom(const Color(0xFF5C6B8A), const Color(0xFF2B3550)),
      const Color(0xFF5C6B8A), const Color(0xFF2B3550)),
  BoardStyle('coral', 'Coral Red',
      _custom(const Color(0xFFFFE3DC), const Color(0xFFE5735E)),
      const Color(0xFFFFE3DC), const Color(0xFFE5735E)),
  BoardStyle('mint', 'Fresh Mint',
      _custom(const Color(0xFFE3F6EC), const Color(0xFF4DB38A)),
      const Color(0xFFE3F6EC), const Color(0xFF4DB38A)),
  BoardStyle('graphite', 'Graphite',
      _custom(const Color(0xFFCFCFCF), const Color(0xFF424242)),
      const Color(0xFFCFCFCF), const Color(0xFF424242)),
];

BoardStyle boardStyleById(String id) =>
    boardStyles.firstWhere((s) => s.id == id, orElse: () => boardStyles.first);

BoardStyle boardStyleOfTheme(BoardTheme t) =>
    boardStyles.firstWhere((s) => identical(s.theme, t) || s.theme == t,
        orElse: () => boardStyles.first);

/// Glyph-based piece styles.
class PieceStyle {
  final String id;
  final String label;
  final Color white;
  final Color black;
  final Color? whiteOutline;
  final Color? blackOutline;
  final List<Shadow> shadows;
  const PieceStyle(this.id, this.label, this.white, this.black,
      {this.whiteOutline, this.blackOutline, this.shadows = const []});
}

const List<PieceStyle> glyphPieceStyles = [
  PieceStyle('classic', 'Classic Glyph', Color(0xFFFFFFFF), Color(0xFF1B1B1B),
      whiteOutline: Color(0xFF1B1B1B), blackOutline: Color(0xFF000000)),
  PieceStyle('gold', 'Gold & Black', Color(0xFFFFC83D), Color(0xFF212121),
      whiteOutline: Color(0xFF7A5A00), blackOutline: Color(0xFFFFC83D)),
  PieceStyle('ice', 'Ice & Navy', Color(0xFFE3F6FF), Color(0xFF0D2B52),
      whiteOutline: Color(0xFF1E6FA8), blackOutline: Color(0xFF4FC3F7)),
  PieceStyle('ruby', 'Ruby & Ebony', Color(0xFFFF6B6B), Color(0xFF1F1F2E),
      whiteOutline: Color(0xFF7F0000), blackOutline: Color(0xFFFF8A80)),
  PieceStyle('neon', 'Neon', Color(0xFF39FF88), Color(0xFFB04DFF),
      whiteOutline: Color(0xFF004D25), blackOutline: Color(0xFF2E0057),
      shadows: [Shadow(color: Color(0x8800FF99), blurRadius: 6)]),
];

/// Maps squares piece symbols (uppercase = white, lowercase = black) to glyphs.
const Map<String, String> _glyphs = {
  'K': '\u2654', 'Q': '\u2655', 'R': '\u2656', 'B': '\u2657', 'N': '\u2658', 'P': '\u2659',
  'k': '\u265A', 'q': '\u265B', 'r': '\u265C', 'b': '\u265D', 'n': '\u265E', 'p': '\u265F',
};

Widget _glyphPiece(PieceStyle s, String symbol) {
  final isWhite = symbol == symbol.toUpperCase();
  // Always use the solid glyphs and colour them ourselves.
  final solid = _glyphs[symbol.toLowerCase()]!;
  final fill = isWhite ? s.white : s.black;
  final outline = isWhite ? s.whiteOutline : s.blackOutline;
  return LayoutBuilder(builder: (context, c) {
    final size = (c.biggest.shortestSide.isFinite ? c.biggest.shortestSide : 40) * 0.86;
    return Center(
      child: Stack(alignment: Alignment.center, children: [
        if (outline != null)
          Text('$solid\uFE0E',
              style: TextStyle(
                fontSize: size,
                height: 1,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = size * 0.07
                  ..strokeJoin = StrokeJoin.round
                  ..color = outline,
              )),
        Text('$solid\uFE0E',
            style: TextStyle(
                fontSize: size, height: 1, color: fill, shadows: s.shadows)),
      ]),
    );
  });
}

/// Free image piece sets (PNG in assets/pieces/<id>/). Credits are on the Credits screen.
class ImagePieceStyle {
  final String id;
  final String label;
  const ImagePieceStyle(this.id, this.label);
}

const List<ImagePieceStyle> imagePieceStyles = [
  ImagePieceStyle('chessnut', 'Chessnut'),
  ImagePieceStyle('fantasy', 'Fantasy'),
  ImagePieceStyle('spatial', 'Spatial'),
  ImagePieceStyle('celtic', 'Celtic'),
];

String _imagePath(String setId, String symbol) {
  final isWhite = symbol == symbol.toUpperCase();
  return 'assets/pieces/$setId/${isWhite ? 'w' : 'b'}${symbol.toUpperCase()}.png';
}

Widget imagePiece(String setId, String symbol) =>
    Image.asset(_imagePath(setId, symbol), fit: BoxFit.contain, gaplessPlayback: true);

PieceSet? imagePieceSetById(String id) {
  for (final s in imagePieceStyles) {
    if (s.id == id) {
      return PieceSet(pieces: {
        for (final k in _glyphs.keys) k: (BuildContext context) => imagePiece(id, k),
      });
    }
  }
  return null;
}

PieceSet? glyphPieceSetById(String id) {
  for (final s in glyphPieceStyles) {
    if (s.id == id) {
      return PieceSet(pieces: {
        for (final k in _glyphs.keys) k: (BuildContext context) => _glyphPiece(s, k),
      });
    }
  }
  return null;
}

/// Small preview for the Options screen.
Widget glyphPreview(PieceStyle s) => SizedBox(
      width: 64,
      height: 36,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(width: 30, height: 34, child: _glyphPiece(s, 'N')),
        SizedBox(width: 30, height: 34, child: _glyphPiece(s, 'n')),
      ]),
    );


/// Optional colour tint for the white / black side. null = original colours.
const List<Color> whitePiecePalette = [
  Color(0xFFFFD54F), // gold
  Color(0xFF81D4FA), // sky
  Color(0xFFA5D6A7), // mint
  Color(0xFFF8BBD0), // pink
  Color(0xFFFFAB91), // orange
  Color(0xFFCE93D8), // lavender
];

const List<Color> blackPiecePalette = [
  Color(0xFF0D47A1), // navy
  Color(0xFFB71C1C), // crimson
  Color(0xFF1B5E20), // forest
  Color(0xFF4A148C), // purple
  Color(0xFF5D4037), // brown
  Color(0xFF006064), // teal
];

Widget _tint(Widget child, Color c, bool isWhite) {
  final r = c.r, g = c.g, b = c.b; // 0..1
  final List<double> m = isWhite
      // white pieces: multiply -> light fill takes the colour, outline stays dark
      ? [r, 0, 0, 0, 0, 0, g, 0, 0, 0, 0, 0, b, 0, 0, 0, 0, 0, 1, 0]
      // black pieces: dark fill takes the colour, white highlights stay white
      : [1 - r, 0, 0, 0, r * 255, 0, 1 - g, 0, 0, g * 255, 0, 0, 1 - b, 0, b * 255, 0, 0, 0, 1, 0];
  return ColorFiltered(colorFilter: ColorFilter.matrix(m), child: child);
}

/// Wraps any PieceSet so white/black pieces get the chosen colours.
PieceSet tintedPieceSet(PieceSet base, Color? white, Color? black) {
  if (white == null && black == null) return base;
  return PieceSet(pieces: {
    for (final k in _glyphs.keys)
      k: (BuildContext context) {
        final isWhite = k == k.toUpperCase();
        final c = isWhite ? white : black;
        final w = base.piece(context, k);
        return c == null ? w : _tint(w, c, isWhite);
      },
  });
}
