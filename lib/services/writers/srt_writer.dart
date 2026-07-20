import '../../models/subtitle_document.dart';
import 'subtitle_writer.dart';

/// SubRip (.srt) writer.
///
/// Format per cue:
/// ```
/// {index}
/// HH:MM:SS,mmm --> HH:MM:SS,mmm
/// text
///
/// ```
/// Indices are 1-based. Empty documents produce an empty string.
class SrtWriter implements SubtitleWriter {
  const SrtWriter();

  @override
  String write(SubtitleDocument doc) {
    if (doc.entries.isEmpty) return '';
    final buf = StringBuffer();
    for (var i = 0; i < doc.entries.length; i++) {
      final e = doc.entries[i];
      buf.writeln(i + 1);
      buf.writeln('${_fmt(e.startMs)} --> ${_fmt(e.endMs)}');
      buf.writeln(effectiveText(e));
      buf.writeln();
    }
    return buf.toString();
  }

  static String _fmt(int ms) {
    final h = ms ~/ 3600000;
    final m = (ms % 3600000) ~/ 60000;
    final s = (ms % 60000) ~/ 1000;
    final millis = ms % 1000;
    return '${h.toString().padLeft(2, '0')}'
        ':${m.toString().padLeft(2, '0')}'
        ':${s.toString().padLeft(2, '0')}'
        ',${millis.toString().padLeft(3, '0')}';
  }
}
