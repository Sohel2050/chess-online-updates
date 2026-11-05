import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  static const _mit = '''Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.''';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget entry(String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            SelectableText(body, style: t.bodySmall),
          ]),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Credits & Licenses')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Chess piece sets', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          entry('Chessnut',
              'By Alexis Luengas. Licensed under the Apache License, Version 2.0 (https://www.apache.org/licenses/LICENSE-2.0). '
              'Source: https://github.com/lichess-org/lila/tree/master/public/piece/chessnut. '
              'Files were converted from SVG to PNG.'),
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Apache License 2.0 (full text)'),
              children: [
                FutureBuilder<String>(
                  future: rootBundle.loadString('assets/licenses/apache-2.0.txt'),
                  builder: (context, snap) => SelectableText(
                    snap.data ?? 'Loading...',
                    style: t.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          entry('Fantasy, Spatial, Celtic',
              'By Maurizio Monge. Licensed under the MIT License. '
              'Source: https://github.com/lichess-org/lila/tree/master/public/piece. '
              'Files were converted from SVG to PNG.\n\nMIT License\n\n$_mit'),
        ],
      ),
    );
  }
}
