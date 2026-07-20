# Subtitle Parsers

## Interface

```dart
abstract class SubtitleParser {
  Future<SubtitleDocument> parse(Stream<List<int>> stream, {double? frameRate});
}
```

- Input: byte stream (from File.openRead, http response, or Uint8List)
- Output: SubtitleDocument with format + entries
- Frame rate only used by MicroDVD (.sub) parser

## Format Detection

`SubtitleParserFactory.forFileName(fileName)` → parser by extension:

| Extension | Parser | Package |
|-----------|--------|---------|
| .srt | SrtParser | subtitle |
| .ass, .ssa | AssParser | dart_ass |
| .vtt | VttParser | subtitle |
| .sub | SubParser | custom |

## SRT Parser

- Uses `SubtitleController` + `SubtitleProvider.fromString`
- Converts subtitle package's `Subtitle` objects to SubtitleEntry
- Timestamps in HH:MM:SS,mmm → milliseconds

## ASS Parser

- Uses `Ass(filePath: tempFile).parse()`
- Extracts from `result.dialogs.dialogs[].text.segments[]`
- Strips `{...}` override tags → stores in `assTags` field
- Speaker labels from dialog `Name` field
- Temp file approach required (dart_ass needs filePath, not stream)

## VTT Parser

- Uses `SubtitleController` + `SubtitleProvider.fromString` with VTT type
- Skips WEBVTT header and NOTE blocks
- Same conversion path as SRT

## MicroDVD Parser

- Custom regex: `\{(\d+)\}\{(\d+)\}(.+)`
- Frame numbers → milliseconds: `(frame * 1000) ~/ frameRate`
- Default frame rate: 23.976 fps
- `|` in text → `\n` line breaks

## Stream Decoding Helper

`decodeStream()` in subtitle_parser.dart:
1. Strip UTF-8 BOM (EF BB BF)
2. Decode to String via utf8.decoder
3. Normalize CRLF → LF

## Tests

46 tests across:
- Correct cue count, start/end timestamps, text content
- Multi-line cue splitting
- BOM detection and stripping
- CRLF normalization
- Empty file → FormatException
- MicroDVD frame rate calculations
- Factory extension detection (case-insensitive)
- End-to-end through factory
