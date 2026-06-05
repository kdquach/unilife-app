import '../models/food.dart';
import '../models/food_category.dart';
import '../models/menu_schedule.dart';
import 'api_client.dart';

class FoodService {
  FoodService(this._apiClient);

  final ApiClient _apiClient;

  /// Lấy danh sách món ăn bán hàng ngày từ API (isMenuItem: false)
  Future<List<Food>> getAlwaysAvailableFoods({String? token}) async {
    final response = await _apiClient.getJson(
      '/foods?kind=alwaysAvailable&isActive=true',
      token: token,
    );
    final data = response['data'];
    final items = data is Map ? data['items'] : null;
    if (items == null || items is! List) return [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(Food.fromJson)
        .toList();
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
      print('Error in getTodayMenuFoods: $e');
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
      print('Error in getWeeklyMenuSchedules: $e');
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
      print('Error in getFoodCategories: $e');
      return [];
    }
  }
}



