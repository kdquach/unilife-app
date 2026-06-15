import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'routes/app_routes.dart';
import 'screens/splash/splash_screen.dart';

class UniLifeApp extends StatelessWidget {
  const UniLifeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'UniLife',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: SplashScreen.routeName,
        onGenerateRoute: AppRoutes.onGenerateRoute,
      ),
    );
  }
}
