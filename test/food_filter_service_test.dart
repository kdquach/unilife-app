import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:unilife_mobile/services/api_client.dart';
import 'package:unilife_mobile/services/food_service.dart';

void main() {
  test('searchFoods sends keyword with selected filters', () async {
    Uri? requestedUrl;
    final service = FoodService(
      ApiClient(
        client: MockClient((request) async {
          requestedUrl = request.url;
          return http.Response('{"data":{"items":[]}}', 200);
        }),
      ),
    );

    await service.searchFoods(
      keyword: ' rice ',
      categoryId: 'category-1',
      minPrice: 10000,
      maxPrice: 30000,
      sortBy: 'price',
      sortOrder: 'asc',
    );

    expect(requestedUrl, isNotNull);
    expect(requestedUrl!.path, endsWith('/foods/search'));
    expect(requestedUrl!.queryParameters['keyword'], 'rice');
    expect(requestedUrl!.queryParameters['categoryId'], 'category-1');
    expect(requestedUrl!.queryParameters['minPrice'], '10000');
    expect(requestedUrl!.queryParameters['maxPrice'], '30000');
    expect(requestedUrl!.queryParameters['sortBy'], 'price');
    expect(requestedUrl!.queryParameters['sortOrder'], 'asc');
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

  test('getAllFoodFilterOptions requests filter options without kind', () async {
    Uri? requestedUrl;
    final service = FoodService(
      ApiClient(
        client: MockClient((request) async {
          requestedUrl = request.url;
          return http.Response(
            '{"data":{"categories":[],"priceRange":{"minPrice":8000,"maxPrice":35000}}}',
            200,
          );
        }),
      ),
    );

    final options = await service.getAllFoodFilterOptions();

    expect(options.minPrice, 8000);
    expect(options.maxPrice, 35000);
    expect(requestedUrl, isNotNull);
    expect(requestedUrl!.path, endsWith('/foods/filter-options'));
    expect(requestedUrl!.queryParameters.containsKey('kind'), isFalse);
  });
}
