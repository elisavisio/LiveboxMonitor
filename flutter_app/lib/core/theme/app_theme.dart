import 'package:material_ui/material_ui.dart';

class AppColors {
  AppColors._();

  // Brand Orange (Livebox inspired)
  static const Color orange = Color(0xFFFF7900);
  static const Color orangeLight = Color(0xFFFF9E44);
  static const Color orangeDark = Color(0xFFD96400);

  // Semantic colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF38BDF8);
  static const Color purple = Color(0xFFA855F7);
  static const Color teal = Color(0xFF14B8A6);

  // Dark surface hierarchy
  static const Color darkCanvas = Color(0xFF0E1117);
  static const Color darkSidebar = Color(0xFF121620);
  static const Color darkCard = Color(0xFF171C28);
  static const Color darkElevated = Color(0xFF1E2534);
  static const Color darkBorder = Color(0xFF283144);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  // Light surface hierarchy
  static const Color lightCanvas = Color(0xFFF4F6FA);
  static const Color lightSidebar = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightElevated = Color(0xFFEEF1F7);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
}

class AppTheme {
  AppTheme._();

  static const TextStyle monoStyle = TextStyle(
    fontFamily: 'monospace',
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.orange,
      brightness: Brightness.dark,
      primary: AppColors.orange,
      onPrimary: Colors.white,
      secondary: AppColors.info,
      surface: AppColors.darkCard,
      onSurface: AppColors.darkTextPrimary,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.darkCanvas,
      cardColor: AppColors.darkCard,
      dividerColor: AppColors.darkBorder,
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkCard,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkElevated,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.orange, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkTextPrimary,
          side: const BorderSide(color: AppColors.darkBorder),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkElevated,
        selectedColor: AppColors.orange.withValues(alpha: 0.2),
        side: const BorderSide(color: AppColors.darkBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: const TextStyle(fontSize: 12),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(AppColors.darkElevated),
        headingTextStyle: const TextStyle(
          color: AppColors.darkTextSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
          letterSpacing: 0.3,
        ),
        dataRowMinHeight: 44,
        dataRowMaxHeight: 52,
        dividerThickness: 0.6,
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: AppColors.orange,
        labelColor: AppColors.orange,
        unselectedLabelColor: AppColors.darkTextSecondary,
        dividerColor: AppColors.darkBorder,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.darkElevated,
        contentTextStyle: const TextStyle(color: AppColors.darkTextPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.darkElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.darkBorder),
        ),
        textStyle: const TextStyle(color: AppColors.darkTextPrimary, fontSize: 12),
      ),
    );
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.orange,
      brightness: Brightness.light,
      primary: AppColors.orange,
      onPrimary: Colors.white,
      secondary: const Color(0xFF0284C7),
      surface: AppColors.lightCard,
      onSurface: AppColors.lightTextPrimary,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.lightCanvas,
      cardColor: AppColors.lightCard,
      dividerColor: AppColors.lightBorder,
      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightCard,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightElevated,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.orange, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.lightTextPrimary,
          side: const BorderSide(color: AppColors.lightBorder),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightElevated,
        selectedColor: AppColors.orange.withValues(alpha: 0.14),
        side: const BorderSide(color: AppColors.lightBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: const TextStyle(fontSize: 12),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(AppColors.lightElevated),
        headingTextStyle: const TextStyle(
          color: AppColors.lightTextSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
          letterSpacing: 0.3,
        ),
        dataRowMinHeight: 44,
        dataRowMaxHeight: 52,
        dividerThickness: 0.6,
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: AppColors.orange,
        labelColor: AppColors.orange,
        unselectedLabelColor: AppColors.lightTextSecondary,
        dividerColor: AppColors.lightBorder,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

extension ThemeContextExt on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get borderColor => isDark ? AppColors.darkBorder : AppColors.lightBorder;
  Color get subtleSurface => isDark ? AppColors.darkElevated : AppColors.lightElevated;
  Color get sidebarColor => isDark ? AppColors.darkSidebar : AppColors.lightSidebar;
  Color get textSecondary => isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
}
