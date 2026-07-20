enum TranslationChunkStatus { pending, inProgress, completed, failed }

class TranslationChunk {
  final int index;
  final String text;
  final int overlap;
  final TranslationChunkStatus status;
  final String? translatedText;

  const TranslationChunk({
    required this.index,
    required this.text,
    required this.overlap,
    required this.status,
    this.translatedText,
  });
}
