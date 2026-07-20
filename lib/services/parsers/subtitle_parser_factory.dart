import '../../models/subtitle_format.dart';
import 'ass_parser.dart';
import 'srt_parser.dart';
import 'sub_parser.dart';
import 'subtitle_parser.dart';
import 'vtt_parser.dart';

/// Picks the right [SubtitleParser] for a given file name / extension.
///
/// BOM stripping and UTF-8 normalisation live in [SubtitleParser.decodeStream]
/// and run for every format, so the factory only needs to map extension → parser.
class SubtitleParserFactory {
  const SubtitleParserFactory();

  /// Returns the parser matching [fileName]'s extension.
  ///
  /// Throws [FormatException] for an unsupported extension.
  SubtitleParser forFileName(String fileName) {
    return forExtension(_extension(fileName));
  }

  /// Returns the parser matching [ext] (e.g. `.srt`, `srt`).
  ///
  /// Throws [FormatException] for an unsupported extension.
  SubtitleParser forExtension(String ext) {
    final e = ext.toLowerCase();
    final normalized = e.startsWith('.') ? e : '.$e';
    switch (normalized) {
      case '.srt':
        return const SrtParser();
      case '.ass':
      case '.ssa':
        return const AssParser();
      case '.vtt':
        return const VttParser();
      case '.sub':
        return const SubParser();
      default:
        throw FormatException('Unsupported subtitle extension: $ext');
    }
  }

  /// Maps a [SubtitleFormat] back to its parser.
  SubtitleParser forFormat(SubtitleFormat format) {
    switch (format) {
      case SubtitleFormat.srt:
        return const SrtParser();
      case SubtitleFormat.ass:
        return const AssParser();
      case SubtitleFormat.vtt:
        return const VttParser();
      case SubtitleFormat.sub:
        return const SubParser();
    }
  }

  static String _extension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) return '';
    // Stop at last path separator so directory dots don't fool us.
    final sep = path.lastIndexOf(RegExp(r'[/\\]'));
    if (sep > dot) return '';
    return path.substring(dot);
  }
}
