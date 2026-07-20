import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'subtitle_provider.dart';

/// Subdl.com subtitle provider — v2 API.
///
/// Auth: `Authorization: Bearer` header (or `X-API-Key`).
/// Search by title, then fetch subtitles for the matched title.
/// Download via nId with format=file for single subtitle files.
class SubdlProvider implements SubtitleProvider {
  SubdlProvider({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const kApiKey = 'subdl_api_key';
  static const _baseUrl = 'https://api.subdl.com/api/v2';
  static const _searchTimeout = Duration(seconds: 15);
  static const _downloadTimeout = Duration(seconds: 30);

  @override
  String get name => 'Subdl';

  @override
  bool get requiresAuth => true;

  Future<String?> _readApiKey() => _storage.read(key: kApiKey);

  Map<String, String> _headers(String apiKey) => {
        'Authorization': 'Bearer $apiKey',
        'Accept': 'application/json',
      };

  /// Validate an API key by hitting the account endpoint.
  /// Returns null on success, error message on failure.
  static Future<String?> validate(String apiKey) async {
    if (apiKey.trim().isEmpty) return 'Enter an API key';
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/me'),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final err = body['error'] as Map<String, dynamic>?;
      return err?['message'] as String? ?? 'HTTP ${res.statusCode}';
    } catch (e) {
      return 'Connection failed: $e';
    }
  }

  @override
  int get pageSize => 30; // Subdl default per_page

  @override
  Future<(List<SubtitleSearchResult>, int)> search(
    String query,
    String language, {
    int page = 1,
  }) async {
    final apiKey = await _readApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError('Subdl API key not configured');
    }

    // Step 1: search for the movie/show by title.
    final searchUri = Uri.parse('$_baseUrl/movies/search').replace(
      queryParameters: {'q': query, 'limit': '5'},
    );
    final searchRes = await http
        .get(searchUri, headers: _headers(apiKey))
        .timeout(_searchTimeout);

    if (searchRes.statusCode != 200) {
      throw http.ClientException(
        'Subdl movie search failed: ${searchRes.statusCode}',
      );
    }

    final searchBody = jsonDecode(searchRes.body) as Map<String, dynamic>;
    final movies = searchBody['results'] as List<dynamic>? ?? [];
    if (movies.isEmpty) return (<SubtitleSearchResult>[], 0);

    // Step 2: for the top match, fetch subtitles in the requested language.
    final top = movies.first as Map<String, dynamic>;
    final sdId = top['sd_id']?.toString();
    if (sdId == null) return (<SubtitleSearchResult>[], 0);

    final subUri = Uri.parse('$_baseUrl/subtitles/search').replace(
      queryParameters: {
        'sd_id': sdId,
        'languages': language,
        'page': '$page',
      },
    );
    final subRes = await http
        .get(subUri, headers: _headers(apiKey))
        .timeout(_searchTimeout);

    if (subRes.statusCode != 200) {
      throw http.ClientException(
        'Subdl subtitle search failed: ${subRes.statusCode}',
      );
    }

    final subBody = jsonDecode(subRes.body) as Map<String, dynamic>;
    final subtitles = subBody['subtitles'] as List<dynamic>? ?? [];
    final totalPages = (subBody['totalPages'] as num?)?.toInt() ?? 1;

    final title = (top['name'] ?? '') as String;
    final year = top['year']?.toString();

    final results = subtitles.map<SubtitleSearchResult>((s) {
      final map = s as Map<String, dynamic>;
      final fileName = (map['release_name'] ?? '') as String;
      return SubtitleSearchResult(
        providerName: name,
        title: '$title${year != null ? ' ($year)' : ''} — $fileName',
        language: (map['language_name'] ?? language) as String,
        downloadId: (map['nId'] ?? map['n_id'] ?? map['id'] ?? '') as String,
        format: map['format'] as String?,
        raw: Map<String, dynamic>.from(map),
      );
    }).toList();

    return (results, totalPages);
  }

  @override
  Future<Uint8List> download(SubtitleSearchResult result) async {
    final apiKey = await _readApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError('Subdl API key not configured');
    }

    // SubDL v2 download: GET /api/v2/subtitles/{nId}/download
    // The 'url' field in search results is the web page URL, NOT the download URL.
    final nId = result.raw['nId'] ??
        result.raw['n_id'] ??
        result.raw['id'] ??
        result.downloadId;
    if (nId == null || '$nId'.isEmpty) {
      throw StateError('No nId in search result');
    }

    final uri = Uri.parse('$_baseUrl/subtitles/$nId/download').replace(
      queryParameters: {'format': 'file'},
    );
    final response = await http
        .get(uri, headers: _headers(apiKey))
        .timeout(_downloadTimeout);

    if (response.statusCode != 200) {
      throw http.ClientException(
        'Subdl download failed: ${response.statusCode}',
      );
    }

    return response.bodyBytes;
  }
}
