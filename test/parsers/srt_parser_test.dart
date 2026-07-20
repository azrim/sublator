import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_translator/models/subtitle_format.dart';
import 'package:subtitle_translator/services/parsers/srt_parser.dart';

const _fixturePath = 'test/fixtures/sample.srt';
const _emptyPath = 'test/fixtures/empty.srt';

Stream<List<int>> _bytes(String path) => File(path).openRead();

void main() {
  test('SrtParser parses sample.srt with correct cue count', () async {
    final doc = await const SrtParser().parse(_bytes(_fixturePath));
    expect(doc.format, SubtitleFormat.srt);
    expect(doc.entries.length, 3);
  });

  test('SrtParser yields correct start/end timestamps for first cue', () async {
    final doc = await const SrtParser().parse(_bytes(_fixturePath));
    expect(doc.entries[0].startMs, 1000);
    expect(doc.entries[0].endMs, 4000);
  });

  test('SrtParser yields correct end timestamps for last cue', () async {
    final doc = await const SrtParser().parse(_bytes(_fixturePath));
    expect(doc.entries[2].startMs, 10000);
    expect(doc.entries[2].endMs, 15000);
  });

  test('SrtParser splits multi-line cue text into lines', () async {
    final doc = await const SrtParser().parse(_bytes(_fixturePath));
    expect(doc.entries[1].lines, ['This is a test', 'Second line']);
  });

  test('SrtParser preserves single-line text', () async {
    final doc = await const SrtParser().parse(_bytes(_fixturePath));
    expect(doc.entries[0].lines, ['Hello World']);
  });

  test('SrtParser assigns sequential ids starting at 0', () async {
    final doc = await const SrtParser().parse(_bytes(_fixturePath));
    expect(doc.entries.map((e) => e.id), [0, 1, 2]);
  });

  test('SrtParser throws FormatException on empty input', () async {
    expect(
      () => const SrtParser().parse(_bytes(_emptyPath)),
      throwsA(isA<FormatException>()),
    );
  });

  test('SrtParser strips UTF-8 BOM if present', () async {
    final base = await File(_fixturePath).readAsBytes();
    final withBom = <int>[0xEF, 0xBB, 0xBF, ...base];
    final stream = Stream<List<int>>.fromIterable([withBom]);
    final doc = await const SrtParser().parse(stream);
    expect(doc.entries.length, 3);
    expect(doc.entries[0].lines, ['Hello World']);
  });

  test('SrtParser normalises CRLF line endings', () async {
    final text = await File(_fixturePath).readAsString();
    final crlf = text.replaceAll('\n', '\r\n');
    final bytes = utf8.encode(crlf);
    final stream = Stream<List<int>>.fromIterable([bytes]);
    final doc = await const SrtParser().parse(stream);
    expect(doc.entries.length, 3);
  });
}
