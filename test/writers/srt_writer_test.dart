import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle/subtitle.dart' as sub hide SubtitleParser;
import 'package:subtitle_translator/models/subtitle_document.dart';
import 'package:subtitle_translator/models/subtitle_entry.dart';
import 'package:subtitle_translator/models/subtitle_format.dart';
import 'package:subtitle_translator/services/writers/srt_writer.dart';

void main() {
  const writer = SrtWriter();

  SubtitleDocument threeCueDoc() => SubtitleDocument(
        format: SubtitleFormat.srt,
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
            lines: ['Second cue', 'with two lines'],
          ),
          SubtitleEntry(
            id: 3,
            startMs: 3661000,
            endMs: 3663500,
            lines: ['Over an hour'],
          ),
        ],
      );

  test('empty document produces empty string', () {
    final doc = SubtitleDocument(format: SubtitleFormat.srt, entries: const []);
    expect(writer.write(doc), '');
  });

  test('writes 3 cues with 1-based index and comma-delimited timestamps', () {
    final out = writer.write(threeCueDoc());
    // Each cue ends with a blank line separator (\n\n).
    expect(out, startsWith('1\n'));
    expect(out, contains('00:00:01,000 --> 00:00:03,000\nHello world\n\n'));
    expect(out, contains('2\n00:00:04,000 --> 00:00:06,000\n'
        'Second cue\nwith two lines\n\n'));
    // >1h cue: 3661000ms = 01:01:01,000.
    expect(out, contains('3\n01:01:01,000 --> 01:01:03,500\nOver an hour\n\n'));
  });

  test('round-trip: parse written SRT and assert equal content', () async {
    final original = threeCueDoc();
    final written = writer.write(original);

    // Round-trip via the subtitle package (which has parse support).
    final controller = sub.SubtitleController(
      provider: sub.SubtitleProvider.fromString(
        data: written,
        type: sub.SubtitleType.srt,
      ),
    );
    await controller.initial();

    final parsed = controller.subtitles;
    expect(parsed.length, equals(original.entries.length));
    for (var i = 0; i < parsed.length; i++) {
      final orig = original.entries[i];
      expect(parsed[i].start.inMilliseconds, equals(orig.startMs));
      expect(parsed[i].end.inMilliseconds, equals(orig.endMs));
      // subtitle package normalizes whitespace; compare trimmed.
      expect(parsed[i].data.trim(),
          equals((orig.translatedText ?? orig.lines.join('\n')).trim()));
    }
  });

  test('translatedText takes precedence over lines', () {
    final doc = SubtitleDocument(
      format: SubtitleFormat.srt,
      entries: [
        SubtitleEntry(
          id: 1,
          startMs: 0,
          endMs: 1000,
          lines: ['original'],
          translatedText: 'translated',
        ),
      ],
    );
    expect(writer.write(doc), contains('translated\n'));
    expect(writer.write(doc), isNot(contains('original')));
  });
}
