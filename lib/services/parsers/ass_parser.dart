import 'dart:async';
import 'dart:io';

import 'package:dart_ass/dart_ass.dart';

import '../../models/subtitle_document.dart';
import '../../models/subtitle_entry.dart';
import '../../models/subtitle_format.dart';
import 'subtitle_parser.dart';

/// Parses SubStation Alpha (.ass / .ssa) subtitle streams via `dart_ass`.
///
/// `dart_ass` only parses from a file path, so the decoded text is spilled
/// to a temp file, parsed, then deleted in `finally`.
///
/// For each dialogue cue:
///   * raw `{...}` override tags are stripped from the visible text and
///     stored in [SubtitleEntry.assTags];
///   * the speaker label comes from the ASS `Name` field (may be empty);
///   * `\\N` / `\\n` ASS line breaks are honoured when splitting `lines`.
class AssParser extends SubtitleParser {
  static final _tagRegex = RegExp(r'\{[^}]*\}');
  static final _lineBreakRegex = RegExp(r'\n|\\N|\\n');

  const AssParser();

  @override
  Future<SubtitleDocument> parse(Stream<List<int>> stream,
      {double? frameRate}) async {
    final text = await SubtitleParser.decodeStream(stream);
    if (text.trim().isEmpty) {
      throw const FormatException('Empty ASS content');
    }

    final tempDir = await Directory.systemTemp.createTemp('ass_parser_');
    final tempPath = '${tempDir.path}${Platform.pathSeparator}input.ass';
    try {
      final tempFile = File(tempPath);
      await tempFile.writeAsString(text);

      final ass = Ass(filePath: tempPath);
      await ass.parse();

      final dialogs = ass.dialogs?.dialogs ?? const <AssDialog>[];
      final entries = <SubtitleEntry>[];
      for (var i = 0; i < dialogs.length; i++) {
        final d = dialogs[i];
        if (d.commented) continue;

        final rawText = d.text.toString();
        final stripped = rawText.replaceAll(_tagRegex, '');
        final tags = _tagRegex
            .allMatches(rawText)
            .map((m) => m.group(0)!)
            .toList(growable: false);

        final lines = stripped
            .split(_lineBreakRegex)
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList(growable: false);

        final speaker = d.name.trim();
        entries.add(SubtitleEntry(
          id: i,
          startMs: d.startTime.time ?? 0,
          endMs: d.endTime.time ?? 0,
          lines: lines,
          assTags: tags.isEmpty ? null : tags,
          speakerLabel: speaker.isEmpty ? null : speaker,
        ));
      }

      if (entries.isEmpty) {
        throw const FormatException('ASS stream yielded no dialogue cues');
      }

      return SubtitleDocument(
        format: SubtitleFormat.ass,
        entries: entries,
      );
    } finally {
      await tempDir.delete(recursive: true);
    }
  }
}
