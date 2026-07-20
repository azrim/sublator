import 'dart:math' show min;

import '../../models/subtitle_document.dart';
import '../../models/subtitle_entry.dart';
import 'subtitle_writer.dart';

/// Adaptive CPL (characters-per-line) overflow post-processor.
///
/// Per the project rules: subtitle cues must never exceed 2 visual lines. If
/// the LLM-translated text would require 3+ lines under the adaptive CPL
/// ceiling, the cue is split into N cues (one per visual line) with
/// proportionally-distributed timestamps:
///
///   `newStart_i = start + (end - start) * i / N`
///   `newEnd_i   = start + (end - start) * (i + 1) / N`
///
/// Adaptive limits (from the project plan):
/// - Latin (regex `[a-zA-Z]`): 42 chars per line
/// - CJK (regex `[\u4e00-\u9fff\u3040-\u309f\u30a0-\u30ff]`): 16 chars/line
///
/// CJK detection takes precedence — if any CJK char is present, the CJK CPL
/// is used for the whole cue (mixed-script cues are rare and conservative is
/// safer than overflowing).
class CplOverflow {
  const CplOverflow({
    this.latinCpl = 42,
    this.cjkCpl = 16,
  });

  /// Latin-script chars-per-line ceiling.
  final int latinCpl;

  /// CJK-script chars-per-line ceiling (lower because CJK glyphs are wider).
  final int cjkCpl;

  static final RegExp _cjkRegex =
      RegExp(r'[\u4e00-\u9fff\u3040-\u309f\u30a0-\u30ff]');

  /// Returns a new [SubtitleDocument] with every cue split as needed so no
  /// cue has more than two visual lines under the adaptive CPL ceiling.
  SubtitleDocument process(SubtitleDocument doc) {
    final out = <SubtitleEntry>[];
    for (final e in doc.entries) {
      out.addAll(_splitEntry(e));
    }
    return SubtitleDocument(format: doc.format, entries: out);
  }

  /// Splits a single entry into 1 (unchanged) or N (proportional) entries.
  List<SubtitleEntry> _splitEntry(SubtitleEntry e) {
    final text = effectiveText(e);
    final cpl = _cjkRegex.hasMatch(text) ? cjkCpl : latinCpl;
    final visualLines = _wrap(text, cpl);

    if (visualLines.length <= 2) return [e];

    final n = visualLines.length;
    final duration = e.endMs - e.startMs;
    final hadTranslation = e.translatedText != null;

    return List.generate(n, (i) {
      final startMs = e.startMs + (duration * i / n).round();
      final endMs = e.startMs + (duration * (i + 1) / n).round();
      return SubtitleEntry(
        id: e.id * 1000 + i,
        // ponytail: composite id avoids collisions within one split; replace
        // with a proper id allocator when the Drift layer lands.
        startMs: startMs,
        endMs: endMs,
        lines: [visualLines[i]],
        translatedText: hadTranslation ? visualLines[i] : null,
        assTags: e.assTags,
        speakerLabel: e.speakerLabel,
      );
    });
  }

  /// Wraps [text] to at most [cpl] chars per visual line, preserving the
  /// user's existing line breaks. CJK lines are hard-split; Latin lines wrap
  /// at word boundaries, with hard-split fallback for words longer than [cpl].
  List<String> _wrap(String text, int cpl) {
    final isCjk = _cjkRegex.hasMatch(text);
    final out = <String>[];
    for (final line in text.split('\n')) {
      if (line.length <= cpl) {
        out.add(line);
        continue;
      }
      if (isCjk) {
        for (var i = 0; i < line.length; i += cpl) {
          out.add(line.substring(i, min(i + cpl, line.length)));
        }
      } else {
        out.addAll(_wrapLatin(line, cpl));
      }
    }
    return out;
  }

  List<String> _wrapLatin(String line, int cpl) {
    final words = line.split(RegExp(r'\s+'));
    final out = <String>[];
    var current = StringBuffer();
    for (final word in words) {
      if (word.isEmpty) continue;
      if (word.length > cpl) {
        // Hard-split a single word longer than the ceiling.
        if (current.isNotEmpty) {
          out.add(current.toString());
          current = StringBuffer();
        }
        for (var i = 0; i < word.length; i += cpl) {
          out.add(word.substring(i, min(i + cpl, word.length)));
        }
        continue;
      }
      if (current.isEmpty) {
        current.write(word);
      } else if (current.length + 1 + word.length <= cpl) {
        current.write(' ');
        current.write(word);
      } else {
        out.add(current.toString());
        current = StringBuffer(word);
      }
    }
    if (current.isNotEmpty) out.add(current.toString());
    return out;
  }
}
