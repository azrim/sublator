import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'credential_service.g.dart';

/// Thrown when the underlying secure storage backend is unavailable (e.g.
/// DPAPI missing on Windows, Keychain locked on macOS, plugin not registered).
/// Distinct from a missing key ([read] returns null for that case) so callers
/// can surface a hard error rather than silently degrade.
class SecureStorageUnavailableException implements Exception {
  final String message;
  const SecureStorageUnavailableException(this.message);

  @override
  String toString() => 'SecureStorageUnavailableException: $message';
}

/// Wraps [FlutterSecureStorage] for the four credential keys this app owns.
/// On Windows the default backend is DPAPI via Windows Credential Manager;
/// on macOS Keychain; on Linux libsecret. Plaintext NEVER touches Drift.
class CredentialService {
  CredentialService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  /// The complete set of credential keys this service is allowed to touch.
  /// Rejecting unknown keys up front prevents accidental plaintext leakage
  /// under arbitrary key names.
  static const Set<String> allowedKeys = {
    kZenApiKey,
    kOpenSubtitlesApiKey,
    kOpenSubtitlesUsername,
    kOpenSubtitlesPassword,
    kSubdlApiKey,
    kSubSourceApiKey,
  };

  static const kZenApiKey = 'zen_api_key';
  static const kOpenSubtitlesApiKey = 'opensubtitles_api_key';
  static const kOpenSubtitlesUsername = 'opensubtitles_username';
  static const kOpenSubtitlesPassword = 'opensubtitles_password';
  static const kSubdlApiKey = 'subdl_api_key';
  static const kSubSourceApiKey = 'subsource_api_key';

  Future<void> save(String key, String value) async {
    _checkKey(key);
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      throw SecureStorageUnavailableException(
        'Failed to write credential "$key": $e',
      );
    }
  }

  Future<String?> read(String key) async {
    _checkKey(key);
    try {
      return await _storage.read(key: key);
    } catch (e) {
      throw SecureStorageUnavailableException(
        'Failed to read credential "$key": $e',
      );
    }
  }

  Future<void> delete(String key) async {
    _checkKey(key);
    try {
      await _storage.delete(key: key);
    } catch (e) {
      throw SecureStorageUnavailableException(
        'Failed to delete credential "$key": $e',
      );
    }
  }

  void _checkKey(String key) {
    if (!allowedKeys.contains(key)) {
      throw ArgumentError.value(
        key,
        'key',
        'Not a known credential key. Allowed: $allowedKeys',
      );
    }
  }
}

@riverpod
CredentialService credentialService(Ref ref) {
  return CredentialService();
}
