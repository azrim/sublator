import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Extra OpenSubtitles.com API methods beyond search/download.
///
/// Covers: features (movie/TV search), languages, user info, guessit.
/// All endpoints require Api-Key; user info also requires JWT.
class OpenSubtitlesInfo {
  OpenSubtitlesInfo({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _baseUrl = 'https://api.opensubtitles.com/api/v1';
  static const _userAgent = 'SubtitleTranslator v1.0';
  static const _timeout = Duration(seconds: 15);
  static const _apiKeyKey = 'opensubtitles_api_key';
  static const _osUserKey = 'opensubtitles_username';
  static const _osPassKey = 'opensubtitles_password';

  Future<String?> _readKey(String key) => _storage.read(key: key);

  Map<String, String> _headers({String? apiKey, String? jwt}) {
    final h = <String, String>{
      'User-Agent': _userAgent,
      'Accept': 'application/json',
    };
    if (apiKey != null) h['Api-Key'] = apiKey;
    if (jwt != null) h['Authorization'] = 'Bearer $jwt';
    return h;
  }

  Future<String?> _getApiKey() => _readKey(_apiKeyKey);

  Future<String?> _getJwt() async {
    final username = await _readKey(_osUserKey);
    final password = await _readKey(_osPassKey);
    if (username == null ||
        username.isEmpty ||
        password == null ||
        password.isEmpty) {
      return null;
    }
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/login'),
            headers: _headers()..['Content-Type'] = 'application/json',
            body: jsonEncode({'username': username, 'password': password}),
          )
          .timeout(_timeout);
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['token'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ── Features ────────────────────────────────────────────────────────────

  /// Search for movies/TV shows by title. Returns feature list with IDs
  /// useful for precise subtitle searching.
  Future<List<OpenSubtitlesFeature>> searchFeatures(String query) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) return [];

    final uri = Uri.parse('$_baseUrl/features').replace(
      queryParameters: {'query': query, 'type': 'all'},
    );
    final res = await http
        .get(uri, headers: _headers(apiKey: apiKey))
        .timeout(_timeout);
    if (res.statusCode != 200) return [];

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as List? ?? [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(OpenSubtitlesFeature.fromJson)
        .toList();
  }

  // ── Languages ───────────────────────────────────────────────────────────

  /// Fetch the full language list from the API.
  Future<List<OpenSubtitlesLanguage>> getLanguages() async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) return [];

    final res = await http
        .get(
          Uri.parse('$_baseUrl/infos/languages'),
          headers: _headers(apiKey: apiKey),
        )
        .timeout(_timeout);
    if (res.statusCode != 200) return [];

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as List? ?? [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(OpenSubtitlesLanguage.fromJson)
        .toList();
  }

  // ── User Info ───────────────────────────────────────────────────────────

  /// Get the authenticated user's profile and download limits.
  /// Returns null if not authenticated or on error.
  Future<OpenSubtitlesUserInfo?> getUserInfo() async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) return null;

    final jwt = await _getJwt();
    final res = await http
        .get(
          Uri.parse('$_baseUrl/infos/user'),
          headers: _headers(apiKey: apiKey, jwt: jwt),
        )
        .timeout(_timeout);
    if (res.statusCode != 200) return null;

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) return null;
    return OpenSubtitlesUserInfo.fromJson(data);
  }

  // ── Guessit ─────────────────────────────────────────────────────────────

  /// Parse a filename to extract title, year, type, etc.
  Future<OpenSubtitlesGuessit?> guessFilename(String filename) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) return null;

    final uri = Uri.parse('$_baseUrl/utilities/guessit').replace(
      queryParameters: {'filename': filename},
    );
    final res = await http
        .get(uri, headers: _headers(apiKey: apiKey))
        .timeout(_timeout);
    if (res.statusCode != 200) return null;

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) return null;
    return OpenSubtitlesGuessit.fromJson(data);
  }
}

// ── Data models ──────────────────────────────────────────────────────────

class OpenSubtitlesFeature {
  final int id;
  final String title;
  final String? year;
  final String? type; // movie, episode, tvshow
  final int? imdbId;
  final int? tmdbId;

  const OpenSubtitlesFeature({
    required this.id,
    required this.title,
    this.year,
    this.type,
    this.imdbId,
    this.tmdbId,
  });

  factory OpenSubtitlesFeature.fromJson(Map<String, dynamic> j) {
    final attrs = j['attributes'] as Map<String, dynamic>? ?? j;
    return OpenSubtitlesFeature(
      id: int.tryParse('${attrs['feature_id'] ?? j['id'] ?? 0}') ?? 0,
      title: (attrs['title'] ?? '') as String,
      year: attrs['year']?.toString(),
      type: (attrs['feature_type'] ?? j['type'] ?? '') as String?,
      imdbId: attrs['imdb_id'] as int?,
      tmdbId: attrs['tmdb_id'] as int?,
    );
  }

  String get displayLabel {
    final label = title.isNotEmpty ? title : 'Unknown';
    final parts = <String>[label];
    if (year != null && year!.isNotEmpty) parts.add('($year)');
    if (type != null && type!.isNotEmpty) parts.add('• $type');
    return parts.join(' ');
  }
}

class OpenSubtitlesLanguage {
  final String code;
  final String name;

  const OpenSubtitlesLanguage({required this.code, required this.name});

  factory OpenSubtitlesLanguage.fromJson(Map<String, dynamic> j) {
    return OpenSubtitlesLanguage(
      code: j['language_code'] as String? ?? '',
      name: j['language_name'] as String? ?? '',
    );
  }
}

class OpenSubtitlesUserInfo {
  final int userId;
  final String level;
  final bool vip;
  final int allowedDownloads;
  final int downloadsCount;
  final int remainingDownloads;

  const OpenSubtitlesUserInfo({
    required this.userId,
    required this.level,
    required this.vip,
    required this.allowedDownloads,
    required this.downloadsCount,
    required this.remainingDownloads,
  });

  factory OpenSubtitlesUserInfo.fromJson(Map<String, dynamic> j) {
    return OpenSubtitlesUserInfo(
      userId: (j['user_id'] as num?)?.toInt() ?? 0,
      level: (j['level'] ?? '') as String,
      vip: j['vip'] as bool? ?? false,
      allowedDownloads: (j['allowed_downloads'] as num?)?.toInt() ?? 0,
      downloadsCount: (j['downloads_count'] as num?)?.toInt() ?? 0,
      remainingDownloads: (j['remaining_downloads'] as num?)?.toInt() ?? 0,
    );
  }
}

class OpenSubtitlesGuessit {
  final String title;
  final int? year;
  final String? type;
  final String? language;
  final String? subtitleLanguage;
  final String? screenSize;
  final String? source;
  final String? videoCodec;
  final String? audioCodec;
  final String? releaseGroup;

  const OpenSubtitlesGuessit({
    required this.title,
    this.year,
    this.type,
    this.language,
    this.subtitleLanguage,
    this.screenSize,
    this.source,
    this.videoCodec,
    this.audioCodec,
    this.releaseGroup,
  });

  factory OpenSubtitlesGuessit.fromJson(Map<String, dynamic> j) {
    return OpenSubtitlesGuessit(
      title: (j['title'] ?? '') as String,
      year: (j['year'] as num?)?.toInt(),
      type: j['type'] as String?,
      language: j['language'] as String?,
      subtitleLanguage: j['subtitle_language'] as String?,
      screenSize: j['screen_size'] as String?,
      source: j['source'] as String?,
      videoCodec: j['video_codec'] as String?,
      audioCodec: j['audio_codec'] as String?,
      releaseGroup: j['release_group'] as String?,
    );
  }
}
