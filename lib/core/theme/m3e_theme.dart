import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_3_expressive/material_3_expressive.dart' as m3e;

/// Design system configuration for Google Music adhering to Google Material 3 Expressive standards.
class M3EMusicTheme {
  /// Primary signature brand red for Google / YouTube Music.
  static const Color primarySeed = Color(0xFFFF0000);

  /// Authentic deep black background matching official YouTube Music.
  static const Color darkBackground = Color(0xFF030303);

  /// Elevated dark container color.
  static const Color darkSurfaceContainer = Color(0xFF212121);

  /// High surface container color for active elements and chips.
  static const Color darkSurfaceContainerHigh = Color(0xFF282828);

  /// Creates authentic dark theme data for Google Music.
  static ThemeData createDarkTheme({Color seedColor = primarySeed}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    ).copyWith(
      surface: const Color(0xFF0F0F0F),
      surfaceContainerLowest: const Color(0xFF000000),
      surfaceContainerLow: const Color(0xFF121212),
      surfaceContainer: const Color(0xFF212121),
      surfaceContainerHigh: const Color(0xFF282828),
      surfaceContainerHighest: const Color(0xFF383838),
      onSurface: const Color(0xFFFFFFFF),
      onSurfaceVariant: const Color(0xFFAAAAAA),
      outline: const Color(0xFF333333),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF030303),
      splashFactory: InkSparkle.splashFactory,
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        selectedColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide.none,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainerLowest,
        selectedItemColor: Colors.white,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }

  /// Creates M3E expressive theme bundle.
  static m3e.M3EThemeData createM3EData({Color seedColor = primarySeed}) {
    return m3e.M3EThemeData.dark(seedColor: seedColor);
  }
}

