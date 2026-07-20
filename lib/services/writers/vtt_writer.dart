import '../../models/subtitle_document.dart';
import 'subtitle_writer.dart';

/// WebVTT (.vtt) writer.
///
/// Format:
/// ```
/// WEBVTT
///
/// HH:MM:SS.fff --> HH:MM:SS.fff
/// text
///
/// ```
/// Uses `.` as the millisecond separator (vs SRT's `,`). Empty documents
/// produce an empty string (no `WEBVTT` header).
class VttWriter implements SubtitleWriter {
  const VttWriter();

  @override
  String write(SubtitleDocument doc) {
    if (doc.entries.isEmpty) return '';
    final buf = StringBuffer()
      ..writeln('WEBVTT')
      ..writeln();
    for (final e in doc.entries) {
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
        '.${millis.toString().padLeft(3, '0')}';
  }
}
