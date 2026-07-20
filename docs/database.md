# Database Schema (Drift)

## Tables

### Settings

| Column | Type | Notes |
|--------|------|-------|
| key | TEXT | Primary key |
| value | TEXT | Nullable |

Key-value store for all settings. Keys:
- `source_lang`, `target_lang` — language codes
- `primary_model`, `fallback_model` — model names
- `active_prompt_id` — SystemPrompt row ID
- `window_state` — CSV "x,y,w,h" for window geometry

### GlossaryEntry

| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER | Auto-increment PK |
| source | TEXT | Source term (do not translate) |
| target | TEXT | Target translation of term |
| caseSensitive | INTEGER | Boolean as int (0/1) |

### SystemPrompt

| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER | Auto-increment PK |
| name | TEXT | Prompt name/label |
| content | TEXT | Full prompt text |
| isActive | INTEGER | Boolean as int (0/1). Only one active at a time. |

## Default System Prompt

Inserted on first run by `SystemPromptService.ensureDefault()`:

```
Translate to {targetLanguage}. Preserve text in {braces} and ALL CAPS.
Preserve character names and speaker labels.
Max {cpl} chars per line, max 2 lines.
Return ONLY translation.
```

Placeholders filled by `SystemPromptService.substitute()`.

## AppDatabase

```dart
@DriftDatabase(tables: [Settings, GlossaryEntry, SystemPrompt])
class AppDatabase extends _$AppDatabase { ... }
```

- Production: `NativeDatabase.createInBackground(file)` — file at app support dir
- Tests: `NativeDatabase.memory()` — in-memory, no persistence
- `ref.onDispose(db.close)` in provider for cleanup

## Credential Storage (NOT Drift)

flutter_secure_storage keys:
- `zen_api_key` — OpenCode Zen API key
- `opensubtitles_api_key` — OpenSubtitles API key
- `opensubtitles_username` — OpenSubtitles username
- `opensubtitles_password` — OpenSubtitles password

Stored in Windows Credential Manager (DPAPI encryption).
Throws `SecureStorageUnavailableException` if platform unavailable.
