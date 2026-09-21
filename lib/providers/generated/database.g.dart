// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../database.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(profilesStream)
final profilesStreamProvider = ProfilesStreamProvider._();

final class ProfilesStreamProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Profile>>,
          List<Profile>,
          Stream<List<Profile>>
        >
    with $FutureModifier<List<Profile>>, $StreamProvider<List<Profile>> {
  ProfilesStreamProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profilesStreamProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profilesStreamHash();

  @$internal
  @override
  $StreamProviderElement<List<Profile>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Profile>> create(Ref ref) {
    return profilesStream(ref);
  }
}

String _$profilesStreamHash() => r'ea944e081294567f0f63286e95e4e66cdc650383';

@ProviderFor(addedRulesStream)
final addedRulesStreamProvider = AddedRulesStreamFamily._();

final class AddedRulesStreamProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Rule>>,
          List<Rule>,
          Stream<List<Rule>>
        >
    with $FutureModifier<List<Rule>>, $StreamProvider<List<Rule>> {
  AddedRulesStreamProvider._({
    required AddedRulesStreamFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'addedRulesStreamProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$addedRulesStreamHash();

  @override
  String toString() {
    return r'addedRulesStreamProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Rule>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Rule>> create(Ref ref) {
    final argument = this.argument as int;
    return addedRulesStream(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AddedRulesStreamProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$addedRulesStreamHash() => r'5d37e4f080094a44c2f6f84dda60d6796f4b3c99';

final class AddedRulesStreamFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Rule>>, int> {
  AddedRulesStreamFamily._()
    : super(
        retry: null,
        name: r'addedRulesStreamProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AddedRulesStreamProvider call(int profileId) =>
      AddedRulesStreamProvider._(argument: profileId, from: this);

  @override
  String toString() => r'addedRulesStreamProvider';
}

@ProviderFor(customRulesCount)
final customRulesCountProvider = CustomRulesCountFamily._();

final class CustomRulesCountProvider
    extends $FunctionalProvider<AsyncValue<int>, int, Stream<int>>
    with $FutureModifier<int>, $StreamProvider<int> {
  CustomRulesCountProvider._({
    required CustomRulesCountFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'customRulesCountProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$customRulesCountHash();

  @override
  String toString() {
    return r'customRulesCountProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<int> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<int> create(Ref ref) {
    final argument = this.argument as int;
    return customRulesCount(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CustomRulesCountProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$customRulesCountHash() => r'caac42ffd898bf21bcd658b9fead3cf2d3e2905c';

final class CustomRulesCountFamily extends $Family
    with $FunctionalFamilyOverride<Stream<int>, int> {
  CustomRulesCountFamily._()
    : super(
        retry: null,
        name: r'customRulesCountProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CustomRulesCountProvider call(int profileId) =>
      CustomRulesCountProvider._(argument: profileId, from: this);

  @override
  String toString() => r'customRulesCountProvider';
}

@ProviderFor(proxyGroupsCount)
final proxyGroupsCountProvider = ProxyGroupsCountFamily._();

final class ProxyGroupsCountProvider
    extends $FunctionalProvider<AsyncValue<int>, int, Stream<int>>
    with $FutureModifier<int>, $StreamProvider<int> {
  ProxyGroupsCountProvider._({
    required ProxyGroupsCountFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'proxyGroupsCountProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$proxyGroupsCountHash();

  @override
  String toString() {
    return r'proxyGroupsCountProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<int> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<int> create(Ref ref) {
    final argument = this.argument as int;
    return proxyGroupsCount(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ProxyGroupsCountProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$proxyGroupsCountHash() => r'e7f2c5ba78500ce97320569842399609538d699d';

final class ProxyGroupsCountFamily extends $Family
    with $FunctionalFamilyOverride<Stream<int>, int> {
  ProxyGroupsCountFamily._()
    : super(
        retry: null,
        name: r'proxyGroupsCountProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ProxyGroupsCountProvider call(int profileId) =>
      ProxyGroupsCountProvider._(argument: profileId, from: this);

  @override
  String toString() => r'proxyGroupsCountProvider';
}

@ProviderFor(Profiles)
final profilesProvider = ProfilesProvider._();

final class ProfilesProvider
    extends $NotifierProvider<Profiles, List<Profile>> {
  ProfilesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profilesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profilesHash();

  @$internal
  @override
  Profiles create() => Profiles();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Profile> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Profile>>(value),
    );
  }
}

String _$profilesHash() => r'cafdd5be8ce48955dd3bbbba4ae29fd87da6eb9a';

abstract class _$Profiles extends $Notifier<List<Profile>> {
  List<Profile> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<Profile>, List<Profile>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<Profile>, List<Profile>>,
              List<Profile>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(Scripts)
final scriptsProvider = ScriptsProvider._();

final class ScriptsProvider
    extends $StreamNotifierProvider<Scripts, List<Script>> {
  ScriptsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'scriptsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$scriptsHash();

  @$internal
  @override
  Scripts create() => Scripts();
}

String _$scriptsHash() => r'5deb6254cd0fd99d9d179ee4576ec680928f182a';

abstract class _$Scripts extends $StreamNotifier<List<Script>> {
  Stream<List<Script>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Script>>, List<Script>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Script>>, List<Script>>,
              AsyncValue<List<Script>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(script)
final scriptProvider = ScriptFamily._();

final class ScriptProvider
    extends $FunctionalProvider<AsyncValue<Script?>, Script?, FutureOr<Script?>>
    with $FutureModifier<Script?>, $FutureProvider<Script?> {
  ScriptProvider._({
    required ScriptFamily super.from,
    required int? super.argument,
  }) : super(
         retry: null,
         name: r'scriptProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$scriptHash();

  @override
  String toString() {
    return r'scriptProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Script?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Script?> create(Ref ref) {
    final argument = this.argument as int?;
    return script(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ScriptProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$scriptHash() => r'c97b48d58cef1bc928cdcfc1b292fd84ef515593';

final class ScriptFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Script?>, int?> {
  ScriptFamily._()
    : super(
        retry: null,
        name: r'scriptProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ScriptProvider call(int? scriptId) =>
      ScriptProvider._(argument: scriptId, from: this);

  @override
  String toString() => r'scriptProvider';
}

@ProviderFor(GlobalRules)
final globalRulesProvider = GlobalRulesProvider._();

final class GlobalRulesProvider
    extends $StreamNotifierProvider<GlobalRules, List<Rule>> {
  GlobalRulesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'globalRulesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$globalRulesHash();

  @$internal
  @override
  GlobalRules create() => GlobalRules();
}

String _$globalRulesHash() => r'e6e597e3e66f748a036110e5b3d6d99acfa46ce9';

abstract class _$GlobalRules extends $StreamNotifier<List<Rule>> {
  Stream<List<Rule>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Rule>>, List<Rule>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Rule>>, List<Rule>>,
              AsyncValue<List<Rule>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(ProfileAddedRules)
final profileAddedRulesProvider = ProfileAddedRulesFamily._();

final class ProfileAddedRulesProvider
    extends $StreamNotifierProvider<ProfileAddedRules, List<Rule>> {
  ProfileAddedRulesProvider._({
    required ProfileAddedRulesFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'profileAddedRulesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$profileAddedRulesHash();

  @override
  String toString() {
    return r'profileAddedRulesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ProfileAddedRules create() => ProfileAddedRules();

  @override
  bool operator ==(Object other) {
    return other is ProfileAddedRulesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$profileAddedRulesHash() => r'a7555e2ce0507b728afcf51ef422c7ef2b0f2191';

final class ProfileAddedRulesFamily extends $Family
    with
        $ClassFamilyOverride<
          ProfileAddedRules,
          AsyncValue<List<Rule>>,
          List<Rule>,
          Stream<List<Rule>>,
          int
        > {
  ProfileAddedRulesFamily._()
    : super(
        retry: null,
        name: r'profileAddedRulesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ProfileAddedRulesProvider call(int profileId) =>
      ProfileAddedRulesProvider._(argument: profileId, from: this);

  @override
  String toString() => r'profileAddedRulesProvider';
}

abstract class _$ProfileAddedRules extends $StreamNotifier<List<Rule>> {
  late final _$args = ref.$arg as int;
  int get profileId => _$args;

  Stream<List<Rule>> build(int profileId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Rule>>, List<Rule>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Rule>>, List<Rule>>,
              AsyncValue<List<Rule>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(ProfileCustomRules)
final profileCustomRulesProvider = ProfileCustomRulesFamily._();

final class ProfileCustomRulesProvider
    extends $StreamNotifierProvider<ProfileCustomRules, List<Rule>> {
  ProfileCustomRulesProvider._({
    required ProfileCustomRulesFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'profileCustomRulesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$profileCustomRulesHash();

  @override
  String toString() {
    return r'profileCustomRulesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ProfileCustomRules create() => ProfileCustomRules();

  @override
  bool operator ==(Object other) {
    return other is ProfileCustomRulesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$profileCustomRulesHash() =>
    r'976fa2bd074d7fe54bb0777bd3b441f01c9791fa';

final class ProfileCustomRulesFamily extends $Family
    with
        $ClassFamilyOverride<
          ProfileCustomRules,
          AsyncValue<List<Rule>>,
          List<Rule>,
          Stream<List<Rule>>,
          int
        > {
  ProfileCustomRulesFamily._()
    : super(
        retry: null,
        name: r'profileCustomRulesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ProfileCustomRulesProvider call(int profileId) =>
      ProfileCustomRulesProvider._(argument: profileId, from: this);

  @override
  String toString() => r'profileCustomRulesProvider';
}

abstract class _$ProfileCustomRules extends $StreamNotifier<List<Rule>> {
  late final _$args = ref.$arg as int;
  int get profileId => _$args;

  Stream<List<Rule>> build(int profileId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Rule>>, List<Rule>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Rule>>, List<Rule>>,
              AsyncValue<List<Rule>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(ProxyGroups)
final proxyGroupsProvider = ProxyGroupsFamily._();

final class ProxyGroupsProvider
    extends $StreamNotifierProvider<ProxyGroups, List<ProxyGroup>> {
  ProxyGroupsProvider._({
    required ProxyGroupsFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'proxyGroupsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$proxyGroupsHash();

  @override
  String toString() {
    return r'proxyGroupsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ProxyGroups create() => ProxyGroups();

  @override
  bool operator ==(Object other) {
    return other is ProxyGroupsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$proxyGroupsHash() => r'39f0f946730dff5fe8c272d6f5c46995ead727cd';

final class ProxyGroupsFamily extends $Family
    with
        $ClassFamilyOverride<
          ProxyGroups,
          AsyncValue<List<ProxyGroup>>,
          List<ProxyGroup>,
          Stream<List<ProxyGroup>>,
          int
        > {
  ProxyGroupsFamily._()
    : super(
        retry: null,
        name: r'proxyGroupsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ProxyGroupsProvider call(int profileId) =>
      ProxyGroupsProvider._(argument: profileId, from: this);

  @override
  String toString() => r'proxyGroupsProvider';
}

abstract class _$ProxyGroups extends $StreamNotifier<List<ProxyGroup>> {
  late final _$args = ref.$arg as int;
  int get profileId => _$args;

  Stream<List<ProxyGroup>> build(int profileId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<ProxyGroup>>, List<ProxyGroup>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<ProxyGroup>>, List<ProxyGroup>>,
              AsyncValue<List<ProxyGroup>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(ProfileDisabledRuleIds)
final profileDisabledRuleIdsProvider = ProfileDisabledRuleIdsFamily._();

final class ProfileDisabledRuleIdsProvider
    extends $StreamNotifierProvider<ProfileDisabledRuleIds, List<int>> {
  ProfileDisabledRuleIdsProvider._({
    required ProfileDisabledRuleIdsFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'profileDisabledRuleIdsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$profileDisabledRuleIdsHash();

  @override
  String toString() {
    return r'profileDisabledRuleIdsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ProfileDisabledRuleIds create() => ProfileDisabledRuleIds();

  @override
  bool operator ==(Object other) {
    return other is ProfileDisabledRuleIdsProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$profileDisabledRuleIdsHash() =>
    r'81d55f3071bc532d68fb29984d9459bb4d267523';

final class ProfileDisabledRuleIdsFamily extends $Family
    with
        $ClassFamilyOverride<
          ProfileDisabledRuleIds,
          AsyncValue<List<int>>,
          List<int>,
          Stream<List<int>>,
          int
        > {
  ProfileDisabledRuleIdsFamily._()
    : super(
        retry: null,
        name: r'profileDisabledRuleIdsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ProfileDisabledRuleIdsProvider call(int profileId) =>
      ProfileDisabledRuleIdsProvider._(argument: profileId, from: this);

  @override
  String toString() => r'profileDisabledRuleIdsProvider';
}

abstract class _$ProfileDisabledRuleIds extends $StreamNotifier<List<int>> {
  late final _$args = ref.$arg as int;
  int get profileId => _$args;

  Stream<List<int>> build(int profileId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<int>>, List<int>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<int>>, List<int>>,
              AsyncValue<List<int>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(editableProfile)
final editableProfileProvider = EditableProfileFamily._();

final class EditableProfileProvider
    extends $FunctionalProvider<Profile?, Profile?, Profile?>
    with $Provider<Profile?> {
  EditableProfileProvider._({
    required EditableProfileFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'editableProfileProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$editableProfileHash();

  @override
  String toString() {
    return r'editableProfileProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<Profile?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Profile? create(Ref ref) {
    final argument = this.argument as int;
    return editableProfile(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Profile? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Profile?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is EditableProfileProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$editableProfileHash() => r'370a6c39a2e7e5f1dbc15fabc1ed4db881201e6b';

final class EditableProfileFamily extends $Family
    with $FunctionalFamilyOverride<Profile?, int> {
  EditableProfileFamily._()
    : super(
        retry: null,
        name: r'editableProfileProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  EditableProfileProvider call(int profileId) =>
      EditableProfileProvider._(argument: profileId, from: this);

  @override
  String toString() => r'editableProfileProvider';
}

@ProviderFor(ProfileDraft)
final profileDraftProvider = ProfileDraftFamily._();

final class ProfileDraftProvider
    extends $NotifierProvider<ProfileDraft, ProfileEditDraft?> {
  ProfileDraftProvider._({
    required ProfileDraftFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'profileDraftProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$profileDraftHash();

  @override
  String toString() {
    return r'profileDraftProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ProfileDraft create() => ProfileDraft();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProfileEditDraft? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProfileEditDraft?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ProfileDraftProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$profileDraftHash() => r'f8d6a8085a598323bd06375322185fb8f433091e';

final class ProfileDraftFamily extends $Family
    with
        $ClassFamilyOverride<
          ProfileDraft,
          ProfileEditDraft?,
          ProfileEditDraft?,
          ProfileEditDraft?,
          int
        > {
  ProfileDraftFamily._()
    : super(
        retry: null,
        name: r'profileDraftProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ProfileDraftProvider call(int profileId) =>
      ProfileDraftProvider._(argument: profileId, from: this);

  @override
  String toString() => r'profileDraftProvider';
}

abstract class _$ProfileDraft extends $Notifier<ProfileEditDraft?> {
  late final _$args = ref.$arg as int;
  int get profileId => _$args;

  ProfileEditDraft? build(int profileId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ProfileEditDraft?, ProfileEditDraft?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ProfileEditDraft?, ProfileEditDraft?>,
              ProfileEditDraft?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
