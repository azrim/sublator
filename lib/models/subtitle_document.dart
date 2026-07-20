import 'subtitle_entry.dart';
import 'subtitle_format.dart';

class SubtitleDocument {
  final SubtitleFormat format;
  final List<SubtitleEntry> entries;

  const SubtitleDocument({required this.format, required this.entries});
}
