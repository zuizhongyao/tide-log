import 'package:flutter/material.dart';

/// 「汐语」全局色彩系统 —— 柔和护眼的潮汐色系。
///
/// 色彩语义约定（全 App 统一引用，日历页与圆环直接复用）：
/// - 潮汐蓝 [tide]：主色，交互元素、圆环底色；
/// - 珊瑚粉 [coral]：经期（实际出血）；
/// - 浅珊瑚 [coralSoft]：预测经期（未来推算）；
/// - 雾紫 [ovulation] / [fertile]：排卵日 / 易孕期；
/// - 浅苔绿 [safe]：安全期。
class AppColors {
  AppColors._();

  // ---- 主色：潮汐 ----
  static const Color tide = Color(0xFF4E8FA3);
  static const Color tideDeep = Color(0xFF2F6675);
  static const Color tideLight = Color(0xFFC9E4EA);
  static const Color tideMist = Color(0xFFEEF6F8);

  // ---- 强调色：经期珊瑚 ----
  static const Color coral = Color(0xFFE88C7D);
  static const Color coralDeep = Color(0xFFD96D5C);
  static const Color coralSoft = Color(0xFFF7D9D3);
  static const Color coralFaint = Color(0xFFFCEEEB);

  // ---- 周期语义色 ----
  static const Color ovulation = Color(0xFF9C89B8);
  static const Color fertile = Color(0xFFCDBFDF);
  static const Color safe = Color(0xFFA8C6A9);

  // ---- 中性色 ----
  static const Color background = Color(0xFFFAF8F5);
  static const Color card = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF2E3B42);
  static const Color textSecondary = Color(0xFF8296A0);
  static const Color divider = Color(0xFFE9EDEC);
  static const Color danger = Color(0xFFD9776B);

  /// 主页潮汐圆环使用的海洋渐变。
  static const LinearGradient tideGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [tideLight, tide, tideDeep],
  );

  /// 经期日使用的珊瑚渐变。
  static const LinearGradient coralGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [coralSoft, coral],
  );
}

/// 全局 Material 3 主题。
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.tide,
        primary: AppColors.tide,
        onPrimary: Colors.white,
        secondary: AppColors.coral,
        onSecondary: Colors.white,
        surface: AppColors.card,
        onSurface: AppColors.textPrimary,
        error: AppColors.danger,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.divider, width: 0.5),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.tideMist,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.tide, width: 1.4),
        ),
        hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.tide,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(64, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.tide),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.tideMist,
        selectedColor: AppColors.tideLight,
        checkmarkColor: AppColors.tideDeep,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        labelStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 0.5,
        space: 0.5,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.tideDeep,
        contentTextStyle: TextStyle(color: Colors.white, fontSize: 14),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.card,
        selectedItemColor: AppColors.tide,
        unselectedItemColor: AppColors.textSecondary,
      ),
    );
  }
}
