import 'package:flutter/material.dart';

/// Responsive utility — dùng chung cho toàn bộ app
class R {
  R._();

  // ─── Screen dimensions ──────────────────────────────────────────────────────
  static double w(BuildContext context) => MediaQuery.of(context).size.width;
  static double h(BuildContext context) => MediaQuery.of(context).size.height;

  /// True nếu màn hình nhỏ (< 360 dp), ví dụ: Galaxy A01, Redmi Go
  static bool isSmall(BuildContext context) => w(context) < 360;

  /// True nếu màn hình vừa (360–413 dp), chiếm đa số Android
  static bool isMedium(BuildContext context) =>
      w(context) >= 360 && w(context) < 414;

  /// True nếu màn hình lớn (≥ 414 dp), ví dụ: iPhone Plus, Galaxy S Ultra
  static bool isLarge(BuildContext context) => w(context) >= 414;

  // ─── Responsive text ─────────────────────────────────────────────────────────
  /// Scale font theo base width 375dp (iPhone 8), clamp [0.85 – 1.25]
  static double sp(BuildContext context, double fontSize) {
    final scale = (w(context) / 375.0).clamp(0.85, 1.25);
    return fontSize * scale;
  }

  // ─── Responsive spacing ───────────────────────────────────────────────────────
  /// Padding ngoài trang (horizontal + vertical)
  static EdgeInsets pagePadding(BuildContext context) {
    if (isSmall(context)) return const EdgeInsets.symmetric(horizontal: 16, vertical: 16);
    if (isMedium(context)) return const EdgeInsets.symmetric(horizontal: 20, vertical: 20);
    return const EdgeInsets.symmetric(horizontal: 24, vertical: 24);
  }

  /// Padding bên trong Card / Form
  static double cardPadding(BuildContext context) {
    if (isSmall(context)) return 18.0;
    if (isMedium(context)) return 24.0;
    return 32.0;
  }

  /// Horizontal padding tiêu chuẩn
  static double hPad(BuildContext context) {
    if (isSmall(context)) return 12.0;
    if (isMedium(context)) return 16.0;
    return 20.0;
  }

  // ─── Responsive sizing ────────────────────────────────────────────────────────
  /// Hero image height: 40% màn hình (capped at 280)
  static double heroHeight(BuildContext context) => (h(context) * 0.35).clamp(160.0, 280.0);

  /// Avatar size
  static double avatarSize(BuildContext context) {
    if (isSmall(context)) return 72.0;
    return 88.0;
  }

  /// Grid cross-axis count dựa vào width
  static int gridCount(BuildContext context) {
    if (w(context) < 400) return 2;
    if (w(context) < 600) return 2;
    return 3;
  }

  /// Grid aspect ratio cho product card
  static double gridAspectRatio(BuildContext context) {
    if (isSmall(context)) return 0.47;
    if (isMedium(context)) return 0.46;
    return 0.45;
  }

  // ─── Responsive icon sizes ────────────────────────────────────────────────────
  static double iconSm(BuildContext context) => isSmall(context) ? 18.0 : 20.0;
  static double iconMd(BuildContext context) => isSmall(context) ? 24.0 : 28.0;
  static double iconLg(BuildContext context) => isSmall(context) ? 36.0 : 48.0;
}
