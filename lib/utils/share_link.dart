/// Finds the 8-character game code in a pasted share link ("https://host/g/abcd2345" or "/g/abcd2345.pgn").
/// Returns null when the text is not a share link (then it is treated as PGN text).
class ShareLink {
  static final RegExp _link = RegExp(r'^https?://[^\s/]+/g/([a-hjkmnpqrstuvwxyz2-9]{8})(?:\.pgn)?/?(?:[?#]\S*)?$', caseSensitive: false);

  static String? extractCode(String text) {
    final m = _link.firstMatch(text.trim());
    return m?.group(1)?.toLowerCase();
  }
}
