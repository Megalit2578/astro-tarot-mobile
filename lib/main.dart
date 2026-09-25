import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/api/api_client.dart';
import 'core/auth/auth_controller.dart';
import 'features/auth/login_screen.dart';
import 'features/shell/home_shell.dart';
import 'theme.dart';

void main() {
  runApp(const ProviderScope(retry: thuLaiKhiNao, child: AstroTarotApp()));
}

/// Khi nào một provider hỏng thì tự thử lại.
///
/// Riverpod 3 mặc định thử lại MỌI lỗi, kéo dài vài chục giây. Với lỗi 4xx
/// (không có quyền, không tìm thấy, dữ liệu sai) thì thử lại vô ích — người
/// dùng chỉ thấy vòng quay lâu hơn rồi mới đọc được câu lỗi. Chỉ thử lại lỗi
/// mạng và 5xx (máy chủ gói free đang thức dậy), tối đa hai lần.
Duration? thuLaiKhiNao(int lan, Object loi) {
  if (lan >= 2) return null;
  if (loi is ApiException) {
    final ma = loi.statusCode;
    if (ma != null && ma < 500) return null;
  }
  return Duration(seconds: 1 << lan);
}

class AstroTarotApp extends StatelessWidget {
  const AstroTarotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AstroTarot',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      themeMode: ThemeMode.dark,
      home: const _Cong(),
    );
  }
}

/// Cổng vào: quyết định hiện màn nào theo trạng thái phiên.
///
/// Dùng widget chuyển nhánh thay vì go_router có bảo vệ tuyến. Ở giai đoạn
/// này app chỉ có hai nhánh — đã đăng nhập hay chưa — nên một bộ định tuyến
/// khai báo kèm refreshListenable chỉ thêm tầng gián tiếp mà chưa giải quyết
/// vấn đề gì. Khi nào cần liên kết sâu (mở thẳng một buổi tư vấn từ thông báo
/// đẩy) thì thay bằng go_router: gói đã cài sẵn trong pubspec.
class _Cong extends ConsumerWidget {
  const _Cong();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trangThai = ref.watch(authControllerProvider).trangThai;

    switch (trangThai) {
      case TrangThaiPhien.dangKhoiDong:
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome, color: Mau.vang, size: 40),
                SizedBox(height: 20),
                SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ),
          ),
        );
      case TrangThaiPhien.chuaDangNhap:
        return const LoginScreen();
      case TrangThaiPhien.daDangNhap:
        return const HomeShell();
    }
  }
}
