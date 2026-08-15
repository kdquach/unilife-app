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
    final query = keyword.trim().toLowerCase();
    if (query.isEmpty) return [];

    var foods = await _getSearchableFoods(token: token);

    foods = foods.where((food) {
      final haystack =
          '${food.name} ${food.description} ${food.category}'.toLowerCase();
      if (!haystack.contains(query)) return false;
      if (categoryId != null &&
          categoryId.isNotEmpty &&
          food.categoryId != categoryId) {
        return false;
      }
      if (minPrice != null && food.price < minPrice) return false;
      if (maxPrice != null && food.price > maxPrice) return false;
      return true;
    }).toList();

    foods = _sortFoods(foods, sortBy: sortBy, sortOrder: sortOrder);

    if (foods.length > limit) {
      return foods.sublist(0, limit);
    }
    return foods;
  }

  Future<FoodFilterOptions> getSearchFilterOptions({String? token}) async {
    final foods = await _getSearchableFoods(token: token);
    return _buildFilterOptionsFromFoods(foods);
  }

  Future<List<Food>> _getSearchableFoods({String? token}) async {
    final results = await Future.wait([
      getTodayMenuFoods(token: token),
      getDailyFoods(token: token),
    ]);
    return [...results[0], ...results[1]];
  }

  FoodFilterOptions _buildFilterOptionsFromFoods(List<Food> foods) {
    final categoriesById = <String, FoodCategory>{};
    for (final food in foods) {
      final id = food.categoryId;
      if (id == null || id.isEmpty || categoriesById.containsKey(id)) {
        continue;
      }
      categoriesById[id] = FoodCategory(
        id: id,
        name: food.category,
      );
    }

    final categories = categoriesById.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (foods.isEmpty) {
      return FoodFilterOptions(
        categories: categories,
        minPrice: 0,
        maxPrice: 0,
      );
    }

    var minPrice = foods.first.price;
    var maxPrice = foods.first.price;
    for (final food in foods) {
      if (food.price < minPrice) minPrice = food.price;
      if (food.price > maxPrice) maxPrice = food.price;
    }

    return FoodFilterOptions(
      categories: categories,
      minPrice: minPrice,
      maxPrice: maxPrice,
    );
  }

  List<Food> _sortFoods(
    List<Food> foods, {
    required String sortBy,
    required String sortOrder,
  }) {
    final sorted = [...foods];
    final ascending = sortOrder == 'asc';

    int compare(Food a, Food b) {
      switch (sortBy) {
        case 'price':
          return a.price.compareTo(b.price);
        case 'name':
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case 'createdAt':
          final aDate = a.createdAt ?? '';
          final bDate = b.createdAt ?? '';
          return aDate.compareTo(bDate);
        default:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    }

    sorted.sort((a, b) => ascending ? compare(a, b) : compare(b, a));
    return sorted;
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

  Future<FoodFilterOptions> getAllFoodFilterOptions({String? token}) {
    return getFoodFilterOptions(token: token, kind: null);
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

  /// Get list of daily food from API (isMenuItem: false)
  Future<Food> getFoodById(String id, {String? token}) async {
    final response = await _apiClient.getJson('/foods/$id', token: token);
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException(statusCode: 500, message: 'Invalid food detail data');
    }
    return Food.fromJson(data);
  }

  Future<List<Food>> getDailyFoods({String? token}) async {
    final response = await _apiClient.getJson('/foods/daily', token: token);
    return _parseFoodItems(response);
  }

  Future<List<Food>> getAlwaysAvailableFoods({String? token}) async {
    return getDailyFoods(token: token);
  }

  /// Get list of today's menu food from API
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

  /// Get weekly menu schedules from API
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

  /// Get list of food categories from API
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
