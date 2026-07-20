// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// A single subtitle cue to translate.
class SubtitleEntry {
  final int index;
  final String text;

  const SubtitleEntry({required this.index, required this.text});
}

/// A glossary term that must not be translated in the output.
class GlossaryEntry {
  final String source;
  final String target;

  const GlossaryEntry({required this.source, required this.target});
}

/// Configuration for a single translation run.
class TranslationConfig {
  final String apiKey;
  final String systemPrompt;
  final String sourceLang;
  final String targetLang;
  final List<GlossaryEntry> glossary;
  final Duration timeout;
  final bool thinkingEnabled;

  const TranslationConfig({
    required this.apiKey,
    required this.systemPrompt,
    required this.sourceLang,
    required this.targetLang,
    this.glossary = const [],
    this.timeout = const Duration(seconds: 30),
    this.thinkingEnabled = false,
  });
}

// --- OpenCode Zen API constants ---------------------------------------------

const String kZenEndpoint = 'https://opencode.ai/zen/v1/chat/completions';
const String kPrimaryModel = 'deepseek-v4-flash-free';
const String kFallbackModel = 'mimo-v2.5-free';
const double kTemperature = 0.1;

// --- Chunking constants ------------------------------------------------------

const int kChunkBytes = 4000;
const int kOverlapBytes = 200;

Duration _defaultBackoff(int attempt) =>
    Duration(milliseconds: 500 * (1 << (attempt - 1))); // 500ms, 1s, 2s...

const _thinkingModels = {'hy3-free', 'nemotron-3-ultra-free', 'deepseek-v4-flash-free'};
bool _supportsThinking(String model) => _thinkingModels.contains(model);

/// Signals the caller to try the next model in the fallback chain.
class _FallbackException implements Exception {
  final String reason;
  _FallbackException(this.reason);
  @override
  String toString() => '_FallbackException($reason)';
}

// --- Public helpers ----------------------------------------------------------

/// Builds the final system prompt for a chunk. Glossary injection is now
/// handled upstream by [SystemPromptService.substitute] via the `{glossary}`
/// placeholder, so this function simply trims the pre-built prompt.
///
/// Kept as a named helper so callers don't have to change their call sites.
String buildSystemPrompt({
  required String basePrompt,
  List<GlossaryEntry> glossary = const [],
  bool isCjk = false,
}) {
  return basePrompt.trim();
}

/// Splits [entries] into cue-aligned chunks of at most [kChunkBytes] UTF-8
/// bytes, with [kOverlapBytes] of overlap from the previous chunk's tail.
/// Never splits a cue mid-text.
List<List<SubtitleEntry>> chunkEntries(List<SubtitleEntry> entries) {
  if (entries.isEmpty) return const [];
  final chunks = <List<SubtitleEntry>>[];
  var i = 0;
  while (i < entries.length) {
    final chunk = <SubtitleEntry>[];
    var chunkBytes = 0;
    // Prepend overlap from the previous chunk's tail (cue-aligned).
    if (chunks.isNotEmpty) {
      final prev = chunks.last;
      final overlap = <SubtitleEntry>[];
      var overlapBytes = 0;
      for (var j = prev.length - 1; j >= 0 && overlapBytes < kOverlapBytes; j--) {
        overlap.insert(0, prev[j]);
        overlapBytes += utf8.encode(prev[j].text).length;
      }
      chunk.addAll(overlap);
      chunkBytes = overlapBytes;
    }
    // Add new cues until the byte budget is exceeded (but always add at least
    // one to guarantee progress even on an oversized cue).
    var added = 0;
    while (i < entries.length) {
      final entryBytes = utf8.encode(entries[i].text).length;
      if (chunkBytes + entryBytes > kChunkBytes && added > 0) break;
      chunk.add(entries[i]);
      chunkBytes += entryBytes;
      i++;
      added++;
    }
    chunks.add(chunk);
  }
  return chunks;
}

bool _isCjk(String lang) {
  final l = lang.toLowerCase();
  return const ['zh', 'ja', 'ko', 'chinese', 'japanese', 'korean', 'cjk']
      .any(l.contains);
}

// --- TranslationService ------------------------------------------------------

/// Streams translations from the OpenCode Zen chat-completions endpoint with
/// manual SSE parsing, per-chunk model fallback, and cancellation.
///
/// Tokens are accumulated in memory per API attempt and forwarded to the
/// consumer only after the attempt completes successfully. This keeps fallback
/// (primary -> secondary model) free of duplicate tokens. Cancellation
/// discards the in-memory partial result; no partial file is ever written.
class TranslationService {
  TranslationService({
    http.Client? client,
    List<String> models = const [kPrimaryModel, kFallbackModel],
    Duration Function(int attempt) backoffFor = _defaultBackoff,
  })  : _client = client ?? http.Client(),
        _models = models,
        _backoffFor = backoffFor;

  final http.Client _client;
  final List<String> _models;
  final Duration Function(int attempt) _backoffFor;

  /// Last `id:` field seen on the SSE stream, for potential reconnection.
  String? get lastEventId => _lastEventId;

  bool _cancelled = false;
  StreamSubscription<List<int>>? _subscription;
  Completer<void>? _done;
  Duration? _retryHint; // parsed from SSE `retry:` field
  String? _lastEventId; // parsed from SSE `id:` field
  DateTime _lastActivity = DateTime.now();

  /// Re-translates a single entry using the same config.
  /// Returns the translated text, or throws on failure.
  Stream<String> retrySingleEntry({
    required TranslationConfig config,
    required SubtitleEntry entry,
  }) {
    final controller = StreamController<String>();

    () async {
      try {
        final messages = _buildMessages(config, [entry], isCjk: _isCjk(config.targetLang));
        final tokens = <String>[];

        // Try each model in order.
        for (final model in _models) {
          try {
            await _streamRequest(config, model, messages, tokens);
            break; // success
          } on _FallbackException {
            continue; // try next model
          }
        }

        // Parse the response — look for [N] format.
        final buffer = StringBuffer();
        for (final token in tokens) {
          if (token.startsWith('[THINK]')) continue;
          buffer.write(token);
        }

        final text = buffer.toString();
        final match = RegExp(r'^\[' + entry.index.toString() + r'\]\s*(.*)$', multiLine: true).firstMatch(text);
        if (match != null) {
          controller.add(match.group(1)!.trim());
        } else if (tokens.isNotEmpty) {
          controller.add(text.trim());
        }
        await controller.close();
      } catch (e) {
        await controller.close();
      }
    }();

    return controller.stream;
  }

  /// Translates [entries] and emits a stream of token deltas.
  Stream<String> translateStream({
    required TranslationConfig config,
    required List<SubtitleEntry> entries,
  }) {
    _cancelled = false;
    final controller = StreamController<String>(onCancel: cancel);
    controller.onListen = () => _run(controller, config, entries);
    return controller.stream;
  }

  Future<void> _run(
    StreamController<String> controller,
    TranslationConfig config,
    List<SubtitleEntry> entries,
  ) async {
    try {
      final chunks = chunkEntries(entries);
      final isCjk = _isCjk(config.targetLang);
      debugPrint('[Translate] ${chunks.length} chunks to process');
      for (var ci = 0; ci < chunks.length; ci++) {
        if (_cancelled) break;
        debugPrint('[Translate] Processing chunk ${ci + 1}/${chunks.length} '
            '(${chunks[ci].length} cues)');
        // Per-chunk retry: try up to 3 times (initial + 2 retries).
        Object? lastError;
        for (var attempt = 1; attempt <= 3; attempt++) {
          if (_cancelled) break;
          try {
            await _translateChunk(controller, config, chunks[ci], isCjk: isCjk);
            lastError = null;
            break; // success
          } catch (e) {
            lastError = e;
            debugPrint('[Translate] Chunk ${ci + 1} attempt $attempt failed: $e');
            if (attempt < 3) {
              final delay = _backoffFor(attempt);
              debugPrint('[Translate] Retrying in ${delay.inMilliseconds}ms...');
              await Future.delayed(delay);
            }
          }
        }
        if (lastError != null) {
          // All retries exhausted — emit failed indices and continue.
          final failedIndices =
              chunks[ci].map((e) => e.index).join(',');
          debugPrint('[Translate] Chunk ${ci + 1} failed after 3 attempts, '
              'failed cues: $failedIndices');
          if (!controller.isClosed) {
            controller.add('[FAILED]$failedIndices');
          }
        }
      }
      debugPrint('[Translate] All chunks done, closing stream');
      if (!controller.isClosed) await controller.close();
    } catch (e, st) {
      debugPrint('[Translate] Error in _run: $e');
      if (!controller.isClosed) {
        controller.addError(e, st);
        await controller.close();
      }
    }
  }

  Future<void> _translateChunk(
    StreamController<String> controller,
    TranslationConfig config,
    List<SubtitleEntry> chunk, {
    bool isCjk = false,
  }) async {
    final messages = _buildMessages(config, chunk, isCjk: isCjk);
    Object? lastError;
    for (final model in _models) {
      if (_cancelled) return;
      try {
        final tokens = <String>[];
        await _streamRequest(config, model, messages, tokens);
        if (_cancelled) return;
        for (final token in tokens) {
          if (_cancelled) return;
          controller.add(token);
        }
        return; // success
      } on _FallbackException catch (e) {
        lastError = e;
        // ponytail: only one fallback hop (primary -> secondary). If the
        // secondary also fails, the error surfaces to the caller.
      }
    }
    throw Exception('Translation failed for all models. Last error: $lastError');
  }

  List<Map<String, String>> _buildMessages(
    TranslationConfig config,
    List<SubtitleEntry> chunk, {
    bool isCjk = false,
  }) {
    final system = buildSystemPrompt(
      basePrompt: config.systemPrompt,
      glossary: config.glossary,
      isCjk: isCjk,
    );
    final user = chunk.map((e) => '[${e.index}] ${e.text}').join('\n');
    return [
      {'role': 'system', 'content': system},
      {'role': 'user', 'content': user},
    ];
  }

  http.Request _buildRequest(
    TranslationConfig config,
    String model,
    List<Map<String, String>> messages,
  ) {
    final request = http.Request('POST', Uri.parse(kZenEndpoint));
    request.headers['Authorization'] = 'Bearer ${config.apiKey}';
    request.headers['Content-Type'] = 'application/json';
    request.headers['Accept'] = 'text/event-stream';
    final body = <String, dynamic>{
      'model': model,
      'messages': messages,
      'stream': true,
      'temperature': kTemperature,
    };
    if (config.thinkingEnabled && _supportsThinking(model)) {
      body['thinking'] = {'type': 'enabled', 'budget_tokens': 2048};
      // Thinking tokens share the output budget — set high enough for
      // reasoning + full translation output.
      body['max_tokens'] = 16384;
    }
    request.body = jsonEncode(body);
    return request;
  }

  Future<void> _streamRequest(
    TranslationConfig config,
    String model,
    List<Map<String, String>> messages,
    List<String> tokens,
  ) async {
    http.StreamedResponse response;
    try {
      debugPrint('[Translate] Sending request to $model...');
      response =
          await _client.send(_buildRequest(config, model, messages)).timeout(
        config.timeout,
      );
      debugPrint('[Translate] Response: HTTP ${response.statusCode}');
    } on TimeoutException {
      debugPrint('[Translate] Request timeout for $model');
      throw _FallbackException('timeout after ${config.timeout}');
    }

    // 429: retry the same model with backoff, then fall back if still failing.
    if (response.statusCode == 429) {
      await Future.delayed(_retryHint ?? _backoffFor(1));
      _retryHint = null;
      try {
        response =
            await _client.send(_buildRequest(config, model, messages)).timeout(
          config.timeout,
        );
      } on TimeoutException {
        throw _FallbackException('timeout on 429 retry');
      }
      if (response.statusCode == 429 || response.statusCode >= 500) {
        throw _FallbackException('HTTP ${response.statusCode} after retry');
      }
    } else if (response.statusCode >= 500) {
      debugPrint('[Translate] Server error: ${response.statusCode}');
      throw _FallbackException('HTTP ${response.statusCode}');
    } else if (response.statusCode != 200) {
      debugPrint('[Translate] Client error: ${response.statusCode}');
      throw _FallbackException('HTTP ${response.statusCode}');
    }

    // Capture raw bytes for debugging 0-token responses.
    final rawBytes = <int>[];
    await _consumeStream(response.stream, tokens, rawBytes: rawBytes);
    debugPrint('[Translate] Stream consumed: ${tokens.length} tokens');
    // Debug: show first 3 tokens to diagnose thinking vs content issues.
    if (tokens.isNotEmpty) {
      final previews = tokens.take(3).map((t) {
        if (t.length > 80) return '${t.substring(0, 80)}...';
        return t;
      });
      debugPrint('[Translate] First tokens: $previews');
    }
    final thinkCount = tokens.where((t) => t.startsWith('[THINK]')).length;
    final contentCount = tokens.length - thinkCount;
    debugPrint('[Translate] Tokens: $contentCount content, $thinkCount thinking');
    if (thinkCount > 0 && contentCount == 0) {
      debugPrint('[Translate] WARNING: thinking consumed all output — '
          'no translation content received');
    }
    if (tokens.isEmpty) {
      final rawPreview = utf8.decode(
        rawBytes.take(2048).toList(),
        allowMalformed: true,
      );
      debugPrint('[Translate] WARNING: 0 tokens received — raw response '
          '(${rawBytes.length} bytes): $rawPreview');
    }
  }

  Future<void> _consumeStream(
    Stream<List<int>> stream,
    List<String> tokens, {
    List<int>? rawBytes,
  }) async {
    _done = Completer<void>();
    var buffer = '';

    void processLines() {
      while (true) {
        final idx = buffer.indexOf('\n');
        if (idx == -1) break;
        final raw = buffer.substring(0, idx);
        buffer = buffer.substring(idx + 1);
        // Normalize CRLF -> LF by stripping a trailing CR.
        final line =
            raw.endsWith('\r') ? raw.substring(0, raw.length - 1) : raw;
        _processLine(line, tokens);
      }
    }

    _subscription = stream.listen(
      (bytes) {
        if (_cancelled) return;
        rawBytes?.addAll(bytes);
        buffer += utf8.decode(bytes, allowMalformed: true);
        _lastActivity = DateTime.now();
        try {
          processLines();
        } catch (e, st) {
          if (!_done!.isCompleted) _done!.completeError(e, st);
          _subscription?.cancel();
        }
      },
      onError: (Object e, StackTrace st) {
        if (!_done!.isCompleted) _done!.completeError(e, st);
      },
      onDone: () {
        // Flush any trailing line without a newline.
        if (buffer.isNotEmpty) {
          try {
            _processLine(buffer, tokens);
          } catch (e, st) {
            if (!_done!.isCompleted) _done!.completeError(e, st);
            return;
          }
          buffer = '';
        }
        if (!_done!.isCompleted) _done!.complete();
      },
      cancelOnError: true,
    );

    // Per-chunk stream timeout: hard limit + idle check. Thinking mode can
    // keep the stream alive with slow tokens, so we need both.
    _lastActivity = DateTime.now();
    final hardDeadline = DateTime.now().add(const Duration(seconds: 120));
    Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_cancelled || _done == null || _done!.isCompleted) {
        timer.cancel();
        return;
      }
      final pastDeadline = DateTime.now().isAfter(hardDeadline);
      final idle = DateTime.now().difference(_lastActivity);
      if (!pastDeadline && idle <= const Duration(seconds: 60)) return;
      timer.cancel();
      final reason = pastDeadline
          ? 'Stream exceeded 120s hard limit'
          : 'No data received for 60 seconds';
      if (!_done!.isCompleted) {
        _done!.completeError(TimeoutException(
          reason,
          const Duration(seconds: 120),
        ));
      }
      _subscription?.cancel();
    });

    try {
      await _done!.future;
    } finally {
      _subscription = null;
      _done = null;
    }
  }

  /// Parses a single SSE line per the WHATWG spec.
  void _processLine(String line, List<String> tokens) {
    if (line.isEmpty) return; // event separator
    if (line.startsWith(':')) return; // comment / keep-alive
    if (line.startsWith('retry:')) {
      final value = line.substring(6).trim();
      final ms = int.tryParse(value);
      if (ms != null) _retryHint = Duration(milliseconds: ms);
      return;
    }
    if (line.startsWith('id:')) {
      _lastEventId = line.substring(3).trim();
      return;
    }
    if (line.startsWith('data:')) {
      var data = line.substring(5);
      // SSE: strip exactly one leading space if present.
      if (data.startsWith(' ')) data = data.substring(1);
      if (data == '[DONE]') return; // end-of-stream marker
      Map<String, dynamic> json;
      try {
        json = jsonDecode(data) as Map<String, dynamic>;
      } catch (e) {
        throw _FallbackException('malformed JSON: $e');
      }
      final choices = json['choices'];
      if (choices is! List || choices.isEmpty) return;
      final first = choices[0];
      if (first is! Map) return;
      final delta = first['delta'];
      if (delta is! Map) return;
      final content = delta['content'];
      if (content is String && content.isNotEmpty) {
        tokens.add(content);
      }
      final reasoning = delta['reasoning_content'];
      if (reasoning is String && reasoning.isNotEmpty) {
        tokens.add('[THINK]$reasoning');
      }
      return;
    }
    // Non-SSE line: API may return plain JSON errors or non-streaming
    // responses instead of SSE format. Detect and surface them.
    if (line.startsWith('{')) {
      try {
        final json = jsonDecode(line) as Map<String, dynamic>;
        final error = json['error'];
        if (error is Map) {
          final message = error['message']?.toString() ?? 'Unknown error';
          final type = error['type']?.toString() ?? 'Error';
          throw _FallbackException('API $type: $message');
        }
        final type = json['type']?.toString();
        if (type == 'error') {
          throw _FallbackException('API error: $line');
        }
        // Non-streaming fallback: API returned a full completion object
        // instead of SSE deltas. Extract message.content directly.
        final choices = json['choices'];
        if (choices is List && choices.isNotEmpty) {
          final first = choices[0];
          if (first is Map) {
            final message = first['message'];
            if (message is Map) {
              final content = message['content'];
              if (content is String && content.isNotEmpty) {
                // Split the content by newlines and add each as a token
                // so the parser sees them as individual [N] lines.
                for (final line in content.split('\n')) {
                  if (line.trim().isNotEmpty) {
                    tokens.add('$line\n');
                  }
                }
              }
            }
          }
        }
      } catch (e) {
        if (e is _FallbackException) rethrow;
        // Not valid JSON or not an error shape — ignore.
      }
    }
  }

  /// Cancels any in-flight translation: cancels the active stream
  /// subscription and closes the HTTP client. Partial tokens accumulated
  /// in memory are discarded (no partial file is written).
  void cancel() {
    _cancelled = true;
    _subscription?.cancel();
    final done = _done;
    if (done != null && !done.isCompleted) done.complete();
    _client.close();
  }
}
