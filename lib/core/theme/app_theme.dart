import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import 'app_palette.dart';
import 'motion.dart';

/// iOS-inspired look: clean grouped background, large tight titles, pill
/// buttons, Cupertino transitions and bouncing scroll (see [AppScrollBehavior]).
class AppTheme {
  const AppTheme._();

  /// Downloads Inter at runtime (google_fonts) instead of using the bundled
  /// copy; off by default and in tests.
  static bool useGoogleFonts = false;

  /// Bundled fonts (assets/fonts/inter): Inter for text and Inter Display,
  /// its cut for large sizes, for titles — like SF Pro Text / Display.
  static String? get bodyFont => useGoogleFonts ? null : 'Inter';
  static String? get titleFont => useGoogleFonts ? null : 'InterDisplay';

  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          secondary: AppColors.income,
          surface: Colors.white,
          surfaceContainerHighest: const Color(0xFFEEEEF0),
          onSurface: AppColors.textPrimary,
          onSurfaceVariant: AppPalette.light.muted,
          outlineVariant: AppPalette.light.hairline,
        );
    return _base(scheme, AppPalette.light, const Color(0xFFF6F6F7));
  }

  static ThemeData dark() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFF9CE0A7),
          secondary: const Color(0xFF4FD99A),
          surface: AppPalette.dark.card,
          surfaceContainerHighest: const Color(0xFF2C2C2E),
          onSurface: const Color(0xFFF6F6F7),
          onSurfaceVariant: AppPalette.dark.muted,
          outlineVariant: AppPalette.dark.hairline,
        );
    return _base(scheme, AppPalette.dark, const Color(0xFF151617));
  }

  static ThemeData _base(
    ColorScheme scheme,
    AppPalette palette,
    Color background,
  ) {
    final baseText = useGoogleFonts
        ? GoogleFonts.interTextTheme()
        : ThemeData(
            brightness: scheme.brightness,
          ).textTheme.apply(fontFamily: bodyFont);
    // Material's tracking is tuned for Roboto (up to +0.5); Inter, like SF
    // Pro, reads best neutral to slightly tight as text grows.
    TextStyle? tracked(TextStyle? style, double spacing) =>
        style?.copyWith(letterSpacing: spacing);
    final textTheme = baseText
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface)
        .copyWith(
          bodyLarge: tracked(baseText.bodyLarge, -0.2),
          bodyMedium: tracked(baseText.bodyMedium, -0.1),
          bodySmall: tracked(baseText.bodySmall, 0),
          labelLarge: tracked(baseText.labelLarge, -0.1),
          labelMedium: tracked(baseText.labelMedium, 0),
          labelSmall: tracked(baseText.labelSmall, 0),
          // Large, tight headings like iOS large titles.
          displaySmall: baseText.displaySmall?.copyWith(
            fontFamily: titleFont,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.2,
            color: scheme.onSurface,
          ),
          headlineMedium: baseText.headlineMedium?.copyWith(
            fontFamily: titleFont,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.9,
            color: scheme.onSurface,
          ),
          headlineSmall: baseText.headlineSmall?.copyWith(
            fontFamily: titleFont,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            color: scheme.onSurface,
          ),
          titleLarge: baseText.titleLarge?.copyWith(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.4,
            color: scheme.onSurface,
          ),
          titleMedium: baseText.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            color: scheme.onSurface,
          ),
        );
    final pillShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: bodyFont,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: background,
      extensions: [palette],
      splashFactory: NoSplash.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: AppPageTransitionsBuilder(),
          TargetPlatform.iOS: AppPageTransitionsBuilder(),
          TargetPlatform.linux: AppPageTransitionsBuilder(),
          TargetPlatform.macOS: AppPageTransitionsBuilder(),
          TargetPlatform.windows: AppPageTransitionsBuilder(),
        },
      ),
      cupertinoOverrideTheme: CupertinoThemeData(
        primaryColor: scheme.primary,
        brightness: scheme.brightness,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: palette.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        color: palette.hairline,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.card,
        selectedColor: palette.pill,
        disabledColor: scheme.surfaceContainerHighest,
        iconTheme: IconThemeData(color: scheme.onSurface, size: 18),
        labelStyle: textTheme.labelLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(
          color: palette.onPill,
          fontWeight: FontWeight.w700,
        ),
        // iOS-like capsules: the selected one fills black, no checkmark.
        showCheckmark: false,
        checkmarkColor: palette.onPill,
        shape: const StadiumBorder(),
        side: BorderSide(color: palette.hairline),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          backgroundColor: palette.pill,
          foregroundColor: palette.onPill,
          textStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          shape: pillShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: pillShape,
          side: BorderSide(color: palette.hairline),
          foregroundColor: scheme.onSurface,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.onSurface,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: scheme.onSurface, width: 1.5),
        ),
        floatingLabelStyle: WidgetStateTextStyle.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.error)
                ? scheme.error
                : scheme.onSurface,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return palette.pill;
            return scheme.surfaceContainerHighest;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return palette.onPill;
            return scheme.onSurface;
          }),
          side: const WidgetStatePropertyAll(BorderSide.none),
          shape: WidgetStatePropertyAll(pillShape),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.onSurface.withValues(alpha: .18),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: palette.pill,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: palette.onPill,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: palette.accent,
        foregroundColor: palette.onAccent,
        elevation: 0,
        shape: const CircleBorder(),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: background,
        indicatorColor: palette.pill,
        selectedIconTheme: IconThemeData(color: palette.onPill),
        selectedLabelTextStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: textTheme.labelLarge?.copyWith(
          color: palette.muted,
        ),
      ),
      // Progress, the text cursor and selection follow the palette (black
      // pill / lime), not the seed's green.
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.pill,
        linearTrackColor: scheme.surfaceContainerHighest,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.onSurface,
        selectionColor: palette.accent.withValues(alpha: .45),
        selectionHandleColor: scheme.onSurface,
      ),
    );
  }
}

/// iOS-style bouncing scroll everywhere, also with mouse drag on desktop/web.
/// A page only moves when its content overflows. Vertical ListViews and
/// CustomScrollViews default to always scrollable regardless, so pages pass
/// `physics: const BouncingScrollPhysics()`, except those under a
/// [RefreshIndicator], which keep [AlwaysScrollableScrollPhysics] so a short
/// page can still be pulled.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics();
}

/// Pushed pages slide in like iOS (keeping its back swipe and its curve,
/// which follows the finger), in [Motion.slow]; when the user asked to reduce
/// motion they only cross-fade and the page below stays still.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  static const _cupertino = CupertinoPageTransitionsBuilder();

  @override
  Duration get transitionDuration => Motion.slow;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      (context, animation, secondaryAnimation, allowSnapshotting, child) =>
          Motion.reduced(context)
          ? child
          : _cupertino.delegatedTransition!(
              context,
              animation,
              secondaryAnimation,
              allowSnapshotting,
              child,
            );

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (Motion.reduced(context)) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Motion.standard),
        child: child,
      );
    }
    return _cupertino.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
