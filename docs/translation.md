# Translation Service

## API Endpoint

```
POST https://opencode.ai/zen/v1/chat/completions
Headers:
  Authorization: Bearer {apiKey}
  Content-Type: application/json
  Accept: text/event-stream
Body:
  {"model": "{model}", "messages": [...], "stream": true, "max_tokens": 4096, "temperature": 0.1}
```

## SSE Parsing (Manual)

1. `http.Client().send(request)` → response stream
2. `utf8.decoder` → split on `\n`
3. Lines starting with `data:` → skip if `data: [DONE]`
4. `jsonDecode(data.substring(5))` → extract `choices[0].delta.content`
5. Lines starting with `:` → keep-alive, skip
6. Parse `retry:` field for backoff hint
7. Store `id:` for potential reconnection

## Chunking

- Group SubtitleEntry objects by **4000 UTF-8 bytes** (NOT characters)
- 200 UTF-8 byte overlap from previous chunk's last cues
- Aligned to cue boundaries (never split mid-cue)
- Use `utf8.encode(text).length` for byte counting

## System Prompt Builder

```
{active system prompt}

Do not translate: {source} = {target}  (one line per glossary entry)
Max 42 chars per line, max 2 lines.
Return ONLY translation.
```

Temperature: always 0.1

## Model Fallback

| Trigger | Behavior |
|---------|----------|
| HTTP 5xx | Retry with fallback model |
| HTTP 429 | Exponential backoff (500ms, 1s, 2s...) |
| Timeout (>30s) | Switch to fallback |
| Empty response | Switch to fallback |
| Malformed JSON | Switch to fallback |

Primary: `deepseek-v4-flash-free`
Fallback: `mimo-v2.5-free`

## Cancellation

```dart
service.cancel();  // StreamSubscription.cancel() + http.Client.close()
```

- In-memory accumulation only — no partial file writes
- Clean cancellation mid-stream

## Output Format

The LLM is prompted to output in this format:
```
[1] Translation for entry 1
[2] Translation for entry 2
[3] Translation for entry 3
```

PreviewPage parses this format from the token stream:
- Accumulates tokens in buffer
- Splits on `\n`
- Regex `^\[(\d+)\]\s*(.*)$` extracts index + translation
- Complete lines update entry's `translatedText`
- Partial last line shows streaming indicator
