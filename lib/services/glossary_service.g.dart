// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'glossary_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(glossaryService)
final glossaryServiceProvider = GlossaryServiceProvider._();

final class GlossaryServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<GlossaryService>,
          GlossaryService,
          FutureOr<GlossaryService>
        >
    with $FutureModifier<GlossaryService>, $FutureProvider<GlossaryService> {
  GlossaryServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'glossaryServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$glossaryServiceHash();

  @$internal
  @override
  $FutureProviderElement<GlossaryService> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<GlossaryService> create(Ref ref) {
    return glossaryService(ref);
  }
}

String _$glossaryServiceHash() => r'8353f45a845e00489b5a9ac9a4d8a57aaf858dce';
