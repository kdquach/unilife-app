import 'package:flutter/material.dart';

import '../models/food.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/reset_password_screen.dart';
import '../screens/cart/cart_screen.dart';
import '../screens/cart/checkout_data_note_screen.dart';
import '../screens/food/food_detail_screen.dart';
import '../screens/home/main_shell.dart';
import '../screens/menu/always_available_screen.dart';
import '../screens/menu/today_menu_screen.dart';
import '../screens/menu/weekly_menu_screen.dart';
import '../screens/notification/notification_detail_screen.dart';
import '../screens/notification/notifications_screen.dart';
import '../screens/order/order_detail_screen.dart';
import '../screens/order/order_list_screen.dart';
import '../screens/payment/payment_success_screen.dart';
import '../screens/payment/sepay_payment_screen.dart';
import '../screens/profile/change_password_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/profile/upload_avatar_screen.dart';
import '../screens/rating/create_rating_screen.dart';
import '../screens/rating/rating_list_screen.dart';
import '../screens/rating/rating_success_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/states/ui_states_screen.dart';

class AppRoutes {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case SplashScreen.routeName:
        return _route(const SplashScreen());
      case LoginScreen.routeName:
        return _route(const LoginScreen());
      case RegisterScreen.routeName:
        return _route(const RegisterScreen());
      case ForgotPasswordScreen.routeName:
        return _route(const ForgotPasswordScreen());
      case ResetPasswordScreen.routeName:
        return _route(const ResetPasswordScreen());
      case MainShell.routeName:
        final arguments = settings.arguments;
        int initialIndex = 0;
        String? categoryId;
        String? categoryName;
        bool todayOnly = false;
        if (arguments is Map) {
          initialIndex = arguments['tabIndex'] as int? ?? 0;
          categoryId = arguments['categoryId'] as String?;
          categoryName = arguments['categoryName'] as String?;
          todayOnly = arguments['todayOnly'] as bool? ?? false;
        }
        return _route(
          MainShell(
            initialIndex: initialIndex,
            initialMenuCategoryId: categoryId,
            initialMenuCategoryName: categoryName,
            initialMenuTodayOnly: todayOnly,
          ),
        );
      case TodayMenuScreen.routeName:
        return _route(const TodayMenuScreen());
      case WeeklyMenuScreen.routeName:
        return _route(const WeeklyMenuScreen());
      case AlwaysAvailableScreen.routeName:
        final arguments = settings.arguments;
        String? categoryId;
        String? categoryName;
        if (arguments is Map) {
          categoryId = arguments['categoryId'] as String?;
          categoryName = arguments['categoryName'] as String?;
        } else {
          categoryName = arguments as String?;
        }
        return _route(
          AlwaysAvailableScreen(
            preselectedCategoryId: categoryId,
            preselectedCategoryName: categoryName,
          ),
        );

      case FoodDetailScreen.routeName:
        return _route(FoodDetailScreen(food: settings.arguments as Food));
      case CartScreen.routeName:
        return _route(const CartScreen());
      case CheckoutDataNoteScreen.routeName:
        return _route(const CheckoutDataNoteScreen());
      case SepayPaymentScreen.routeName:
        return _route(const SepayPaymentScreen());
      case PaymentSuccessScreen.routeName:
        return _route(const PaymentSuccessScreen());
      case OrderListScreen.routeName:
        return _route(const OrderListScreen());
      case OrderDetailScreen.routeName:
        return _route(const OrderDetailScreen());
      case NotificationsScreen.routeName:
        return _route(const NotificationsScreen());
      case NotificationDetailScreen.routeName:
        return _route(const NotificationDetailScreen());
      case RatingListScreen.routeName:
        return _route(const RatingListScreen());
      case CreateRatingScreen.routeName:
        return _route(const CreateRatingScreen());
      case RatingSuccessScreen.routeName:
        return _route(const RatingSuccessScreen());
      case EditProfileScreen.routeName:
        return _route(const EditProfileScreen());
      case UploadAvatarScreen.routeName:
        return _route(const UploadAvatarScreen());
      case ChangePasswordScreen.routeName:
        return _route(const ChangePasswordScreen());
      case UiStatesScreen.routeName:
        return _route(const UiStatesScreen());
      default:
        return _route(const LoginScreen());
    }
  }

  static MaterialPageRoute<dynamic> _route(Widget page) {
    return MaterialPageRoute(builder: (_) => page);
  }
}
