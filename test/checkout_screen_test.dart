import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unilife_mobile/models/cart.dart';
import 'package:unilife_mobile/models/cart_item.dart';
import 'package:unilife_mobile/models/food.dart';
import 'package:unilife_mobile/screens/cart/checkout_screen.dart';
import 'package:unilife_mobile/states/cart_provider.dart';

class MockCartNotifier extends CartNotifier {
  final Cart mockCart;
  MockCartNotifier(this.mockCart);

  @override
  Future<Cart?> build() async {
    return mockCart;
  }
}

void main() {
  group('CheckoutScreen', () {
    late Cart mockCart;
    late Cart emptyCart;

    setUp(() {
      final mockFood = const Food(
        id: 'food_1',
        name: 'Spicy Chicken Rice',
        category: 'Lunch',
        description: 'Delicious',
        price: 35000,
        kind: FoodKind.alwaysAvailable,
        status: FoodStatus.available,
      );

      final mockCartItemDto = CartItemDto(
        cartItemId: 'item_1',
        quantity: 2,
        food: mockFood,
        isValid: true,
        subtotal: 70000,
      );

      mockCart = Cart(
        cartId: 'cart_1',
        userId: 'user_1',
        totalPrice: 70000,
        totalItems: 2,
        items: [mockCartItemDto],
      );

      emptyCart = Cart(
        cartId: 'cart_1',
        userId: 'user_1',
        totalPrice: 0,
        totalItems: 0,
        items: [],
      );
    });

    Widget buildTestWidget(Cart cart) {
      return ProviderScope(
        overrides: [
          cartProvider.overrideWith(() => MockCartNotifier(cart)),
        ],
        child: const MaterialApp(
          home: CheckoutScreen(),
        ),
      );
    }

    testWidgets('does NOT crash with RenderBox layout error', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(mockCart));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('uses standard AppBar consistent with other screens', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(mockCart));
      await tester.pumpAndSettle();

      // Must have a standard AppBar (not a custom gradient header)
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Checkout'), findsOneWidget);
    });

    testWidgets('renders food item with name, quantity badge, and subtotal', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(mockCart));
      await tester.pumpAndSettle();

      expect(find.text('Spicy Chicken Rice'), findsOneWidget);
      expect(find.text('x2'), findsOneWidget);
    });

    testWidgets('renders SePay payment method with check mark', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(mockCart));
      await tester.pumpAndSettle();

      expect(find.text('SePay'), findsOneWidget);
      expect(find.text('Scan QR code via banking app'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('renders bottom bar with Pay Now button and total', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(mockCart));
      await tester.pumpAndSettle();

      expect(find.textContaining('Pay Now'), findsOneWidget);
      expect(find.text('Total Payment'), findsOneWidget);
    });

    testWidgets('renders order summary with Free payment fee', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(mockCart));
      await tester.pumpAndSettle();

      expect(find.text('Order Summary'), findsOneWidget);
      expect(find.text('Payment Fee'), findsOneWidget);
      expect(find.text('Free'), findsOneWidget);
    });

    testWidgets('does NOT show old Vietnamese strings or placeholder text', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(mockCart));
      await tester.pumpAndSettle();

      expect(find.text('Quét mã QR qua ứng dụng ngân hàng'), findsNothing);
      expect(find.text('Backend data mapping'), findsNothing);
      expect(find.text('Proceed to Payment'), findsNothing);
    });

    testWidgets('shows empty state when cart is empty', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(emptyCart));
      await tester.pumpAndSettle();

      expect(find.text('Your cart is empty'), findsOneWidget);
      expect(find.byIcon(Icons.shopping_bag_outlined), findsOneWidget);
    });

    testWidgets('renders correctly with multiple cart items without crash', (WidgetTester tester) async {
      final food1 = const Food(id: 'f1', name: 'Item A', category: 'Cat', description: '', price: 10000, kind: FoodKind.alwaysAvailable, status: FoodStatus.available);
      final food2 = const Food(id: 'f2', name: 'Item B', category: 'Cat', description: '', price: 20000, kind: FoodKind.alwaysAvailable, status: FoodStatus.available);
      final multiCart = Cart(
        cartId: 'c1', userId: 'u1', totalPrice: 50000, totalItems: 3,
        items: [
          CartItemDto(cartItemId: 'i1', quantity: 1, food: food1, isValid: true, subtotal: 10000),
          CartItemDto(cartItemId: 'i2', quantity: 2, food: food2, isValid: true, subtotal: 40000),
        ],
      );

      await tester.pumpWidget(buildTestWidget(multiCart));
      await tester.pumpAndSettle();

      expect(find.text('Item A'), findsOneWidget);
      expect(find.text('Item B'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
