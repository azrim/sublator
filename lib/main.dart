import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'theme/theme.dart';

import 'models/active_document.dart';
import 'services/app_database_provider.dart';
import 'services/settings_service.dart';
import 'views/home_page.dart';
import 'views/history_page.dart';
import 'views/preview_page.dart';
import 'views/search_page.dart';
import 'views/settings_page.dart';
import 'widgets/desktop_title_bar.dart';

/// Top-level flag for tracking unsaved changes in the preview page.
/// ponytail: ValueNotifier over Riverpod provider — simpler, no deprecated API.
final hasUnsavedChangesNotifier = ValueNotifier<bool>(false);

/// Default window configuration. Top-level so tests can assert the values
/// without invoking [main]'s platform-channel side effects.
const defaultWindowOptions = WindowOptions(
  size: Size(1200, 800),
  minimumSize: Size(800, 600),
  center: true,
  titleBarStyle: TitleBarStyle.hidden,
);

/// Returns zero duration when the platform requests reduced motion.
///
/// Used by AnimatedSwitcher/AnimatedContainer/AnimatedSize across views to
/// respect `MediaQuery.disableAnimationsOf`. Import main.dart to use.
/// ponytail: No ForUI theme token for reduced-motion — keep platform check.
Duration motionDuration(
  BuildContext context, {
  Duration fallback = const Duration(milliseconds: 200),
}) {
  return MediaQuery.disableAnimationsOf(context) ? Duration.zero : fallback;
}

/// Sublator entry point.
///
/// Window lifecycle:
///   1. ensureInitialized on WindowManager
///   2. apply [defaultWindowOptions] (size 1200x800, min 800x600, hidden title bar)
///   3. waitUntilReadyToShow -> show + focus after first frame
///   4. AppShell restores last-saved position from Drift on init
///   5. on close: AppShell persists the current geometry back to Drift
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  await windowManager.waitUntilReadyToShow(defaultWindowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const ProviderScope(child: SublatorApp()));
}

/// Top-level app widget. Mounts the ForUI desktop theme + toaster + shell.
class SublatorApp extends ConsumerWidget {
  const SublatorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Subtitle Translator',
      debugShowCheckedModeBanner: false,
      // ponytail: FLocalizations delegates enable ForUI's built-in i18n.
      // Without them, ForUI widgets may fall back to raw keys instead of
      // translated strings. supportedLocales covers all 115 languages.
      localizationsDelegates: FLocalizations.localizationsDelegates,
      supportedLocales: FLocalizations.supportedLocales,
      builder: (context, child) {
        final brightness = MediaQuery.platformBrightnessOf(context);
        final themeData = brightness == Brightness.dark ? darkTheme : lightTheme;
        return FTheme(
          data: themeData,
          child: FToaster(child: FTooltipGroup(child: child!)),
        );
      },
      home: const AppShell(),
    );
  }
}

/// Root shell: ForUI sidebar swapping Home/Editor/Settings, with a custom
/// desktop title bar on top.
///
/// Owns window-close persistence: a [WindowListener] intercepts close,
/// writes the current geometry to Drift, then destroys the window.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WindowListener, TickerProviderStateMixin {
  int _index = 0;
  bool _navigatedToEditor = false;
  late final AnimationController _pageAnimCtrl;

  @override
  void initState() {
    super.initState();
    _pageAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    windowManager.addListener(this);
    windowManager.setPreventClose(true);
    _restoreWindowState();
  }

  Future<void> _restoreWindowState() async {
    try {
      final db = await ref.read(appDatabaseProvider.future);
      final settings = SettingsService(db);
      final (offset, size) = await settings.getWindowState();
      // Only restore non-zero positions; first run keeps the centered default.
      if (offset != Offset.zero) {
        await windowManager.setPosition(offset);
      }
      await windowManager.setSize(size);
    } catch (e) {
      // Window state restore failed — use defaults. Only notify if the error
      // is something other than the database not being ready.
      debugPrint('Window state restore failed: $e');
    }
  }

  @override
  void dispose() {
    _pageAnimCtrl.dispose();
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    if (hasUnsavedChangesNotifier.value) {
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
                Text('Unsaved Changes', style: style.titleTextStyle),
                Text(
                  'You have unsaved translations. Discard them?',
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
                      child: const Text('Discard'),
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
    final db = await ref.read(appDatabaseProvider.future);
    final settings = SettingsService(db);
    final pos = await windowManager.getPosition();
    final size = await windowManager.getSize();
    await settings.setWindowState(pos, size);
    await windowManager.destroy();
  }

  Widget _buildSidebar() {
    final document = ref.watch(activeDocumentProvider);
    final activeFileName = ref.watch(activeFileNameProvider);
    final theme = context.theme;

    return FSidebar(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Text(
          'Sublator',
          style: context.theme.typography.display.sm.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      children: [
        FSidebarGroup(
          children: [
            FSidebarItem(
              key: ValueKey('home-${document != null}'),
              icon: const Icon(FLucideIcons.house, size: 18),
              label: const Text('Home'),
              selected: _index == 0 && document == null,
              onPress: () => setState(() => _index = 0),
              initiallyExpanded: document != null,
              children: [
                if (document != null)
                  FSidebarItem(
                    icon: const Icon(FLucideIcons.fileText, size: 18),
                    label: Row(
                      children: [
                        Expanded(
                          child: Text(
                            activeFileName.isNotEmpty ? activeFileName : 'Editor',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // ponytail: Close button to dismiss the loaded file
                        // and return to the Home page. Uses FTooltip for
                        // discoverability on hover.
                        FTooltip(
                          tipBuilder: (context, _) => const Text('Close file'),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _closeEditor,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(
                                FLucideIcons.x,
                                size: 14,
                                color: theme.colors.mutedForeground,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    selected: _index == 1,
                    onPress: () => setState(() => _index = 1),
                  ),
              ],
            ),
            FSidebarItem(
              icon: const Icon(FLucideIcons.search, size: 18),
              label: const Text('Search'),
              selected: _index == 2,
              onPress: () => setState(() => _index = 2),
            ),
            FSidebarItem(
              icon: const Icon(FLucideIcons.clock, size: 18),
              label: const Text('History'),
              selected: _index == 3,
              onPress: () => setState(() => _index = 3),
            ),
            FSidebarItem(
              icon: const Icon(FLucideIcons.settings, size: 18),
              label: const Text('Settings'),
              selected: _index == 4,
              onPress: () => setState(() => _index = 4),
            ),
          ],
        ),
      ],
    );
  }

  /// Closes the current editor and returns to Home.
  /// Prompts if there are unsaved changes.
  Future<void> _closeEditor() async {
    if (hasUnsavedChangesNotifier.value) {
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
                Text('Unsaved Changes', style: style.titleTextStyle),
                Text(
                  'You have unsaved translations. Discard them?',
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
                      child: const Text('Discard'),
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
    if (!mounted) return;
    ref.read(activeDocumentProvider.notifier).set(null);
    ref.read(activeFileNameProvider.notifier).set('');
    hasUnsavedChangesNotifier.value = false;
    setState(() => _index = 0);
  }

  Widget _buildPageTransition(Widget child) {
    return AnimatedSwitcher(
      duration: motionDuration(context),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeOut,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: KeyedSubtree(
        key: ValueKey(_index),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final document = ref.watch(activeDocumentProvider);

    // Auto-navigate to Editor when a document is loaded (once per load).
    if (document != null && !_navigatedToEditor) {
      _navigatedToEditor = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _index = 1);
      });
    }
    if (document == null) _navigatedToEditor = false;

    return Column(
      children: [
        const DesktopTitleBar(),
        Expanded(
          child: FResizable(
            axis: .horizontal,
            divider: .divider,
            children: [
              FResizableRegion.fixed(
                extent: 200,
                minExtent: 150,
                builder: (_, data, _) => _buildSidebar(),
              ),
              FResizableRegion.flex(
                builder: (_, data, _) {
                  return _buildPageTransition(
                    IndexedStack(
                      index: _index,
                      children: [
                        HomePage(
                          key: const ValueKey('home'),
                          onNavigateToSearch: () => setState(() => _index = 2),
                        ),
                        document != null
                            ? PreviewPage(
                                key: const ValueKey('preview'),
                                document: document,
                              )
                            : const SizedBox.shrink(key: ValueKey('preview-empty')),
                        const SearchPage(key: ValueKey('search')),
                        HistoryPage(
                          key: const ValueKey('history'),
                          onOpenInEditor: (doc, fileName) {
                            ref.read(activeDocumentProvider.notifier).set(doc);
                            ref.read(activeFileNameProvider.notifier).set(fileName);
                            setState(() => _index = 1);
                          },
                        ),
                        const SettingsPage(key: ValueKey('settings')),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
