import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config/app_colors.dart';
import 'config/app_settings.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.instance.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      primary: isDark ? const Color(0xFFFF8CA3) : AppColors.primary,
      secondary: AppColors.accent,
      surface: isDark ? const Color(0xFF171923) : AppColors.surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF10131A)
          : AppColors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : AppColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : AppColors.textPrimary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF2B3040) : AppColors.primary,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF1A1F2A) : AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF171923) : AppColors.surface,
        indicatorColor: isDark ? const Color(0x33E85D75) : AppColors.secondary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: AppSettings.instance.themeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}
