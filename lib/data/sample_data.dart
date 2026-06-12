import '../models/cart_item.dart';
import '../models/food.dart';
import '../models/order.dart';

class SampleData {
  static const List<Food> menuFoods = [
    Food(
      id: 'food_chicken_rice',
      menuScheduleItemId: 'menu_item_chicken_rice_lunch_today',
      name: 'Grilled Chicken Rice',
      category: 'Rice',
      description: 'Tender grilled chicken served with rice, fresh vegetables and UniLife sauce.',
      price: 35000,
      kind: FoodKind.menuFood,
      status: FoodStatus.available,
      remainingServings: 42,
      mealType: 'Lunch',
      menuDateLabel: 'Today',
      rating: 4.8,
    ),
    Food(
      id: 'food_beef_noodle',
      menuScheduleItemId: 'menu_item_beef_noodle_lunch_today',
      name: 'Beef Noodle Soup',
      category: 'Noodle',
      description: 'Hot beef noodle soup with herbs and rich broth.',
      price: 40000,
      kind: FoodKind.menuFood,
      status: FoodStatus.available,
      remainingServings: 28,
      mealType: 'Lunch',
      menuDateLabel: 'Today',
      rating: 4.7,
    ),
    Food(
      id: 'food_pork_rib_rice',
      menuScheduleItemId: 'menu_item_pork_rib_lunch_today',
      name: 'Pork Rib Rice',
      category: 'Rice',
      description: 'Pork rib rice with cucumber, pickles and soup.',
      price: 38000,
      kind: FoodKind.menuFood,
      status: FoodStatus.soldOut,
      remainingServings: 0,
      mealType: 'Lunch',
      menuDateLabel: 'Today',
      rating: 4.6,
    ),
    Food(
      id: 'food_vegetarian_rice',
      menuScheduleItemId: 'menu_item_vegetarian_lunch_today',
      name: 'Vegetarian Rice',
      category: 'Vegetarian',
      description: 'Balanced vegetarian rice plate with tofu and vegetables.',
      price: 30000,
      kind: FoodKind.menuFood,
      status: FoodStatus.available,
      remainingServings: 18,
      mealType: 'Lunch',
      menuDateLabel: 'Today',
      rating: 4.5,
    ),
  ];

  static const List<Food> regularFoods = [
    Food(
      id: 'food_coca_cola',
      name: 'Coca Cola',
      category: 'Drink',
      description: 'Cold soft drink available every day. Can be added with any meal order.',
      price: 12000,
      kind: FoodKind.alwaysAvailable,
      status: FoodStatus.available,
      stockQuantity: 120,
      rating: 4.7,
    ),
    Food(
      id: 'food_pepsi',
      name: 'Pepsi',
      category: 'Drink',
      description: 'Refreshing soft drink, always available at the canteen.',
      price: 12000,
      kind: FoodKind.alwaysAvailable,
      status: FoodStatus.available,
      stockQuantity: 95,
      rating: 4.6,
    ),
    Food(
      id: 'food_chocolate_cake',
      name: 'Chocolate Cake',
      category: 'Cake',
      description: 'Sweet chocolate cake for snack time.',
      price: 18000,
      kind: FoodKind.alwaysAvailable,
      status: FoodStatus.available,
      stockQuantity: 32,
      rating: 4.9,
    ),
    Food(
      id: 'food_ice_cream',
      name: 'Ice Cream',
      category: 'Ice Cream',
      description: 'Cold ice cream, available daily.',
      price: 15000,
      kind: FoodKind.alwaysAvailable,
      status: FoodStatus.available,
      stockQuantity: 54,
      rating: 4.8,
    ),
    Food(
      id: 'food_snack_pack',
      name: 'Snack Pack',
      category: 'Snack',
      description: 'Packed snack, easy to buy with lunch.',
      price: 10000,
      kind: FoodKind.alwaysAvailable,
      status: FoodStatus.outOfStock,
      stockQuantity: 0,
      rating: 4.3,
    ),
  ];

  static List<Food> get allFoods => [...menuFoods, ...regularFoods];

  static List<CartItem> initialCart = [
    CartItem(food: menuFoods[0], quantity: 2),
    CartItem(food: regularFoods[0], quantity: 1),
    CartItem(food: regularFoods[3], quantity: 1),
  ];

  static Order sampleOrder() => Order(
        id: 'order_24001',
        code: 'ORD-24001',
        status: 'Preparing',
        queueNumber: 'A12',
        items: initialCart,
        totalPrice: initialCart.fold(0, (sum, item) => sum + item.subtotal),
        paymentMethod: 'SEPAY',
        paymentStatus: 'PAID',
        createdAt: DateTime.now(),
      );
}
