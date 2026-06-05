import '../models/food.dart';
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

  // Mock - sẽ thay bằng API sau khi hoàn thiện Today Menu feature
  Future<List<Food>> getTodayMenuFoods() async => [];
}

