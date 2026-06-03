import '../data/sample_data.dart';
import '../models/food.dart';
import 'api_client.dart';

class FoodService {
  FoodService(this._apiClient);

  final ApiClient _apiClient;

  // Mock methods for first UI build. Replace with API calls later.
  Future<List<Food>> getTodayMenuFoods() async => SampleData.menuFoods;

  Future<List<Food>> getAlwaysAvailableFoods() async => SampleData.regularFoods;

  Future<Map<String, dynamic>> fetchTodayMenuFromApi({String? token}) {
    return _apiClient.getJson('/menu-schedules/today', token: token);
  }

  Future<Map<String, dynamic>> fetchRegularFoodsFromApi({String? token}) {
    return _apiClient.getJson('/foods?kind=alwaysAvailable', token: token);
  }
}
