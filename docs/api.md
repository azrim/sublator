# API Reference

## OpenCode Zen API

### Translate (SSE Streaming)

```
POST https://opencode.ai/zen/v1/chat/completions

Headers:
  Authorization: Bearer <api_key>
  Content-Type: application/json
  Accept: text/event-stream

Body:
{
  "model": "deepseek-v4-flash-free",
  "messages": [
    {"role": "system", "content": "<system prompt>"},
    {"role": "user", "content": "[1] Hello world\n[2] Goodbye world"}
  ],
  "stream": true,
  "max_tokens": 4096,
  "temperature": 0.1
}

Response (SSE):
  data: {"choices":[{"delta":{"content":"[1] "}}]}
  data: {"choices":[{"delta":{"content":"Hola mundo"}}]}
  data: {"choices":[{"delta":{"content":"\n"}}]}
  data: {"choices":[{"delta":{"content":"[2] Adi"}}]}
  data: {"choices":[{"delta":{"content":"ós mundo"}}]}
  data: [DONE]
```

## OpenSubtitles API

### Search Subtitles

```
GET https://api.opensubtitles.com/api/v1/subtitles?query={query}&languages={lang}

Headers:
  Api-Key: <opensubtitles_api_key>
  User-Agent: SubtitleTranslator/1.0

Response:
{
  "data": [
    {
      "id": "...",
      "attributes": {
        "release": "Movie.2024.720p.BluRay.srt",
        "language": "en",
        "files": [{"file_id": 12345}],
        "ratings": 8.5
      }
    }
  ]
}
```

### Download Subtitle

```
POST https://api.opensubtitles.com/api/v1/download

Headers:
  Api-Key: <opensubtitles_api_key>
  User-Agent: SubtitleTranslator/1.0
  Content-Type: application/json

Body:
{"file_id": 12345}

Response:
{
  "link": "https://dl.opensubtitles.org/en/download/...",
  "file_name": "Movie.srt"
}
```

## Subtitle Format Specifications

### SRT

```
1
00:00:01,000 --> 00:00:03,000
Hello world

2
00:00:04,000 --> 00:00:06,000
Goodbye world
```

### VTT

```
WEBVTT

00:00:01.000 --> 00:00:03.000
Hello world

00:00:04.000 --> 00:00:06.000
Goodbye world
```

### MicroDVD (.sub)

```
{24}{72}Hello world
{96}{144}Goodbye world
```

Frame-based. Default 23.976 fps. `|` for line breaks.

### ASS/SSA

```ini
[Script Info]
ScriptType: v4.00+
PlayResX: 1920
PlayResY: 1080

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, ...
Style: Default,Arial,48,&H00FFFFFF,...

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:01.00,0:00:03.00,Default,,0,0,0,,Hello world
```

Override tags: `{\\b1}bold text{\\b0}` — preserved in `assTags` field.
Speaker labels: `Name` field in Dialogue line → `speakerLabel` field.
