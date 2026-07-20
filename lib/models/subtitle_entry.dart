class SubtitleEntry {
  final int id;
  final int startMs;
  final int endMs;
  final List<String> lines;
  final String? translatedText;
  final List<String>? assTags;
  final String? speakerLabel;

  const SubtitleEntry({
    required this.id,
    required this.startMs,
    required this.endMs,
    required this.lines,
    this.translatedText,
    this.assTags,
    this.speakerLabel,
  });
}
