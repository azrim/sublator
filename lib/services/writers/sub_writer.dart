import '../../models/subtitle_document.dart';
import 'subtitle_writer.dart';

/// MicroDVD (.sub) writer.
///
/// Format per cue (frame-based timing):
/// ```
/// {startFrame}
/// {endFrame}
/// text
///
/// ```
/// Frame conversion: `frame = round(ms * frameRate / 1000)`.
///
/// The default 23.976 fps matches the most common film framerate; users can
/// override via [frameRate] (e.g. 25.0 for PAL, 29.97 for NTSC).
class SubWriter implements SubtitleWriter {
  const SubWriter({this.frameRate = 23.976});

  final double frameRate;

  @override
  String write(SubtitleDocument doc) {
    if (doc.entries.isEmpty) return '';
    final buf = StringBuffer();
    for (final e in doc.entries) {
      buf.writeln('{${_toFrame(e.startMs)}}');
      buf.writeln('{${_toFrame(e.endMs)}}');
      buf.writeln(effectiveText(e));
      buf.writeln();
    }
    return buf.toString();
  }

  int _toFrame(int ms) => (ms * frameRate / 1000).round();
}
