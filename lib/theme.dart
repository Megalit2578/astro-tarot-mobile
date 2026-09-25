import 'package:flutter/material.dart';

/// Bảng màu lấy từ giao diện web để hai nơi trông như một sản phẩm.
class Mau {
  const Mau._();
  static const nen = Color(0xFF0A0A0F);
  static const the = Color(0xFF14141C);
  static const vang = Color(0xFFD4AF37);
  static const vangNhat = Color(0xFFF0D98C);
  static const chu = Color(0xFFEDEAE3);
  static const chuMo = Color(0xFF9C9AA3);
  static const vien = Color(0x33D4AF37);
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: Mau.nen,
    colorScheme: base.colorScheme.copyWith(
      primary: Mau.vang,
      onPrimary: const Color(0xFF1A1206),
      surface: Mau.the,
      onSurface: Mau.chu,
      error: const Color(0xFFE5645E),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: Mau.chu,
      displayColor: Mau.chu,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Mau.nen,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Mau.the,
      hintStyle: const TextStyle(color: Mau.chuMo),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Mau.vien),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Mau.vien),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Mau.vang),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Mau.vang,
        foregroundColor: const Color(0xFF1A1206),
        // Cao 52: ngón tay cái chạm thoải mái, trên ngưỡng 48dp mà hướng dẫn
        // tiếp cận yêu cầu.
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    // Thanh tab dưới cao 64 thay vì 80 mặc định: màn điện thoại đã chật,
    // nhãn 11pt dưới biểu tượng vẫn đủ chỗ chạm.
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Mau.the,
      height: 64,
      indicatorColor: Mau.vang.withValues(alpha: 0.18),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 11,
          color: s.contains(WidgetState.selected) ? Mau.vang : Mau.chuMo,
        ),
      ),
    ),
    // Nút nổi mặc định của Material 3 lấy màu tím; ở đây theo tông vàng.
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Mau.vang,
      foregroundColor: Color(0xFF1A1206),
      extendedTextStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
    cardTheme: CardThemeData(
      color: Mau.the,
      elevation: 0,
      // Bỏ lề 4 mặc định: thẻ phải thẳng mép với khối khác cùng trang, lề
      // giữa các thẻ do danh sách tự đặt.
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Mau.vien),
      ),
    ),
  );
}
