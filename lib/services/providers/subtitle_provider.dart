import 'dart:typed_data';

/// A single subtitle search result from any provider.
class SubtitleSearchResult {
  final String providerName;
  final String title;
  final String language;
  final String? format;
  final double? rating;
  final String downloadId;
  final Map<String, dynamic> raw;

  const SubtitleSearchResult({
    required this.providerName,
    required this.title,
    required this.language,
    this.format,
    this.rating,
    required this.downloadId,
    this.raw = const {},
  });
}

/// Abstract interface for subtitle download providers.
///
/// Each provider implements [search] and [download]. The UI calls [search]
/// with a query + language code, displays results, then calls [download]
/// with the selected result to get raw subtitle file bytes.
abstract class SubtitleProvider {
  /// Display name shown in the provider selector.
  String get name;

  /// Whether this provider requires API credentials.
  bool get requiresAuth;

  /// Number of results per page (provider-specific).
  int get pageSize;

  /// Search for subtitles matching [query] in the given [language] code.
  /// Returns (results, totalPages).
  Future<(List<SubtitleSearchResult>, int)> search(
    String query,
    String language, {
    int page = 1,
  });

  /// Download the subtitle file bytes for [result].
  Future<Uint8List> download(SubtitleSearchResult result);
}
