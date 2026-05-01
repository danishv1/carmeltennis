import 'package:flutter/material.dart';

/// Design tokens for the Booking Grid (Variant B v3.1 — Sport / clay).
///
/// Token names mirror the CSS custom properties in the design handoff
/// (see design_handoff_booking_grid/README.md). Values are matched
/// against the handoff hex codes.
@immutable
class BgTokens extends ThemeExtension<BgTokens> {
  final Color bg;
  final Color surface;
  final Color ink;
  final Color ink2;
  final Color line;
  final Color line2;
  final Color clay;
  final Color clayD;
  final Color clayTint;
  final Color clayInk;
  final Color green;
  final Color greenTint;
  final Color pastBg;
  final Color pastInk;
  final Color warn;
  final List<BoxShadow> shadowMine;

  const BgTokens({
    required this.bg,
    required this.surface,
    required this.ink,
    required this.ink2,
    required this.line,
    required this.line2,
    required this.clay,
    required this.clayD,
    required this.clayTint,
    required this.clayInk,
    required this.green,
    required this.greenTint,
    required this.pastBg,
    required this.pastInk,
    required this.warn,
    required this.shadowMine,
  });

  static const BgTokens light = BgTokens(
    bg: Color(0xFFFFF8F3),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF1F1715),
    ink2: Color(0xFF7A5447),
    line: Color(0xFFF0E3D4),
    line2: Color(0xFFE9D8C8),
    clay: Color(0xFFC0532B),
    clayD: Color(0xFFA8431F),
    clayTint: Color(0xFFFBEADB),
    clayInk: Color(0xFFA8431F),
    green: Color(0xFF1F6F4A),
    greenTint: Color(0xFFE2F1E9),
    pastBg: Color(0xFFF7EFE7),
    pastInk: Color(0xFFC8B8AC),
    warn: Color(0xFFFFD6A8),
    shadowMine: [
      BoxShadow(
        color: Color(0x2E000000), // rgba(0,0,0,0.18)
        offset: Offset(0, -3),
        blurRadius: 0,
      ),
    ],
  );

  static const BgTokens dark = BgTokens(
    bg: Color(0xFF0E1413),
    surface: Color(0xFF161E1C),
    ink: Color(0xFFF1EBE4),
    ink2: Color(0xFF9A8A7E),
    line: Color(0xFF22302C),
    line2: Color(0xFF1A2422),
    clay: Color(0xFFE06A3E),
    clayD: Color(0xFFC0532B),
    clayTint: Color(0xFF2A1A13),
    clayInk: Color(0xFFF5A884),
    green: Color(0xFF3AA674),
    greenTint: Color(0xFF0F2A1F),
    pastBg: Color(0xFF141A19),
    pastInk: Color(0xFF3A4744),
    warn: Color(0xFFFFB877),
    shadowMine: [
      BoxShadow(
        color: Color(0x59000000), // rgba(0,0,0,0.35)
        offset: Offset(0, -3),
        blurRadius: 0,
      ),
    ],
  );

  static BgTokens of(BuildContext context) {
    final ext = Theme.of(context).extension<BgTokens>();
    if (ext != null) return ext;
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }

  @override
  BgTokens copyWith({
    Color? bg,
    Color? surface,
    Color? ink,
    Color? ink2,
    Color? line,
    Color? line2,
    Color? clay,
    Color? clayD,
    Color? clayTint,
    Color? clayInk,
    Color? green,
    Color? greenTint,
    Color? pastBg,
    Color? pastInk,
    Color? warn,
    List<BoxShadow>? shadowMine,
  }) {
    return BgTokens(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      ink: ink ?? this.ink,
      ink2: ink2 ?? this.ink2,
      line: line ?? this.line,
      line2: line2 ?? this.line2,
      clay: clay ?? this.clay,
      clayD: clayD ?? this.clayD,
      clayTint: clayTint ?? this.clayTint,
      clayInk: clayInk ?? this.clayInk,
      green: green ?? this.green,
      greenTint: greenTint ?? this.greenTint,
      pastBg: pastBg ?? this.pastBg,
      pastInk: pastInk ?? this.pastInk,
      warn: warn ?? this.warn,
      shadowMine: shadowMine ?? this.shadowMine,
    );
  }

  @override
  ThemeExtension<BgTokens> lerp(ThemeExtension<BgTokens>? other, double t) {
    if (other is! BgTokens) return this;
    return BgTokens(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      ink2: Color.lerp(ink2, other.ink2, t)!,
      line: Color.lerp(line, other.line, t)!,
      line2: Color.lerp(line2, other.line2, t)!,
      clay: Color.lerp(clay, other.clay, t)!,
      clayD: Color.lerp(clayD, other.clayD, t)!,
      clayTint: Color.lerp(clayTint, other.clayTint, t)!,
      clayInk: Color.lerp(clayInk, other.clayInk, t)!,
      green: Color.lerp(green, other.green, t)!,
      greenTint: Color.lerp(greenTint, other.greenTint, t)!,
      pastBg: Color.lerp(pastBg, other.pastBg, t)!,
      pastInk: Color.lerp(pastInk, other.pastInk, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      shadowMine: t < 0.5 ? shadowMine : other.shadowMine,
    );
  }
}

class BgRadii {
  static const double chip = 5;
  static const double slot = 7;
  static const double pill = 7;
  static const double iconBtn = 7;
  static const double avatar = 8;
  static const double sheetIcon = 10;
  static const double toast = 10;
  static const double tile = 18;
  static const double sheetTop = 20;
  static const double frame = 28;
}

class BgDurations {
  static const heroPad = Duration(milliseconds: 180);
  static const slotPress = Duration(milliseconds: 80);
  static const previewTimeout = Duration(milliseconds: 3500);
  static const pending = Duration(milliseconds: 700);
  static const pulse = Duration(milliseconds: 1000);
  static const shimmer = Duration(milliseconds: 1200);
  static const shake = Duration(milliseconds: 400);
  static const toastIn = Duration(milliseconds: 200);
  static const toastVisible = Duration(milliseconds: 2400);
  static const sheetFade = Duration(milliseconds: 180);
  static const sheetUp = Duration(milliseconds: 220);
}
