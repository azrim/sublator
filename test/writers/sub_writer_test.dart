import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_translator/models/subtitle_document.dart';
import 'package:subtitle_translator/models/subtitle_entry.dart';
import 'package:subtitle_translator/models/subtitle_format.dart';
import 'package:subtitle_translator/services/writers/sub_writer.dart';

void main() {
  const writer = SubWriter();
  const palWriter = SubWriter(frameRate: 25.0);

  SubtitleDocument twoCueDoc() => SubtitleDocument(
        format: SubtitleFormat.sub,
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

  test('empty document produces empty string', () {
    final doc = SubtitleDocument(format: SubtitleFormat.sub, entries: const []);
    expect(writer.write(doc), '');
  });

  test('writes frame-based cues with braces and blank-line separator', () {
    final out = writer.write(twoCueDoc());
    // 23.976 fps: 1000ms -> 24 frames, 3000ms -> 72 frames.
    expect(out, contains('{24}\n{72}\nHello world\n\n'));
    // 4000ms -> 96 frames, 6000ms -> 144 frames.
    expect(out, contains('{96}\n{144}\nSecond cue\n\n'));
  });

  test('frame conversion respects user-specified frame rate', () {
    // PAL 25fps: 1000ms -> 25 frames, 3000ms -> 75 frames.
    final doc = SubtitleDocument(
      format: SubtitleFormat.sub,
      entries: [
        SubtitleEntry(
          id: 1,
          startMs: 1000,
          endMs: 3000,
          lines: ['PAL'],
        ),
      ],
    );
    expect(palWriter.write(doc), contains('{25}\n{75}\nPAL\n\n'));
  });

  test('round-trip: parse written SUB and assert equal frame numbers + text',
      () {
    final original = twoCueDoc();
    final written = writer.write(original);

    final reparsed = _parseSub(written);
    expect(reparsed.length, equals(original.entries.length));
    for (var i = 0; i < reparsed.length; i++) {
      final orig = original.entries[i];
      // Frame numbers are the lossless representation in MicroDVD — comparing
      // ms would compound rounding errors (3000ms -> 72 frames -> 3003ms).
      expect(reparsed[i].startFrame,
          equals((orig.startMs * 23.976 / 1000).round()));
      expect(reparsed[i].endFrame,
          equals((orig.endMs * 23.976 / 1000).round()));
      expect(reparsed[i].text,
          equals(orig.translatedText ?? orig.lines.join('\n')));
    }
  });
}

/// Parsed MicroDVD cue: frame numbers are lossless, ms is derived (lossy).
class _ParsedSub {
  final int startFrame;
  final int endFrame;
  final String text;
  _ParsedSub(this.startFrame, this.endFrame, this.text);
}

/// Inline test-only MicroDVD parser matching [SubWriter]'s output format
/// (`{frame}\n{frame}\ntext\n\n`). Not used in production — Task 3 ships the
/// real parser.
List<_ParsedSub> _parseSub(String output) {
  final cues = output.trim().split(RegExp(r'\n\n+'));
  final out = <_ParsedSub>[];
  for (final cue in cues) {
    final lines = cue.split('\n');
    if (lines.length < 3) continue;
    final startFrame =
        int.parse(lines[0].replaceAll(RegExp(r'[\{\}]'), ''));
    final endFrame = int.parse(lines[1].replaceAll(RegExp(r'[\{\}]'), ''));
    final text = lines.sublist(2).join('\n');
    out.add(_ParsedSub(startFrame, endFrame, text));
  }
  return out;
}
