import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_translator/models/subtitle_format.dart';
import 'package:subtitle_translator/services/parsers/ass_parser.dart';

const _fixturePath = 'test/fixtures/sample.ass';

Stream<List<int>> _bytes(String path) => File(path).openRead();

void main() {
  test('AssParser parses sample.ass with correct cue count', () async {
    final doc = await const AssParser().parse(_bytes(_fixturePath));
    expect(doc.format, SubtitleFormat.ass);
    // Comment cues are skipped; the fixture has 3 dialogue cues.
    expect(doc.entries.length, 3);
  });

  test('AssParser converts ASS timestamps to ms', () async {
    final doc = await const AssParser().parse(_bytes(_fixturePath));
    expect(doc.entries[0].startMs, 1000); // 0:00:01.00
    expect(doc.entries[0].endMs, 4000); // 0:00:04.00
    expect(doc.entries[2].startMs, 10000); // 0:00:10.00
    expect(doc.entries[2].endMs, 15000); // 0:00:15.00
  });

  test('AssParser strips {...} override tags from visible text', () async {
    final doc = await const AssParser().parse(_bytes(_fixturePath));
    expect(doc.entries[0].lines, ['Bold text']);
  });

  test('AssParser stores raw {...} tags in assTags field', () async {
    final doc = await const AssParser().parse(_bytes(_fixturePath));
    expect(doc.entries[0].assTags, isNotNull);
    // Raw tags include the literal backslash from the ASS source.
    expect(doc.entries[0].assTags, [r'{\b1}', r'{\b0}']);
  });

  test('AssParser sets assTags to null when no tags present', () async {
    final doc = await const AssParser().parse(_bytes(_fixturePath));
    expect(doc.entries[1].assTags, isNull);
    expect(doc.entries[2].assTags, isNull);
  });

  test('AssParser extracts speaker label from Name field', () async {
    final doc = await const AssParser().parse(_bytes(_fixturePath));
    expect(doc.entries[0].speakerLabel, 'Alice');
    expect(doc.entries[1].speakerLabel, 'Bob');
  });

  test('AssParser sets speakerLabel to null when Name field empty', () async {
    final doc = await const AssParser().parse(_bytes(_fixturePath));
    expect(doc.entries[2].speakerLabel, isNull);
  });

  test('AssParser honours \\N hard line breaks', () async {
    final doc = await const AssParser().parse(_bytes(_fixturePath));
    expect(doc.entries[1].lines, ['Line one', 'Line two']);
  });

  test('AssParser throws FormatException on empty input', () async {
    expect(
      () => const AssParser().parse(Stream<List<int>>.empty()),
      throwsA(isA<FormatException>()),
    );
  });
}
