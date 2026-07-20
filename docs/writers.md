# Subtitle Writers

## Interface

```dart
abstract class SubtitleWriter {
  String write(SubtitleDocument doc);
}
```

- Input: SubtitleDocument (with optional `translatedText` per entry)
- Output: formatted string (caller writes to file)

## Writer Selection

`SubtitleWriterFactory.create(format)` → writer by SubtitleFormat enum.

## SRT Writer

```
{index}
{HH:MM:SS,mmm} --> {HH:MM:SS,mmm}
{translatedText or lines.join('\n')}
```

- 1-based index
- Comma-separated timestamps
- Uses `translatedText` if present, falls back to `lines`

## VTT Writer

```
WEBVTT

{HH:MM:SS.fff} --> {HH:MM:SS.fff}
{translatedText or lines.join('\n')}
```

- Dot-separated milliseconds
- WEBVTT header required

## MicroDVD Writer

```
{startFrame}
{endFrame}
{translatedText or lines.join('\n')}
```

- Frame-based: `Duration.inMilliseconds * frameRate ~/ 1000`
- Configurable frameRate parameter (default 23.976)

## ASS Writer

- Writes ASS format with `[Script Info]`, `[V4+ Styles]`, `[Events]` sections
- Preserves override tags from `assTags` field
- Speaker labels from `speakerLabel` field
- dart_ass round-trip: `Ass(filePath).parse()` then `ass.toFile(outputPath)`

## CPL Overflow Post-Processor

`CplOverflow.process(doc)` → new SubtitleDocument with split cues.

### Rules

1. **Latin text** (`[a-zA-Z]`): max 42 chars per line
2. **CJK text** (`[\u4e00-\u9fff\u3040-\u309f\u30a0-\u30ff]`): max 14-16 chars per line
3. **3+ line cues**: split into multiple cues (never wrap to 3rd line)
4. **Timestamp split**: proportional — `newStart = start + (end - start) * i / splitCount`
5. **ID generation**: composite `{originalId}_{splitIndex}` to avoid collisions

### Behavior

- 100-char Latin cue → splits into 3 proportional cues
- 2-line cue within limits → unchanged (idempotent)
- Empty document → empty output
- Preserves `assTags` and `speakerLabel` across split cues
