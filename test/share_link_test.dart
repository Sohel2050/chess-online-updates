import 'package:flutter_chess_app/utils/share_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads the code from a share link', () {
    expect(ShareLink.extractCode('https://chess-api.albonik.com/g/abcd2345'), 'abcd2345');
    expect(ShareLink.extractCode('  https://x.com/g/abcd2345.pgn \n'), 'abcd2345');
    expect(ShareLink.extractCode('https://x.com/g/ABCD2345?utm=1'), 'abcd2345');
  });

  test('anything else is not a link', () {
    expect(ShareLink.extractCode('1. e4 e5'), isNull);
    expect(ShareLink.extractCode('https://x.com/g/short'), isNull);
    expect(ShareLink.extractCode('https://x.com/other/abcd2345'), isNull);
    expect(ShareLink.extractCode('[Event "x"]\n\n1. e4 https://x.com/g/abcd2345'), isNull);
  });
}
