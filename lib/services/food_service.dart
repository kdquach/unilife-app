import 'package:flutter/foundation.dart';

import '../models/food.dart';
import '../models/food_category.dart';
import '../models/menu_schedule.dart';
import 'api_client.dart';

class FoodService {
  FoodService(this._apiClient);

  final ApiClient _apiClient;

  List<Food> _parseFoodItems(Map<String, dynamic> response) {
    final data = response['data'];
    final items = data is Map ? data['items'] : null;
    if (items == null || items is! List) return [];
    return items.whereType<Map<String, dynamic>>().map(Food.fromJson).toList();
  }

  Future<List<Food>> searchFoods({
    required String keyword,
    String? token,
    String? kind,
    String? categoryId,
    int? minPrice,
    int? maxPrice,
    String sortBy = 'createdAt',
    String sortOrder = 'desc',
    int limit = 20,
  }) async {
    final query = keyword.trim();
    if (query.isEmpty) return [];

    final path = Uri(
      path: '/foods/search',
      queryParameters: {
        'keyword': query,
        'isActive': 'true',
        'sortBy': sortBy,
        'sortOrder': sortOrder,
        'limit': limit.toString(),
        if (kind != null && kind.isNotEmpty) 'kind': kind,
        if (categoryId != null && categoryId.isNotEmpty)
          'categoryId': categoryId,
        if (minPrice != null) 'minPrice': minPrice.toString(),
        if (maxPrice != null) 'maxPrice': maxPrice.toString(),
      },
    ).toString();

    final response = await _apiClient.getJson(path, token: token);
    return _parseFoodItems(response);
  }

  Future<FoodFilterOptions> getFoodFilterOptions({
    String? token,
    String? kind = 'alwaysAvailable',
  }) async {
    final path = Uri(
      path: '/foods/filter-options',
      queryParameters: {
        'isActive': 'true',
        if (kind != null && kind.isNotEmpty) 'kind': kind,
      },
    ).toString();

    final response = await _apiClient.getJson(path, token: token);
    final data = response['data'];
    return FoodFilterOptions.fromJson(
      data is Map<String, dynamic> ? data : <String, dynamic>{},
    );
  }

  Future<List<Food>> filterFoods({
    String? token,
    String? kind = 'alwaysAvailable',
    String? categoryId,
    int? minPrice,
    int? maxPrice,
    String sortBy = 'createdAt',
    String sortOrder = 'desc',
    int limit = 100,
  }) async {
    final path = Uri(
      path: '/foods/filter',
      queryParameters: {
        'isActive': 'true',
        'sortBy': sortBy,
        'sortOrder': sortOrder,
        'limit': limit.toString(),
        if (kind != null && kind.isNotEmpty) 'kind': kind,
        if (categoryId != null && categoryId.isNotEmpty)
          'categoryId': categoryId,
        if (minPrice != null) 'minPrice': minPrice.toString(),
        if (maxPrice != null) 'maxPrice': maxPrice.toString(),
      },
    ).toString();

    final response = await _apiClient.getJson(path, token: token);
    return _parseFoodItems(response);
  }

  /// Lấy danh sách món ăn bán hàng ngày từ API (isMenuItem: false)
  Future<Food> getFoodById(String id, {String? token}) async {
    final response = await _apiClient.getJson('/foods/$id', token: token);
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException(statusCode: 500, message: 'Invalid food detail data');
    }
    return Food.fromJson(data);
  }

  Future<List<Food>> getAlwaysAvailableFoods({String? token}) async {
    final response = await _apiClient.getJson(
      '/foods?kind=alwaysAvailable&isActive=true',
      token: token,
    );
    return _parseFoodItems(response);
  }

  /// Lấy danh sách món ăn bán theo menu hôm nay từ API
  Future<List<Food>> getTodayMenuFoods({String? token}) async {
    try {
      final response = await _apiClient.getJson(
        '/menu-schedules/today',
        token: token,
      );
      final data = response['data'];
      if (data == null) return [];

      final items = data['items'];
      if (items == null || items is! List) return [];

      return items
          .whereType<Map<String, dynamic>>()
          .map(Food.fromMenuScheduleItemJson)
          .toList();
    } catch (e) {
      debugPrint('Error in getTodayMenuFoods: $e');
      return [];
    }
  }

  /// Lấy danh sách thực đơn theo tuần (khoảng ngày) từ API
  Future<List<MenuSchedule>> getWeeklyMenuSchedules({
    required String dateFrom,
    required String dateTo,
    String? token,
  }) async {
    try {
      final response = await _apiClient.getJson(
        '/menu-schedules?dateFrom=$dateFrom&dateTo=$dateTo',
        token: token,
      );
      final data = response['data'];
      final items = data is Map ? data['items'] : null;
      if (items == null || items is! List) return [];

      return items
          .whereType<Map<String, dynamic>>()
          .map(MenuSchedule.fromJson)
          .toList();
    } catch (e) {
      debugPrint('Error in getWeeklyMenuSchedules: $e');
      return [];
    }
  }

  /// Lấy danh sách danh mục món ăn từ API
  Future<List<FoodCategory>> getFoodCategories({String? token}) async {
    try {
      final response = await _apiClient.getJson(
        '/food-categories?isActive=true',
        token: token,
      );
      final data = response['data'];
      final items = data is Map ? data['items'] : null;
      if (items == null || items is! List) return [];

      return items
          .whereType<Map<String, dynamic>>()
          .map(FoodCategory.fromJson)
          .toList();
    } catch (e) {
      debugPrint('Error in getFoodCategories: $e');
      return [];
    }
  }
}

class FoodFilterOptions {
  final List<FoodCategory> categories;
  final int minPrice;
  final int maxPrice;

  const FoodFilterOptions({
    required this.categories,
    required this.minPrice,
    required this.maxPrice,
  });

  factory FoodFilterOptions.fromJson(Map<String, dynamic> json) {
    final categories = json['categories'];
    final priceRange = json['priceRange'];
    final priceRangeMap =
        priceRange is Map<String, dynamic> ? priceRange : <String, dynamic>{};

    return FoodFilterOptions(
      categories: categories is List
          ? categories
              .whereType<Map<String, dynamic>>()
              .map(FoodCategory.fromJson)
              .toList()
          : const [],
      minPrice: ((priceRangeMap['minPrice'] as num?) ?? 0).toInt(),
      maxPrice: ((priceRangeMap['maxPrice'] as num?) ?? 0).toInt(),
    );
  }
}
