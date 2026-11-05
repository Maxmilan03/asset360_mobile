import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/api/api_exception.dart';
import 'package:asset360_mobile/data/reference/asset_options.dart';
import 'package:asset360_mobile/data/reference/registration_options.dart';
import 'package:asset360_mobile/data/repositories/live_assets_repository.dart';

/// The options of one Register Asset dropdown: a local list (apiMode = false) or a server list
/// that may still be loading or have failed (apiMode = true).
class OptionSource {
  const OptionSource(this.options, {this.loading = false, this.error, this.onRetry, this.empty});

  final List<String> options;
  final bool loading;

  /// Why loading failed (the server's message); shown with [onRetry].
  final String? error;
  final void Function()? onRetry;

  /// Hint when [options] is empty ("No categories on the server yet").
  final String? empty;

  bool get ready => !loading && error == null;
}

/// Every Register Asset value list for the current mode. API mode: GET
/// /api/asset-registrations/options (fixed lists), /api/asset-categories, /api/asset-category-types,
/// /api/asset-models, /api/asset-criticality/options and /api/asset-condition-assessments/ratings.
/// Lists the server does not provide (Department, Cost Center, Supplier …) stay local.
class RegLists {
  RegLists(this.ref);

  final WidgetRef ref;

  OptionSource _from<T>(
    ProviderListenable<AsyncValue<T>> provider,
    List<String> Function(T) pick,
    String what,
    void Function() retry,
  ) {
    final v = ref.watch(provider);
    final empty = 'No $what on the server yet';
    if (v.hasValue && !v.isLoading) return OptionSource(pick(v.requireValue), empty: empty);
    if (v.hasError && !v.isLoading) {
      return OptionSource(
        const [],
        error: 'Could not load $what: ${ApiException.from(v.error!).message}',
        onRetry: retry,
        empty: empty,
      );
    }
    return OptionSource(const [], loading: true, empty: empty);
  }

  /// A list from GET /api/asset-registrations/options, or [local] in mock mode.
  OptionSource _options(List<String> local, List<String> Function(RegistrationOptions) pick, String what) => apiMode
      ? _from(registrationOptionsProvider, pick, what, () => ref.invalidate(registrationOptionsProvider))
      : OptionSource(local);

  // Step 1
  OptionSource get statuses => _options(AssetOptions.statuses, (o) => o.statuses, 'statuses');
  OptionSource get conditions => apiMode
      ? _from(conditionRatingsProvider, (l) => l, 'condition ratings', () => ref.invalidate(conditionRatingsProvider))
      : const OptionSource(AssetOptions.conditions);

  // Step 2
  OptionSource get criticalities => apiMode
      ? _from(
          criticalityOptionsProvider,
          (o) => o.criticalityLevels,
          'criticality levels',
          () => ref.invalidate(criticalityOptionsProvider),
        )
      : const OptionSource(AssetOptions.criticalityLevels);
  OptionSource get functionPurposes =>
      _options(AssetOptions.functionPurposes, (o) => o.functionPurposes, 'functions / purposes');
  OptionSource get taggingMethods => _options(AssetOptions.taggingMethods, (o) => o.taggingMethods, 'tagging methods');
  OptionSource get complianceCategories =>
      _options(AssetOptions.complianceCategories, (o) => o.complianceCategories, 'compliance categories');
  OptionSource get lifecycleStages =>
      _options(AssetOptions.lifecycleStages, (o) => o.lifecycleStages, 'lifecycle stages');

  // Step 3
  OptionSource get ownershipTypes => _options(AssetOptions.ownershipTypes, (o) => o.ownershipTypes, 'ownership types');

  // Step 4
  OptionSource get quantityUnits => _options(AssetOptions.quantityUnits, (o) => o.quantityUnits, 'quantity units');

  /// Mock mode stores the ISO code ("AED", label "AED - UAE Dirham"); the server's list holds the
  /// labels themselves, stored as sent.
  OptionSource get currencies => _options(AssetOptions.currencies.keys.toList(), (o) => o.currencies, 'currencies');
  OptionSource get paymentTerms => _options(AssetOptions.paymentTerms, (o) => o.paymentTerms, 'payment terms');
  OptionSource get procurementMethods =>
      _options(AssetOptions.procurementMethods, (o) => o.procurementMethods, 'procurement methods');
  OptionSource get warrantyTypes => _options(AssetOptions.warrantyTypes, (o) => o.warrantyTypes, 'warranty types');
  OptionSource get warrantyPeriodUnits =>
      _options(AssetOptions.warrantyPeriodUnits, (o) => o.warrantyPeriodUnits, 'period units');
  OptionSource get supportCoverages =>
      _options(AssetOptions.supportCoverages, (o) => o.supportCoverages, 'support coverages');

  // Step 5
  OptionSource additional(String name, List<String> local, String what) =>
      _options(local, (o) => o.additional(name), what);
  OptionSource get dimensionUnits => additional('dimensionUnits', AssetOptions.dimensionUnits, 'dimension units');
  OptionSource get weightUnits => additional('weightUnits', AssetOptions.weightUnits, 'weight units');
  OptionSource get lifespanUnits => additional('lifespanUnits', AssetOptions.lifespanUnits, 'lifespan units');
  OptionSource get operatingHoursUnits =>
      additional('operatingHoursUnits', AssetOptions.operatingHoursUnits, 'operating hours units');
  OptionSource get operatingShifts => additional('operatingShifts', AssetOptions.operatingShifts, 'operating shifts');
  OptionSource get utilizations => additional('utilizations', AssetOptions.utilizations, 'utilizations');
  OptionSource get maintenanceFrequencyUnits =>
      additional('maintenanceFrequencyUnits', AssetOptions.maintenanceFrequencyUnits, 'frequency units');
  OptionSource get complianceStandards =>
      additional('complianceStandards', AssetOptions.complianceStandards, 'compliance standards');
  OptionSource get customFieldTypes =>
      additional('customFieldTypes', AssetOptions.customFieldTypes, 'custom field types');

  // ---------------------------------------------------------------- categories, types, models

  /// API mode: every category, or null while loading / failed.
  List<AssetCategoryItem>? get _liveCategories => ref.watch(liveCategoriesProvider).value;

  OptionSource get categories => apiMode
      ? _from(
          liveCategoriesProvider,
          (l) => [
            for (final c in l)
              if (c.isTopLevel) c.name,
          ],
          'categories',
          () => ref.invalidate(liveCategoriesProvider),
        )
      : OptionSource([for (final o in assetCategories) o.name]);

  /// The server's sub category [name] under [category] (null when unknown or not loaded).
  AssetCategoryItem? liveSubCategory(String? category, String? name) {
    final all = _liveCategories;
    if (all == null || category == null || name == null) return null;
    final parent = all.firstWhereOrNull((c) => c.isTopLevel && c.name == category);
    return all.firstWhereOrNull((c) => c.parentCategoryId == parent?.id && parent != null && c.name == name);
  }

  OptionSource subCategories(String? category) {
    if (!apiMode) {
      final c = assetCategories.firstWhereOrNull((o) => o.name == category);
      return OptionSource([for (final s in c?.subCategories ?? const <SubCategoryOption>[]) s.name]);
    }
    if (category == null) return const OptionSource([], empty: 'Choose a category first');
    final src = categories;
    if (!src.ready) return src;
    final all = _liveCategories ?? const <AssetCategoryItem>[];
    final parent = all.firstWhereOrNull((c) => c.isTopLevel && c.name == category);
    return OptionSource([
      for (final c in all)
        if (parent != null && c.parentCategoryId == parent.id) c.name,
    ], empty: 'No sub categories on the server yet');
  }

  /// API mode: the Asset Types of the sub category (GET /api/asset-category-types?categoryId=).
  /// Mock mode: [local] (the reference tree plus Master Data types).
  OptionSource assetTypes(String? category, String? subCategory, {required List<String> local}) {
    if (!apiMode) return OptionSource(local);
    if (subCategory == null) return const OptionSource([], empty: 'Choose a sub category first');
    final sub = liveSubCategory(category, subCategory);
    if (sub == null) {
      final src = categories;
      return src.ready ? const OptionSource([], empty: 'No asset types on the server yet') : src;
    }
    return _from(
      liveCategoryTypesProvider(sub.id),
      (l) => [for (final t in l) t.typeName],
      'asset types',
      () => ref.invalidate(liveCategoryTypesProvider(sub.id)),
    );
  }

  /// API mode: the server's asset type [typeName] (null when unknown or not loaded).
  AssetCategoryType? liveType(String? category, String? subCategory, String? typeName) {
    final sub = liveSubCategory(category, subCategory);
    if (sub == null || typeName == null) return null;
    return ref.watch(liveCategoryTypesProvider(sub.id)).value?.firstWhereOrNull((t) => t.typeName == typeName);
  }

  /// API mode: the models of the chosen asset type (all models until a type is chosen), for the
  /// Model suggestions; free text stays allowed. Empty in mock mode.
  List<AssetModelItem> models(String? category, String? subCategory, String? typeName) {
    if (!apiMode) return const [];
    final type = liveType(category, subCategory, typeName);
    return ref.watch(liveModelsProvider(type?.id)).value ?? const [];
  }

  /// Manufacturer suggestions. API mode: the manufacturers of the server's asset models (Master
  /// Management's manufacturer list is not called); mock mode: [local].
  List<String> manufacturers(List<String> Function() local) {
    if (!apiMode) return local();
    final all = ref.watch(liveModelsProvider(null)).value ?? const <AssetModelItem>[];
    return ({for (final m in all) m.manufacturerName}..remove('')).toList()..sort();
  }
}

extension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
