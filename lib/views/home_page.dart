import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';


import '../main.dart' show motionDuration;
import '../models/active_document.dart';
import '../services/parsers/subtitle_parser_factory.dart';

const _supportedExtensions = <String>['srt', 'ass', 'ssa', 'vtt', 'sub'];

/// Home page: file picker, drag-drop, and OpenSubtitles search/download.
///
/// On load, sets [activeDocumentProvider] / [activeFileNameProvider]; the
/// AppShell watches those to surface the Editor sidebar item and swap pages.
class HomePage extends ConsumerStatefulWidget {
  final VoidCallback? onNavigateToSearch;

  const HomePage({super.key, this.onNavigateToSearch});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _dragging = false;
  bool _loading = false;
  String? _errorMessage;

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: _supportedExtensions,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final path = file.path;
    if (path == null) {
      _toast('Cannot read file: no path');
      return;
    }
    await _loadFile(path, file.name);
  }

  Future<void> _loadFile(String path, String name) async {
    setState(() { _loading = true; _errorMessage = null; });
    try {
      final parser = const SubtitleParserFactory().forFileName(name);
      final doc = await parser.parse(File(path).openRead());
      if (!mounted) return;
      ref.read(activeDocumentProvider.notifier).set(doc);
      ref.read(activeFileNameProvider.notifier).set(name);
    } on FormatException catch (e) {
      _toast('Unsupported or corrupted file: ${e.message}');
      setState(() => _errorMessage = 'Unsupported or corrupted file: ${e.message}');
    } catch (e) {
      _toast('Could not load file: $e');
      setState(() => _errorMessage = 'Could not load file: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onDrop(DropDoneDetails detail) async {
    setState(() => _dragging = false);
    if (detail.files.length != 1) {
      _toast('Drop exactly one subtitle file');
      setState(() => _errorMessage = 'Drop exactly one subtitle file');
      return;
    }
    final path = detail.files.single.path;
    final name = path.split(RegExp(r'[/\\]')).last;
    final dot = name.lastIndexOf('.');
    final ext = dot >= 0 ? name.substring(dot + 1).toLowerCase() : '';
    if (!_supportedExtensions.contains(ext)) {
      _toast('Unsupported file type: .$ext');
      setState(() => _errorMessage = 'Unsupported file type: .$ext');
      return;
    }
    await _loadFile(path, name);
  }

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
    final theme = context.theme;
    return FScaffold(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Focus(
          autofocus: true,
          child: CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.keyO, control: true): _pickFile,
            },
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Subtitle Translator',
                    style: context.theme.typography.display.xl2,
                  ),
                ),
                Expanded(
                  child: DropTarget(
                    onDragEntered: (_) => setState(() => _dragging = true),
                    onDragExited: (_) => setState(() => _dragging = false),
                    onDragDone: _onDrop,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 400),
                            child: FCard(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 40,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  spacing: 20,
                                  children: [
                                    ExcludeSemantics(
                                        child: Center(
                                        child: SizedBox(
                                          width: 72,
                                          height: 72,
                                          child: DecoratedBox(
                                            decoration: ShapeDecoration(
                                              color: theme.colors.primary.withValues(alpha: 0.1),
                                              shape: RoundedSuperellipseBorder(
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                            ),
                                            child: Icon(
                                              FLucideIcons.subtitles,
                                              size: 36,
                                              color: theme.colors.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      'AI-powered subtitle translation with smart line-length control.',
                                      style: theme.typography.body.sm.copyWith(
                                        color: theme.colors.mutedForeground,
                                        height: 1.5,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    // Feature highlights — orient first-time users.
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      child: Wrap(
                                        alignment: WrapAlignment.center,
                                        spacing: 12,
                                        runSpacing: 6,
                                        children: [
                                          _FeatureChip(
                                            icon: FLucideIcons.subtitles,
                                            label: 'SRT, ASS, VTT, SUB',
                                          ),
                                          _FeatureChip(
                                            icon: FLucideIcons.wrapText,
                                            label: 'Auto CPL overflow',
                                          ),
                                          _FeatureChip(
                                            icon: FLucideIcons.languages,
                                            label: '60+ languages',
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Semantics(
                                      label: 'Open subtitle file from disk',
                                      button: true,
                                      child: FTooltip(
                                        tipBuilder: (context, _) =>
                                            const Text('Ctrl+O'),
                                        child: FButton(
                                          onPress: _loading ? null : _pickFile,
                                          suffix: const Icon(FLucideIcons.folderOpen),
                                          child: const Text('Open File'),
                                        ),
                                      ),
                                    ),
                                    Semantics(
                                      label: 'Search subtitles online',
                                      button: true,
                                      child: FButton(
                                        variant: FButtonVariant.outline,
                                        onPress: widget.onNavigateToSearch,
                                        suffix: const Icon(FLucideIcons.search),
                                        child: const Text('Search Subtitles'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        AnimatedSwitcher(
                        duration: motionDuration(context),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeOut,
                        child: _dragging
                            ? IgnorePointer(
                                key: const ValueKey('drag-overlay'),
                                child: DecoratedBox(
                                   decoration: ShapeDecoration(
                                     color: theme.colors.primary.withValues(alpha: 0.08),
                                     shape: RoundedSuperellipseBorder(
                                       side: BorderSide(
                                         color: theme.colors.primary,
                                         width: theme.style.borderWidth,
                                         strokeAlign: BorderSide.strokeAlignOutside,
                                       ),
                                       borderRadius: theme.style.borderRadius.lg,
                                     ),
                                   ),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      spacing: 16,
                                      children: [
                                        SizedBox(
                                          width: 72,
                                          height: 72,
                                          child: DecoratedBox(
                                            decoration: ShapeDecoration(
                                              color: theme.colors.primary.withValues(alpha: 0.15),
                                              shape: RoundedSuperellipseBorder(
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                            ),
                                            child: Icon(
                                              FLucideIcons.fileDown,
                                              size: 36,
                                              color: theme.colors.primary,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          'Drop subtitle file to load',
                                          style: theme.typography.display.sm.copyWith(
                                            color: theme.colors.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(key: ValueKey('drag-empty')),
                      ),
                      // ponytail: FAlert replaces raw Container + BoxDecoration
                      // error banner with ForUI's semantic alert component.
                      if (_errorMessage != null)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: AnimatedSize(
                            duration: motionDuration(context),
                            child: FAlert(
                              variant: .destructive,
                              icon: const Icon(FLucideIcons.alertCircle),
                              title: Text(_errorMessage!),
                            ),
                          ),
                        ),
                      if (_loading)
                        const Center(child: FCircularProgress()),
                    ],
                  ),
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small labeled feature badge for the home page empty state.
class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: theme.colors.mutedForeground),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.typography.body.xs2.copyWith(
            color: theme.colors.mutedForeground,
          ),
        ),
      ],
    );
  }
}
