import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:swift_animations/swift_animations.dart';


import '../main.dart' show motionDuration, hasUnsavedChangesNotifier;
import '../models/active_document.dart';
import '../theme/theme.dart';
import '../models/language.dart';
import '../models/subtitle_document.dart';
import '../models/subtitle_entry.dart';
import '../models/subtitle_format.dart';
import '../services/app_database_provider.dart';
import '../services/credential_service.dart';
import '../services/glossary_service.dart';
import '../services/history_service.dart';
import '../services/settings_service.dart';
import '../services/system_prompt_service.dart';
import '../services/translation_service.dart' as translation;
import '../services/writers/cpl_overflow.dart';
import '../services/writers/subtitle_writer_factory.dart';

/// Per-entry translation status shown in the right-hand status column.
enum _EntryStatus { pending, translating, done, failed }

/// Full preview page: side-by-side original | translated cues with streaming
/// translation, inline text + timing editing, and format-aware export with
/// CPL overflow post-processing.
///
/// Layout:
///   - Toolbar: title, translate/cancel/export actions, format picker
///   - Header row: column labels
///   - Scrollable body: one row per cue, original | translated | timing | status
///
/// Streaming parser: the [TranslationService] emits raw token deltas for the
/// whole document. We accumulate them in a buffer and split on `\n` to recover
/// the per-cue `[index] text` lines the service's prompt asks the model to
/// emit. The last partial line (no trailing newline) is shown live as the
/// in-progress cue's translation.
class PreviewPage extends ConsumerStatefulWidget {
  final SubtitleDocument document;

  const PreviewPage({super.key, required this.document});

  @override
  ConsumerState<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends ConsumerState<PreviewPage>
    with SingleTickerProviderStateMixin {
  // ponytail: late-init from widget so the constructor stays const. Lazy
  // initialization happens on first build, after `widget` is bound.
  late final List<SubtitleEntry> _entries = List.of(widget.document.entries);
  late SubtitleFormat _exportFormat = widget.document.format;

  // id -> status / partial-streaming-text. Kept in maps keyed by id so the
  // SubtitleEntry model stays immutable; we swap entries in [_entries] when
  // a translation completes.
  final Map<int, _EntryStatus> _status = {};
  final Map<int, String> _partial = {};

  bool _translating = false;
  bool _translationComplete = false;
  bool _hasUnsavedChanges = false;
  int _completedCount = 0;
  int _totalCount = 0;
  String _settingsSummary = '';
  String? _translateError;
  translation.TranslationService? _service;
  StreamSubscription<String>? _sub;
  final StringBuffer _buffer = StringBuffer();

  // Source/target language codes saved during translation for history.
  String _sourceLang = 'en';
  String _targetLang = 'en';

  /// Loads settings summary reactively. Called when settingsServiceProvider
  /// emits a new value, not during build.
  Future<void> _loadSettingsSummary() async {
    final svc = await ref.read(settingsServiceProvider.future);
    final source = await svc.getSourceLang();
    final target = await svc.getTargetLang();
    final model = await svc.getPrimaryModel();
    final summary = '${languageName(source)} \u2192 ${languageName(target)} \u00b7 $model';
    if (mounted && summary != _settingsSummary) {
      setState(() => _settingsSummary = summary);
    }
  }

  bool get hasUnsavedChanges => _hasUnsavedChanges;

  // Cached text controllers per entry id. Created lazily on first row build.
  // ponytail: never disposed per-entry when entries are removed (none are);
  // all disposed together in dispose(). Switch to a LRU cache if huge docs
  // cause memory pressure.
  final Map<int, TextEditingController> _textCtrls = {};
  final Map<int, TextEditingController> _startCtrls = {};
  final Map<int, TextEditingController> _endCtrls = {};

  final ScrollController _scrollCtrl = ScrollController();

  static final RegExp _lineRegex = RegExp(r'^\[(\d+)\]\s*(.*)$');
  static final RegExp _failedRegex = RegExp(r'^\[FAILED\](.*)$');

  @override
  void initState() {
    super.initState();
    // ponytail: Load settings summary on mount AND on changes.
    // ref.listen only fires on changes, not the initial value, so the
    // initial load is needed for the file-open path where settings are
    // already loaded when this page mounts.
    _loadSettingsSummary();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _service?.cancel();
    for (final c in _textCtrls.values) {
      c.dispose();
    }
    for (final c in _startCtrls.values) {
      c.dispose();
    }
    for (final c in _endCtrls.values) {
      c.dispose();
    }
    _scrollCtrl.dispose();
    super.dispose();
  }

  // --- Model helpers --------------------------------------------------------

  SubtitleEntry _copyWith(
    SubtitleEntry e, {
    String? translatedText,
    int? startMs,
    int? endMs,
  }) {
    return SubtitleEntry(
      id: e.id,
      startMs: startMs ?? e.startMs,
      endMs: endMs ?? e.endMs,
      lines: e.lines,
      translatedText: translatedText ?? e.translatedText,
      assTags: e.assTags,
      speakerLabel: e.speakerLabel,
    );
  }

  TextEditingController _textCtrlFor(SubtitleEntry e) {
    return _textCtrls.putIfAbsent(e.id, () {
      final c = TextEditingController(
        text: e.translatedText ?? e.lines.join('\n'),
      );
      c.addListener(() {
        final idx = _entries.indexWhere((x) => x.id == e.id);
        if (idx < 0) return;
        final cur = _entries[idx].translatedText;
        if (cur != c.text) {
          _hasUnsavedChanges = true;
          // Silent update: no setState, controller already shows the text.
          // The state change is picked up on next rebuild (e.g. when a new
          // token arrives or user triggers any action).
          _entries[idx] = _copyWith(_entries[idx], translatedText: c.text);
        }
      });
      return c;
    });
  }

  TextEditingController _startCtrlFor(SubtitleEntry e) {
    return _startCtrls.putIfAbsent(e.id, () {
      final c = TextEditingController(text: e.startMs.toString());
      c.addListener(() {
        final ms = int.tryParse(c.text);
        if (ms == null) return;
        final idx = _entries.indexWhere((x) => x.id == e.id);
        if (idx < 0) return;
        if (_entries[idx].startMs != ms) {
          _entries[idx] = _copyWith(_entries[idx], startMs: ms);
        }
      });
      return c;
    });
  }

  TextEditingController _endCtrlFor(SubtitleEntry e) {
    return _endCtrls.putIfAbsent(e.id, () {
      final c = TextEditingController(text: e.endMs.toString());
      c.addListener(() {
        final ms = int.tryParse(c.text);
        if (ms == null) return;
        final idx = _entries.indexWhere((x) => x.id == e.id);
        if (idx < 0) return;
        if (_entries[idx].endMs != ms) {
          _entries[idx] = _copyWith(_entries[idx], endMs: ms);
        }
      });
      return c;
    });
  }

  // --- Translation ----------------------------------------------------------

  /// Reads credentials and settings and assembles a [TranslationConfig].
  /// Returns null (and shows a toast) if the API key is missing.
  Future<
      ({
        translation.TranslationConfig config,
        String primaryModel,
        String fallbackModel,
      })?> _buildTranslationSetup() async {
    final credSvc = ref.read(credentialServiceProvider);
    final apiKey = await credSvc.read(CredentialService.kZenApiKey);
    if (apiKey == null || apiKey.isEmpty) {
      setState(() {
        _translateError = 'Set your translation API key in Settings first';
        _translating = false;
      });
      _toast('Set your translation API key in Settings first');
      return null;
    }

    final settingsSvc = await ref.read(settingsServiceProvider.future);
    final promptSvc = await ref.read(systemPromptServiceProvider.future);
    final glossarySvc = await ref.read(glossaryServiceProvider.future);

    final sourceLang = await settingsSvc.getSourceLang();
    final targetLang = await settingsSvc.getTargetLang();
    _sourceLang = sourceLang;
    _targetLang = targetLang;
    final primaryModel = await settingsSvc.getPrimaryModel();
    final fallbackModel = await settingsSvc.getFallbackModel();
    final activePrompt = await promptSvc.ensureDefault();
    final glossaryRows = await glossarySvc.getAll();
    final glossaryForPrompt = [
      for (final g in glossaryRows)
        (source: g.source, target: g.target),
    ];
    final glossary = [
      for (final g in glossaryRows)
        translation.GlossaryEntry(source: g.source, target: g.target),
    ];
    final promptContent = SystemPromptService.substitute(
      activePrompt.content,
      sourceLanguage: languageName(sourceLang),
      targetLanguage: languageName(targetLang),
      cpl: 42,
      glossary: glossaryForPrompt,
    );
    final thinkingEnabled = await settingsSvc.getThinkingEnabled();

    return (
      config: translation.TranslationConfig(
        apiKey: apiKey,
        systemPrompt: promptContent,
        sourceLang: sourceLang,
        targetLang: targetLang,
        glossary: glossary,
        thinkingEnabled: thinkingEnabled,
      ),
      primaryModel: primaryModel,
      fallbackModel: fallbackModel,
    );
  }

  Future<void> _startTranslation() async {
    if (_translating || _entries.isEmpty) return;

    setState(() {
      _translating = true;
      _translationComplete = false;
      _translateError = null;
      _status.clear();
      _partial.clear();
      _buffer.clear();
      _multiLineBuffer.clear();
    });

    try {
      final setup = await _buildTranslationSetup();
      if (setup == null) return; // error already handled

      final translationEntries = [
        for (final e in _entries)
          translation.SubtitleEntry(index: e.id, text: e.lines.join('\n')),
      ];

      setState(() {
        for (final e in _entries) {
          _status[e.id] = _EntryStatus.pending;
        }
      });

      debugPrint('[Translate] Starting: ${_entries.length} cues, '
          'model=${setup.primaryModel}, '
          'endpoint=${translation.kZenEndpoint}');

      _service = translation.TranslationService(
        models: [setup.primaryModel, setup.fallbackModel],
      );
      _sub = _service!
          .translateStream(config: setup.config, entries: translationEntries)
          .listen(_onToken, onDone: _onDone, onError: _onError);
    } catch (e) {
      setState(() {
        _translateError = 'Could not start translation: $e. Check your API key in Settings.';
        _translating = false;
      });
      _toast('Could not start translation: $e. Check your API key in Settings.');
    }
  }

  /// Re-runs [translateStream] for only the failed entries.
  Future<void> _retryFailed() async {
    if (_translating) return;
    final failedEntries = _entries
        .where((e) => _status[e.id] == _EntryStatus.failed)
        .toList();
    if (failedEntries.isEmpty) return;

    setState(() {
      _translating = true;
      _translationComplete = false;
      _translateError = null;
      _buffer.clear();
      _multiLineBuffer.clear();
      for (final e in failedEntries) {
        _status[e.id] = _EntryStatus.pending;
        _partial.remove(e.id);
      }
    });

    try {
      final setup = await _buildTranslationSetup();
      if (setup == null) return;

      final translationEntries = [
        for (final e in failedEntries)
          translation.SubtitleEntry(index: e.id, text: e.lines.join('\n')),
      ];

      debugPrint('[RetryFailed] ${failedEntries.length} cues');

      _service = translation.TranslationService(
        models: [setup.primaryModel, setup.fallbackModel],
      );
      _sub = _service!
          .translateStream(config: setup.config, entries: translationEntries)
          .listen(_onToken, onDone: _onDone, onError: _onError);
    } catch (e) {
      setState(() {
        _translateError = 'Could not retry failed entries: $e';
        _translating = false;
        for (final e in failedEntries) {
          _status[e.id] = _EntryStatus.failed;
        }
      });
      _toast('Could not retry failed entries: $e');
    }
  }

  /// Retries a single [entryId] using [retrySingleEntry], which handles model
  /// fallback internally and returns only the final translated text.
  Future<void> _retrySingleEntry(int entryId) async {
    if (_translating) return;
    final idx = _entries.indexWhere((e) => e.id == entryId);
    if (idx < 0) return;

    final setup = await _buildTranslationSetup();
    if (setup == null) return;

    final entry = _entries[idx];
    setState(() {
      _status[entryId] = _EntryStatus.translating;
      _partial.remove(entryId);
    });

    final svc = translation.TranslationService(
      models: [setup.primaryModel, setup.fallbackModel],
    );
    svc
        .retrySingleEntry(
          config: setup.config,
          entry: translation.SubtitleEntry(
            index: entryId,
            text: entry.lines.join('\n'),
          ),
        )
        .listen(
          (text) {
            if (mounted && text.isNotEmpty) _setTranslation(entryId, text);
          },
          onError: (_) {
            if (mounted) setState(() => _status[entryId] = _EntryStatus.failed);
          },
          onDone: () {
            if (mounted && _status[entryId] == _EntryStatus.translating) {
              setState(() => _status[entryId] = _EntryStatus.failed);
            }
          },
        );
  }

  void _onToken(String token) {
    if (!mounted) return;
    final failedMatch = _failedRegex.firstMatch(token);
    if (failedMatch != null) {
      final indices = failedMatch.group(1)!.split(',').where((s) => s.isNotEmpty);
      for (final idxStr in indices) {
        final idx = int.tryParse(idxStr);
        if (idx != null) {
          _status[idx] = _EntryStatus.failed;
          _partial.remove(idx);
        }
      }
      setState(() {});
      return;
    }
    _buffer.write(token);
    _parseBuffer(updatePartial: true);
  }

  void _onDone() {
    if (!mounted) return;
    _parseBuffer(updatePartial: false);
    _buffer.clear();
    _flushMultiLineBuffer();
    final translatedCount = _entries.where((e) => e.translatedText != null).length;
    final failedCount = _entries.where((e) => _status[e.id] == _EntryStatus.failed).length;
    setState(() {
      _translating = false;
      _translationComplete = true;
      _hasUnsavedChanges = true;
      _completedCount = translatedCount;
      _totalCount = _entries.length;
      for (final e in _entries) {
        final s = _status[e.id];
        if (s == _EntryStatus.failed) continue; // don't overwrite failed
        if (s == _EntryStatus.translating || s == _EntryStatus.pending) {
          _status[e.id] = _EntryStatus.done;
        }
      }
    });
    final msg = failedCount > 0
        ? 'Translation complete! $translatedCount/${_entries.length} cues translated, $failedCount failed'
        : 'Translation complete! $translatedCount/${_entries.length} cues translated';
    _toast(msg);

    // Save to history.
    _saveToHistory(
      status: failedCount > 0 ? 'partial' : 'done',
    );
  }

  Future<void> _saveToHistory({required String status}) async {
    if (!mounted) return;
    try {
      final db = await ref.read(appDatabaseProvider.future);
      final historySvc = HistoryService(db);
      final original = _buildSrtContent(widget.document.entries);
      final translated = _buildSrtContent(_entries);
      final fileName = ref.read(activeFileNameProvider);
      await historySvc.add(
        fileName: fileName.isNotEmpty ? fileName : 'untitled.srt',
        sourceLanguage: _sourceLang,
        targetLanguage: _targetLang,
        status: status,
        originalContent: original,
        translatedContent: translated,
      );
    } catch (e) {
      debugPrint('Failed to save history: $e');
    }
  }

  String _buildSrtContent(List<SubtitleEntry> entries) {
    final buf = StringBuffer();
    for (final e in entries) {
      buf.writeln(e.id);
      buf.writeln('${_fmtTimestamp(e.startMs)} --> ${_fmtTimestamp(e.endMs)}');
      buf.writeln(e.lines.join('\n'));
      buf.writeln();
    }
    return buf.toString();
  }

  String _fmtTimestamp(int ms) {
    final h = ms ~/ 3600000;
    final m = (ms % 3600000) ~/ 60000;
    final s = (ms % 60000) ~/ 1000;
    final millis = ms % 1000;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')},'
        '${millis.toString().padLeft(3, '0')}';
  }

  void _onError(Object e, StackTrace st) {
    if (!mounted) return;
    debugPrint('Translation stream error: $e\n$st');
    setState(() {
      _translating = false;
      _translateError = e.toString();
      for (final entry in _entries) {
        if (_status[entry.id] != _EntryStatus.done) {
          _status[entry.id] = _EntryStatus.failed;
        }
      }
    });
    _toast('Translation failed: $e');
  }

  void _parseBuffer({required bool updatePartial}) {
    final text = _buffer.toString();
    if (text.isEmpty) return;
    final lines = text.split('\n');

    // Process only COMPLETE lines (those that had a trailing \n).
    // The tail (last element after split) is incomplete — no \n yet.
    // Processing the tail immediately causes double-counting: the partial
    // fragment gets appended to _multiLineBuffer, then the SAME bytes arrive
    // again in the next token and get appended a second time.
    for (var i = 0; i < lines.length - 1; i++) {
      final line = lines[i].trim();
      if (line.isNotEmpty) _processLine(line);
    }

    // Keep the unterminated tail in the buffer; it will be completed
    // when the next token delivers the missing \n.
    _buffer.clear();
    final tail = lines.last;
    if (tail.isNotEmpty) {
      if (updatePartial) {
        // Still streaming: store tail for the next token.
        _buffer.write(tail);
      } else {
        // Stream ended (_onDone): treat the tail as a complete line.
        final trimmed = tail.trim();
        if (trimmed.isNotEmpty) _processLine(trimmed);
      }
    }
  }

  /// Accumulates multi-line translations between [N] markers.
  final Map<int, StringBuffer> _multiLineBuffer = {};

  /// Processes one complete (newline-terminated) output line from the model.
  ///
  /// If the line matches `[N] text`, it starts (or replaces) a buffer for
  /// that entry index and flushes any prior entry. If it is a plain text
  /// line, it is appended to the most-recently-opened entry as a
  /// continuation. Finalization (calling [_setTranslation]) is deferred to
  /// [_flushMultiLineBuffer] so that multi-line model output is collected
  /// before being written to state.
  void _processLine(String line) {
    final m = _lineRegex.firstMatch(line);
    if (m != null) {
      final index = int.parse(m.group(1)!);
      final translated = m.group(2)!.trim();

      // Finalize any PREVIOUS entry now that we know it is complete.
      _flushMultiLineBuffer(except: index);

      // Buffer this entry — continuation lines may still follow before the
      // next [N+1] marker arrives.
      _multiLineBuffer[index] = StringBuffer(translated);
      _status[index] = _EntryStatus.translating;
      _partial[index] = translated;
      setState(() {});
      return;
    }

    // Plain text line: continuation of the most-recently-opened entry.
    if (line.isNotEmpty && _multiLineBuffer.isNotEmpty) {
      final lastKey = _multiLineBuffer.keys.last;
      _multiLineBuffer[lastKey]!.write('\n$line');
      _partial[lastKey] = _multiLineBuffer[lastKey].toString();
      setState(() {});
    }
  }

  void _flushMultiLineBuffer({int? except}) {
    for (final entry in _multiLineBuffer.entries.toList()) {
      if (entry.key == except) continue;
      final text = entry.value.toString().trim();
      if (text.isNotEmpty) {
        _setTranslation(entry.key, text);
      }
      _multiLineBuffer.remove(entry.key);
    }
  }

  void _setTranslation(int index, String text) {
    final idx = _entries.indexWhere((e) => e.id == index);
    if (idx < 0) return;
    // The prompt instructs the model to use the literal token \n (backslash-n)
    // for two-line subtitles so it doesn't confuse the [N] regex parser.
    // Unescape it here before storing.
    final unescaped = text.replaceAll(r'\n', '\n');
    setState(() {
      _entries[idx] = _copyWith(_entries[idx], translatedText: unescaped);
      _status[index] = _EntryStatus.done;
      _partial.remove(index);
      _multiLineBuffer.remove(index);
      // Sync the inline editor controller if it exists.
      final ctrl = _textCtrls[index];
      if (ctrl != null && ctrl.text != unescaped) {
        ctrl.value = TextEditingValue(
          text: unescaped,
          selection: TextSelection.collapsed(offset: unescaped.length),
        );
      }
    });
  }

  Future<void> _cancelTranslation() async {
    if (_translating) {
      final confirmed = await showFDialog<bool>(
        context: context,
        builder: (context, style, animation) => FDialog(
          style: style,
          animation: animation,
          constraints: const BoxConstraints(maxWidth: 360),
          builder: (context, style) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                Text('Cancel Translation?', style: style.titleTextStyle),
                Text(
                  'Translation is in progress. Canceling will mark '
                  'unfinished entries as failed.',
                  style: context.theme.typography.body.sm.copyWith(
                    color: context.theme.colors.mutedForeground,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  spacing: 8,
                  children: [
                    FButton(
                      variant: FButtonVariant.outline,
                      size: FButtonSizeVariant.sm,
                      onPress: () => Navigator.of(context).pop(false),
                      child: const Text('Keep translating'),
                    ),
                    FButton(
                      size: FButtonSizeVariant.sm,
                      onPress: () => Navigator.of(context).pop(true),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      if (confirmed != true) return;
    }
    // Cancel my subscription first so onDone does not fire and override the
    // failed status we are about to set.
    _sub?.cancel();
    _sub = null;
    _service?.cancel();
    _service = null;
    if (!mounted) return;
    setState(() {
      _translating = false;
      for (final e in _entries) {
        final s = _status[e.id];
        if (s == _EntryStatus.translating || s == _EntryStatus.pending) {
          _status[e.id] = _EntryStatus.failed;
        }
      }
    });
  }

  // --- Export ---------------------------------------------------------------

  Future<void> _export() async {
    if (_entries.isEmpty) return;
    final doc = SubtitleDocument(format: _exportFormat, entries: _entries);
    // CPL overflow post-processing: splits long cues into N timed cues.
    final processed = const CplOverflow().process(doc);
    final writer = const SubtitleWriterFactory().create(_exportFormat);
    final output = writer.write(processed);

    final ext = _extFor(_exportFormat);
    final path = await FilePicker.saveFile(
      dialogTitle: 'Export subtitles',
      fileName: 'translated.$ext',
      bytes: Uint8List.fromList(utf8.encode(output)),
    );
    if (path == null) return;
    if (mounted) _toast('Exported to $path');
  }

  String _extFor(SubtitleFormat f) {
    switch (f) {
      case SubtitleFormat.srt:
        return 'srt';
      case SubtitleFormat.ass:
        return 'ass';
      case SubtitleFormat.vtt:
        return 'vtt';
      case SubtitleFormat.sub:
        return 'sub';
    }
  }

  // --- UI helpers -----------------------------------------------------------

  void _toast(String message) {
    if (!mounted) return;
    showFToast(
      context: context,
      title: Text(message),
      alignment: FToastAlignment.bottomCenter,
    );
  }

  @override
  Widget build(BuildContext context) {
    hasUnsavedChangesNotifier.value = _hasUnsavedChanges;
    final theme = context.theme;

    // Reactively compute settings summary so it updates when user changes
    // language/model in Settings without needing to reload the page.
    // ponytail: ref.listen in build (not initState) is the Riverpod-correct
    // way to react to provider changes without triggering unnecessary rebuilds.
    ref.listen(settingsServiceProvider, (_, _) => _loadSettingsSummary());

    return FScaffold(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
              if (!_translating) _startTranslation();
            },
            const SingleActivator(LogicalKeyboardKey.escape): () {
              if (_translating) _cancelTranslation();
            },
            const SingleActivator(LogicalKeyboardKey.keyS, control: true): _export,
          },
          child: Column(
          children: [
          // --- Header ---
          Builder(builder: (context) {
            final theme = context.theme;
            final fileName = ref.watch(activeFileNameProvider);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Preview',
                    style: theme.typography.display.xl2,
                  ),
                  if (fileName.isNotEmpty)
                    Text(
                      fileName,
                      style: theme.typography.body.sm.copyWith(
                        color: theme.colors.mutedForeground,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            );
          }),
          // --- Action bar ---
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                // Subtitle info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${widget.document.format.name.toUpperCase()} '
                        '• ${_entries.length} cues',
                        style: theme.typography.body.sm.copyWith(
                          color: theme.colors.mutedForeground,
                        ),
                      ),
                      if (_settingsSummary.isNotEmpty)
                        Text(
                          _settingsSummary,
                          style: theme.typography.body.xs.copyWith(
                            color: theme.colors.mutedForeground,
                          ),
                        ),
                    ],
                  ),
                ),
                if (_translating) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(
                      _status.isEmpty
                          ? 'Connecting...'
                          : '${_status.values.where((s) => s == _EntryStatus.done).length}/${_entries.length}',
                      style: theme.typography.body.sm.copyWith(
                        color: theme.colors.mutedForeground,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: const FCircularProgress(size: .sm),
                    ),
                  ),
                ],
                AnimatedOpacity(
                  opacity: _translationComplete && !_translating ? 1.0 : 0.0,
                  duration: motionDuration(context),
                  child: AnimatedSize(
                    duration: motionDuration(context),
                    curve: Curves.easeOut,
                    child: _translationComplete && !_translating
                        ? Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Row(
                              key: const ValueKey('translation-complete'),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  FLucideIcons.checkCircle,
                                  size: 16,
                                  color: theme.colors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Translation complete — $_completedCount/$_totalCount cues',
                                  style: theme.typography.body.sm.copyWith(
                                    color: theme.colors.primary,
                                  ),
                                ),
                              ],
                            ).animate().fadeIn().scale(1.05).duration(200.ms).springGentle(),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                // Show retry-failed button when translation is done and some cues failed.
                Builder(builder: (context) {
                  final failedCount = _status.values
                      .where((s) => s == _EntryStatus.failed)
                      .length;
                  if (_translating || failedCount == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FTooltip(
                      tipBuilder: (context, _) => Text('Re-translate only the $failedCount failed cue(s)'),
                      child: FButton(
                        variant: FButtonVariant.outline,
                        onPress: _retryFailed,
                        suffix: const Icon(FLucideIcons.refreshCw),
                        child: Text('Retry failed ($failedCount)'),
                      ),
                    ),
                  );
                }),
                FButton(
                  onPress: _translating ? null : _startTranslation,
                  child: const Text('Translate'),
                ),
                const SizedBox(width: 8),
                FButton(
                  variant: FButtonVariant.outline,
                  onPress: _translating ? _cancelTranslation : null,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          // --- Secondary toolbar: format + export ---
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: FSelect<SubtitleFormat>(
                    items: {
                      for (final f in SubtitleFormat.values)
                        f.name.toUpperCase(): f,
                    },
                    control: FSelectControl.lifted(
                      value: _exportFormat,
                      onChange: (v) {
                        if (v != null) setState(() => _exportFormat = v);
                      },
                    ),
                    hint: 'Format',
                  ),
                ),
                const SizedBox(width: 8),
                FTooltip(
                  tipBuilder: (context, _) => const Text('Export translated subtitles'),
                  child: FButton(
                    variant: FButtonVariant.outline,
                    onPress: _entries.isEmpty ? null : _export,
                    suffix: const Icon(FLucideIcons.download),
                    child: const Text('Export'),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
          // --- Animated error bar ---
          AnimatedSize(
            duration: motionDuration(context),
            curve: Curves.easeOut,
            child: _translateError != null
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FAlert(
                      variant: .destructive,
                      icon: const Icon(FLucideIcons.alertCircle),
                      title: Text(_translateError!),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          // --- Progress bar ---
          if (_translating) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ponytail: FDeterminateProgress replaces Material's
                  // LinearProgressIndicator with ForUI's native component.
                  // Uses theme-aware styling and proper semantics.
                  FDeterminateProgress(
                    value: _entries.isEmpty
                        ? 0.0
                        : _status.values
                                .where((s) => s == _EntryStatus.done)
                                .length /
                            _entries.length,
                    semanticsLabel: 'Translation progress',
                  ),
                ],
              ),
            ),
          ],
          const FDivider(),
          // --- Body ---
          Expanded(
            child: _entries.isEmpty
                ? Center(
                    child: Text(
                      'No entries to preview.\nOpen a subtitle file to begin.',
                      style: theme.typography.body.lg
                          .copyWith(color: theme.colors.mutedForeground),
                      textAlign: TextAlign.center,
                    ),
                  )
                // ponytail: Material wrapper removed — FTextField is a ForUI
                // widget that works within FTheme without Material ancestor.
                // The transparent Material sheet was a workaround for raw
                // Flutter TextField; FTextField handles its own theming.
                : Column(
                    children: [
                      _headerRow(theme),
                      Expanded(
                        child: ListView.builder(
                            controller: _scrollCtrl,
                            itemCount: _entries.length,
                            itemBuilder: (_, i) =>
                                _entryRow(_entries[i], theme),
                          ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    ),
  ),
);
  }

  Widget _headerRow(FThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colors.muted,
        border: Border(
          bottom: BorderSide(
            color: theme.colors.border,
            width: theme.style.borderWidth,
          ),
        ),
      ),
      child: Row(
        children: [
          // ponytail: Header labels use body.xs with mutedForeground to
          // distinguish from content text. Weight w600 adds emphasis without
          // being heavy.
          Expanded(
            flex: 2,
            child: Text(
              'Original',
              style: theme.typography.body.xs.copyWith(
                color: theme.colors.mutedForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Translated',
              style: theme.typography.body.xs.copyWith(
                color: theme.colors.mutedForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 140,
            child: Text(
              'Timing',
              style: theme.typography.body.xs.copyWith(
                color: theme.colors.mutedForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 32),
        ],
      ),
    );
  }

  Widget _entryRow(SubtitleEntry e, FThemeData theme) {
    final status = _status[e.id] ?? _EntryStatus.pending;
    final partial = _partial[e.id];

    return AnimatedContainer(
      duration: motionDuration(context),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colors.border,
            width: theme.style.borderWidth,
          ),
        ),
        // ponytail: Subtle background tint for translating entries (0.12 alpha)
        // uses info blue to distinguish from primary action buttons.
        color: status == _EntryStatus.translating
            ? theme.colors.app.info.withValues(alpha: 0.12)
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Original text (read-only display).
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                e.lines.join('\n'),
                style: theme.typography.body.sm,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // Translated text: editable TextField when done/failed, streaming
          // Text while translating, placeholder while pending.
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _translatedWidget(e, status, partial, theme),
            ),
          ),
          // Timing editors: raw ms, two compact rows stacked vertically so
          // a wide formatted-time string can never force a horizontal overflow.
          SizedBox(
            width: 140,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    FTooltip(
                      tipBuilder: (context, _) => const Text('Start time (ms)'),
                      child: Text(
                        'S ',
                        style: theme.typography.body.xs.copyWith(
                          color: theme.colors.mutedForeground,
                        ),
                      ),
                    ),
                    Expanded(
                      child: FTextField(
                        control: FTextFieldControl.managed(
                          controller: _startCtrlFor(e),
                        ),
                        size: .sm,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    FTooltip(
                      tipBuilder: (context, _) => const Text('End time (ms)'),
                      child: Text(
                        'E ',
                        style: theme.typography.body.xs.copyWith(
                          color: theme.colors.mutedForeground,
                        ),
                      ),
                    ),
                    Expanded(
                      child: FTextField(
                        control: FTextFieldControl.managed(
                          controller: _endCtrlFor(e),
                        ),
                        size: .sm,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 32,
            child: _statusIcon(status, e.id),
          ),
        ],
      ),
    );
  }

  Widget _translatedWidget(
    SubtitleEntry e,
    _EntryStatus status,
    String? partial,
    FThemeData theme,
  ) {
    switch (status) {
      case _EntryStatus.pending:
        return Text(
          '—',
          style: theme.typography.body.sm
              .copyWith(color: theme.colors.mutedForeground),
        );
      case _EntryStatus.translating:
        return Text(
          '${partial ?? ''}…',
          style: theme.typography.body.sm
              .copyWith(color: theme.colors.primary),
        );
      case _EntryStatus.done:
      case _EntryStatus.failed:
        // Inline editable: controller keeps the text in sync with state.
        return FTextField(
          control: FTextFieldControl.managed(
            controller: _textCtrlFor(e),
          ),
          size: .sm,
          minLines: 1,
          maxLines: 4,
        );
    }
  }

  Widget _statusIcon(_EntryStatus s, int id) {
    final colors = context.theme.colors;
    Widget icon;
    switch (s) {
      case _EntryStatus.pending:
        icon = FTooltip(
          key: const ValueKey('pending'),
          tipBuilder: (context, _) => const Text('Pending'),
          child: Semantics(
            label: 'Pending',
            child: Icon(FLucideIcons.circle, size: 16, color: colors.mutedForeground),
          ),
        );
      case _EntryStatus.translating:
        icon = FTooltip(
          key: const ValueKey('translating'),
          tipBuilder: (context, _) => const Text('Translating'),
          child: Semantics(
            label: 'Translating',
            child: const SizedBox(
              width: 16,
              height: 16,
              child: FCircularProgress(size: .sm),
            ),
          ),
        );
      case _EntryStatus.done:
        icon = FBadge(
          key: const ValueKey('done'),
          variant: .secondary,
          child: Semantics(
            label: 'Translation complete',
            child: Icon(
              FLucideIcons.checkCircle,
              size: 16,
              color: colors.app.success,
            ),
          ),
        );
      case _EntryStatus.failed:
        icon = _translating
            ? FTooltip(
                key: const ValueKey('failed'),
                tipBuilder: (context, _) => const Text('Translation failed'),
                child: FBadge(
                  variant: .destructive,
                  child: Semantics(
                    label: 'Translation failed',
                    child: const Icon(FLucideIcons.alertCircle, size: 16),
                  ),
                ),
              )
            : FTooltip(
                key: const ValueKey('failed-retry'),
                tipBuilder: (context, _) =>
                    const Text('Translation failed — click to retry'),
                child: Semantics(
                  label: 'Translation failed, click to retry',
                  button: true,
                  child: FBadge(
                    variant: .destructive,
                    child: FButton(
                      variant: FButtonVariant.ghost,
                      size: FButtonSizeVariant.xs,
                      onPress: () => _retrySingleEntry(id),
                      child: const Icon(FLucideIcons.refreshCw, size: 14),
                    ),
                  ),
                ),
              );
    }
    return AnimatedSwitcher(
      duration: motionDuration(context),
      transitionBuilder: (child, animation) =>
          ScaleTransition(scale: animation, child: child),
      child: icon,
    );
  }
}
