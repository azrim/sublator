// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'system_prompt_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(systemPromptService)
final systemPromptServiceProvider = SystemPromptServiceProvider._();

final class SystemPromptServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<SystemPromptService>,
          SystemPromptService,
          FutureOr<SystemPromptService>
        >
    with
        $FutureModifier<SystemPromptService>,
        $FutureProvider<SystemPromptService> {
  SystemPromptServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'systemPromptServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$systemPromptServiceHash();

  @$internal
  @override
  $FutureProviderElement<SystemPromptService> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SystemPromptService> create(Ref ref) {
    return systemPromptService(ref);
  }
}

String _$systemPromptServiceHash() =>
    r'8de2c4a14321328b27e0d4f94e4f8bbb55bfa3fa';
