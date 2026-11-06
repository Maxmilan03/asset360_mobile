import 'package:asset360_mobile/data/api/api_client.dart';
import 'package:asset360_mobile/data/api/master_data/master_data_models.dart' show mdParseList;

/// The read-only endpoints of the Master Data Management service (MASTER_DATA_BASE_URL) the app
/// uses. Every list is a bare JSON array (no paging). Lists that take `status` are asked for
/// `status=Active`; the parser ([mdParseList]) drops inactive rows again, which also covers
/// master-data-items (no status parameter).
class MasterDataApi {
  const MasterDataApi(this.client);

  final ApiClient client;

  static const base = '/api/master-data';
  static const active = {'status': 'Active'};

  static const categories = '$base/asset-categories';
  static String subCategories(String categoryId) =>
      '$base/asset-categories/${Uri.encodeComponent(categoryId)}/subcategories';
  static const assetTypes = '$base/asset-types';
  static const assetModels = '$base/asset-models';
  static const manufacturers = '$base/manufacturers';
  static const conditions = '$base/conditions';
  static const criticalities = '$base/criticalities';
  static const departments = '$base/departments';
  static const businessUnits = '$base/business-units';
  static const suppliers = '$base/suppliers';
  static const amcVendors = '$base/amc-vendors';
  static const serviceProviders = '$base/service-providers';
  static const teams = '$base/teams';
  static const shifts = '$base/shifts';
  static const uoms = '$base/uoms';
  static const employees = '$base/employees';
  static const locationTree = '$base/locations/tree';
  static const sites = '$base/sites';
  static const buildings = '$base/buildings';
  static const floors = '$base/floors';
  static const zones = '$base/zones';

  /// No status parameter on this endpoint (inactive items are dropped by the parser).
  static String itemsOfType(String masterType) => '/api/master-data-items/type/${Uri.encodeComponent(masterType)}';

  /// GET [path] and return the decoded JSON body.
  Future<Object?> get(String path, {Map<String, String> query = const {}}) async =>
      (await client.get<Object?>(path, query: query.isEmpty ? null : query)).data;
}
