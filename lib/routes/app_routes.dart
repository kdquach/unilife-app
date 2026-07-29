import 'package:flutter/material.dart';

import '../models/customer_rating.dart';
import '../models/food.dart';
import '../models/order.dart';
import '../models/user_notification.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/reset_password_screen.dart';
import '../screens/auth/verify_register_otp_screen.dart';
import '../screens/cart/cart_screen.dart';
import '../screens/cart/checkout_screen.dart';
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
      case VerifyRegisterOtpScreen.routeName:
        final args = settings.arguments;
        final email = args is VerifyRegisterOtpArgs ? args.email : '';
        return _route(VerifyRegisterOtpScreen(email: email));
      case ForgotPasswordScreen.routeName:
        return _route(const ForgotPasswordScreen());
      case ResetPasswordScreen.routeName:
        final args = settings.arguments;
        final email = args is ResetPasswordArgs ? args.email : '';
        return _route(ResetPasswordScreen(email: email));
      case MainShell.routeName:
        final arguments = settings.arguments;
        int initialIndex = 0;
        String? categoryId;
        String? categoryName;
        bool todayOnly = false;
        String? menuTab;
        if (arguments is Map) {
          initialIndex = arguments['tabIndex'] as int? ?? 0;
          categoryId = arguments['categoryId'] as String?;
          categoryName = arguments['categoryName'] as String?;
          todayOnly = arguments['todayOnly'] as bool? ?? false;
          menuTab = arguments['menuTab'] as String?;
        }
        return _route(
          MainShell(
            initialIndex: initialIndex,
            initialMenuCategoryId: categoryId,
            initialMenuCategoryName: categoryName,
            initialMenuTodayOnly: todayOnly,
            initialMenuTab: menuTab,
          ),
        );
      case TodayMenuScreen.routeName:
        final arguments = settings.arguments;
        String? categoryName;
        if (arguments is Map) {
          categoryName = arguments['categoryName'] as String?;
        }
        return _route(TodayMenuScreen(preselectedCategoryName: categoryName));
      case WeeklyMenuScreen.routeName:
        final arguments = settings.arguments;
        String? categoryName;
        if (arguments is Map) {
          categoryName = arguments['categoryName'] as String?;
        }
        return _route(WeeklyMenuScreen(preselectedCategoryName: categoryName));
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
      case CheckoutScreen.routeName:
        return _route(const CheckoutScreen());
      case SepayPaymentScreen.routeName:
        final order = settings.arguments as Order;
        return _route(SepayPaymentScreen(order: order));
      case PaymentSuccessScreen.routeName:
        final arguments = settings.arguments;
        String orderId = '';
        String? orderCode;
        if (arguments is Map) {
          orderId = arguments['orderId'] as String? ?? '';
          orderCode = arguments['orderCode'] as String?;
        } else if (arguments is String) {
          orderId = arguments;
        }
        return _route(
            PaymentSuccessScreen(orderId: orderId, orderCode: orderCode));
      case OrderListScreen.routeName:
        final arguments = settings.arguments;
        String initialTab = 'Active';
        if (arguments is Map) {
          initialTab = arguments['initialTab'] as String? ?? 'Active';
        }
        return _route(OrderListScreen(initialTab: initialTab));
      case OrderDetailScreen.routeName:
        final orderId = settings.arguments as String? ?? '';
        return _route(OrderDetailScreen(orderId: orderId));
      case NotificationsScreen.routeName:
        return _route(const NotificationsScreen());
      case NotificationDetailScreen.routeName:
        final notification = settings.arguments is UserNotification
            ? settings.arguments as UserNotification
            : null;
        return _route(
          NotificationDetailScreen(initialNotification: notification),
        );
      case RatingListScreen.routeName:
        final arguments = settings.arguments;
        return _route(
          RatingListScreen(
            args: arguments is RatingListArgs ? arguments : null,
          ),
        );
      case CreateRatingScreen.routeName:
        final arguments = settings.arguments;
        Order? order;
        CustomerRating? rating;
        if (arguments is CreateRatingArgs) {
          order = arguments.order;
          rating = arguments.rating;
        } else if (arguments is Order) {
          order = arguments;
        } else if (arguments is CustomerRating) {
          rating = arguments;
        }
        return _route(CreateRatingScreen(initialOrder: order, rating: rating));
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
