import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'subtitle_provider.dart';

/// Subtitle provider for Subsource.net.
///
/// Requires an API key stored in FlutterSecureStorage under [kApiKey].
/// Search returns movies by query, then fetches subtitles per movie.
/// Download resolves a subtitle ID to a link, then fetches raw bytes.
class SubSourceProvider implements SubtitleProvider {
  SubSourceProvider({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  final http.Client _client;
  final FlutterSecureStorage _storage;

  static const kApiKey = 'subsource_api_key';
  static const _baseUrl = 'https://api.subsource.net/api/v1';

  @override
  String get name => 'SubSource';

  @override
  bool get requiresAuth => true;

  /// Validate an API key by hitting the search endpoint with a test query.
  /// Returns null on success, error message on failure.
  static Future<String?> validate(String apiKey) async {
    if (apiKey.trim().isEmpty) return 'Enter an API key';
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/movies/search?q=test&searchType=text'),
            headers: {
              'X-API-Key': apiKey,
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['message'] as String? ?? 'HTTP ${res.statusCode}';
    } catch (e) {
      return 'Connection failed: $e';
    }
  }

  Future<String?> _readApiKey() => _storage.read(key: kApiKey);

  /// Search movies by [query], then fetch subtitles for each movie
  /// in the given [language].
  @override
  int get pageSize => 30;

  @override
  Future<(List<SubtitleSearchResult>, int)> search(
    String query,
    String language, {
    int page = 1,
  }) async {
    final apiKey = await _readApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError('SubSource API key not configured');
    }

    final searchUri = Uri.parse(
      '$_baseUrl/movies/search?q=${Uri.encodeQueryComponent(query)}&searchType=text',
    );

    final searchResponse = await _client
        .get(
          searchUri,
          headers: {
            'X-API-Key': apiKey,
            'Accept': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 15));

    if (searchResponse.statusCode != 200) {
      throw http.ClientException(
        'SubSource search failed: ${searchResponse.statusCode}',
      );
    }

    final searchData = jsonDecode(searchResponse.body) as Map<String, dynamic>;
    final movies = (searchData['movies'] as List?) ?? [];

    final results = <SubtitleSearchResult>[];
    int maxTotalPages = 1;

    for (final movie in movies) {
      final imdbId = movie['imdb_id'];
      if (imdbId == null) continue;

      final (subs, totalPages) = await _fetchSubtitles(apiKey, imdbId, language, page: page);
      results.addAll(subs);
      if (totalPages > maxTotalPages) maxTotalPages = totalPages;
    }

    return (results, maxTotalPages);
  }

  Future<(List<SubtitleSearchResult>, int)> _fetchSubtitles(
    String apiKey,
    dynamic imdbId,
    String language, {
    int page = 1,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/subtitles?movie_imdb=$imdbId&languages=$language&page=$page',
    );

    final response = await _client
        .get(
          uri,
          headers: {
            'X-API-Key': apiKey,
            'Accept': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) return (<SubtitleSearchResult>[], 1);

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final subtitles = (data['subtitles'] as List?) ?? [];
    final totalPages = (data['total_pages'] as num?)?.toInt() ?? 1;

    final results = subtitles
        .map(
          (s) => SubtitleSearchResult(
            providerName: name,
            title: (s['release_name'] ?? '') as String,
            language: (s['language'] ?? language) as String,
            rating: (s['rating'] as num?)?.toDouble(),
            downloadId: '${s['id']}',
            raw: Map<String, dynamic>.from(s as Map),
          ),
        )
        .toList();

    return (results, totalPages);
  }

  /// Download subtitle bytes by resolving the [result]'s download ID
  /// to a link, then fetching the raw content.
  @override
  Future<Uint8List> download(SubtitleSearchResult result) async {
    final apiKey = await _readApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError('SubSource API key not configured');
    }

    final uri = Uri.parse('$_baseUrl/download/${result.downloadId}');

    final response = await _client
        .get(
          uri,
          headers: {
            'X-API-Key': apiKey,
            'Accept': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw http.ClientException(
        'SubSource download resolve failed: ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final link = data['link'] as String?;
    if (link == null || link.isEmpty) {
      throw http.ClientException('SubSource returned empty download link');
    }

    final fileResponse = await _client
        .get(Uri.parse(link))
        .timeout(const Duration(seconds: 30));

    if (fileResponse.statusCode != 200) {
      throw http.ClientException(
        'SubSource file download failed: ${fileResponse.statusCode}',
      );
    }

    return fileResponse.bodyBytes;
  }
}
