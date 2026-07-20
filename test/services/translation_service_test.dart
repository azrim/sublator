import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:subtitle_translator/services/translation_service.dart';

/// A wrapper around [http.Client] that records when [close] is called. The
/// stock [MockClient.close] is a no-op with no observable state, so we wrap it
/// to make cancellation observable from tests.
class CloseTrackingClient extends http.BaseClient {
  CloseTrackingClient(this._inner);
  final http.Client _inner;
  bool isClosed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request);

  @override
  void close() {
    isClosed = true;
    _inner.close();
  }
}

TranslationConfig _config({
  String apiKey = 'test-key',
  String systemPrompt = 'You are a translator.',
  String sourceLang = 'en',
  String targetLang = 'es',
  List<GlossaryEntry> glossary = const [],
  Duration timeout = const Duration(seconds: 5),
}) {
  return TranslationConfig(
    apiKey: apiKey,
    systemPrompt: systemPrompt,
    sourceLang: sourceLang,
    targetLang: targetLang,
    glossary: glossary,
    timeout: timeout,
  );
}

/// Builds an SSE response body that emits [tokens] as separate `data:` events
/// followed by `[DONE]`.
List<int> sseBody(List<String> tokens) {
  final sb = StringBuffer();
  for (final t in tokens) {
    sb.write('data: ');
    sb.write(jsonEncode({
      'choices': [
        {'delta': {'content': t}}
      ]
    }));
    sb.write('\n\n');
  }
  sb.write('data: [DONE]\n\n');
  return utf8.encode(sb.toString());
}

void main() {
  group('TranslationService', () {
    test('request payload has correct model, messages, temperature, headers',
        () async {
      http.BaseRequest? capturedRequest;
      String? capturedBody;

      final client = MockClient.streaming((request, bodyStream) async {
        capturedRequest = request;
        final bytes = await bodyStream.toBytes();
        capturedBody = utf8.decode(bytes);
        return http.StreamedResponse(
          Stream.value(sseBody(['ok'])),
          200,
        );
      });

      final service = TranslationService(client: client);
      final tokens = await service
          .translateStream(
            config: _config(apiKey: 'key123'),
            entries: const [
              SubtitleEntry(index: 1, text: 'Hello'),
              SubtitleEntry(index: 2, text: 'World'),
            ],
          )
          .toList();

      expect(tokens, ['ok']);

      // Endpoint + headers.
      expect(capturedRequest!.url.toString(),
          'https://opencode.ai/zen/v1/chat/completions');
      expect(capturedRequest!.method, 'POST');
      expect(capturedRequest!.headers['Authorization'], 'Bearer key123');
      expect(capturedRequest!.headers['Content-Type'], 'application/json');
      expect(capturedRequest!.headers['Accept'], 'text/event-stream');

      // Body fields.
      final body = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(body['model'], 'deepseek-v4-flash-free');
      expect(body['stream'], true);
      expect(body['temperature'], 0.1);

      final messages = body['messages'] as List;
      expect(messages.length, 2);
      expect(messages[0]['role'], 'system');
      expect(messages[1]['role'], 'user');
      // User content contains the cue indices.
      final userContent = messages[1]['content'] as String;
      expect(userContent, contains('[1] Hello'));
      expect(userContent, contains('[2] World'));
    });

    test('SSE parsing yields correct token stream (3 tokens)', () async {
      final client = MockClient.streaming((_, _) async {
        return http.StreamedResponse(
          Stream.value(sseBody(['Hello', ' World', '!'])),
          200,
        );
      });

      final service = TranslationService(client: client);
      final tokens = await service
          .translateStream(
            config: _config(),
            entries: const [SubtitleEntry(index: 1, text: 'Hi')],
          )
          .toList();

      expect(tokens, ['Hello', ' World', '!']);
    });

    test('SSE keep-alive lines (starting with :) are ignored', () async {
      final body = utf8.encode(
        ': ping\n\n'
        'data: ${jsonEncode({
          'choices': [
            {'delta': {'content': 'A'}}
          ]
        })}\n\n'
        ': keep-alive\n\n'
        'data: [DONE]\n\n',
      );
      final client = MockClient.streaming((_, _) async {
        return http.StreamedResponse(Stream.value(body), 200);
      });

      final service = TranslationService(client: client);
      final tokens = await service
          .translateStream(
            config: _config(),
            entries: const [SubtitleEntry(index: 1, text: 'x')],
          )
          .toList();

      expect(tokens, ['A']);
    });

    test('retry: field is parsed as backoff hint and id: is stored', () async {
      final body = utf8.encode(
        'retry: 1500\n'
        'id: evt-42\n'
        'data: ${jsonEncode({
          'choices': [
            {'delta': {'content': 'ok'}}
          ]
        })}\n\n'
        'data: [DONE]\n\n',
      );
      final client = MockClient.streaming((_, _) async {
        return http.StreamedResponse(Stream.value(body), 200);
      });

      final service = TranslationService(client: client);
      await service
          .translateStream(
            config: _config(),
            entries: const [SubtitleEntry(index: 1, text: 'x')],
          )
          .toList();

      expect(service.lastEventId, 'evt-42');
    });

    test('fallback triggers on HTTP 500 (first 500, second 200)', () async {
      var callCount = 0;
      final client = MockClient.streaming((_, _) async {
        callCount++;
        if (callCount == 1) {
          // Primary model -> 500.
          return http.StreamedResponse(Stream.value([]), 500);
        }
        // Fallback model -> 200 with tokens.
        return http.StreamedResponse(
          Stream.value(sseBody(['fallback-ok'])),
          200,
        );
      });

      final service = TranslationService(client: client);
      final tokens = await service
          .translateStream(
            config: _config(),
            entries: const [SubtitleEntry(index: 1, text: 'Hi')],
          )
          .toList();

      expect(callCount, 2);
      expect(tokens, ['fallback-ok']);
    });

    test('HTTP 429 triggers retry with backoff then succeeds', () async {
      var callCount = 0;
      final client = MockClient.streaming((_, _) async {
        callCount++;
        if (callCount == 1) {
          return http.StreamedResponse(Stream.value([]), 429);
        }
        return http.StreamedResponse(
          Stream.value(sseBody(['after-retry'])),
          200,
        );
      });

      final service = TranslationService(
        client: client,
        backoffFor: (_) => Duration.zero, // no real delay in tests
      );
      final tokens = await service
          .translateStream(
            config: _config(),
            entries: const [SubtitleEntry(index: 1, text: 'Hi')],
          )
          .toList();

      expect(callCount, greaterThanOrEqualTo(2));
      expect(tokens, ['after-retry']);
    });

    test('HTTP 429 then 500 falls back to secondary model', () async {
      var callCount = 0;
      final client = MockClient.streaming((_, _) async {
        callCount++;
        // call 1: primary -> 429; call 2: primary retry -> 500 (still bad);
        // call 3: fallback model -> 200.
        if (callCount <= 2) {
          return http.StreamedResponse(Stream.value([]), callCount == 1 ? 429 : 500);
        }
        return http.StreamedResponse(
          Stream.value(sseBody(['secondary'])),
          200,
        );
      });

      final service = TranslationService(
        client: client,
        backoffFor: (_) => Duration.zero,
      );
      final tokens = await service
          .translateStream(
            config: _config(),
            entries: const [SubtitleEntry(index: 1, text: 'Hi')],
          )
          .toList();

      expect(tokens, ['secondary']);
      expect(callCount, greaterThanOrEqualTo(3));
    });

    test('empty stream yields empty result, no crash', () async {
      final client = MockClient.streaming((_, _) async {
        return http.StreamedResponse(Stream.empty(), 200);
      });

      final service = TranslationService(client: client);
      final tokens = await service
          .translateStream(
            config: _config(),
            entries: const [SubtitleEntry(index: 1, text: 'x')],
          )
          .toList();

      expect(tokens, isEmpty);
    });

    test('cancellation closes both StreamSubscription and http.Client',
        () async {
      var streamCancelled = false;
      final streamController = StreamController<List<int>>(
        onCancel: () => streamCancelled = true,
      );
      final mockClient = MockClient.streaming((_, _) async {
        return http.StreamedResponse(streamController.stream, 200);
      });
      final client = CloseTrackingClient(mockClient);

      final service = TranslationService(client: client);
      final done = Completer<void>();
      final sub = service
          .translateStream(
            config: _config(),
            entries: const [SubtitleEntry(index: 1, text: 'x')],
          )
          .listen((_) {}, onDone: done.complete, onError: done.completeError);

      // Let the subscription attach and start consuming the stream.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      service.cancel();

      // Give async cleanup a turn.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(streamCancelled, isTrue,
          reason: 'inner stream subscription should be cancelled');
      expect(client.isClosed, isTrue,
          reason: 'http.Client.close() should be called');

      await streamController.close();
      await sub.cancel();
      // Drain the done future so it doesn't surface as an unhandled error.
      done.future.ignore();
    });

    test('chunking groups entries by UTF-8 byte budget with overlap', () {
      // Each entry's text is 10 bytes ("aaaaaaaaaa" -> 10 ASCII bytes).
      final entries = List.generate(
        60,
        (i) => SubtitleEntry(index: i + 1, text: 'a' * 10),
      );
      final chunks = chunkEntries(entries);

      // 60 entries * 10 bytes = 600 bytes total -> a single chunk.
      expect(chunks.length, 1);
      expect(chunks.first.length, 60);

      // Now with bigger entries to force multiple chunks.
      final big = List.generate(
        10,
        (i) => SubtitleEntry(index: i + 1, text: 'a' * 1000),
      );
      final bigChunks = chunkEntries(big);
      // 10 * 1000 = 10000 bytes -> at least 3 chunks of <= 4000 bytes each.
      expect(bigChunks.length, greaterThanOrEqualTo(3));
      // Each chunk should respect the 4000-byte budget (except possibly the
      // last, or when overlap forces an oversized entry).
      for (final c in bigChunks) {
        final bytes =
            c.fold<int>(0, (sum, e) => sum + utf8.encode(e.text).length);
        // Allow one entry overflow since we never split mid-cue.
        expect(bytes, lessThanOrEqualTo(4000 + 1000));
      }
      // Overlap: every chunk after the first shares cues with the previous.
      for (var i = 1; i < bigChunks.length; i++) {
        final prevTail = bigChunks[i - 1].last.index;
        final curHead = bigChunks[i].first.index;
        expect(curHead, lessThanOrEqualTo(prevTail),
            reason: 'overlap should rewind into the previous chunk');
      }
    });

    test('system prompt builder returns trimmed base prompt', () {
      final latin = buildSystemPrompt(
        basePrompt: 'Translate to Spanish.',
        glossary: const [GlossaryEntry(source: 'API', target: 'API')],
        isCjk: false,
      );
      expect(latin, 'Translate to Spanish.');

      final cjk = buildSystemPrompt(
        basePrompt: 'Translate to Japanese.',
        isCjk: true,
      );
      expect(cjk, 'Translate to Japanese.');
    });

    test('malformed JSON triggers fallback to secondary model', () async {
      var callCount = 0;
      final client = MockClient.streaming((_, _) async {
        callCount++;
        if (callCount == 1) {
          // Primary returns malformed JSON in a data: event.
          return http.StreamedResponse(
            Stream.value(utf8.encode('data: {not valid json}\n\n')),
            200,
          );
        }
        return http.StreamedResponse(
          Stream.value(sseBody(['recovered'])),
          200,
        );
      });

      final service = TranslationService(client: client);
      final tokens = await service
          .translateStream(
            config: _config(),
            entries: const [SubtitleEntry(index: 1, text: 'x')],
          )
          .toList();

      expect(tokens, ['recovered']);
      expect(callCount, 2);
    });

    test('all models failing surfaces error in output', () async {
      final client = MockClient.streaming((_, _) async {
        return http.StreamedResponse(Stream.value([]), 500);
      });

      final service = TranslationService(client: client);
      final results = await service
          .translateStream(
            config: _config(),
            entries: const [SubtitleEntry(index: 1, text: 'x')],
          )
          .toList();
      // Service marks failed entries with [FAILED] prefix instead of throwing.
      expect(results, anyElement(contains('[FAILED]')));
    });
  });
}
