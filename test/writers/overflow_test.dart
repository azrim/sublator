import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_translator/models/subtitle_document.dart';
import 'package:subtitle_translator/models/subtitle_entry.dart';
import 'package:subtitle_translator/models/subtitle_format.dart';
import 'package:subtitle_translator/services/writers/cpl_overflow.dart';

void main() {
  const overflow = CplOverflow();

  test('100-char Latin cue splits into 3 cues with proportional timestamps',
      () {
    final doc = SubtitleDocument(
      format: SubtitleFormat.srt,
      entries: [
        SubtitleEntry(
          id: 1,
          startMs: 0,
          endMs: 3000,
          lines: ['a' * 100],
        ),
      ],
    );
    final result = overflow.process(doc);
    expect(result.entries.length, equals(3));

    // Proportional split: 0-1000, 1000-2000, 2000-3000.
    expect(result.entries[0].startMs, equals(0));
    expect(result.entries[0].endMs, equals(1000));
    expect(result.entries[1].startMs, equals(1000));
    expect(result.entries[1].endMs, equals(2000));
    expect(result.entries[2].startMs, equals(2000));
    expect(result.entries[2].endMs, equals(3000));

    // 100 chars / 42 CPL = 3 lines (42 + 42 + 16). Each cue carries one line.
    expect(result.entries[0].lines.first.length, equals(42));
    expect(result.entries[1].lines.first.length, equals(42));
    expect(result.entries[2].lines.first.length, equals(16));
    // Total chars preserved.
    expect(
        result.entries.fold<int>(0,
            (sum, e) => sum + e.lines.first.length),
        equals(100));
  });

  test('90 Latin chars splits into 3 cues with proportional timestamps', () {
    final doc = SubtitleDocument(
      format: SubtitleFormat.srt,
      entries: [
        SubtitleEntry(
          id: 7,
          startMs: 1000,
          endMs: 4000,
          lines: ['a' * 90],
        ),
      ],
    );
    final result = overflow.process(doc);
    expect(result.entries.length, equals(3));
    // duration 3000, n 3 -> step 1000, offset 1000.
    expect(result.entries[0].startMs, equals(1000));
    expect(result.entries[0].endMs, equals(2000));
    expect(result.entries[1].startMs, equals(2000));
    expect(result.entries[1].endMs, equals(3000));
    expect(result.entries[2].startMs, equals(3000));
    expect(result.entries[2].endMs, equals(4000));
  });

  test('cue that fits in 2 lines is left unchanged', () {
    final doc = SubtitleDocument(
      format: SubtitleFormat.srt,
      entries: [
        SubtitleEntry(
          id: 1,
          startMs: 0,
          endMs: 1000,
          lines: ['short', 'two lines'],
        ),
      ],
    );
    final result = overflow.process(doc);
    expect(result.entries.length, equals(1));
    expect(result.entries.first.startMs, equals(0));
    expect(result.entries.first.endMs, equals(1000));
    expect(result.entries.first.lines, equals(['short', 'two lines']));
  });

  test('3 short lines split into 3 cues with proportional timestamps', () {
    final doc = SubtitleDocument(
      format: SubtitleFormat.srt,
      entries: [
        SubtitleEntry(
          id: 1,
          startMs: 0,
          endMs: 9000,
          lines: ['L1', 'L2', 'L3'],
        ),
      ],
    );
    final result = overflow.process(doc);
    expect(result.entries.length, equals(3));
    expect(result.entries[0].startMs, equals(0));
    expect(result.entries[0].endMs, equals(3000));
    expect(result.entries[1].startMs, equals(3000));
    expect(result.entries[1].endMs, equals(6000));
    expect(result.entries[2].startMs, equals(6000));
    expect(result.entries[2].endMs, equals(9000));
    expect(result.entries[0].lines.first, equals('L1'));
    expect(result.entries[1].lines.first, equals('L2'));
    expect(result.entries[2].lines.first, equals('L3'));
  });

  test('CJK cue uses tighter CPL (16) and splits accordingly', () {
    final doc = SubtitleDocument(
      format: SubtitleFormat.srt,
      entries: [
        SubtitleEntry(
          id: 1,
          startMs: 0,
          endMs: 4000,
          lines: ['日' * 50],
        ),
      ],
    );
    final result = overflow.process(doc);
    // 50 / 16 = 3.125 -> 4 visual lines (16+16+16+2).
    expect(result.entries.length, equals(4));
    expect(result.entries[0].startMs, equals(0));
    expect(result.entries[0].endMs, equals(1000));
    expect(result.entries[1].startMs, equals(1000));
    expect(result.entries[1].endMs, equals(2000));
    expect(result.entries[2].startMs, equals(2000));
    expect(result.entries[2].endMs, equals(3000));
    expect(result.entries[3].startMs, equals(3000));
    expect(result.entries[3].endMs, equals(4000));
    expect(result.entries[3].lines.first, equals('日' * 2));
  });

  test('preserves assTags and speakerLabel across split cues', () {
    final doc = SubtitleDocument(
      format: SubtitleFormat.ass,
      entries: [
        SubtitleEntry(
          id: 1,
          startMs: 0,
          endMs: 3000,
          lines: ['a' * 100],
          assTags: ['{\\b1}'],
          speakerLabel: 'Narrator',
        ),
      ],
    );
    final result = overflow.process(doc);
    expect(result.entries.length, equals(3));
    for (final e in result.entries) {
      expect(e.assTags, equals(['{\\b1}']));
      expect(e.speakerLabel, equals('Narrator'));
    }
  });

  test('translated text is preserved as translatedText on split cues', () {
    final doc = SubtitleDocument(
      format: SubtitleFormat.srt,
      entries: [
        SubtitleEntry(
          id: 1,
          startMs: 0,
          endMs: 3000,
          lines: ['original'],
          translatedText: 'a' * 100,
        ),
      ],
    );
    final result = overflow.process(doc);
    expect(result.entries.length, equals(3));
    for (final e in result.entries) {
      expect(e.translatedText, isNotNull);
      expect(e.translatedText!.length, lessThanOrEqualTo(42));
    }
  });

  test('empty document stays empty', () {
    final doc = SubtitleDocument(format: SubtitleFormat.srt, entries: const []);
    final result = overflow.process(doc);
    expect(result.entries, isEmpty);
  });

  test('idempotent: processing an already-short doc leaves it unchanged', () {
    final doc = SubtitleDocument(
      format: SubtitleFormat.srt,
      entries: [
        SubtitleEntry(
          id: 1,
          startMs: 0,
          endMs: 1000,
          lines: ['short'],
        ),
      ],
    );
    final once = overflow.process(doc);
    final twice = overflow.process(once);
    expect(twice.entries.length, equals(1));
    expect(twice.entries.first.lines, equals(['short']));
  });
}
