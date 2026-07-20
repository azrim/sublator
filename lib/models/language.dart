class Language {
  final String code;
  final String name;

  const Language({required this.code, required this.name});
}

/// Special sentinel for "detect source language automatically".
const kAutoDetectCode = 'auto';

/// Common language presets shared by home (OpenSubtitles) and settings pages.
const kLanguages = <(String code, String name)>[
  ('en', 'English'),
  ('es', 'Spanish'),
  ('fr', 'French'),
  ('de', 'German'),
  ('id', 'Indonesian'),
  ('ja', 'Japanese'),
  ('ko', 'Korean'),
  ('zh', 'Chinese'),
  ('ar', 'Arabic'),
  ('pt', 'Portuguese'),
];

final Map<String, String> kLanguageNames = {
  for (final (code, name) in kLanguages) code: name,
};

/// Returns the full language name for a code, or the code itself if unknown.
/// The special code [kAutoDetectCode] maps to 'Auto detect'.
String languageName(String code) {
  if (code == kAutoDetectCode) return 'Auto detect';
  return kLanguageNames[code] ?? code;
}
