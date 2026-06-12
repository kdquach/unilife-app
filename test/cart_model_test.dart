import 'package:flutter_test/flutter_test.dart';
import 'package:unilife_mobile/models/cart.dart';
import 'package:unilife_mobile/models/food.dart';

void main() {
  group('Cart Model Test', () {
    test('Cart.fromJson parses correctly', () {
      final json = {
        "cartId": "123",
        "userId": "456",
        "totalPrice": 100000,
        "totalItems": 2,
        "items": [
          {
            "cartItemId": "789",
            "menuScheduleItemId": "abc",
            "quantity": 2,
            "food": {
              "foodId": "def",
              "name": "Cơm Sườn Chả",
              "price": 50000,
              "imageUrl": "https://...",
              "description": "Cơm sườn nướng cực ngon"
            },
            "menuSchedule": {
              "menuScheduleId": "ghi",
              "date": "2026-06-12T00:00:00.000Z",
              "status": "PUBLISHED"
            },
            "maxServing": 20,
            "remainingCount": 10,
            "isValid": true,
            "reason": null,
            "subtotal": 100000
          }
        ]
      };

      final cart = Cart.fromJson(json);
      expect(cart.cartId, '123');
      expect(cart.userId, '456');
      expect(cart.totalPrice, 100000);
      expect(cart.totalItems, 2);
      expect(cart.items.length, 1);
      
      final item = cart.items.first;
      expect(item.cartItemId, '789');
      expect(item.quantity, 2);
      expect(item.subtotal, 100000);
      expect(item.isValid, true);
      expect(item.reason, null);
      
      expect(item.food, isNotNull);
      expect(item.food?.name, 'Cơm Sườn Chả');
      expect(item.food?.price, 50000);
      
      expect(item.menuSchedule, isNotNull);
    });

    test('Food canAddToCart is true for Regular Foods', () {
      final alwaysAvailableFood = Food(
        id: 'food-2',
        name: 'Regular Drink',
        description: 'Cola',
        price: 15000,
        imageUrl: '',
        category: 'Drinks',
        status: FoodStatus.available,
        rating: 4.0,
        kind: FoodKind.alwaysAvailable,
        stockQuantity: 10,
      );

      // Backend now supports Regular Foods in cart
      expect(alwaysAvailableFood.canAddToCart, true);
      final payload = alwaysAvailableFood.toCartAddPayload(1);
      expect(payload['foodId'], 'food-2');
      expect(payload['menuScheduleItemId'], null);
    });

    test('Food toCartAddPayload creates correct payload for Menu Food', () {
      final menuFood = Food(
        id: 'food-123',
        menuScheduleItemId: 'menu-abc',
        name: 'Menu Item',
        category: 'Cat',
        description: 'Desc',
        price: 10000,
        kind: FoodKind.menuFood,
        status: FoodStatus.available,
      );

      final menuPayload = menuFood.toCartAddPayload(2);
      expect(menuPayload.containsKey('foodId'), isFalse);
      expect(menuPayload.containsKey('dishId'), isFalse);
      expect(menuPayload['menuScheduleItemId'], 'menu-abc');
      expect(menuPayload['quantity'], 2);
    });
  });
}
