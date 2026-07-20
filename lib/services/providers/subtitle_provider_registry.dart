import 'opensubtitles_provider.dart';
import 'subdl_provider.dart';
import 'subsource_provider.dart';
import 'subtitle_provider.dart';

/// Enum of all available subtitle providers.
enum SubtitleProviderType {
  openSubtitles,
  subdl,
  subSource,
}

/// Central registry of all subtitle providers.
///
/// Call [providersFor] to get a list of providers filtered by auth requirements,
/// or [all] for the full list.
class SubtitleProviderRegistry {
  const SubtitleProviderRegistry._();

  static final Map<SubtitleProviderType, SubtitleProvider> _instances = {
    SubtitleProviderType.openSubtitles: OpenSubtitlesProvider(),
    SubtitleProviderType.subdl: SubdlProvider(),
    SubtitleProviderType.subSource: SubSourceProvider(),
  };

  /// All registered providers.
  static List<SubtitleProvider> get all =>
      _instances.values.toList(growable: false);

  /// Returns providers that don't require auth, or all if [includeAuth] is true.
  static List<SubtitleProvider> providersFor({bool includeAuth = true}) {
    if (includeAuth) return all;
    return all.where((p) => !p.requiresAuth).toList(growable: false);
  }

  /// Get a provider by its enum type.
  static SubtitleProvider? getProvider(SubtitleProviderType type) =>
      _instances[type];

  /// Get the enum type for a provider name.
  static SubtitleProviderType? typeByName(String name) {
    for (final entry in _instances.entries) {
      if (entry.value.name == name) return entry.key;
    }
    return null;
  }
}
