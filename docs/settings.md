# Settings & Configuration

## Settings Page

Accessed via sidebar → Settings. All values persisted to Drift Settings table.

### Language Pair
- Source language (default: English)
- Target language (default: Spanish)
- Shared `kLanguages` list from `lib/models/language.dart`
- 10 languages: EN, ES, FR, DE, ID, JA, KO, ZH, AR, PT

### Model Preferences
- Primary model (default: `deepseek-v4-flash-free`)
- Fallback model (default: `mimo-v2.5-free`)
- Editable via FSelect dropdown

### System Prompt
- Full text editor (FTextField, 5-12 lines)
- Saved to SystemPrompt table in Drift
- Supports placeholder substitution:
  - `{targetLanguage}` — current target language
  - `{cpl}` — characters per line limit

### Glossary
- CRUD: add, remove, update terms
- Export to JSON (FilePicker.saveFile)
- Import from JSON (FilePicker.pickFiles)
- Injected per-chunk into system prompt as:
  `Do not translate: {source} = {target}`

### OpenSubtitles Credentials
- API Key (required for search + download)
- Username (optional)
- Password (optional)
- Stored in flutter_secure_storage

## Window State

Persisted to Drift as CSV string:
- Key: `window_state`
- Value: `"x,y,width,height"`
- Saved on close, restored on start
- Defaults: center screen, 1200x800

## Default Values

| Setting | Default | Source |
|---------|---------|--------|
| Source language | `en` | SettingsService.defaultSourceLang |
| Target language | `es` | SettingsService.defaultTargetLang |
| Primary model | `deepseek-v4-flash-free` | SettingsService.defaultPrimaryModel |
| Fallback model | `mimo-v2.5-free` | SettingsService.defaultFallbackModel |
| Frame rate (MicroDVD) | 23.976 | SubParser default |
| CPL (Latin) | 42 | CplOverflow.latinCpl |
| CPL (CJK) | 14-16 | CplOverflow.cjkCpl |
