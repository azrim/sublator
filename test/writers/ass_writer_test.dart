import 'dart:io';

import 'package:dart_ass/dart_ass.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_translator/models/subtitle_document.dart';
import 'package:subtitle_translator/models/subtitle_entry.dart';
import 'package:subtitle_translator/models/subtitle_format.dart';
import 'package:subtitle_translator/services/writers/ass_writer.dart';

void main() {
  const writer = AssWriter();

  test('empty document produces empty string', () {
    final doc = SubtitleDocument(format: SubtitleFormat.ass, entries: const []);
    expect(writer.write(doc), '');
  });

  test('emits valid ASS sections with cue text and timing', () {
    final doc = SubtitleDocument(
      format: SubtitleFormat.ass,
      entries: [
        SubtitleEntry(
          id: 1,
          startMs: 1000,
          endMs: 3000,
          lines: ['Hello world'],
          speakerLabel: 'Speaker',
        ),
        SubtitleEntry(
          id: 2,
          startMs: 4000,
          endMs: 6000,
          lines: ['Second cue'],
        ),
      ],
    );
    final out = writer.write(doc);
    expect(out, contains('[Script Info]'));
    expect(out, contains('[V4+ Styles]'));
    expect(out, contains('[Events]'));
    // 1000ms -> 0:00:01.00, 3000ms -> 0:00:03.00.
    expect(out, contains(
        'Dialogue: 0,0:00:01.00,0:00:03.00,Default,Speaker,'
        '0000,0000,0000,,Hello world'));
    expect(out, contains(
        'Dialogue: 0,0:00:04.00,0:00:06.00,Default,,'
        '0000,0000,0000,,Second cue'));
  });

  test('preserves override tags verbatim before cue text', () {
    final doc = SubtitleDocument(
      format: SubtitleFormat.ass,
      entries: [
        SubtitleEntry(
          id: 1,
          startMs: 1000,
          endMs: 3000,
          lines: ['Bold and italic'],
          assTags: ['{\\b1}', '{\\i1}'],
        ),
      ],
    );
    final out = writer.write(doc);
    // Tags must appear before the text, in original order.
    expect(out, contains(',,{\\b1}{\\i1}Bold and italic'));
  });

  test('round-trip: AssWriter output is parseable by dart_ass', () async {
    final doc = SubtitleDocument(
      format: SubtitleFormat.ass,
      entries: [
        SubtitleEntry(
          id: 1,
          startMs: 1000,
          endMs: 3000,
          lines: ['Hello world'],
        ),
        SubtitleEntry(
          id: 2,
          startMs: 4000,
          endMs: 6000,
          lines: ['Second cue'],
        ),
      ],
    );
    final out = writer.write(doc);
    final tmp = '${Directory.systemTemp.path}/'
        'asswriter_rt_${DateTime.now().microsecondsSinceEpoch}.ass';
    File(tmp).writeAsStringSync(out);
    try {
      final ass = Ass(filePath: tmp);
      await ass.parse();
      final dialogs = ass.dialogs?.dialogs ?? [];
      expect(dialogs.length, equals(doc.entries.length));
      for (var i = 0; i < dialogs.length; i++) {
        final orig = doc.entries[i];
        expect(dialogs[i].startTime.time, equals(orig.startMs));
        expect(dialogs[i].endTime.time, equals(orig.endMs));
        expect(dialogs[i].text.toString().trim(),
            equals((orig.translatedText ?? orig.lines.join('\n')).trim()));
      }
    } finally {
      File(tmp).deleteSync();
    }
  });

  test('dart_ass round-trip: parse fixture, toFile, tags preserved in output',
      () async {
    final fixturePath = 'test/writers/fixtures/sample.ass';
    final outPath = '${Directory.systemTemp.path}/'
        'ass_rt_${DateTime.now().microsecondsSinceEpoch}.ass';

    final ass = Ass(filePath: fixturePath);
    await ass.parse();

    final dialogs = ass.dialogs?.dialogs ?? [];
    expect(dialogs.length, equals(3));
    // Fixture asserts: tags parsed into the second dialog's text segments.
    expect(dialogs[1].text.toString(),
        equals('{\\b1}Bold{\\b0} {\\i1}italic{\\i0}'));

    // dart_ass 1.2.2's AssDialog.toString emits `$style` (the full Style
    // line) instead of `$styleName`, so re-parsing the written file would
    // fail to match Dialogue lines (regex can't handle commas in the Style
    // column). We therefore assert the *written file content* preserves the
    // tag strings — i.e. toFile did not drop or mangle override tags.
    await ass.toFile(outPath);
    final written = File(outPath).readAsStringSync();
    expect(written, contains('{\\b1}Bold{\\b0}'));
    expect(written, contains('{\\i1}italic{\\i0}'));
    expect(written, contains('Hello world'));
    expect(written, contains('Third cue with speaker'));

    File(outPath).deleteSync();
  });
}
