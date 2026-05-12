import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const Color accentBlue   = Color(0xFF42A5F5);
  static const Color accentGreen  = Color(0xFF66BB6A);
  static const Color accentOrange = Color(0xFFFFA726);
  static const Color accentRed    = Color(0xFFEF5350);
  static const Color accentYellow = Color(0xFFFDD835);
  static const Color accentTeal   = Color(0xFF26C6DA);
  static const Color accentPurple = Color(0xFFAB47BC);

  static const Color bgCanvas    = Color(0xFF0D0D0D);
  static const Color bgSurface   = Color(0xFF161616);
  static const Color bgElevated  = Color(0xFF1E1E1E);
  static const Color bgStrip     = Color(0xFF121212);
  static const Color borderSub   = Color(0xFF242424);
  static const Color borderMain  = Color(0xFF2E2E2E);
  static const Color trackClr      = Color(0xFF3A3A3A);
  static const Color trackClrLight = Color(0xFFECE9E4); // meleg krém (világos mód)

  /// Haladásjelző / műszer ív háttérszín — témafüggő.
  static Color trackColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? trackClr : trackClrLight;

  static const Color textPrimary = Color(0xFFF0F0F0);
  static const Color textSec     = Color(0xFF9E9E9E);
  static const Color textDim     = Color(0xFF5A5A5A);

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary:                 accentBlue,
      secondary:               accentGreen,
      surface:                 bgSurface,
      error:                   accentRed,
      onPrimary:               Colors.black,
      onSecondary:             Colors.black,
      onSurface:               textPrimary,
      outline:                 borderMain,
      surfaceContainerHighest: bgElevated,
      primaryContainer:        Color(0xFF1A2A3D),
      onPrimaryContainer:      textPrimary,
    ),
    scaffoldBackgroundColor: bgCanvas,

    appBarTheme: const AppBarTheme(
      backgroundColor:  bgStrip,
      foregroundColor:  textPrimary,
      elevation:        0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: textPrimary, fontSize: 18,
        fontWeight: FontWeight.w600, letterSpacing: 0.2,
      ),
      iconTheme: IconThemeData(color: textSec, size: 22),
    ),

    cardTheme: CardThemeData(
      color:     bgSurface,
      elevation: 0,
      margin:    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: borderSub),
      ),
    ),

    listTileTheme: const ListTileThemeData(
      tileColor:         Colors.transparent,
      textColor:         textPrimary,
      iconColor:         textSec,
      subtitleTextStyle: TextStyle(color: textSec, fontSize: 12),
    ),

    dividerTheme: const DividerThemeData(
      color: borderSub, thickness: 1, space: 1,
    ),

    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        backgroundColor: WidgetStateProperty.resolveWith<Color>((s) =>
          s.contains(WidgetState.selected) ? accentBlue : bgElevated),
        foregroundColor: WidgetStateProperty.resolveWith<Color>((s) =>
          s.contains(WidgetState.selected) ? Colors.black : textSec),
        iconColor: WidgetStateProperty.resolveWith<Color>((s) =>
          s.contains(WidgetState.selected) ? Colors.black : textDim),
        side: WidgetStateProperty.all(const BorderSide(color: borderMain)),
        overlayColor: WidgetStateProperty.all(
          Color.fromRGBO(66, 165, 245, 0.12)),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: bgElevated,
      selectedColor:   const Color(0xFF1A2A3D),
      checkmarkColor:  accentBlue,
      labelStyle:      const TextStyle(color: textPrimary, fontSize: 13),
      side:            const BorderSide(color: borderMain),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    ),

    sliderTheme: SliderThemeData(
      activeTrackColor:   accentBlue,
      inactiveTrackColor: trackClr,
      thumbColor:         accentBlue,
      overlayColor:       Color.fromRGBO(66, 165, 245, 0.12),
      valueIndicatorColor: accentBlue,
      valueIndicatorShape: const RectangularSliderValueIndicatorShape(),
      valueIndicatorTextStyle: const TextStyle(color: Colors.black, fontSize: 12),
    ),

    dialogTheme: const DialogThemeData(
      backgroundColor:  bgElevated,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
      contentTextStyle: TextStyle(color: textSec, fontSize: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),

    snackBarTheme: const SnackBarThemeData(
      backgroundColor:  Color(0xFF2A2A2A),
      contentTextStyle: TextStyle(color: textPrimary),
      actionTextColor:  accentBlue,
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor:  bgSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: borderMain),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.black,
        backgroundColor: accentBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: accentBlue),
    ),

    textTheme: const TextTheme(
      bodyLarge:   TextStyle(color: textPrimary),
      bodyMedium:  TextStyle(color: textPrimary),
      bodySmall:   TextStyle(color: textSec),
      labelLarge:  TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      labelMedium: TextStyle(color: textSec),
      labelSmall:  TextStyle(color: textDim),
      titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      titleSmall:  TextStyle(color: textSec),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: accentBlue,
    ),
  );

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary:                 accentBlue,
      secondary:               accentGreen,
      surface:                 Color(0xFFFFFFFF),
      error:                   accentRed,
      onPrimary:               Colors.white,
      onSecondary:             Colors.white,
      onSurface:               Color(0xFF1A1A1A),
      outline:                 Color(0xFFD0D3D8),
      surfaceContainerHighest: Color(0xFFEDEFF2),
      primaryContainer:        Color(0xFFDCEBFF),
      onPrimaryContainer:      Color(0xFF001D36),
    ),
    scaffoldBackgroundColor: const Color(0xFFF0F2F5),

    appBarTheme: const AppBarTheme(
      backgroundColor:  Colors.white,
      foregroundColor:  Color(0xFF1A1A1A),
      elevation:        0,
      surfaceTintColor: Colors.transparent,
      shadowColor:      Color(0x14000000),
      titleTextStyle: TextStyle(
        color: Color(0xFF1A1A1A), fontSize: 18,
        fontWeight: FontWeight.w600, letterSpacing: 0.2,
      ),
      iconTheme: IconThemeData(color: Color(0xFF555555), size: 22),
    ),

    cardTheme: CardThemeData(
      color:     Colors.white,
      elevation: 0,
      margin:    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFD8DCE2)),
      ),
    ),

    listTileTheme: const ListTileThemeData(
      tileColor:         Colors.transparent,
      textColor:         Color(0xFF1A1A1A),
      iconColor:         Color(0xFF555555),
      subtitleTextStyle: TextStyle(color: Color(0xFF666666), fontSize: 12),
    ),

    dividerTheme: const DividerThemeData(
      color: Color(0xFFDEE1E6), thickness: 1, space: 1,
    ),

    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        backgroundColor: WidgetStateProperty.resolveWith<Color>((s) =>
          s.contains(WidgetState.selected) ? accentBlue : const Color(0xFFF0F2F5)),
        foregroundColor: WidgetStateProperty.resolveWith<Color>((s) =>
          s.contains(WidgetState.selected) ? Colors.white : const Color(0xFF444444)),
        iconColor: WidgetStateProperty.resolveWith<Color>((s) =>
          s.contains(WidgetState.selected) ? Colors.white : const Color(0xFF666666)),
        side: WidgetStateProperty.all(const BorderSide(color: Color(0xFFCDD0D5))),
        overlayColor: WidgetStateProperty.all(
          Color.fromRGBO(66, 165, 245, 0.10)),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFEDEFF2),
      selectedColor:   const Color(0xFFDCEBFF),
      checkmarkColor:  accentBlue,
      labelStyle: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 13),
      side: const BorderSide(color: Color(0xFFD0D3D8)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    ),

    sliderTheme: SliderThemeData(
      activeTrackColor:    accentBlue,
      inactiveTrackColor:  const Color(0xFFCDD0D5),
      thumbColor:          accentBlue,
      overlayColor:        Color.fromRGBO(66, 165, 245, 0.12),
      valueIndicatorColor: accentBlue,
      valueIndicatorShape: const RectangularSliderValueIndicatorShape(),
      valueIndicatorTextStyle: const TextStyle(color: Colors.white, fontSize: 12),
    ),

    dialogTheme: const DialogThemeData(
      backgroundColor:  Colors.white,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: Color(0xFF1A1A1A), fontSize: 18, fontWeight: FontWeight.w600),
      contentTextStyle: TextStyle(color: Color(0xFF555555), fontSize: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),

    snackBarTheme: const SnackBarThemeData(
      backgroundColor:  Color(0xFF323232),
      contentTextStyle: TextStyle(color: Colors.white),
      actionTextColor:  accentBlue,
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor:  Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: Color(0xFFD8DCE2)),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: accentBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: accentBlue),
    ),

    textTheme: const TextTheme(
      bodyLarge:   TextStyle(color: Color(0xFF1A1A1A)),
      bodyMedium:  TextStyle(color: Color(0xFF1A1A1A)),
      bodySmall:   TextStyle(color: Color(0xFF555555)),
      labelLarge:  TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w600),
      labelMedium: TextStyle(color: Color(0xFF555555)),
      labelSmall:  TextStyle(color: Color(0xFF888888)),
      titleMedium: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w600),
      titleSmall:  TextStyle(color: Color(0xFF555555)),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: accentBlue,
    ),
  );
}
