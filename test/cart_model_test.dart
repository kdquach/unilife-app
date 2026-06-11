import 'package:flutter_test/flutter_test.dart';
import 'package:unilife_mobile/models/cart.dart';

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
  });
}
