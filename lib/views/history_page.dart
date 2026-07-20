import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../models/app_database.dart';
import '../models/language.dart';
import '../models/subtitle_document.dart';
import '../models/subtitle_entry.dart';
import '../models/subtitle_format.dart';
import '../services/app_database_provider.dart';
import '../services/history_service.dart';

/// History page: list of past translations with side-by-side preview.
///
/// Selecting an entry shows original vs translated content in a comparison
/// panel. "Open in Editor" loads the translated document into the Editor.
class HistoryPage extends ConsumerStatefulWidget {
  final void Function(SubtitleDocument doc, String fileName)? onOpenInEditor;

  const HistoryPage({super.key, this.onOpenInEditor});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  TranslationHistoryData? _selected;
  bool _clearing = false;
  bool _selecting = false;
  final Set<int> _selectedIds = {};
  final _searchController = TextEditingController();
  String _query = '';

  HistoryService _service(AppDatabase db) => HistoryService(db);

  String _languageLabel(String code) => languageName(code);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final q = _searchController.text.trim().toLowerCase();
      if (q != _query) setState(() => _query = q);
    });
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Future<void> _clearAll() async {
    final db = await ref.read(appDatabaseProvider.future);
    if (!mounted) return;
    final confirmed = await showFDialog<bool>(
      context: context,
      builder: (context, style, animation) => FDialog(
        style: style,
        animation: animation,
        constraints: const BoxConstraints(maxWidth: 400),
        builder: (context, style) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              Text('Clear History', style: style.titleTextStyle),
              Text(
                'This will delete all translation history. This cannot be undone.',
                style: style.bodyTextStyle,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                spacing: 8,
                children: [
                  FButton(
                    variant: FButtonVariant.outline,
                    size: FButtonSizeVariant.sm,
                    onPress: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FButton(
                    size: FButtonSizeVariant.sm,
                    onPress: () => Navigator.of(context).pop(true),
                    child: const Text('Clear All'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) return;
    setState(() => _clearing = true);
    await _service(db).clearAll();
    if (mounted) {
      setState(() {
        _clearing = false;
        _selected = null;
      });
    }
  }

  Future<void> _deleteEntry(int id) async {
    final db = await ref.read(appDatabaseProvider.future);
    await _service(db).delete(id);
    if (mounted && _selected?.id == id) {
      setState(() => _selected = null);
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await showFDialog<bool>(
      context: context,
      builder: (context, style, animation) => FDialog(
        style: style,
        animation: animation,
        constraints: const BoxConstraints(maxWidth: 400),
        builder: (context, style) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              Text('Delete ${_selectedIds.length} entries?',
                  style: style.titleTextStyle),
              Text(
                'This action cannot be undone.',
                style: style.bodyTextStyle,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                spacing: 8,
                children: [
                  FButton(
                    variant: FButtonVariant.outline,
                    size: FButtonSizeVariant.sm,
                    onPress: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FButton(
                    size: FButtonSizeVariant.sm,
                    onPress: () => Navigator.of(context).pop(true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) return;
    final db = await ref.read(appDatabaseProvider.future);
    for (final id in _selectedIds) {
      await _service(db).delete(id);
    }
    if (mounted) {
      setState(() {
        _selectedIds.clear();
        _selecting = false;
        if (_selected != null && _selectedIds.contains(_selected!.id)) {
          _selected = null;
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final dbAsync = ref.watch(appDatabaseProvider);

    return FScaffold(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: FHeader(title: const Text('Translation History')),
                ),
                SizedBox(
                  width: 200,
                  child: FTextField(
                    control: FTextFieldControl.managed(
                      controller: _searchController,
                    ),
                    hint: 'Search files...',
                  ),
                ),
                const SizedBox(width: 8),
                FButton(
                  variant: FButtonVariant.ghost,
                  size: FButtonSizeVariant.sm,
                  onPress: _selecting
                      ? () => setState(() {
                            _selecting = false;
                            _selectedIds.clear();
                          })
                      : () => setState(() => _selecting = true),
                  child: Text(_selecting ? 'Done' : 'Select'),
                ),
                if (_selecting && _selectedIds.isNotEmpty)
                  FButton(
                    variant: FButtonVariant.ghost,
                    size: FButtonSizeVariant.sm,
                    onPress: _deleteSelected,
                    suffix: const Icon(FLucideIcons.trash2, size: 16),
                    child: Text('Delete (${_selectedIds.length})'),
                  ),
                if (!_selecting)
                  FButton(
                    variant: FButtonVariant.ghost,
                    size: FButtonSizeVariant.sm,
                    onPress: _clearing ? null : _clearAll,
                    suffix: const Icon(FLucideIcons.trash2, size: 16),
                    child: const Text('Clear All'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: dbAsync.when(
                loading: () => const Center(child: FCircularProgress()),
                error: (e, _) => FAlert(
                  variant: .destructive,
                  icon: const Icon(FLucideIcons.alertCircle),
                  title: Text('Failed to load history: $e'),
                ),
                data: (db) => StreamBuilder<List<TranslationHistoryData>>(
                  stream: _service(db).watchAll(),
                  builder: (context, snapshot) {
                    final allEntries = snapshot.data ?? [];
                    final entries = _query.isEmpty
                        ? allEntries
                        : allEntries
                            .where((e) =>
                                e.fileName.toLowerCase().contains(_query))
                            .toList();
                    if (entries.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 8,
                          children: [
                            Icon(
                              _query.isEmpty ? FLucideIcons.clock : FLucideIcons.search,
                              size: 48,
                              color: theme.colors.mutedForeground,
                            ),
                            Text(
                              _query.isEmpty
                                  ? 'No translation history yet'
                                  : 'No results for "$_query"',
                              style: theme.typography.body.sm.copyWith(
                                color: theme.colors.mutedForeground,
                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return Row(
                      children: [
                        // List panel
                        SizedBox(
                          width: 320,
                          child: FTileGroup(
                            children: [
                              for (final entry in entries)
                                FTile(
                                  title: Text(
                                    entry.fileName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    '${_languageLabel(entry.sourceLanguage)} → ${_languageLabel(entry.targetLanguage)}  ·  ${_timeAgo(entry.createdAt)}',
                                  ),
                                  prefix: _selecting
                                      ? GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () => setState(() {
                                            if (_selectedIds
                                                .contains(entry.id)) {
                                              _selectedIds.remove(entry.id);
                                            } else {
                                              _selectedIds.add(entry.id);
                                            }
                                          }),
                                          child: Padding(
                                            padding: const EdgeInsets.all(4),
                                            child: Icon(
                                              _selectedIds.contains(entry.id)
                                                  ? FLucideIcons.checkSquare
                                                  : FLucideIcons.square,
                                              size: 16,
                                              color: _selectedIds
                                                      .contains(entry.id)
                                                  ? theme.colors.primary
                                                  : theme.colors
                                                      .mutedForeground,
                                            ),
                                          ),
                                        )
                                      : null,
                                  details: entry.status == 'done'
                                      ? Icon(FLucideIcons.check,
                                          size: 14, color: theme.colors.mutedForeground)
                                      : Icon(FLucideIcons.x,
                                          size: 14, color: theme.colors.error),
                                  selected: _selected?.id == entry.id,
                                  onPress: () =>
                                      setState(() => _selected = entry),
                                  suffix: FTooltip(
                                    tipBuilder: (context, _) =>
                                        const Text('Delete'),
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _deleteEntry(entry.id),
                                      child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Icon(
                                          FLucideIcons.trash2,
                                          size: 14,
                                          color:
                                              theme.colors.mutedForeground,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Divider
                        const FDivider(axis: Axis.vertical),
                        // Preview panel
                        Expanded(
                          child: _selected == null
                              ? Center(
                                  child: Text(
                                    'Select an entry to preview',
                                    style: theme.typography.body.sm.copyWith(
                                      color: theme.colors.mutedForeground,
                height: 1.5,
                                    ),
                                  ),
                                )
                              : _buildPreview(theme),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(FThemeData theme) {
    final entry = _selected!;
    return Column(
      children: [
        // Header
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.fileName,
                    style: theme.typography.display.sm,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_languageLabel(entry.sourceLanguage)} → ${_languageLabel(entry.targetLanguage)}  ·  ${_timeAgo(entry.createdAt)}',
                    style: theme.typography.body.xs.copyWith(
                      color: theme.colors.mutedForeground,
                height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            FButton(
              size: FButtonSizeVariant.sm,
              onPress: widget.onOpenInEditor != null
                  ? () => widget.onOpenInEditor!(
                      SubtitleDocument(
                        format: _guessFormat(entry.fileName),
                        entries: _parseSrt(entry.originalContent),
                      ),
                      entry.fileName,
                    )
                  : null,
              suffix: const Icon(FLucideIcons.externalLink, size: 14),
              child: const Text('Open in Editor'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Comparison
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _buildColumn(theme, 'Original', entry.originalContent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildColumn(
                    theme, 'Translated', entry.translatedContent),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildColumn(FThemeData theme, String label, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.typography.body.xs.copyWith(
            color: theme.colors.mutedForeground,
                height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: FCard(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                child: Text(
                  content,
                  style: theme.typography.body.sm,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Guess subtitle format from file extension.
  SubtitleFormat _guessFormat(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'ass':
      case 'ssa':
        return SubtitleFormat.ass;
      case 'vtt':
        return SubtitleFormat.vtt;
      case 'sub':
        return SubtitleFormat.sub;
      default:
        return SubtitleFormat.srt;
    }
  }

  /// Minimal synchronous SRT parser for history preview.
  ///
  /// ponytail: The real SrtParser (services/parsers/srt_parser.dart) is async
  /// and requires a `Stream<List<int>>`. This sync variant handles the basic
  /// cases needed for in-memory history preview. If edge cases arise (BOM,
  /// multi-line text), extract a sync variant from SrtParser instead of
  /// maintaining this separately.
  List<SubtitleEntry> _parseSrt(String content) {
    final lines = content.split('\n');
    final entries = <SubtitleEntry>[];
    int? id;
    String? timing;
    final textLines = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        if (id != null && timing != null) {
          final parts = timing.split(' --> ');
          if (parts.length == 2) {
            entries.add(SubtitleEntry(
              id: id,
              startMs: _parseTimestamp(parts[0].trim()),
              endMs: _parseTimestamp(parts[1].trim()),
              lines: textLines.isNotEmpty ? List.of(textLines) : [''],
            ));
          }
        }
        id = null;
        timing = null;
        textLines.clear();
        continue;
      }
      if (id == null) {
        final parsed = int.tryParse(trimmed);
        if (parsed != null) id = parsed;
      } else if (timing == null) {
        timing = trimmed;
      } else {
        textLines.add(trimmed);
      }
    }
    // Last entry
    if (id != null && timing != null) {
      final parts = timing.split(' --> ');
      if (parts.length == 2) {
        entries.add(SubtitleEntry(
          id: id,
          startMs: _parseTimestamp(parts[0].trim()),
          endMs: _parseTimestamp(parts[1].trim()),
          lines: textLines.isNotEmpty ? List.of(textLines) : [''],
        ));
      }
    }
    return entries;
  }

  int _parseTimestamp(String ts) {
    // HH:MM:SS,mmm or HH:MM:SS.mmm
    final parts = ts.replaceAll(',', '.').split(':');
    if (parts.length != 3) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final secParts = parts[2].split('.');
    final s = int.tryParse(secParts[0]) ?? 0;
    final ms = secParts.length > 1 ? int.tryParse(secParts[1]) ?? 0 : 0;
    return h * 3600000 + m * 60000 + s * 1000 + ms;
  }
}
