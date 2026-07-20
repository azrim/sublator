import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_translator/services/parsers/ass_parser.dart';
import 'package:subtitle_translator/services/parsers/srt_parser.dart';
import 'package:subtitle_translator/services/parsers/sub_parser.dart';
import 'package:subtitle_translator/services/parsers/subtitle_parser_factory.dart';
import 'package:subtitle_translator/services/parsers/vtt_parser.dart';

const _srtPath = 'test/fixtures/sample.srt';
const _assPath = 'test/fixtures/sample.ass';
const _vttPath = 'test/fixtures/sample.vtt';
const _subPath = 'test/fixtures/sample.sub';

void main() {
  const factory = SubtitleParserFactory();

  group('forFileName', () {
    test('returns SrtParser for .srt', () {
      expect(factory.forFileName('movie.srt'), isA<SrtParser>());
    });

    test('returns AssParser for .ass', () {
      expect(factory.forFileName('movie.ass'), isA<AssParser>());
    });

    test('returns AssParser for .ssa', () {
      expect(factory.forFileName('movie.ssa'), isA<AssParser>());
    });

    test('returns VttParser for .vtt', () {
      expect(factory.forFileName('movie.vtt'), isA<VttParser>());
    });

    test('returns SubParser for .sub', () {
      expect(factory.forFileName('movie.sub'), isA<SubParser>());
    });

    test('handles paths containing directories with dots', () {
      expect(
        factory.forFileName('C:\\my.folder\\subtitle.srt'),
        isA<SrtParser>(),
      );
    });

    test('throws FormatException for unsupported extension', () {
      expect(
        () => factory.forFileName('movie.txt'),
        throwsA(isA<FormatException>()),
      );
    });

    test('is case-insensitive on extension', () {
      expect(factory.forFileName('MOVIE.SRT'), isA<SrtParser>());
      expect(factory.forFileName('Movie.Ass'), isA<AssParser>());
    });
  });

  group('forExtension', () {
    test('accepts extension with or without leading dot', () {
      expect(factory.forExtension('.srt'), isA<SrtParser>());
      expect(factory.forExtension('srt'), isA<SrtParser>());
    });
  });

  group('end-to-end via factory', () {
    test('parses .srt through factory-selected parser', () async {
      final parser = factory.forFileName(_srtPath);
      final doc = await parser.parse(File(_srtPath).openRead());
      expect(doc.entries.length, 3);
    });

    test('parses .ass through factory-selected parser', () async {
      final parser = factory.forFileName(_assPath);
      final doc = await parser.parse(File(_assPath).openRead());
      expect(doc.entries.length, 3);
    });

    test('parses .vtt through factory-selected parser', () async {
      final parser = factory.forFileName(_vttPath);
      final doc = await parser.parse(File(_vttPath).openRead());
      expect(doc.entries.length, 3);
    });

    test('parses .sub through factory-selected parser', () async {
      final parser = factory.forFileName(_subPath);
      final doc = await parser.parse(File(_subPath).openRead());
      expect(doc.entries.length, 3);
    });
  });

  test('factory parser strips BOM end-to-end', () async {
    final base = await File(_srtPath).readAsBytes();
    final withBom = <int>[0xEF, 0xBB, 0xBF, ...base];
    final stream = Stream<List<int>>.fromIterable([withBom]);
    final parser = factory.forFileName('bom.srt');
    final doc = await parser.parse(stream);
    expect(doc.entries.length, 3);
    expect(doc.entries[0].lines, ['Hello World']);
  });

  test('factory parser handles UTF-8 multibyte content', () async {
    final srt = '1\n00:00:01,000 --> 00:00:02,000\nこんにちは世界\n';
    final bytes = utf8.encode(srt);
    final stream = Stream<List<int>>.fromIterable([bytes]);
    final parser = factory.forFileName('utf8.srt');
    final doc = await parser.parse(stream);
    expect(doc.entries.length, 1);
    expect(doc.entries[0].lines, ['こんにちは世界']);
  });
}
