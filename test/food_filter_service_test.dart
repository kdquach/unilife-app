import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:unilife_mobile/services/api_client.dart';
import 'package:unilife_mobile/services/food_service.dart';

void main() {
  test('searchFoods filters today menu and daily foods by keyword', () async {
    final requestedPaths = <String>[];
    final service = FoodService(
      ApiClient(
        client: MockClient((request) async {
          requestedPaths.add(request.url.path);

          if (request.url.path.contains('menu-schedules/today')) {
            return http.Response(
              r'{"data":{"items":[{"_id":"menu-item-1","remainingCount":5,"isActive":true,"foodId":{"_id":"food-menu-1","name":"Com ga","description":"combo vietnam","price":30000,"createdAt":"2026-07-26T01:54:35.835Z","categoryId":{"_id":"cat-rice","name":"Rice Meals"}}}]}}',
              200,
            );
          }

          if (request.url.path.contains('foods/daily')) {
            return http.Response(
              r'{"data":{"items":[{"_id":"food-daily-1","name":"Milk Tea","description":"Tra sua","price":15000,"isMenuItem":false,"stockQuantity":49,"isActive":true,"createdAt":"2026-06-01T16:40:28.093Z","categoryId":{"_id":"cat-drinks","name":"Drinks"}},{"_id":"food-daily-2","name":"Egg Sandwich","description":"Bread sandwich","price":20000,"isMenuItem":false,"stockQuantity":11,"isActive":true,"createdAt":"2026-06-01T16:40:28.191Z","categoryId":{"_id":"cat-snacks","name":"Snacks"}}]}}',
              200,
            );
          }

          return http.Response('{"data":{"items":[]}}', 404);
        }),
      ),
    );

    final results = await service.searchFoods(keyword: 'milk');

    expect(requestedPaths.any((path) => path.contains('menu-schedules/today')),
        isTrue);
    expect(requestedPaths.any((path) => path.contains('foods/daily')), isTrue);
    expect(requestedPaths.any((path) => path.contains('foods/search')), isFalse);
    expect(results, hasLength(1));
    expect(results.first.name, 'Milk Tea');
  });

  test('searchFoods applies category and price filters client-side', () async {
    final service = FoodService(
      ApiClient(
        client: MockClient((request) async {
          if (request.url.path.contains('menu-schedules/today')) {
            return http.Response('{"data":{"items":[]}}', 200);
          }
          if (request.url.path.contains('foods/daily')) {
            return http.Response(
              r'{"data":{"items":[{"_id":"food-daily-1","name":"Milk Tea","description":"Tra sua","price":15000,"isMenuItem":false,"stockQuantity":49,"isActive":true,"categoryId":{"_id":"cat-drinks","name":"Drinks"}},{"_id":"food-daily-2","name":"Egg Sandwich","description":"Bread sandwich","price":20000,"isMenuItem":false,"stockQuantity":11,"isActive":true,"categoryId":{"_id":"cat-snacks","name":"Snacks"}}]}}',
              200,
            );
          }
          return http.Response('{"data":{"items":[]}}', 404);
        }),
      ),
    );

    final results = await service.searchFoods(
      keyword: 'e',
      categoryId: 'cat-snacks',
      minPrice: 18000,
      maxPrice: 25000,
      sortBy: 'price',
      sortOrder: 'desc',
    );

    expect(results, hasLength(1));
    expect(results.first.name, 'Egg Sandwich');
  });

  test('getSearchFilterOptions derives options from searchable foods', () async {
    final service = FoodService(
      ApiClient(
        client: MockClient((request) async {
          if (request.url.path.contains('menu-schedules/today')) {
            return http.Response(
              r'{"data":{"items":[{"_id":"menu-item-1","remainingCount":5,"isActive":true,"foodId":{"_id":"food-menu-1","name":"Com ga","price":30000,"categoryId":{"_id":"cat-rice","name":"Rice Meals"}}}]}}',
              200,
            );
          }
          if (request.url.path.contains('foods/daily')) {
            return http.Response(
              r'{"data":{"items":[{"_id":"food-daily-1","name":"Milk Tea","price":15000,"isMenuItem":false,"stockQuantity":49,"isActive":true,"categoryId":{"_id":"cat-drinks","name":"Drinks"}}]}}',
              200,
            );
          }
          return http.Response('{"data":{"items":[]}}', 404);
        }),
      ),
    );

    final options = await service.getSearchFilterOptions();

    expect(options.minPrice, 15000);
    expect(options.maxPrice, 30000);
    expect(options.categories, hasLength(2));
    expect(
      options.categories.map((category) => category.name),
      containsAll(['Rice Meals', 'Drinks']),
    );
  });

  test('filterFoods does not send price params when price filter is inactive',
      () async {
    Uri? requestedUrl;
    final service = FoodService(
      ApiClient(
        client: MockClient((request) async {
          requestedUrl = request.url;
          return http.Response('{"data":{"items":[]}}', 200);
        }),
      ),
    );

    await service.filterFoods(
      kind: null,
      categoryId: 'category-1',
      minPrice: null,
      maxPrice: null,
    );

    expect(requestedUrl, isNotNull);
    expect(requestedUrl!.path, endsWith('/foods/filter'));
    expect(requestedUrl!.queryParameters['categoryId'], 'category-1');
    expect(requestedUrl!.queryParameters.containsKey('kind'), isFalse);
    expect(requestedUrl!.queryParameters.containsKey('minPrice'), isFalse);
    expect(requestedUrl!.queryParameters.containsKey('maxPrice'), isFalse);
  });

  test('getDailyFoods requests /foods/daily endpoint', () async {
    Uri? requestedUrl;
    final service = FoodService(
      ApiClient(
        client: MockClient((request) async {
          requestedUrl = request.url;
          return http.Response('{"data":{"items":[]}}', 200);
        }),
      ),
    );

    await service.getDailyFoods();

    expect(requestedUrl, isNotNull);
    expect(requestedUrl!.path, endsWith('/foods/daily'));
  });
}
