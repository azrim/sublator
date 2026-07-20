import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_translator/models/subtitle_format.dart';
import 'package:subtitle_translator/services/parsers/sub_parser.dart';

const _fixturePath = 'test/fixtures/sample.sub';

Stream<List<int>> _bytes(String path) => File(path).openRead();

void main() {
  test('SubParser parses sample.sub with correct cue count', () async {
    final doc = await const SubParser().parse(_bytes(_fixturePath));
    expect(doc.format, SubtitleFormat.sub);
    expect(doc.entries.length, 3);
  });

  test('SubParser converts frames to ms using default 23.976 fps', () async {
    final doc = await const SubParser().parse(_bytes(_fixturePath));
    // Frame 0 -> 0ms; Frame 100 at 23.976 -> 100000 ~/ 23.976 = 4170ms.
    expect(doc.entries[0].startMs, 0);
    expect(doc.entries[0].endMs, 4170);
  });

  test('SubParser converts later cues correctly', () async {
    final doc = await const SubParser().parse(_bytes(_fixturePath));
    expect(doc.entries[1].startMs, 8341); // 200000 ~/ 23.976
    expect(doc.entries[1].endMs, 12512); // 300000 ~/ 23.976
  });

  test('SubParser splits pipe-delimited text into lines', () async {
    final doc = await const SubParser().parse(_bytes(_fixturePath));
    expect(doc.entries[0].lines, ['Hello', 'World']);
  });

  test('SubParser with wrong frame rate produces offset timestamps', () async {
    final docAtDefault = await const SubParser().parse(_bytes(_fixturePath));
    final docAt25 = await const SubParser()
        .parse(_bytes(_fixturePath), frameRate: 25.0);

    // Same cue count, but timestamps differ.
    expect(docAt25.entries.length, docAtDefault.entries.length);

    // At 25 fps, frame 100 = 4000ms (vs 4170 at 23.976).
    expect(docAt25.entries[0].endMs, 4000);
    expect(docAt25.entries[0].endMs, isNot(docAtDefault.entries[0].endMs));

    // Frame 400 at 25 fps = 16000ms (vs 16694 at 23.976).
    expect(docAt25.entries[2].startMs, 16000);
    expect(docAt25.entries[2].startMs,
        isNot(docAtDefault.entries[2].startMs));
  });

  test('SubParser honours explicit frameRate override', () async {
    final doc = await const SubParser()
        .parse(_bytes(_fixturePath), frameRate: 30.0);
    // Frame 100 at 30 fps = 100000 ~/ 30 = 3333ms.
    expect(doc.entries[0].endMs, 3333);
  });

  test('SubParser throws FormatException on empty input', () async {
    expect(
      () => const SubParser().parse(Stream<List<int>>.empty()),
      throwsA(isA<FormatException>()),
    );
  });

  test('SubParser rejects non-positive frame rate', () async {
    expect(
      () => const SubParser().parse(_bytes(_fixturePath), frameRate: 0),
      throwsA(isA<FormatException>()),
    );
  });
}
