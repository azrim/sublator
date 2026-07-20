import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../credential_service.dart';
import 'subtitle_provider.dart';

/// OpenSubtitles.com provider.
///
/// Auth flow per API docs:
/// 1. Api-Key header (mandatory) — developer's consumer key from profile
/// 2. Authorization: Bearer JWT — obtained by logging in with user credentials
///    Required for downloads beyond 5/day per IP.
class OpenSubtitlesProvider implements SubtitleProvider {
  OpenSubtitlesProvider({CredentialService? credentials, http.Client? client})
      : _credentials = credentials ?? CredentialService(),
        _client = client ?? http.Client();

  final CredentialService _credentials;
  final http.Client _client;

  static const _baseUrl = 'https://api.opensubtitles.com/api/v1';
  static const _userAgent = 'SubtitleTranslator v1.0';
  static const _searchTimeout = Duration(seconds: 15);
  static const _downloadTimeout = Duration(seconds: 30);

  @override
  String get name => 'OpenSubtitles';

  @override
  bool get requiresAuth => true;

  // -- Auth -------------------------------------------------------------------

  Future<String?> _login() async {
    final username =
        await _credentials.read(CredentialService.kOpenSubtitlesUsername);
    final password =
        await _credentials.read(CredentialService.kOpenSubtitlesPassword);
    if (username == null ||
        username.isEmpty ||
        password == null ||
        password.isEmpty) {
      return null;
    }
    final res = await _client
        .post(
          Uri.parse('$_baseUrl/login'),
          headers: {
            'User-Agent': _userAgent,
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'username': username, 'password': password}),
        )
        .timeout(_searchTimeout);
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final msg = body['message'] as String? ?? 'HTTP ${res.statusCode}';
      throw http.ClientException('OpenSubtitles login failed: $msg');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['token'] as String?;
  }

  Future<Map<String, String>> _authHeaders() async {
    final apiKey =
        await _credentials.read(CredentialService.kOpenSubtitlesApiKey);
    if (apiKey == null || apiKey.isEmpty) {
      return {'User-Agent': _userAgent};
    }
    final headers = <String, String>{
      'Api-Key': apiKey,
      'User-Agent': _userAgent,
    };
    // Try JWT login for download permissions.
    try {
      final jwt = await _login();
      if (jwt != null) {
        headers['Authorization'] = 'Bearer $jwt';
      }
    } on http.ClientException {
      // Login failed — search still works with just Api-Key.
    }
    return headers;
  }

  // -- Provider API -----------------------------------------------------------

  /// Validate API key (+ optional username/password login).
  /// Returns null on success, error message on failure.
  static Future<String?> validate({
    required String apiKey,
    String? username,
    String? password,
  }) async {
    if (apiKey.trim().isEmpty) return 'Enter an API key';
    final client = http.Client();
    try {
      // Test API key with a search request.
      final res = await client
          .get(
            Uri.parse('$_baseUrl/subtitles?query=test&languages=en'),
            headers: {
              'Api-Key': apiKey,
              'User-Agent': _userAgent,
              'Accept': 'application/json',
            },
          )
          .timeout(_searchTimeout);
      if (res.statusCode != 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return body['message'] as String? ?? 'HTTP ${res.statusCode}';
      }
      // Test user login if credentials provided.
      if (username != null &&
          username.isNotEmpty &&
          password != null &&
          password.isNotEmpty) {
        final loginRes = await client
            .post(
              Uri.parse('$_baseUrl/login'),
              headers: {
                'Api-Key': apiKey,
                'User-Agent': _userAgent,
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode({
                'username': username,
                'password': password,
              }),
            )
            .timeout(_searchTimeout);
        if (loginRes.statusCode != 200) {
          final body =
              jsonDecode(loginRes.body) as Map<String, dynamic>;
          return 'API key OK, but login failed: ${body['message'] ?? 'HTTP ${loginRes.statusCode}'}';
        }
      }
      return null;
    } catch (e) {
      return 'Connection failed: $e';
    } finally {
      client.close();
    }
  }

  @override
  int get pageSize => 40; // OpenSubtitles default per_page

  @override
  Future<(List<SubtitleSearchResult>, int)> search(
    String query,
    String language, {
    int page = 1,
  }) async {
    final headers = await _authHeaders();
    if (!headers.containsKey('Api-Key')) {
      throw StateError(
        'No OpenSubtitles API key found. '
        'Add one in Settings → API Keys.',
      );
    }

    final uri = Uri.parse('$_baseUrl/subtitles').replace(
      queryParameters: {
        'query': query,
        'languages': language,
        'page': '$page',
      },
    );

    final res = await _client
        .get(uri, headers: headers)
        .timeout(_searchTimeout);

    if (res.statusCode != 200) {
      throw http.ClientException(
        'OpenSubtitles search failed: HTTP ${res.statusCode}',
      );
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as List? ?? [];
    final totalPages = (body['total_pages'] as num?)?.toInt() ?? 1;
    final results = <SubtitleSearchResult>[];

    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      final attrs = item['attributes'] as Map<String, dynamic>?;
      if (attrs == null) continue;
      final files = attrs['files'];
      if (files is! List || files.isEmpty) continue;
      final firstFile = files.first;
      if (firstFile is! Map<String, dynamic>) continue;
      final fileId = firstFile['file_id'];
      if (fileId is! num) continue;

      results.add(SubtitleSearchResult(
        providerName: name,
        title: (attrs['release'] as String?) ??
            (attrs['feature_details'] as Map<String, dynamic>?)?['title']
                ?.toString() ??
            'Untitled',
        language: (attrs['language'] as String?) ?? language,
        rating: (attrs['ratings'] as num?)?.toDouble(),
        downloadId: '${fileId.toInt()}',
        raw: {
          'file_id': fileId.toInt(),
          'file_name': firstFile['file_name'],
        },
      ));
    }

    return (results, totalPages);
  }

  @override
  Future<Uint8List> download(SubtitleSearchResult result) async {
    final fileId = result.raw['file_id'] as int? ??
        int.tryParse(result.downloadId);
    if (fileId == null) {
      throw StateError('No file_id in search result');
    }

    final authH = await _authHeaders();
    if (!authH.containsKey('Api-Key')) {
      throw StateError('No OpenSubtitles API key in Settings');
    }

    final res = await _client
        .post(
          Uri.parse('$_baseUrl/download'),
          headers: {
            ...authH,
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'file_id': fileId}),
        )
        .timeout(_downloadTimeout);

    if (res.statusCode != 200) {
      throw http.ClientException(
        'OpenSubtitles download failed: HTTP ${res.statusCode}',
      );
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final link = body['link'] as String?;
    if (link == null) {
      throw http.ClientException('OpenSubtitles returned no download link');
    }

    final fileRes = await _client
        .get(Uri.parse(link), headers: {'User-Agent': _userAgent})
        .timeout(_downloadTimeout);

    if (fileRes.statusCode != 200) {
      throw http.ClientException(
        'OpenSubtitles file fetch failed: HTTP ${fileRes.statusCode}',
      );
    }

    return fileRes.bodyBytes;
  }
}
