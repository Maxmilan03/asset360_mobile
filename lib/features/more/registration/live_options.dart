import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable, ProviderOrFamily;

import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/api/api_exception.dart';
import 'package:asset360_mobile/data/api/master_data/master_data_repository.dart';
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

  /// Reloads a server list (shown with [error], and with [empty] when the list is empty).
  final void Function()? onRetry;

  /// Hint when [options] is empty ("No categories on the server yet").
  final String? empty;

  bool get ready => !loading && error == null;
}

/// Every Register Asset value list for the current mode.
///
/// API mode:
/// * Master Data service (MASTER_DATA_BASE_URL): Category, Sub Category, Asset Type, Model,
///   Manufacturer, Condition, Criticality, Department (+ Custodian / Department), Business Unit,
///   Supplier / Vendor, Service Provider (AMC vendors when Warranty Type is AMC), Responsible Team,
///   Operating Shift, Quantity Unit. See master_data_repository.dart.
/// * Asset service GET /api/asset-registrations/options: Status, Function / Purpose, Tagging
///   Method, Compliance Category, Lifecycle Stage, Ownership Type, Currency, Payment Terms,
///   Procurement Method, Warranty Type, Period Unit, Support Coverage and the step-5 units (Master
///   Data has no list for them: no master-data-items types are defined).
/// * Local: Cost Center (no list on any service yet).
///
/// Every value is saved as its NAME: the Asset service stores these fields as text.
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
    if (v.hasError && !v.isLoading) {
      return OptionSource(
        const [],
        error: 'Could not load $what: ${ApiException.from(v.error!).message}',
        onRetry: retry,
        empty: empty,
      );
    }
    // A reload keeps showing the previous list until the new one arrives.
    if (v.hasValue) return OptionSource(pick(v.requireValue), empty: empty, onRetry: retry);
    return OptionSource(const [], loading: true, empty: empty);
  }

  /// A Master Data list as names (first of each name only), or [local] in mock mode.
  OptionSource _md<T extends MdEntry>(
    ProviderListenable<AsyncValue<List<T>>> provider,
    ProviderOrFamily invalidate,
    String what, {
    List<String> local = const [],
  }) => apiMode ? _from(provider, namesOf, what, () => ref.invalidate(invalidate)) : OptionSource(local);

  /// A list from GET /api/asset-registrations/options, or [local] in mock mode.
  OptionSource _options(List<String> local, List<String> Function(RegistrationOptions) pick, String what) => apiMode
      ? _from(registrationOptionsProvider, pick, what, () => ref.invalidate(registrationOptionsProvider))
      : OptionSource(local);

  // Step 1
  OptionSource get statuses => _options(AssetOptions.statuses, (o) => o.statuses, 'statuses');
  OptionSource get conditions =>
      _md(mdConditionsProvider, mdConditionsProvider, 'conditions', local: AssetOptions.conditions);

  // Step 2
  OptionSource get criticalities =>
      _md(mdCriticalitiesProvider, mdCriticalitiesProvider, 'criticalities', local: AssetOptions.criticalityLevels);
  OptionSource get departments =>
      _md(mdDepartmentsProvider, mdDepartmentsProvider, 'departments', local: AssetOptions.departments);
  OptionSource get businessUnits =>
      _md(mdBusinessUnitsProvider, mdBusinessUnitsProvider, 'business units', local: AssetOptions.businessUnits);

  /// Local in both modes: neither Master Data nor the Asset service has a cost center list.
  OptionSource get costCenters => const OptionSource(AssetOptions.costCenters);
  OptionSource get functionPurposes =>
      _options(AssetOptions.functionPurposes, (o) => o.functionPurposes, 'functions / purposes');
  OptionSource get taggingMethods => _options(AssetOptions.taggingMethods, (o) => o.taggingMethods, 'tagging methods');
  OptionSource get complianceCategories =>
      _options(AssetOptions.complianceCategories, (o) => o.complianceCategories, 'compliance categories');
  OptionSource get lifecycleStages =>
      _options(AssetOptions.lifecycleStages, (o) => o.lifecycleStages, 'lifecycle stages');

  // Step 3
  OptionSource get ownershipTypes => _options(AssetOptions.ownershipTypes, (o) => o.ownershipTypes, 'ownership types');
  OptionSource get responsibleTeams =>
      _md(mdTeamsProvider, mdTeamsProvider, 'teams', local: AssetOptions.responsibleTeams);

  // Step 4
  OptionSource get quantityUnits => apiMode
      ? _md(mdUomsProvider, mdUomsProvider, 'units of measure')
      : _options(AssetOptions.quantityUnits, (o) => o.quantityUnits, 'quantity units');

  /// Supplier / Vendor suggestions (free text stays allowed). Mock mode: [local].
  OptionSource suppliers(List<String> local) =>
      _md(mdSuppliersProvider, mdSuppliersProvider, 'suppliers', local: local);

  /// Service Provider: the AMC vendors when [warrantyType] is "AMC", else the service providers.
  OptionSource serviceProviders(String? warrantyType) {
    if (!apiMode) return const OptionSource(AssetOptions.serviceProviders);
    return warrantyType?.trim().toUpperCase() == 'AMC'
        ? _md(mdAmcVendorsProvider, mdAmcVendorsProvider, 'AMC vendors')
        : _md(mdServiceProvidersProvider, mdServiceProvidersProvider, 'service providers');
  }

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

  /// API mode: Master Data /shifts.
  OptionSource get operatingShifts => apiMode
      ? _md(mdShiftsProvider, mdShiftsProvider, 'shifts')
      : additional('operatingShifts', AssetOptions.operatingShifts, 'operating shifts');
  OptionSource get utilizations => additional('utilizations', AssetOptions.utilizations, 'utilizations');
  OptionSource get maintenanceFrequencyUnits =>
      additional('maintenanceFrequencyUnits', AssetOptions.maintenanceFrequencyUnits, 'frequency units');
  OptionSource get complianceStandards =>
      additional('complianceStandards', AssetOptions.complianceStandards, 'compliance standards');
  OptionSource get customFieldTypes =>
      additional('customFieldTypes', AssetOptions.customFieldTypes, 'custom field types');

  // ---------------------------------------------------------------- categories, types, models

  /// API mode: the top-level category named [name] (null when unknown or not loaded).
  MdCategory? mdCategory(String? name) => name == null
      ? null
      : ref.watch(mdCategoriesProvider).value?.where((c) => c.isTopLevel && c.name == name).firstOrNull;

  /// API mode: the sub category [name] under [category].
  MdSubCategory? mdSubCategory(String? category, String? name) {
    final parent = mdCategory(category);
    if (parent == null || name == null) return null;
    return ref.watch(mdSubCategoriesProvider(parent.id)).value?.where((s) => s.name == name).firstOrNull;
  }

  OptionSource get categories => apiMode
      ? _from(
          mdCategoriesProvider,
          (l) => namesOf(l.where((c) => c.isTopLevel)),
          'categories',
          () => ref.invalidate(mdCategoriesProvider),
        )
      : OptionSource([for (final o in assetCategories) o.name]);

  /// API mode: GET /asset-categories/{categoryId}/subcategories of the chosen category.
  OptionSource subCategories(String? category) {
    if (!apiMode) {
      final c = assetCategories.where((o) => o.name == category).firstOrNull;
      return OptionSource([for (final s in c?.subCategories ?? const <SubCategoryOption>[]) s.name]);
    }
    if (category == null) return const OptionSource([], empty: 'Choose a category first');
    final parent = mdCategory(category);
    if (parent == null) {
      final src = categories;
      return src.ready ? const OptionSource([], empty: 'No sub categories on the server yet') : src;
    }
    return _from(
      mdSubCategoriesProvider(parent.id),
      namesOf,
      'sub categories',
      () => ref.invalidate(mdSubCategoriesProvider(parent.id)),
    );
  }

  /// API mode: the asset types linked to the chosen category (GET /asset-types?categoryId=). A
  /// sub category can name one asset type (`assetType`, free text); when that name is in the list
  /// only it is offered. Mock mode: [local] (the reference tree plus Master Data types).
  OptionSource assetTypes(String? category, String? subCategory, {required List<String> local}) {
    if (!apiMode) return OptionSource(local);
    if (subCategory == null) return const OptionSource([], empty: 'Choose a sub category first');
    final parent = mdCategory(category);
    if (parent == null) {
      final src = categories;
      return src.ready ? const OptionSource([], empty: 'No asset types on the server yet') : src;
    }
    final named = mdSubCategory(category, subCategory)?.assetType?.trim().toLowerCase();
    return _from(
      mdAssetTypesProvider(parent.id),
      (types) {
        final all = namesOf(types);
        final only = [
          for (final t in all)
            if (t.toLowerCase() == named) t,
        ];
        return only.isEmpty ? all : only;
      },
      'asset types',
      () => ref.invalidate(mdAssetTypesProvider(parent.id)),
    );
  }

  /// API mode: the server's asset type [typeName] under [category] (null when unknown / not loaded).
  MdAssetType? mdAssetType(String? category, String? typeName) {
    final parent = mdCategory(category);
    if (parent == null || typeName == null) return null;
    return ref.watch(mdAssetTypesProvider(parent.id)).value?.where((t) => t.name == typeName).firstOrNull;
  }

  /// API mode: the models of the chosen asset type (all models until a type is chosen), for the
  /// Model suggestions; free text stays allowed. Empty in mock mode.
  OptionSource models(String? category, String? typeName) {
    if (!apiMode) return const OptionSource([]);
    final p = mdAssetModelsProvider(mdAssetType(category, typeName)?.id);
    return _md(p, p, 'asset models');
  }

  /// Manufacturer suggestions. API mode: Master Data /manufacturers; mock mode: [local].
  OptionSource manufacturers(List<String> Function() local) =>
      apiMode ? _md(mdManufacturersProvider, mdManufacturersProvider, 'manufacturers') : OptionSource(local());
}

/// The names of [entries], each once, in the server's order.
List<String> namesOf(Iterable<MdEntry> entries) => {
  for (final e in entries)
    if (e.name.isNotEmpty) e.name,
}.toList();
