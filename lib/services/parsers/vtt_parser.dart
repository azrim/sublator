import 'dart:async';

import 'package:subtitle/subtitle.dart' hide SubtitleParser;

import '../../models/subtitle_document.dart';
import '../../models/subtitle_entry.dart';
import '../../models/subtitle_format.dart';
import 'subtitle_parser.dart';

/// Parses WebVTT (.vtt) subtitle streams via the `subtitle` package.
class VttParser extends SubtitleParser {
  const VttParser();

  @override
  Future<SubtitleDocument> parse(Stream<List<int>> stream,
      {double? frameRate}) async {
    final text = await SubtitleParser.decodeStream(stream);
    if (text.trim().isEmpty) {
      throw const FormatException('Empty VTT content');
    }

    final controller = SubtitleController(
      provider: SubtitleProvider.fromString(
        data: text,
        type: SubtitleType.vtt,
      ),
    );
    await controller.initial();

    final entries = <SubtitleEntry>[
      for (var i = 0; i < controller.subtitles.length; i++)
        SubtitleEntry(
          id: i,
          startMs: controller.subtitles[i].start.inMilliseconds,
          endMs: controller.subtitles[i].end.inMilliseconds,
          lines: controller.subtitles[i].data
              .split('\n')
              .where((l) => l.isNotEmpty)
              .toList(growable: false),
        ),
    ];

    if (entries.isEmpty) {
      throw const FormatException('VTT stream yielded no cues');
    }

    return SubtitleDocument(
      format: SubtitleFormat.vtt,
      entries: entries,
    );
  }
}
