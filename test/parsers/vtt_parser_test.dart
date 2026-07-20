import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_translator/models/subtitle_format.dart';
import 'package:subtitle_translator/services/parsers/vtt_parser.dart';

const _fixturePath = 'test/fixtures/sample.vtt';

Stream<List<int>> _bytes(String path) => File(path).openRead();

void main() {
  test('VttParser parses sample.vtt with correct cue count', () async {
    final doc = await const VttParser().parse(_bytes(_fixturePath));
    expect(doc.format, SubtitleFormat.vtt);
    expect(doc.entries.length, 3);
  });

  test('VttParser yields correct start/end timestamps', () async {
    final doc = await const VttParser().parse(_bytes(_fixturePath));
    expect(doc.entries[0].startMs, 1000);
    expect(doc.entries[0].endMs, 4000);
    expect(doc.entries[2].startMs, 10000);
    expect(doc.entries[2].endMs, 15000);
  });

  test('VttParser splits multi-line cues', () async {
    final doc = await const VttParser().parse(_bytes(_fixturePath));
    expect(doc.entries[1].lines, ['This is a test', 'Second line']);
  });

  test('VttParser skips WEBVTT header and NOTE blocks', () async {
    final bytes = '''
WEBVTT

NOTE This is a comment.

00:00:01.000 --> 00:00:02.000
Only cue
''';
    final file = File('test/fixtures/vtt_with_notes.vtt')
      ..writeAsStringSync(bytes);
    addTearDown(() => file.exists().then((_) => file.delete()));
    final doc = await const VttParser().parse(file.openRead());
    expect(doc.entries.length, 1);
    expect(doc.entries[0].lines, ['Only cue']);
  });

  test('VttParser throws FormatException on empty input', () async {
    expect(
      () => const VttParser().parse(Stream<List<int>>.empty()),
      throwsA(isA<FormatException>()),
    );
  });
}
