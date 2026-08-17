import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ============================================================================
// FINZO PREMIUM THEME - Inspired by Spotify, Instagram & Modern Finance Apps
// Sophisticated, warm, premium feel with smooth transitions
// ============================================================================

/// App-wide color constants for Light Theme
class FinzoColors {
  // Brand Colors - Warm, premium gold/copper tones
  static const Color brandPrimary = Color(0xFF1A1A2E);  // Deep navy
  static const Color brandAccent = Color(0xFFD4A574);   // Warm copper/gold
  static const Color brandGradientStart = Color(0xFF16213E);
  static const Color brandGradientEnd = Color(0xFF0F3460);
  
  // Background Colors - Warm off-whites
  static const Color background = Color(0xFFFAF9F7);   // Warm white
  static const Color backgroundSecondary = Color(0xFFF5F3EF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF0EDE8);
  
  // Text Colors - Warm grays
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnAccent = Color(0xFF1A1A2E);
  
  // Border & Divider - Subtle warm tones
  static const Color border = Color(0xFFE5E2DC);
  static const Color divider = Color(0xFFF0EDE8);
  
  // Status Colors - Muted, sophisticated
  static const Color success = Color(0xFF059669);  // Emerald
  static const Color warning = Color(0xFFD97706);  // Amber
  static const Color error = Color(0xFFDC2626);    // Red
  static const Color info = Color(0xFF0284C7);     // Sky blue
  
  // Financial Colors
  static const Color income = Color(0xFF059669);
  static const Color expense = Color(0xFFDC2626);
  static const Color neutral = Color(0xFF6B7280);
  
  // Interactive - Premium gold accent
  static const Color link = Color(0xFF0F3460);
  static const Color buttonPrimary = Color(0xFF1A1A2E);
  static const Color buttonSecondary = Color(0xFFF0EDE8);
  
  // Secondary brand color
  static const Color brandSecondary = Color(0xFFD4A574);
  
  // Premium gradients
  static const List<Color> premiumGradient = [
    Color(0xFF1A1A2E),
    Color(0xFF16213E),
  ];
  
  static const List<Color> goldGradient = [
    Color(0xFFD4A574),
    Color(0xFFB8956E),
  ];
  
  static const List<Color> warmGradient = [
    Color(0xFFF5F3EF),
    Color(0xFFE8E4DD),
  ];

  // Specific gradient requested by user (Navy -> Gold)
  static const List<Color> darkToGoldGradient = [
    Color(0xFF1A1A2E),
    Color(0xFFD4A574),
  ];
}

/// App-wide color constants for Dark Theme - Spotify-inspired
class FinzoColorsDark {
  // Brand Colors
  static const Color brandPrimary = Color(0xFFF5F3EF);
  static const Color brandAccent = Color(0xFFD4A574);   // Warm copper/gold
  static const Color brandGradientStart = Color(0xFF1A1A2E);
  static const Color brandGradientEnd = Color(0xFF16213E);
  
  // Background Colors - Deep, warm blacks (Spotify-style)
  static const Color background = Color(0xFF0D0D0D);   // Near black
  static const Color backgroundSecondary = Color(0xFF161616);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color surfaceVariant = Color(0xFF282828);
  
  // Text Colors - Warm whites
  static const Color textPrimary = Color(0xFFF5F3EF);
  static const Color textSecondary = Color(0xFFA3A3A3);
  static const Color textTertiary = Color(0xFF6B6B6B);
  static const Color textOnPrimary = Color(0xFF0D0D0D);
  static const Color textOnAccent = Color(0xFF1A1A2E);
  
  // Border & Divider
  static const Color border = Color(0xFF333333);
  static const Color divider = Color(0xFF262626);
  
  // Status Colors - Vibrant but not harsh
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFFBBF24);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF38BDF8);
  
  // Financial Colors
  static const Color income = Color(0xFF10B981);
  static const Color expense = Color(0xFFEF4444);
  static const Color neutral = Color(0xFFA3A3A3);
  
  // Interactive
  static const Color link = Color(0xFFD4A574);
  static const Color buttonPrimary = Color(0xFFD4A574);
  static const Color buttonSecondary = Color(0xFF282828);
  
  // Secondary brand color
  static const Color brandSecondary = Color(0xFFD4A574);
  
  // Premium gradients
  static const List<Color> premiumGradient = [
    Color(0xFF1A1A2E),
    Color(0xFF0D0D0D),
  ];
  
  static const List<Color> goldGradient = [
    Color(0xFFD4A574),
    Color(0xFFB8956E),
  ];
  
  static const List<Color> cardGradient = [
    Color(0xFF1E1E1E),
    Color(0xFF161616),
  ];

  static const List<Color> darkToGoldGradient = [
    Color(0xFF1A1A2E),
    Color(0xFFD4A574),
  ];
}

/// Dynamic color helper that respects current theme
class FinzoTheme {
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  // Brand
  static Color brandPrimary(BuildContext context) =>
      isDark(context) ? FinzoColorsDark.brandPrimary : FinzoColors.brandPrimary;
  
  static Color brandSecondary(BuildContext context) =>
      isDark(context) ? FinzoColorsDark.brandSecondary : FinzoColors.brandSecondary;
  
  static Color brandAccent(BuildContext context) =>
      isDark(context) ? FinzoColorsDark.brandAccent : FinzoColors.brandAccent;

  // Background
  static Color background(BuildContext context) =>
      isDark(context) ? FinzoColorsDark.background : FinzoColors.background;
  
  static Color backgroundSecondary(BuildContext context) =>
      isDark(context) ? FinzoColorsDark.backgroundSecondary : FinzoColors.backgroundSecondary;
  
  static Color surface(BuildContext context) =>
      isDark(context) ? FinzoColorsDark.surface : FinzoColors.surface;
  
  static Color surfaceVariant(BuildContext context) =>
      isDark(context) ? FinzoColorsDark.surfaceVariant : FinzoColors.surfaceVariant;

  // Text
  static Color textPrimary(BuildContext context) =>
      isDark(context) ? FinzoColorsDark.textPrimary : FinzoColors.textPrimary;
  
  static Color textSecondary(BuildContext context) =>
      isDark(context) ? FinzoColorsDark.textSecondary : FinzoColors.textSecondary;
  
  static Color textTertiary(BuildContext context) =>
      isDark(context) ? FinzoColorsDark.textTertiary : FinzoColors.textTertiary;

  // Border
  static Color border(BuildContext context) =>
      isDark(context) ? FinzoColorsDark.border : FinzoColors.border;
  
  static Color divider(BuildContext context) =>
      isDark(context) ? FinzoColorsDark.divider : FinzoColors.divider;

  // Status
  static Color success(BuildContext context) =>
      isDark(context) ? FinzoColorsDark.success : FinzoColors.success;
  
  static Color warning(BuildContext context) =>
      isDark(context) ? FinzoColorsDark.warning : FinzoColors.warning;
  
  static Color error(BuildContext context) =>
      isDark(context) ? FinzoColorsDark.error : FinzoColors.error;
  
  static Color info(BuildContext context) =>
      isDark(context) ? FinzoColorsDark.info : FinzoColors.info;

  // Financial
  static Color income(BuildContext context) =>
      isDark(context) ? FinzoColorsDark.income : FinzoColors.income;
  
  static Color expense(BuildContext context) =>
      isDark(context) ? FinzoColorsDark.expense : FinzoColors.expense;

  // Button
  static Color buttonPrimary(BuildContext context) =>
      isDark(context) ? FinzoColorsDark.buttonPrimary : FinzoColors.buttonPrimary;
  
  static Color buttonSecondary(BuildContext context) =>
      isDark(context) ? FinzoColorsDark.buttonSecondary : FinzoColors.buttonSecondary;
}

/// Typography - Instagram-inspired clean fonts
/// All methods accept an optional {Color? color} for flexible use
class FinzoTypography {
  // Use system font for best cross-platform rendering
  static String get fontFamily => GoogleFonts.inter().fontFamily ?? 'Inter';

  // Display - Large headlines
  static TextStyle displayLarge({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.2,
    color: color ?? FinzoColors.textPrimary,
  );

  static TextStyle displayMedium({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.25,
    color: color ?? FinzoColors.textPrimary,
  );

  static TextStyle displaySmall({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.3,
    color: color ?? FinzoColors.textPrimary,
  );

  // Headline
  static TextStyle headlineLarge({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.35,
    color: color ?? FinzoColors.textPrimary,
  );

  static TextStyle headlineMedium({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.4,
    color: color ?? FinzoColors.textPrimary,
  );

  static TextStyle headlineSmall({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: color ?? FinzoColors.textPrimary,
  );

  // Title
  static TextStyle titleLarge({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.5,
    color: color ?? FinzoColors.textPrimary,
  );

  static TextStyle titleMedium({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: color ?? FinzoColors.textPrimary,
  );

  static TextStyle titleSmall({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: color ?? FinzoColors.textPrimary,
  );

  // Body
  static TextStyle bodyLarge({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: color ?? FinzoColors.textPrimary,
  );

  static TextStyle bodyMedium({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: color ?? FinzoColors.textPrimary,
  );

  static TextStyle bodySmall({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: color ?? FinzoColors.textSecondary,
  );

  // Label
  static TextStyle labelLarge({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: color ?? FinzoColors.textPrimary,
  );

  static TextStyle labelMedium({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: color ?? FinzoColors.textSecondary,
  );

  static TextStyle labelSmall({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: color ?? FinzoColors.textSecondary,
  );

  // Amount/Money display
  static TextStyle amountLarge({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.2,
    color: color ?? FinzoColors.textPrimary,
  );

  static TextStyle amountMedium({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    height: 1.3,
    color: color ?? FinzoColors.textPrimary,
  );

  static TextStyle amountSmall({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.4,
    color: color ?? FinzoColors.textPrimary,
  );

  // Button text
  static TextStyle button({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.3,
    color: color ?? FinzoColors.textOnAccent,
  );
}

/// Spacing constants
class FinzoSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

/// Border radius constants
class FinzoRadius {
  static const double sm = 4;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double xxl = 20;
  static const double full = 999;
}

/// Box shadows
class FinzoShadows {
  // Static versions without context (for light mode default)
  static List<BoxShadow> get small => [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];
  
  static List<BoxShadow> get medium => [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> get large => [
    BoxShadow(
      color: Colors.black.withOpacity(0.12),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
  
  // Context-aware versions
  static List<BoxShadow> sm(BuildContext context) => [
    BoxShadow(
      color: FinzoTheme.isDark(context)
          ? Colors.black.withOpacity(0.3)
          : Colors.black.withOpacity(0.05),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> md(BuildContext context) => [
    BoxShadow(
      color: FinzoTheme.isDark(context)
          ? Colors.black.withOpacity(0.4)
          : Colors.black.withOpacity(0.08),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> lg(BuildContext context) => [
    BoxShadow(
      color: FinzoTheme.isDark(context)
          ? Colors.black.withOpacity(0.5)
          : Colors.black.withOpacity(0.12),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
}

/// App Theme Data
class FinzoAppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: FinzoTypography.fontFamily,
      scaffoldBackgroundColor: FinzoColors.background,
      
      colorScheme: const ColorScheme.light(
        primary: FinzoColors.brandAccent,
        secondary: FinzoColors.textSecondary,
        surface: FinzoColors.surface,
        error: FinzoColors.error,
        onPrimary: Colors.white,
        onSecondary: FinzoColors.textPrimary,
        onSurface: FinzoColors.textPrimary,
        onError: Colors.white,
      ),
      
      appBarTheme: AppBarTheme(
        backgroundColor: FinzoColors.background,
        foregroundColor: FinzoColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: FinzoTypography.fontFamily,
          color: FinzoColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(
          color: FinzoColors.textPrimary,
          size: 24,
        ),
      ),
      
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: FinzoColors.background,
        selectedItemColor: FinzoColors.textPrimary,
        unselectedItemColor: FinzoColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
      ),
      
      cardTheme: CardThemeData(
        color: FinzoColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FinzoRadius.lg),
          side: const BorderSide(color: FinzoColors.border, width: 0.5),
        ),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FinzoColors.surfaceVariant,
        hintStyle: TextStyle(
          color: FinzoColors.textSecondary.withOpacity(0.7),
          fontWeight: FontWeight.w400,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FinzoRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FinzoRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FinzoRadius.md),
          borderSide: const BorderSide(color: FinzoColors.brandAccent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FinzoRadius.md),
          borderSide: const BorderSide(color: FinzoColors.error, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: FinzoColors.brandAccent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FinzoRadius.lg),
          ),
          elevation: 0,
          textStyle: TextStyle(
            fontFamily: FinzoTypography.fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: FinzoColors.brandAccent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FinzoRadius.lg),
          ),
          textStyle: TextStyle(
            fontFamily: FinzoTypography.fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: FinzoColors.textPrimary,
          side: const BorderSide(color: FinzoColors.border),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FinzoRadius.md),
          ),
          textStyle: TextStyle(
            fontFamily: FinzoTypography.fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: FinzoColors.brandAccent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: TextStyle(
            fontFamily: FinzoTypography.fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      dividerTheme: const DividerThemeData(
        color: FinzoColors.divider,
        thickness: 0.5,
        space: 0,
      ),
      
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: FinzoColors.brandAccent,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: FinzoTypography.fontFamily,
      scaffoldBackgroundColor: FinzoColorsDark.background,
      
      colorScheme: const ColorScheme.dark(
        primary: FinzoColorsDark.brandAccent,
        secondary: FinzoColorsDark.textSecondary,
        surface: FinzoColorsDark.surface,
        error: FinzoColorsDark.error,
        onPrimary: Colors.white,
        onSecondary: FinzoColorsDark.textPrimary,
        onSurface: FinzoColorsDark.textPrimary,
        onError: Colors.white,
      ),
      
      appBarTheme: AppBarTheme(
        backgroundColor: FinzoColorsDark.background,
        foregroundColor: FinzoColorsDark.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: FinzoTypography.fontFamily,
          color: FinzoColorsDark.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(
          color: FinzoColorsDark.textPrimary,
          size: 24,
        ),
      ),
      
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: FinzoColorsDark.background,
        selectedItemColor: FinzoColorsDark.textPrimary,
        unselectedItemColor: FinzoColorsDark.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
      ),
      
      cardTheme: CardThemeData(
        color: FinzoColorsDark.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FinzoRadius.lg),
          side: const BorderSide(color: FinzoColorsDark.border, width: 0.5),
        ),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FinzoColorsDark.surfaceVariant,
        hintStyle: TextStyle(
          color: FinzoColorsDark.textSecondary.withOpacity(0.7),
          fontWeight: FontWeight.w400,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FinzoRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FinzoRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FinzoRadius.md),
          borderSide: const BorderSide(color: FinzoColorsDark.brandAccent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FinzoRadius.md),
          borderSide: const BorderSide(color: FinzoColorsDark.error, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: FinzoColorsDark.brandAccent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FinzoRadius.lg),
          ),
          elevation: 0,
          textStyle: TextStyle(
            fontFamily: FinzoTypography.fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: FinzoColorsDark.brandAccent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FinzoRadius.lg),
          ),
          textStyle: TextStyle(
            fontFamily: FinzoTypography.fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: FinzoColorsDark.textPrimary,
          side: const BorderSide(color: FinzoColorsDark.border),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FinzoRadius.md),
          ),
          textStyle: TextStyle(
            fontFamily: FinzoTypography.fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: FinzoColorsDark.brandAccent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: TextStyle(
            fontFamily: FinzoTypography.fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      dividerTheme: const DividerThemeData(
        color: FinzoColorsDark.divider,
        thickness: 0.5,
        space: 0,
      ),
      
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: FinzoColorsDark.brandAccent,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
    );
  }
}

// ============================================================================
// BACKWARD COMPATIBILITY ALIASES
// These allow older code using AppColors, AppColorsDark, etc. to still work
// ============================================================================

/// Alias for backward compatibility - maps to FinzoColors
class AppColors {
  static const Color primary = FinzoColors.brandAccent;
  static const Color primaryLight = Color(0xFF58A6FF);
  static const Color secondary = Color(0xFFC13584);
  static const Color secondaryLight = Color(0xFFE040FB);
  static const Color background = FinzoColors.background;
  static const Color surface = FinzoColors.surface;
  static const Color textPrimary = FinzoColors.textPrimary;
  static const Color textSecondary = FinzoColors.textSecondary;
  static const Color success = FinzoColors.success;
  static const Color error = FinzoColors.error;
  static const Color warning = FinzoColors.warning;
  static const Color income = FinzoColors.income;
  static const Color expense = FinzoColors.expense;
}

/// Alias for backward compatibility - maps to FinzoColorsDark
class AppColorsDark {
  static const Color primary = FinzoColorsDark.brandAccent;
  static const Color primaryLight = Color(0xFF58A6FF);
  static const Color secondary = Color(0xFFC13584);
  static const Color secondaryLight = Color(0xFFE040FB);
  static const Color background = FinzoColorsDark.background;
  static const Color surface = FinzoColorsDark.surface;
  static const Color textPrimary = FinzoColorsDark.textPrimary;
  static const Color textSecondary = FinzoColorsDark.textSecondary;
  static const Color success = FinzoColorsDark.success;
  static const Color error = FinzoColorsDark.error;
  static const Color warning = FinzoColorsDark.warning;
  static const Color income = FinzoColorsDark.income;
  static const Color expense = FinzoColorsDark.expense;
}

/// Alias for backward compatibility - basic text styles
class AppTextStyles {
  static TextStyle heading1 = FinzoTypography.displayLarge(color: FinzoColors.textPrimary);
  static TextStyle heading2 = FinzoTypography.displayMedium(color: FinzoColors.textPrimary);
  static TextStyle heading3 = FinzoTypography.titleLarge(color: FinzoColors.textPrimary);
  static TextStyle body1 = FinzoTypography.bodyLarge(color: FinzoColors.textPrimary);
  static TextStyle body2 = FinzoTypography.bodyMedium(color: FinzoColors.textSecondary);
  static TextStyle caption = FinzoTypography.bodySmall(color: FinzoColors.textSecondary);
}

/// Alias for backward compatibility - box decorations
class AppDecorations {
  static BoxDecoration gradientDecoration = BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [FinzoColors.brandAccent, Color(0xFFC13584)],
    ),
    borderRadius: BorderRadius.circular(FinzoRadius.lg),
    boxShadow: [
      BoxShadow(
        color: FinzoColors.brandAccent.withOpacity(0.3),
        blurRadius: 12,
        offset: const Offset(0, 6),
      ),
    ],
  );

  static BoxDecoration cardDecoration = BoxDecoration(
    color: FinzoColors.surface,
    borderRadius: BorderRadius.circular(FinzoRadius.lg),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
    ],
    border: Border.all(color: FinzoColors.divider),
  );
}
