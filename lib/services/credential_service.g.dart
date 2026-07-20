// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'credential_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(credentialService)
final credentialServiceProvider = CredentialServiceProvider._();

final class CredentialServiceProvider
    extends
        $FunctionalProvider<
          CredentialService,
          CredentialService,
          CredentialService
        >
    with $Provider<CredentialService> {
  CredentialServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'credentialServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$credentialServiceHash();

  @$internal
  @override
  $ProviderElement<CredentialService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CredentialService create(Ref ref) {
    return credentialService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CredentialService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CredentialService>(value),
    );
  }
}

String _$credentialServiceHash() => r'5538df6f8d1fe7b0eee1f60070d409042d5386d4';
