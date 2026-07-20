import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../models/active_document.dart';
import '../models/language.dart';
import '../services/providers/opensubtitles_info.dart';
import '../services/parsers/subtitle_parser_factory.dart';
import '../services/providers/subtitle_provider.dart';
import '../services/providers/subtitle_provider_registry.dart';
import '../services/settings_service.dart';

/// Dedicated page for searching and downloading subtitles from multiple providers.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _queryController = TextEditingController();
  final _opensubtitlesInfo = OpenSubtitlesInfo();
  String _language = 'en';
  SubtitleProviderType _selectedProvider = SubtitleProviderType.openSubtitles;
  bool _featureSearchMode = false;
  bool _searching = false;
  bool _downloading = false;
  List<SubtitleSearchResult> _results = const [];
  List<OpenSubtitlesFeature> _featureResults = const [];
  List<(String, String)> _languages = kLanguages;
  String? _errorMessage;
  int _page = 1;
  int _totalPages = 1;

  SubtitleProvider get _provider =>
      SubtitleProviderRegistry.getProvider(_selectedProvider)!;

  @override
  void initState() {
    super.initState();
    _fetchLanguages();
  }

  Future<void> _fetchLanguages() async {
    if (_selectedProvider != SubtitleProviderType.openSubtitles) return;
    try {
      final apiLangs = await _opensubtitlesInfo.getLanguages();
      if (apiLangs.isEmpty || !mounted) return;
      final merged = <String, String>{
        for (final (code, name) in kLanguages) code: name,
        for (final l in apiLangs)
          if (l.code.isNotEmpty && l.name.isNotEmpty) l.code: l.name,
      };
      setState(() {
        _languages = merged.entries.map((e) => (e.key, e.value)).toList();
      });
    } catch (_) {
      // Fall back to kLanguages — already set as default
    }
  }

  Future<void> _search() async {
    final q = _queryController.text.trim();
    if (q.isEmpty) {
      _toast('Enter a search query');
      return;
    }
    setState(() {
      _searching = true;
      _results = const [];
      _featureResults = const [];
      _errorMessage = null;
      _page = 1;
    });
    try {
      if (_featureSearchMode &&
          _selectedProvider == SubtitleProviderType.openSubtitles) {
        final features = await _opensubtitlesInfo.searchFeatures(q);
        if (!mounted) return;
        setState(() => _featureResults = features);
        if (features.isEmpty) _toast('No features found');
      } else {
        final (results, totalPages) = await _provider.search(q, _language);
        if (!mounted) return;
        setState(() {
          _results = results;
          _totalPages = totalPages;
        });
        if (results.isEmpty) _toast('No results');
      }
    } on TimeoutException {
      _toast('Search timed out');
    } catch (e) {
      setState(() => _errorMessage = 'Could not search subtitles. Check your API credentials in Settings.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _onFeatureSelected(OpenSubtitlesFeature feature) async {
    setState(() {
      _searching = true;
      _results = const [];
      _featureResults = const [];
      _errorMessage = null;
      _page = 1;
    });
    try {
      final (results, totalPages) =
          await _provider.search(feature.title, _language);
      if (!mounted) return;
      setState(() {
        _results = results;
        _totalPages = totalPages;
      });
      if (results.isEmpty) _toast('No subtitles found for ${feature.title}');
    } on TimeoutException {
      _toast('Search timed out');
    } catch (e) {
      setState(() => _errorMessage = 'Could not search subtitles. Check your API credentials in Settings.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _downloadToDisk(SubtitleSearchResult result) async {
    setState(() => _downloading = true);
    try {
      final Uint8List bytes;
      try {
        bytes = await _provider.download(result);
      } catch (e) {
        _toast('Download failed: $e');
        return;
      }
      if (bytes.isEmpty) {
        _toast('Downloaded file is empty');
        return;
      }

      final ext = _extractExtension(result);
      final fileName = '${result.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')}.$ext';

      // Check if "always ask" is enabled
      final settingsSvc = await ref.read(settingsServiceProvider.future);
      final alwaysAsk = await settingsSvc.getAlwaysAskLocation();

      String saveDir;
      if (alwaysAsk) {
        final picked = await FilePicker.getDirectoryPath(
          dialogTitle: 'Select Download Location',
        );
        if (picked == null) {
          _toast('Download cancelled');
          return;
        }
        saveDir = picked;
      } else {
        saveDir = await _getDownloadsDir();
      }

      final file = File('$saveDir/$fileName');
      await file.writeAsBytes(bytes);
      _toast('Saved: $fileName');
    } on TimeoutException {
      _toast('Download timed out');
    } catch (e) {
      _toast('Could not download subtitle: $e');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<String> _getDownloadsDir() async {
    final settingsSvc = await ref.read(settingsServiceProvider.future);
    final custom = await settingsSvc.getDownloadLocation();
    if (custom.isNotEmpty) return custom;
    final home = Platform.environment['USERPROFILE'] ?? '';
    final dir = Directory('$home\\Downloads');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  Future<void> _translate(SubtitleSearchResult result) async {
    setState(() => _downloading = true);
    try {
      final Uint8List bytes;
      try {
        bytes = await _provider.download(result);
      } catch (e) {
        _toast('Download failed: $e');
        return;
      }
      if (bytes.isEmpty) {
        _toast('Downloaded file is empty');
        return;
      }
      final ext = _extractExtension(result);
      final parser = const SubtitleParserFactory().forExtension(ext);
      final doc = await parser.parse(Stream<List<int>>.value(bytes));
      if (!mounted) return;
      final displayName = '${result.title}.$ext';
      ref.read(activeDocumentProvider.notifier).set(doc);
      ref.read(activeFileNameProvider.notifier).set(displayName);
      _toast('Loaded: $displayName');
    } on FormatException catch (e) {
      _toast('Cannot parse downloaded file: ${e.message}');
    } on TimeoutException {
      _toast('Download timed out');
    } catch (e) {
      _toast('Could not download subtitle: $e');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  String _extractExtension(SubtitleSearchResult result) {
    // Try format field first
    if (result.format != null && result.format!.isNotEmpty) {
      return result.format!;
    }
    // Try to extract from title (e.g. "Movie.2024.1080p.BluRay.srt")
    final dotIndex = result.title.lastIndexOf('.');
    if (dotIndex >= 0) {
      final ext = result.title.substring(dotIndex + 1).toLowerCase();
      if (['srt', 'ass', 'ssa', 'vtt', 'sub'].contains(ext)) return ext;
    }
    return 'srt'; // default
  }

  void _toast(String message) {
    if (!mounted) return;
    showFToast(
      context: context,
      title: Text(message),
      alignment: FToastAlignment.bottomCenter,
    );
  }

  Future<void> _gotoPage(int page) async {
    if (_searching || page < 1 || page > _totalPages || page == _page) return;
    setState(() {
      _page = page;
      _searching = true;
    });
    try {
      final q = _queryController.text.trim();
      final (results, totalPages) = await _provider.search(q, _language, page: page);
      if (!mounted) return;
      setState(() {
        _results = results;
        _totalPages = totalPages;
      });
    } on TimeoutException {
      _toast('Search timed out');
    } catch (e) {
      _toast('Page load failed: $e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return FScaffold(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Search Subtitles',
                style: context.theme.typography.display.xl2,
              ),
            ),
            // Search bar with provider selector
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Provider selector
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            'Provider',
                            style: theme.typography.body.xs.copyWith(
                              color: theme.colors.mutedForeground,
                              height: 1.5,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 140,
                          child: FSelect<String>(
                            items: {
                              for (final type in SubtitleProviderType.values)
                                _providerDisplayName(type): type.name,
                            },
                            control: FSelectControl.lifted(
                              value: _selectedProvider.name,
                              onChange: (s) {
                                  if (s != null) {
                                    final type = SubtitleProviderType.values
                                        .byName(s);
                                    setState(() {
                                      _selectedProvider = type;
                                      if (type !=
                                          SubtitleProviderType.openSubtitles) {
                                        _featureSearchMode = false;
                                        _featureResults = const [];
                                      }
                                    });
                                  }
                                },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    // Query input
                    Expanded(
                      flex: 3,
                      child: FTextField(
                        control: FTextFieldControl.managed(
                            controller: _queryController),
                        hint: 'Movie or show title',
                        onSubmit: (_) => _search(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Language selector
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            'Language',
                            style: theme.typography.body.xs.copyWith(
                              color: theme.colors.mutedForeground,
                              height: 1.5,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 160,
                          child: FSelect<String>(
                            items: {
                              for (final (code, label) in _languages)
                                label: code,
                            },
                            control: FSelectControl.lifted(
                              value: _language,
                              onChange: (s) {
                                if (s != null) setState(() => _language = s);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    FButton(
                      onPress: _searching ? null : _search,
                      suffix: _searching
                          ? const FCircularProgress(size: .sm)
                          : const Icon(FLucideIcons.search),
                      child: const Text('Search'),
                    ),
                  ],
                ),
                // Auth hint
                if (_provider.requiresAuth)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Requires API credentials — configure in Settings',
                      style: theme.typography.body.xs.copyWith(
                        color: theme.colors.mutedForeground,
                        height: 1.4,
                      ),
                    ),
                  ),
                // Feature search toggle (OpenSubtitles only)
                if (_selectedProvider ==
                    SubtitleProviderType.openSubtitles)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Text(
                          'Feature',
                          style: theme.typography.body.sm.copyWith(
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FSwitch(
                          value: _featureSearchMode,
                          onChange: (v) => setState(() {
                            _featureSearchMode = v;
                            _featureResults = const [];
                          }),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Search movies/TV first',
                          style: theme.typography.body.xs.copyWith(
                            color: theme.colors.mutedForeground,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            // Error
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FAlert(
                  variant: .destructive,
                  icon: const Icon(FLucideIcons.alertCircle),
                  title: Text(_errorMessage!),
                ),
              ),
            // Results + pagination
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: _featureResults.isNotEmpty
                        ? FTileGroup(
                            children: [
                              for (final f in _featureResults)
                                FTile(
                                  title: Text(f.displayLabel),
                                  subtitle: Text(
                                    [if (f.imdbId != null) 'IMDB: ${f.imdbId}']
                                        .join(' • '),
                                  ),
                                  onPress: _searching
                                      ? null
                                      : () => _onFeatureSelected(f),
                                  suffix: _searching
                                      ? const FCircularProgress(size: .sm)
                                      : const Icon(FLucideIcons.chevronRight),
                                ),
                            ],
                          )
                        : _results.isEmpty && !_searching
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  spacing: 12,
                                  children: [
                                    Icon(
                                      _queryController.text.isEmpty
                                          ? FLucideIcons.search
                                          : FLucideIcons.searchX,
                                      size: 48,
                                      color: theme.colors.mutedForeground,
                                    ),
                                    Text(
                                      _queryController.text.isEmpty
                                          ? 'Search ${_provider.name} for ${_featureSearchMode ? 'movies and shows' : 'subtitle files'}'
                                          : 'No results found',
                                      style: theme.typography.body.sm.copyWith(
                                        color: theme.colors.mutedForeground,
                                        height: 1.5,
                                      ),
                                    ),
                                    if (_queryController.text.isNotEmpty)
                                      Text(
                                        'Try a different search term or language',
                                        style: theme.typography.body.xs.copyWith(
                                          color: theme.colors.mutedForeground,
                                          height: 1.5,
                                        ),
                                      ),
                                  ],
                                ),
                              )
                            : FTileGroup(
                                children: [
                                  for (final r in _results)
                                    FTile(
                                      title: Text(r.title),
                                      subtitle: Text(
                                        '${r.language} • ${r.providerName}',
                                      ),
                                      details: r.rating != null
                                          ? Text(
                                              '★ ${r.rating!.toStringAsFixed(1)}')
                                          : null,
                                      suffix: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          FTooltip(
                                            tipBuilder: (context, _) =>
                                                const Text('Download & Translate'),
                                            child: FButton(
                                              variant: FButtonVariant.outline,
                                              onPress: _downloading
                                                  ? null
                                                  : () => _translate(r),
                                              suffix: _downloading
                                                  ? const FCircularProgress(
                                                      size: .sm)
                                                  : const Icon(
                                                      FLucideIcons.languages,
                                                      size: 14,
                                                    ),
                                              child: const Text('Translate'),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          FTooltip(
                                            tipBuilder: (context, _) =>
                                                const Text('Download only'),
                                            child: FButton(
                                              onPress: _downloading
                                                  ? null
                                                  : () => _downloadToDisk(r),
                                              suffix: _downloading
                                                  ? const FCircularProgress(
                                                      size: .sm)
                                                  : const Icon(
                                                      FLucideIcons.download,
                                                      size: 14,
                                                    ),
                                              child: const Text('Download'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                  ),
                  // Pagination — only when there are multiple pages of subtitle results
                  if (_results.isNotEmpty && _totalPages > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: FPagination(
                        control: .managed(
                          pages: _totalPages,
                          initial: _page - 1,
                          onChange: (i) => _gotoPage(i + 1),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _providerDisplayName(SubtitleProviderType type) {
  switch (type) {
    case SubtitleProviderType.openSubtitles:
      return 'OpenSubtitles';
    case SubtitleProviderType.subdl:
      return 'Subdl';
    case SubtitleProviderType.subSource:
      return 'SubSource';
  }
}
