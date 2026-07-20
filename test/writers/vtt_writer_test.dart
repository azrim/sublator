import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle/subtitle.dart' as sub hide SubtitleParser;
import 'package:subtitle_translator/models/subtitle_document.dart';
import 'package:subtitle_translator/models/subtitle_entry.dart';
import 'package:subtitle_translator/models/subtitle_format.dart';
import 'package:subtitle_translator/services/writers/vtt_writer.dart';

void main() {
  const writer = VttWriter();

  SubtitleDocument threeCueDoc() => SubtitleDocument(
        format: SubtitleFormat.vtt,
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
            endMs: 6500,
            lines: ['Second cue', 'line two'],
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
    final doc = SubtitleDocument(format: SubtitleFormat.vtt, entries: const []);
    expect(writer.write(doc), '');
  });

  test('writes WEBVTT header and dot-delimited timestamps', () {
    final out = writer.write(threeCueDoc());
    expect(out, startsWith('WEBVTT\n\n'));
    expect(out, contains('00:00:01.000 --> 00:00:03.000\nHello world\n\n'));
    expect(out, contains('00:00:04.000 --> 00:00:06.500\n'
        'Second cue\nline two\n\n'));
    expect(out, contains('01:01:01.000 --> 01:01:03.500\nOver an hour\n\n'));
    // No 'WEBVTT' appears mid-output (only at the start).
    expect('WEBVTT'.allMatches(out).length, equals(1));
  });

  test('round-trip: parse written VTT and assert equal content', () async {
    final original = threeCueDoc();
    final written = writer.write(original);

    final controller = sub.SubtitleController(
      provider: sub.SubtitleProvider.fromString(
        data: written,
        type: sub.SubtitleType.vtt,
      ),
    );
    await controller.initial();

    final parsed = controller.subtitles;
    expect(parsed.length, equals(original.entries.length));
    for (var i = 0; i < parsed.length; i++) {
      final orig = original.entries[i];
      expect(parsed[i].start.inMilliseconds, equals(orig.startMs));
      expect(parsed[i].end.inMilliseconds, equals(orig.endMs));
      expect(parsed[i].data.trim(),
          equals((orig.translatedText ?? orig.lines.join('\n')).trim()));
    }
  });
}
