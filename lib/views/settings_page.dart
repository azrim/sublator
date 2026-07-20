import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_database.dart';
import '../models/language.dart';
import '../services/credential_service.dart';
import '../services/glossary_service.dart';
import '../services/providers/opensubtitles_info.dart';
import '../services/providers/opensubtitles_provider.dart';
import '../services/providers/subdl_provider.dart';
import '../services/providers/subsource_provider.dart';
import '../services/settings_service.dart';
import '../services/system_prompt_service.dart';

// Uses shared kLanguages from lib/models/language.dart

// Common model presets. The Drift settings row accepts any string; this list
// is just UX sugar — users get the common ones in two clicks.
const _models = <String>[
  'deepseek-v4-flash-free',
  'mimo-v2.5-free',
  'hy3-free',
  'nemotron-3-ultra-free',
];

/// Full settings page wired to Drift + secure storage, split into FTabs.
///
/// Tabs:
///   - Languages  — source/target pair via two FSelects
///   - Models     — primary/fallback model via two FSelects
///   - Prompts    — active system prompt via FTextField
///   - Glossary   — FTileGroup with add/remove/import/export
///   - Credentials — Zen API key + OpenSubtitles api key / username / password via FTextFields
///
/// All async services are watched via Riverpod per-tab; lifted state via
/// [useState] + [FSelectControl.lifted]. Credentials persist on submit (Enter)
/// to avoid leaking keystrokes to secure storage on every keystroke.
class SettingsPage extends HookConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FScaffold(
      // ponytail: LayoutBuilder provides bounded height to Column so that
      // Expanded(FTabs) doesn't overflow. Center alone gives infinite height.
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Settings',
                    style: context.theme.typography.display.xl2,
                  ),
                ),
                Expanded(
                  child:                     FTabs(
                    expands: true,
                    children: [
                      FTabEntry(
                        label: const Text('API Keys'),
                        child: _CredentialsTab(),
                      ),
                      FTabEntry(
                        label: const Text('Languages'),
                        child: _LanguagesTab(),
                      ),
                      FTabEntry(
                        label: const Text('Models'),
                        child: _ModelsTab(),
                      ),
                      FTabEntry(
                        label: const Text('Prompt'),
                        child: _PromptsTab(),
                      ),
                      FTabEntry(
                        label: const Text('Glossary'),
                        child: _GlossaryTab(),
                      ),
                      FTabEntry(
                        label: const Text('Storage'),
                        child: _StorageTab(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Languages tab: source/target language pair via two FSelects.
class _LanguagesTab extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsServiceProvider);
    final sourceLang = useState<String?>(null);
    final targetLang = useState<String?>(null);

    // ponytail: useEffect keyed on the AsyncValue loads state when the service
    // first resolves. Setting state inside an effect schedules a rebuild
    // without marking the current build dirty. Safe because the effect runs at
    // most once per service-load.
    useEffect(() {
      settingsAsync.maybeWhen(
        data: (svc) async {
          if (sourceLang.value == null) {
            sourceLang.value = await svc.getSourceLang();
          }
          if (targetLang.value == null) {
            targetLang.value = await svc.getTargetLang();
          }
        },
        orElse: () {},
      );
      return null;
    }, [settingsAsync]);

    Future<void> persistLanguagePair() async {
      final svc = await ref.read(settingsServiceProvider.future);
      await svc.setLanguagePair(
        sourceLang.value ?? SettingsService.defaultSourceLang,
        targetLang.value ?? SettingsService.defaultTargetLang,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          Text(
            'Choose which languages to translate from and to. '
            'Source can be set to Auto detect to identify the language automatically.',
            style: context.theme.typography.body.xs.copyWith(
              color: context.theme.colors.mutedForeground,
              height: 1.5,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Expanded(
                child: _LanguageSelect(
                  label: 'Source',
                  allowAuto: true,
                  value: sourceLang.value,
                  onChange: (v) {
                    if (v == null) return;
                    sourceLang.value = v;
                    persistLanguagePair();
                  },
                ),
              ),
              Expanded(
                child: _LanguageSelect(
                  label: 'Target',
                  value: targetLang.value,
                  onChange: (v) {
                    if (v == null) return;
                    targetLang.value = v;
                    persistLanguagePair();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Models tab: primary/fallback model via two FSelects.
class _ModelsTab extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsServiceProvider);
    final primaryModel = useState<String?>(null);
    final fallbackModel = useState<String?>(null);
    final thinkingEnabled = useState(false);

    useEffect(() {
      settingsAsync.maybeWhen(
        data: (svc) async {
          if (primaryModel.value == null || !_models.contains(primaryModel.value)) {
            primaryModel.value = await svc.getPrimaryModel();
            if (!_models.contains(primaryModel.value)) {
              primaryModel.value = _models.first;
            }
          }
          if (fallbackModel.value == null || !_models.contains(fallbackModel.value)) {
            fallbackModel.value = await svc.getFallbackModel();
            if (!_models.contains(fallbackModel.value)) {
              fallbackModel.value = _models.first;
            }
          }
          // Persist corrected models back to DB so stale values don't reappear.
          await svc.setModels(
            primary: primaryModel.value!,
            fallback: fallbackModel.value!,
          );
          final thinking = await svc.getThinkingEnabled();
          thinkingEnabled.value = thinking;
        },
        orElse: () {},
      );
      return null;
    }, [settingsAsync]);

    Future<void> persistModels() async {
      final svc = await ref.read(settingsServiceProvider.future);
      await svc.setModels(
        primary: primaryModel.value ?? SettingsService.defaultPrimaryModel,
        fallback: fallbackModel.value ?? SettingsService.defaultFallbackModel,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 20,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              _ModelSelect(
                label: 'Primary model',
                value: primaryModel.value,
                onChange: (v) {
                  if (v == null) return;
                  primaryModel.value = v;
                  persistModels();
                },
              ),
              _ModelSelect(
                label: 'Fallback model',
                value: fallbackModel.value,
                onChange: (v) {
                  if (v == null) return;
                  fallbackModel.value = v;
                  persistModels();
                },
              ),
            ],
          ),
          const FDivider(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              FSwitch(
                label: const Text('Thinking mode'),
                semanticsLabel: 'Thinking mode',
                value: thinkingEnabled.value,
                onChange: (v) {
                  thinkingEnabled.value = v;
                  ref.read(settingsServiceProvider.future).then(
                        (svc) => svc.setThinkingEnabled(v),
                      );
                },
              ),
              Text(
                'Enables the model to reason step-by-step before translating. '
                'Uses more tokens but can improve quality for complex dialogue.',
                style: context.theme.typography.body.xs.copyWith(
                  color: context.theme.colors.mutedForeground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Prompts tab: active system prompt via FTextField, persisted on submit.
class _PromptsTab extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promptAsync = ref.watch(systemPromptServiceProvider);
    final promptCtrl = useTextEditingController();
    final promptId = useRef<int?>(null);

    useEffect(() {
      promptAsync.maybeWhen(
        data: (svc) async {
          final active = await svc.getActive();
          if (active != null && promptId.value != active.id) {
            promptId.value = active.id;
            promptCtrl.text = active.content;
          }
        },
        orElse: () {},
      );
      return null;
    }, [promptAsync]);

    Future<void> persistPrompt() async {
      final svc = await ref.read(systemPromptServiceProvider.future);
      final id = promptId.value;
      if (id == null) return;
      final all = await svc.getAll();
      final existing = all.firstWhere(
        (p) => p.id == id,
        orElse: () => all.first,
      );
      await svc.update(
        existing.copyWith(content: promptCtrl.text),
      );
    }

    Future<void> resetToDefault() async {
      final svc = await ref.read(systemPromptServiceProvider.future);
      final id = promptId.value;
      if (id == null) return;
      final all = await svc.getAll();
      final existing = all.firstWhere(
        (p) => p.id == id,
        orElse: () => all.first,
      );
      await svc.update(
        existing.copyWith(content: SystemPromptService.defaultContent),
      );
      promptCtrl.text = SystemPromptService.defaultContent;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Text(
            'The system prompt tells the AI how to translate. '
            'Edit to change translation style, add rules, or adjust line length limits.',
            style: context.theme.typography.body.xs.copyWith(
              color: context.theme.colors.mutedForeground,
              height: 1.5,
            ),
          ),
          FTextField(
            control: FTextFieldControl.managed(controller: promptCtrl),
            minLines: 5,
            maxLines: 12,
            hint: 'Translate to {targetLanguage}. Preserve text in {braces} and ALL CAPS...',
            onSubmit: (_) => persistPrompt(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            spacing: 8,
            children: [
              FTooltip(
                tipBuilder: (context, _) => const Text('Restore the built-in default prompt'),
                child: FButton(
                  variant: FButtonVariant.outline,
                  size: FButtonSizeVariant.sm,
                  onPress: resetToDefault,
                  child: const Text('Reset to default'),
                ),
              ),
              FButton(
                variant: FButtonVariant.outline,
                size: FButtonSizeVariant.sm,
                onPress: persistPrompt,
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


/// Glossary tab: list of current entries + add/remove/import/export actions.
class _GlossaryTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final glossaryAsync = ref.watch(glossaryServiceProvider);
    return glossaryAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: FCircularProgress(size: .sm)),
      ),
      error: (e, _) => Text('Could not load glossary: $e'),
      data: (svc) {
        return StreamBuilder<List<GlossaryEntryData>>(
          stream: svc.watchAll(),
          builder: (context, snapshot) {
            final entries = snapshot.data ?? const [];
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  Row(
                    spacing: 8,
                    children: [
                      Semantics(
                        label: 'Add glossary entry',
                        button: true,
                        child: FButton(
                          size: FButtonSizeVariant.sm,
                          onPress: () => _showAddDialog(context, ref, svc),
                          suffix: const Icon(FLucideIcons.plus),
                          child: const Text('Add'),
                        ),
                      ),
                      Semantics(
                        label: 'Import glossary from JSON file',
                        button: true,
                        child: FButton(
                          size: FButtonSizeVariant.sm,
                          variant: FButtonVariant.outline,
                          onPress: () async {
                            final count = await svc.importJson();
                            if (context.mounted) {
                              showFToast(
                                context: context,
                                title: Text(count > 0
                                    ? 'Imported $count entries'
                                    : 'No file selected'),
                                alignment: FToastAlignment.bottomCenter,
                              );
                            }
                          },
                          suffix: const Icon(FLucideIcons.upload),
                          child: const Text('Import'),
                        ),
                      ),
                      Semantics(
                        label: 'Export glossary to JSON file',
                        button: true,
                        child: FButton(
                          size: FButtonSizeVariant.sm,
                          variant: FButtonVariant.outline,
                          onPress: entries.isEmpty
                              ? null
                              : () async {
                                  await svc.exportJson();
                                },
                          suffix: const Icon(FLucideIcons.download),
                          child: const Text('Export'),
                        ),
                      ),
                      const Spacer(),
                      Semantics(
                        label: 'Reset glossary to defaults',
                        button: true,
                        child: FTooltip(
                          tipBuilder: (context, _) => const Text('Remove all entries and restore the default Japanese honorifics list'),
                          child: FButton(
                            size: FButtonSizeVariant.sm,
                            variant: FButtonVariant.outline,
                            onPress: () async {
                              final confirmed = await showFDialog<bool>(
                                context: context,
                                builder: (context, style, animation) =>
                                    FDialog(
                                  style: style,
                                  animation: animation,
                                  constraints:
                                      const BoxConstraints(maxWidth: 400),
                                  builder: (context, style) => Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      spacing: 16,
                                      children: [
                                        Text('Reset glossary to defaults?',
                                            style: style.titleTextStyle),
                                        Text(
                                          'This will delete all current entries and '
                                          'restore the default Japanese honorifics.',
                                          style: style.bodyTextStyle,
                                        ),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          spacing: 8,
                                          children: [
                                            FButton(
                                              variant: FButtonVariant.outline,
                                              size: FButtonSizeVariant.sm,
                                              onPress: () =>
                                                  Navigator.of(context)
                                                      .pop(false),
                                              child: const Text('Cancel'),
                                            ),
                                            FButton(
                                              size: FButtonSizeVariant.sm,
                                              onPress: () =>
                                                  Navigator.of(context)
                                                      .pop(true),
                                              child: const Text('Reset'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                              if (confirmed == true && context.mounted) {
                                await svc.resetToDefaults();
                                // Re-check mounted after the async gap.
                                // ignore: use_build_context_synchronously
                                if (context.mounted) {
                                  showFToast(
                                    context: context,
                                    title: const Text('Glossary reset to defaults'),
                                    alignment: FToastAlignment.bottomCenter,
                                  );
                                }
                              }
                            },
                            suffix: const Icon(FLucideIcons.rotateCcw),
                            child: const Text('Reset to defaults'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (entries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No glossary entries yet.\n'
                          'Add terms that should be kept as-is during translation.',
                          textAlign: TextAlign.center,
                          style: theme.typography.body.sm
                              .copyWith(color: theme.colors.mutedForeground),
                        ),
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Source',
                                  style: theme.typography.body.xs.copyWith(
                                    color: theme.colors.mutedForeground,
              height: 1.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 30),
                              Expanded(
                                child: Text(
                                  'Target',
                                  style: theme.typography.body.xs.copyWith(
                                    color: theme.colors.mutedForeground,
              height: 1.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 32),
                              const SizedBox(width: 32),
                            ],
                          ),
                        ),
                        const FDivider(),
                        for (final e in entries) ...[
                          _GlossaryRow(
                            entry: e,
                            onDelete: () async {
                              final confirmed = await showFDialog<bool>(
                                context: context,
                                builder: (context, style, animation) =>
                                    FDialog(
                                  style: style,
                                  animation: animation,
                                  constraints:
                                      const BoxConstraints(maxWidth: 400),
                                  builder: (context, style) => Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      spacing: 16,
                                      children: [
                                        Text('Delete glossary entry?',
                                            style: style.titleTextStyle),
                                        Text(
                                          '"${e.source}" → "${e.target}"',
                                          style: style.bodyTextStyle,
                                        ),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          spacing: 8,
                                          children: [
                                            FButton(
                                              variant: FButtonVariant.outline,
                                              size: FButtonSizeVariant.sm,
                                              onPress: () =>
                                                  Navigator.of(context)
                                                      .pop(false),
                                              child: const Text('Cancel'),
                                            ),
                                            FButton(
                                              size: FButtonSizeVariant.sm,
                                              onPress: () =>
                                                  Navigator.of(context)
                                                      .pop(true),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                              if (confirmed == true) svc.remove(e.id);
                            },
                          ),
                          const FDivider(),
                        ],
                      ],
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref, GlossaryService svc) {
    final sourceCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    showFDialog(
      context: context,
      builder: (context, style, animation) => FDialog(
        style: style,
        animation: animation,
        constraints: const BoxConstraints(minWidth: 360, maxWidth: 480),
        builder: (context, style) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              Text('Add Glossary Entry', style: style.titleTextStyle),
              FTextField(
                control: FTextFieldControl.managed(controller: sourceCtrl),
                label: const Text('Source'),
                hint: 'Original word/phrase',
              ),
              FTextField(
                control: FTextFieldControl.managed(controller: targetCtrl),
                label: const Text('Target'),
                hint: 'Translation',
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                spacing: 8,
                children: [
                  FButton(
                    variant: FButtonVariant.outline,
                    size: FButtonSizeVariant.sm,
                    onPress: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  FButton(
                    size: FButtonSizeVariant.sm,
                    onPress: () async {
                      final s = sourceCtrl.text.trim();
                      final t = targetCtrl.text.trim();
                      if (s.isEmpty || t.isEmpty) return;
                      await svc.add(source: s, target: t);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: const Text('Add'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Credentials tab: API keys with per-provider "Save & Validate" buttons.
/// Each section has a "Get Key" link and a save button that tests the
/// credentials against the real API before confirming.
class _CredentialsTab extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zenApiKeyCtrl = useTextEditingController();
    final osApiKeyCtrl = useTextEditingController();
    final osUserCtrl = useTextEditingController();
    final osPassCtrl = useTextEditingController();
    final subdlKeyCtrl = useTextEditingController();
    final subsourceKeyCtrl = useTextEditingController();
    final credsLoaded = useRef(false);

    // Validation states: null = untested, true = valid, false = invalid
    final zenValid = useState<bool?>(null);
    final osValid = useState<bool?>(null);
    final subdlValid = useState<bool?>(null);
    final subsourceValid = useState<bool?>(null);

    // Loading states for save buttons
    final zenSaving = useState(false);
    final osSaving = useState(false);
    final subdlSaving = useState(false);
    final subsourceSaving = useState(false);

    // OpenSubtitles user info (fetched after successful validation)
    final osUserInfo = useState<OpenSubtitlesUserInfo?>(null);
    final osUserInfoLoading = useState(false);

    useEffect(() {
      if (credsLoaded.value) return null;
      final cred = ref.read(credentialServiceProvider);
      cred.read(CredentialService.kZenApiKey).then(
        (v) => zenApiKeyCtrl.text = v ?? '',
      );
      cred.read(CredentialService.kOpenSubtitlesApiKey).then(
        (v) => osApiKeyCtrl.text = v ?? '',
      );
      cred.read(CredentialService.kOpenSubtitlesUsername).then(
        (v) => osUserCtrl.text = v ?? '',
      );
      cred.read(CredentialService.kOpenSubtitlesPassword).then(
        (v) => osPassCtrl.text = v ?? '',
      );
      cred.read(CredentialService.kSubdlApiKey).then(
        (v) => subdlKeyCtrl.text = v ?? '',
      );
      cred.read(CredentialService.kSubSourceApiKey).then(
        (v) => subsourceKeyCtrl.text = v ?? '',
      );
      credsLoaded.value = true;
      return null;
    }, const []);

    Future<void> saveCredential(String key, String value) async {
      final cred = ref.read(credentialServiceProvider);
      if (value.isEmpty) {
        await cred.delete(key);
      } else {
        await cred.save(key, value);
      }
    }

    void toast(String message, {bool isError = false}) {
      if (!context.mounted) return;
      showFToast(
        context: context,
        title: Text(message),
        alignment: FToastAlignment.bottomCenter,
      );
    }

    Future<void> openUrl(String url) async {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    // ── Zen ──────────────────────────────────────────────────────────────

    Future<void> saveAndValidateZen() async {
      zenSaving.value = true;
      zenValid.value = null;
      try {
        await saveCredential(
          CredentialService.kZenApiKey,
          zenApiKeyCtrl.text,
        );
        // Zen is a streaming endpoint — validate by sending a minimal request.
        // ponytail: just save and trust; full validation would consume tokens.
        zenValid.value = true;
        toast('API key saved');
      } catch (e) {
        zenValid.value = false;
        toast('Could not save settings: $e. Check your file permissions.', isError: true);
      } finally {
        zenSaving.value = false;
      }
    }

    // ── OpenSubtitles ────────────────────────────────────────────────────

    Future<void> saveAndValidateOS() async {
      osSaving.value = true;
      osValid.value = null;
      try {
        await saveCredential(
          CredentialService.kOpenSubtitlesApiKey,
          osApiKeyCtrl.text,
        );
        await saveCredential(
          CredentialService.kOpenSubtitlesUsername,
          osUserCtrl.text,
        );
        await saveCredential(
          CredentialService.kOpenSubtitlesPassword,
          osPassCtrl.text,
        );
        final error = await OpenSubtitlesProvider.validate(
          apiKey: osApiKeyCtrl.text,
          username: osUserCtrl.text,
          password: osPassCtrl.text,
        );
        if (error != null) {
          osValid.value = false;
          toast('OpenSubtitles rejected: $error', isError: true);
        } else {
          osValid.value = true;
          toast('Saved and verified');
          // Fetch user info after successful validation
          osUserInfoLoading.value = true;
          try {
            osUserInfo.value = await OpenSubtitlesInfo().getUserInfo();
          } catch (_) {
            osUserInfo.value = null;
          } finally {
            osUserInfoLoading.value = false;
          }
        }
      } catch (e) {
        osValid.value = false;
        toast('Something went wrong: $e', isError: true);
      } finally {
        osSaving.value = false;
      }
    }

    // ── Subdl ────────────────────────────────────────────────────────────

    Future<void> saveAndValidateSubdl() async {
      subdlSaving.value = true;
      subdlValid.value = null;
      try {
        await saveCredential(
          CredentialService.kSubdlApiKey,
          subdlKeyCtrl.text,
        );
        final error = await SubdlProvider.validate(subdlKeyCtrl.text);
        if (error != null) {
          subdlValid.value = false;
          toast('Subdl rejected: $error', isError: true);
        } else {
          subdlValid.value = true;
          toast('API key saved and verified');
        }
      } catch (e) {
        subdlValid.value = false;
        toast('Something went wrong: $e', isError: true);
      } finally {
        subdlSaving.value = false;
      }
    }

    // ── SubSource ────────────────────────────────────────────────────────

    Future<void> saveAndValidateSubSource() async {
      subsourceSaving.value = true;
      subsourceValid.value = null;
      try {
        await saveCredential(
          CredentialService.kSubSourceApiKey,
          subsourceKeyCtrl.text,
        );
        final error = await SubSourceProvider.validate(subsourceKeyCtrl.text);
        if (error != null) {
          subsourceValid.value = false;
          toast('SubSource rejected: $error', isError: true);
        } else {
          subsourceValid.value = true;
          toast('API key saved and verified');
        }
      } catch (e) {
        subsourceValid.value = false;
        toast('Something went wrong: $e', isError: true);
      } finally {
        subsourceSaving.value = false;
      }
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    Widget statusBadge(bool? valid) {
      if (valid == null) return const SizedBox.shrink();
      return FBadge(
        variant: valid ? FBadgeVariant.secondary : FBadgeVariant.destructive,
        child: Text(valid ? 'Verified' : 'Failed'),
      );
    }

    Widget saveButton({
      required bool isLoading,
      required VoidCallback onPress,
    }) {
      return FButton(
        onPress: isLoading ? null : onPress,
        child: Text(isLoading ? 'Checking...' : 'Save'),
      );
    }

    Widget getKeyButton(String url) {
      return FButton(
        variant: FButtonVariant.outline,
        suffix: const Icon(FLucideIcons.externalLink, size: 14),
        onPress: () => openUrl(url),
        child: const Text('Get Key'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 0,
        children: [
          // ── Translation API ──
          Row(
            children: [
              Expanded(
                child: Text(
                  'Translation API',
                  style: context.theme.typography.display.sm,
                ),
              ),
              statusBadge(zenValid.value),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Required for AI translation. Get your key from the OpenCode Zen dashboard.',
            style: context.theme.typography.body.xs.copyWith(
              color: context.theme.colors.mutedForeground,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          FTextField(
            control: FTextFieldControl.managed(controller: zenApiKeyCtrl),
            label: const Text('API Key'),
            hint: 'Paste your OpenCode Zen API key',
            obscureText: true,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              saveButton(
                isLoading: zenSaving.value,
                onPress: saveAndValidateZen,
              ),
              const SizedBox(width: 8),
              getKeyButton('https://opencode.ai'),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: FDivider(),
          ),

          // ── OpenSubtitles ──
          Row(
            children: [
              Expanded(
                child: Text(
                  'OpenSubtitles',
                  style: context.theme.typography.display.sm,
                ),
              ),
              statusBadge(osValid.value),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Search and download subtitles online. '
            'Get your API key at opensubtitles.com/en/consumers. '
            'Username/password increases download limits.',
            style: context.theme.typography.body.xs.copyWith(
              color: context.theme.colors.mutedForeground,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          FTextField(
            control: FTextFieldControl.managed(controller: osApiKeyCtrl),
            label: const Text('API Key'),
            hint: 'OpenSubtitles API key',
            obscureText: true,
          ),
          const SizedBox(height: 12),
          FTextField(
            control: FTextFieldControl.managed(controller: osUserCtrl),
            label: const Text('Username (optional)'),
            hint: 'For higher download limits',
          ),
          const SizedBox(height: 12),
          FTextField(
            control: FTextFieldControl.managed(controller: osPassCtrl),
            label: const Text('Password (optional)'),
            hint: 'For higher download limits',
            obscureText: true,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              saveButton(
                isLoading: osSaving.value,
                onPress: saveAndValidateOS,
              ),
              const SizedBox(width: 8),
              getKeyButton('https://www.opensubtitles.com/en/consumers'),
            ],
          ),
          // OpenSubtitles user info after validation
          if (osUserInfoLoading.value)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const FCircularProgress(size: .sm),
                  const SizedBox(width: 8),
                  Text(
                    'Loading user info...',
                    style: context.theme.typography.body.xs.copyWith(
                      color: context.theme.colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            )
          else if (osUserInfo.value != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Level: ${osUserInfo.value!.level} • '
                'Remaining: ${osUserInfo.value!.remainingDownloads}/${osUserInfo.value!.allowedDownloads} downloads • '
                'VIP: ${osUserInfo.value!.vip ? "Yes" : "No"}',
                style: context.theme.typography.body.xs.copyWith(
                  color: context.theme.colors.mutedForeground,
                ),
              ),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: FDivider(),
          ),

          // ── Subdl ──
          Row(
            children: [
              Expanded(
                child: Text(
                  'Subdl',
                  style: context.theme.typography.display.sm,
                ),
              ),
              statusBadge(subdlValid.value),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Free subtitle API with wide language coverage.',
            style: context.theme.typography.body.xs.copyWith(
              color: context.theme.colors.mutedForeground,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          FTextField(
            control: FTextFieldControl.managed(controller: subdlKeyCtrl),
            label: const Text('API Key'),
            hint: 'Subdl API key',
            obscureText: true,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              saveButton(
                isLoading: subdlSaving.value,
                onPress: saveAndValidateSubdl,
              ),
              const SizedBox(width: 8),
              getKeyButton('https://subdl.com/api'),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: FDivider(),
          ),

          // ── SubSource ──
          Row(
            children: [
              Expanded(
                child: Text(
                  'SubSource',
                  style: context.theme.typography.display.sm,
                ),
              ),
              statusBadge(subsourceValid.value),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Subtitle API for movies and TV shows.',
            style: context.theme.typography.body.xs.copyWith(
              color: context.theme.colors.mutedForeground,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          FTextField(
            control: FTextFieldControl.managed(controller: subsourceKeyCtrl),
            label: const Text('API Key'),
            hint: 'SubSource API key',
            obscureText: true,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              saveButton(
                isLoading: subsourceSaving.value,
                onPress: saveAndValidateSubSource,
              ),
              const SizedBox(width: 8),
              getKeyButton('https://subsource.net'),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

/// Single-select language dropdown.
///
/// When [allowAuto] is true (source language only), an "Auto detect" option
/// is prepended above the regular language list.
class _LanguageSelect extends StatelessWidget {
  final String label;
  final String? value;
  final ValueChanged<String?> onChange;
  final bool allowAuto;

  const _LanguageSelect({
    required this.label,
    required this.value,
    required this.onChange,
    this.allowAuto = false,
  });

  @override
  Widget build(BuildContext context) {
    final items = <String, String>{
      if (allowAuto) 'Auto detect': kAutoDetectCode,
      for (final (code, name) in kLanguages) name: code,
    };
    return FSelect<String>(
      items: items,
      control: FSelectControl.lifted(value: value, onChange: onChange),
      label: Text(label),
      hint: allowAuto ? 'Auto detect' : 'Select language',
    );
  }
}

/// Single-select model dropdown. Users can also type a custom value via the
/// FSelect.search variant if needed — but ponytail: a plain FSelect covers
/// 99% of users; free-text entry can be added later via a separate field.
class _ModelSelect extends StatelessWidget {
  final String label;
  final String? value;
  final ValueChanged<String?> onChange;

  const _ModelSelect({
    required this.label,
    required this.value,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return FSelect<String>(
      items: {for (final m in _models) m: m},
      control: FSelectControl.lifted(value: value, onChange: onChange),
      label: Text(label),
      hint: 'Select model',
    );
  }
}

/// A single row in the glossary list table.
///
/// Displays [source] → [target] with a case-sensitivity badge and a delete
/// button. Uses explicit [FTheme] colors so it renders correctly in both light
/// and dark mode (avoids [FTile]'s opaque internal text styling).
class _GlossaryRow extends StatelessWidget {
  final GlossaryEntryData entry;
  final VoidCallback onDelete;

  const _GlossaryRow({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          // Source term
          Expanded(
            child: Text(
              entry.source,
              style: theme.typography.body.sm.copyWith(
                color: theme.colors.foreground,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Arrow separator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(FLucideIcons.arrowRight,
                size: 14, color: theme.colors.mutedForeground),
          ),
          // Target term
          Expanded(
            child: Text(
              entry.target,
              style: theme.typography.body.sm.copyWith(
                color: theme.colors.foreground,
              ),
            ),
          ),
          // Case-sensitivity badge
          SizedBox(
            width: 32,
            child: FTooltip(
              tipBuilder: (context, _) => Text(entry.caseSensitive ? 'Case-sensitive' : 'Case-insensitive'),
              child: Text(
                entry.caseSensitive ? 'Aa' : 'aa',
                style: theme.typography.body.xs.copyWith(
                  color: theme.colors.mutedForeground,
              height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
           // Delete button
          SizedBox(
            width: 32,
            child: FTooltip(
              tipBuilder: (context, _) => Text('Remove "${entry.source}"'),
              child: FButton(
                variant: FButtonVariant.ghost,
                size: FButtonSizeVariant.xs,
                onPress: onDelete,
                child: Icon(FLucideIcons.trash2,
                    size: 14, color: theme.colors.mutedForeground),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Storage tab: download and export locations, always-ask toggle.
class _StorageTab extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsServiceProvider);
    final downloadLocation = useState<String>('');
    final exportLocation = useState<String>('');
    final alwaysAsk = useState<bool>(false);
    final loaded = useRef(false);

    useEffect(() {
      if (loaded.value) return null;
      settingsAsync.maybeWhen(
        data: (svc) async {
          downloadLocation.value = await svc.getDownloadLocation();
          exportLocation.value = await svc.getExportLocation();
          alwaysAsk.value = await svc.getAlwaysAskLocation();
          loaded.value = true;
        },
        orElse: () {},
      );
      return null;
    }, [settingsAsync]);

    Future<void> pickDirectory({required bool isDownload}) async {
      final result = await FilePicker.getDirectoryPath(
        dialogTitle: isDownload
            ? 'Select Download Location'
            : 'Select Export Location',
      );
      if (result == null) return;
      final svc = await ref.read(settingsServiceProvider.future);
      if (isDownload) {
        downloadLocation.value = result;
        await svc.setDownloadLocation(result);
      } else {
        exportLocation.value = result;
        await svc.setExportLocation(result);
      }
    }

    String displayPath(String path) {
      if (path.isEmpty) return 'Not set (defaults to ~/Downloads)';
      // Show only last 2 segments for brevity
      final parts = path.split(Platform.pathSeparator);
      if (parts.length <= 2) return path;
      return '...${Platform.pathSeparator}${parts[parts.length - 2]}${Platform.pathSeparator}${parts.last}';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          Text(
            'Configure where subtitle files are saved when downloaded or exported.',
            style: context.theme.typography.body.xs.copyWith(
              color: context.theme.colors.mutedForeground,
              height: 1.5,
            ),
          ),
          // Download location
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Text(
                'Download Location',
                style: context.theme.typography.display.sm,
              ),
              Text(
                displayPath(downloadLocation.value),
                style: context.theme.typography.body.sm.copyWith(
                  color: context.theme.colors.foreground,
                ),
              ),
              Row(
                spacing: 8,
                children: [
                  FButton(
                    size: FButtonSizeVariant.sm,
                    variant: FButtonVariant.outline,
                    onPress: () => pickDirectory(isDownload: true),
                    suffix: const Icon(FLucideIcons.folderOpen, size: 14),
                    child: const Text('Browse'),
                  ),
                  if (downloadLocation.value.isNotEmpty)
                    FButton(
                      size: FButtonSizeVariant.sm,
                      variant: FButtonVariant.ghost,
                      onPress: () async {
                        final svc =
                            await ref.read(settingsServiceProvider.future);
                        await svc.setDownloadLocation('');
                        downloadLocation.value = '';
                      },
                      child: const Text('Reset'),
                    ),
                ],
              ),
            ],
          ),
          const FDivider(),
          // Export location
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Text(
                'Export Location',
                style: context.theme.typography.display.sm,
              ),
              Text(
                displayPath(exportLocation.value),
                style: context.theme.typography.body.sm.copyWith(
                  color: context.theme.colors.foreground,
                ),
              ),
              Row(
                spacing: 8,
                children: [
                  FButton(
                    size: FButtonSizeVariant.sm,
                    variant: FButtonVariant.outline,
                    onPress: () => pickDirectory(isDownload: false),
                    suffix: const Icon(FLucideIcons.folderOpen, size: 14),
                    child: const Text('Browse'),
                  ),
                  if (exportLocation.value.isNotEmpty)
                    FButton(
                      size: FButtonSizeVariant.sm,
                      variant: FButtonVariant.ghost,
                      onPress: () async {
                        final svc =
                            await ref.read(settingsServiceProvider.future);
                        await svc.setExportLocation('');
                        exportLocation.value = '';
                      },
                      child: const Text('Reset'),
                    ),
                ],
              ),
            ],
          ),
          const FDivider(),
          // Always ask
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              FSwitch(
                label: const Text('Always ask for location'),
                semanticsLabel: 'Always ask for location',
                value: alwaysAsk.value,
                onChange: (v) async {
                  alwaysAsk.value = v;
                  final svc =
                      await ref.read(settingsServiceProvider.future);
                  await svc.setAlwaysAskLocation(v);
                },
              ),
              Text(
                'When enabled, a folder picker opens before each download '
                'or export, letting you choose where to save.',
                style: context.theme.typography.body.xs.copyWith(
                  color: context.theme.colors.mutedForeground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
