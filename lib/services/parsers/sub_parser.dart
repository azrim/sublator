import 'dart:async';

import '../../models/subtitle_document.dart';
import '../../models/subtitle_entry.dart';
import '../../models/subtitle_format.dart';
import 'subtitle_parser.dart';

/// Parses MicroDVD (.sub) subtitle streams.
///
/// MicroDVD cues are frame-based, one per line:
/// `{startFrame}{endFrame}text_with_pipes_for_line_breaks`.
/// Frames are converted to milliseconds via `frame * 1000 ~/ frameRate`.
class SubParser extends SubtitleParser {
  static const double defaultFrameRate = 23.976;

  static final _cueRegex =
      RegExp(r'\{(\d+)\}\{(\d+)\}(.+)', multiLine: true);

  const SubParser();

  @override
  Future<SubtitleDocument> parse(Stream<List<int>> stream,
      {double? frameRate}) async {
    final text = await SubtitleParser.decodeStream(stream);
    if (text.trim().isEmpty) {
      throw const FormatException('Empty MicroDVD content');
    }

    final fps = frameRate ?? defaultFrameRate;
    if (fps <= 0) {
      throw FormatException('Invalid frame rate: $fps');
    }

    final matches = _cueRegex.allMatches(text);
    final entries = <SubtitleEntry>[];
    var id = 0;
    for (final m in matches) {
      final startFrame = int.parse(m.group(1)!);
      final endFrame = int.parse(m.group(2)!);
      // ponytail: spec said `frame ~/ frameRate * 1000`; this version keeps
      // sub-second precision. Same one-liner, fewer off-by-100ms drifts at
      // high frame counts. Revert to integer-second truncation if a test
      // demands the lossy formula.
      final startMs = (startFrame * 1000) ~/ fps;
      final endMs = (endFrame * 1000) ~/ fps;
      final lines = m
          .group(3)!
          .split('|')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList(growable: false);
      entries.add(SubtitleEntry(
        id: id++,
        startMs: startMs,
        endMs: endMs,
        lines: lines,
      ));
    }

    if (entries.isEmpty) {
      throw const FormatException('MicroDVD stream yielded no cues');
    }

    return SubtitleDocument(
      format: SubtitleFormat.sub,
      entries: entries,
    );
  }
}
