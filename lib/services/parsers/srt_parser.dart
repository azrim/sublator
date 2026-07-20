import 'dart:async';

import 'package:subtitle/subtitle.dart' hide SubtitleParser;

import '../../models/subtitle_document.dart';
import '../../models/subtitle_entry.dart';
import '../../models/subtitle_format.dart';
import 'subtitle_parser.dart';

/// Parses SubRip (.srt) subtitle streams via the `subtitle` package.
class SrtParser extends SubtitleParser {
  const SrtParser();

  @override
  Future<SubtitleDocument> parse(Stream<List<int>> stream,
      {double? frameRate}) async {
    final text = await SubtitleParser.decodeStream(stream);
    if (text.trim().isEmpty) {
      throw const FormatException('Empty SRT content');
    }

    final controller = SubtitleController(
      provider: SubtitleProvider.fromString(
        data: text,
        type: SubtitleType.srt,
      ),
    );
    await controller.initial();

    final entries = <SubtitleEntry>[
      for (var i = 0; i < controller.subtitles.length; i++)
        SubtitleEntry(
          id: i,
          startMs: controller.subtitles[i].start.inMilliseconds,
          endMs: controller.subtitles[i].end.inMilliseconds,
          lines: _splitLines(controller.subtitles[i].data),
        ),
    ];

    if (entries.isEmpty) {
      throw const FormatException('SRT stream yielded no cues');
    }

    return SubtitleDocument(
      format: SubtitleFormat.srt,
      entries: entries,
    );
  }

  static List<String> _splitLines(String data) =>
      data.split('\n').where((l) => l.isNotEmpty).toList(growable: false);
}
