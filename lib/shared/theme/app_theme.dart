import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── PALETTE ───────────────────────────────────────────────────────────────
  static const Color _darkBg        = Color(0xFF0A0B0D);
  static const Color _darkSurface   = Color(0xFF111318);
  static const Color _darkSurface2  = Color(0xFF181C23);
  static const Color _darkSurface3  = Color(0xFF1E2330);
  static const Color _darkBorder    = Color(0xFF252B38);
  static const Color _darkBorder2   = Color(0xFF2E3545);
  static const Color _darkText      = Color(0xFFE8EAF0);
  static const Color _darkText2     = Color(0xFF8B92A8);
  static const Color _darkText3     = Color(0xFF555E75);
  static const Color _accent        = Color(0xFF00D4FF);
  static const Color _accentDim     = Color(0xFF0099BB);
  static const Color _red           = Color(0xFFFF4466);
  static const Color _green         = Color(0xFF00E5A0);
  static const Color _amber         = Color(0xFFFFAA00);
  static const Color _purple        = Color(0xFFA855F7);

  static const Color _lightBg       = Color(0xFFF5F7FA);
  static const Color _lightSurface  = Color(0xFFFFFFFF);
  static const Color _lightSurface2 = Color(0xFFF0F2F5);
  static const Color _lightBorder   = Color(0xFFE2E5EA);
  static const Color _lightText     = Color(0xFF0D1117);
  static const Color _lightText2    = Color(0xFF4A5568);
  static const Color _lightText3    = Color(0xFF9AA5B4);

  // ── EXTENSIONS ───────────────────────────────────────────────────────────
  static const accent    = _accent;
  static const accentDim = _accentDim;
  static const danger    = _red;
  static const success   = _green;
  static const warning   = _amber;
  static const purple    = _purple;

  // ── DARK THEME ───────────────────────────────────────────────────────────
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: _darkBg,
      colorScheme: const ColorScheme.dark(
        primary:      _accent,
        onPrimary:    Colors.black,
        secondary:    _purple,
        onSecondary:  Colors.white,
        error:        _red,
        surface:      _darkSurface,
        onSurface:    _darkText,
        outline:      _darkBorder,
        surfaceContainerHighest: _darkSurface3,
      ),
      textTheme: _textTheme(_darkText, _darkText2),
      iconTheme: const IconThemeData(color: _darkText2, size: 18),
      dividerColor: _darkBorder,
      dividerTheme: const DividerThemeData(color: _darkBorder, thickness: 1, space: 1),
      cardTheme: CardTheme(
        color: _darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: _darkBorder),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _accentDim, width: 1.5),
        ),
        hintStyle: const TextStyle(color: _darkText3, fontSize: 13),
        labelStyle: const TextStyle(color: _darkText2, fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: Colors.black,
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _darkText,
          side: const BorderSide(color: _darkBorder2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _accent,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? Colors.black : _darkText3),
        trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? _accent : _darkSurface3),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: _accent,
        thumbColor: _accent,
        inactiveTrackColor: _darkSurface3,
        overlayColor: _accent.withOpacity(0.2),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _darkSurface2,
        selectedColor: _accent.withOpacity(0.15),
        labelStyle: const TextStyle(fontSize: 11, color: _darkText2),
        side: const BorderSide(color: _darkBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: WidgetStateProperty.all(3),
        thumbColor: WidgetStateProperty.all(_darkBorder2),
        radius: const Radius.circular(2),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: _darkSurface3,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _darkBorder2),
        ),
        textStyle: const TextStyle(color: _darkText, fontSize: 12),
        waitDuration: const Duration(milliseconds: 600),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _darkSurface2,
        contentTextStyle: const TextStyle(color: _darkText, fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: _darkBorder2),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: _darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _darkBorder2),
        ),
        titleTextStyle: const TextStyle(color: _darkText, fontSize: 16, fontWeight: FontWeight.w700),
        contentTextStyle: const TextStyle(color: _darkText2, fontSize: 13),
      ),
      extensions: const [AppColors.dark],
    );
  }

  // ── LIGHT THEME ──────────────────────────────────────────────────────────
  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: _lightBg,
      colorScheme: const ColorScheme.light(
        primary:      _accent,
        onPrimary:    Colors.black,
        secondary:    _purple,
        error:        _red,
        surface:      _lightSurface,
        onSurface:    _lightText,
        outline:      _lightBorder,
      ),
      textTheme: _textTheme(_lightText, _lightText2),
      cardTheme: CardTheme(
        color: _lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: _lightBorder),
        ),
        margin: EdgeInsets.zero,
      ),
      extensions: const [AppColors.light],
    );
  }

  // ── TEXT THEME ────────────────────────────────────────────────────────────
  static TextTheme _textTheme(Color primary, Color secondary) {
    return GoogleFonts.outfitTextTheme().copyWith(
      bodyLarge:    TextStyle(color: primary,   fontSize: 14, height: 1.55),
      bodyMedium:   TextStyle(color: primary,   fontSize: 13, height: 1.55),
      bodySmall:    TextStyle(color: secondary, fontSize: 12, height: 1.5),
      labelLarge:   TextStyle(color: primary,   fontSize: 13, fontWeight: FontWeight.w600),
      labelMedium:  TextStyle(color: secondary, fontSize: 12),
      labelSmall:   TextStyle(color: secondary, fontSize: 11, letterSpacing: 0.05),
      titleLarge:   TextStyle(color: primary,   fontSize: 18, fontWeight: FontWeight.w700),
      titleMedium:  TextStyle(color: primary,   fontSize: 15, fontWeight: FontWeight.w600),
      titleSmall:   TextStyle(color: primary,   fontSize: 13, fontWeight: FontWeight.w600),
    );
  }

  // ── MONO STYLE ────────────────────────────────────────────────────────────
  static TextStyle mono({double size = 12, Color? color}) =>
    GoogleFonts.jetBrainsMono(fontSize: size, color: color);
}

// ── THEME EXTENSION ───────────────────────────────────────────────────────

class AppColors extends ThemeExtension<AppColors> {
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color surface3;
  final Color border;
  final Color border2;
  final Color text;
  final Color text2;
  final Color text3;
  final Color accent;
  final Color accentDim;
  final Color accentBg;
  final Color red;
  final Color redBg;
  final Color green;
  final Color greenBg;
  final Color amber;
  final Color amberBg;
  final Color purple;
  final Color purpleBg;

  const AppColors({
    required this.bg, required this.surface, required this.surface2,
    required this.surface3, required this.border, required this.border2,
    required this.text, required this.text2, required this.text3,
    required this.accent, required this.accentDim, required this.accentBg,
    required this.red, required this.redBg,
    required this.green, required this.greenBg,
    required this.amber, required this.amberBg,
    required this.purple, required this.purpleBg,
  });

  static const dark = AppColors(
    bg: Color(0xFF0A0B0D), surface: Color(0xFF111318), surface2: Color(0xFF181C23),
    surface3: Color(0xFF1E2330), border: Color(0xFF252B38), border2: Color(0xFF2E3545),
    text: Color(0xFFE8EAF0), text2: Color(0xFF8B92A8), text3: Color(0xFF555E75),
    accent: Color(0xFF00D4FF), accentDim: Color(0xFF0099BB), accentBg: Color(0x1200D4FF),
    red: Color(0xFFFF4466), redBg: Color(0x15FF4466),
    green: Color(0xFF00E5A0), greenBg: Color(0x1500E5A0),
    amber: Color(0xFFFFAA00), amberBg: Color(0x15FFAA00),
    purple: Color(0xFFA855F7), purpleBg: Color(0x15A855F7),
  );

  static const light = AppColors(
    bg: Color(0xFFF5F7FA), surface: Color(0xFFFFFFFF), surface2: Color(0xFFF0F2F5),
    surface3: Color(0xFFE8EBF0), border: Color(0xFFE2E5EA), border2: Color(0xFFCDD1D9),
    text: Color(0xFF0D1117), text2: Color(0xFF4A5568), text3: Color(0xFF9AA5B4),
    accent: Color(0xFF0099BB), accentDim: Color(0xFF007A96), accentBg: Color(0x120099BB),
    red: Color(0xFFDC2626), redBg: Color(0x15DC2626),
    green: Color(0xFF059669), greenBg: Color(0x15059669),
    amber: Color(0xFFD97706), amberBg: Color(0x15D97706),
    purple: Color(0xFF7C3AED), purpleBg: Color(0x157C3AED),
  );

  @override
  AppColors copyWith({Color? bg, Color? surface, Color? surface2, Color? surface3,
    Color? border, Color? border2, Color? text, Color? text2, Color? text3,
    Color? accent, Color? accentDim, Color? accentBg,
    Color? red, Color? redBg, Color? green, Color? greenBg,
    Color? amber, Color? amberBg, Color? purple, Color? purpleBg}) => AppColors(
    bg: bg ?? this.bg, surface: surface ?? this.surface, surface2: surface2 ?? this.surface2,
    surface3: surface3 ?? this.surface3, border: border ?? this.border, border2: border2 ?? this.border2,
    text: text ?? this.text, text2: text2 ?? this.text2, text3: text3 ?? this.text3,
    accent: accent ?? this.accent, accentDim: accentDim ?? this.accentDim, accentBg: accentBg ?? this.accentBg,
    red: red ?? this.red, redBg: redBg ?? this.redBg,
    green: green ?? this.green, greenBg: greenBg ?? this.greenBg,
    amber: amber ?? this.amber, amberBg: amberBg ?? this.amberBg,
    purple: purple ?? this.purple, purpleBg: purpleBg ?? this.purpleBg,
  );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!, surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!, surface3: Color.lerp(surface3, other.surface3, t)!,
      border: Color.lerp(border, other.border, t)!, border2: Color.lerp(border2, other.border2, t)!,
      text: Color.lerp(text, other.text, t)!, text2: Color.lerp(text2, other.text2, t)!,
      text3: Color.lerp(text3, other.text3, t)!,
      accent: Color.lerp(accent, other.accent, t)!, accentDim: Color.lerp(accentDim, other.accentDim, t)!,
      accentBg: Color.lerp(accentBg, other.accentBg, t)!,
      red: Color.lerp(red, other.red, t)!, redBg: Color.lerp(redBg, other.redBg, t)!,
      green: Color.lerp(green, other.green, t)!, greenBg: Color.lerp(greenBg, other.greenBg, t)!,
      amber: Color.lerp(amber, other.amber, t)!, amberBg: Color.lerp(amberBg, other.amberBg, t)!,
      purple: Color.lerp(purple, other.purple, t)!, purpleBg: Color.lerp(purpleBg, other.purpleBg, t)!,
    );
  }
}

extension BuildContextThemeExt on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>() ?? AppColors.dark;
  TextTheme get text => Theme.of(this).textTheme;
  ColorScheme get scheme => Theme.of(this).colorScheme;
}
