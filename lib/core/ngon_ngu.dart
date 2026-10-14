import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'tu_dien_en.dart';

/// Chuyển đổi tiếng Việt ↔ tiếng Anh.
///
/// KHOÁ TRA LÀ CHÍNH CÂU TIẾNG VIỆT, không phải mã kiểu `booking.title`.
///
/// Lý do: app có gần một nghìn năm trăm chuỗi tiếng Việt viết thẳng trong mã.
/// Dùng mã khoá thì mỗi chuỗi chưa khai báo sẽ hiện ra đúng cái mã ấy — giao
/// diện vỡ ngay từ lần đầu bật, và phải dịch xong sạch mới dám bật. Tra theo
/// câu tiếng Việt thì chuỗi nào chưa dịch tự rơi về tiếng Việt: màn hình vẫn
/// đọc được, chỉ lẫn hai thứ tiếng, nên dịch dần mà không bao giờ gãy.
///
/// Dùng `ValueNotifier` toàn cục chứ không phải provider của Riverpod: hàm
/// dịch cần gọi được từ MỌI widget, kể cả `StatelessWidget` không có `ref`,
/// và từ cả những chỗ không phải widget (thông báo lỗi trong repository).
/// Đổi `Ngu.hien` thì `NguNghe` ở gốc dựng lại cả cây.
class Ngu {
  Ngu._();

  static const _khoa = 'ngon_ngu';
  static const _kho = FlutterSecureStorage();

  /// 'vi' hoặc 'en'. Mặc định tiếng Việt.
  static final hien = ValueNotifier<String>('vi');

  /// Đọc lựa chọn đã lưu. Gọi một lần lúc khởi động.
  static Future<void> nap() async {
    try {
      final d = await _kho.read(key: _khoa);
      if (d == 'en') hien.value = 'en';
    } catch (_) {
      // Kho khoá hỏng hoặc chưa cấp quyền: cứ chạy tiếng Việt.
    }
  }

  static Future<void> doi(String ma) async {
    hien.value = ma == 'en' ? 'en' : 'vi';
    try {
      await _kho.write(key: _khoa, value: hien.value);
    } catch (_) {
      // Không lưu được thì vẫn đổi cho phiên này.
    }
  }

  /// Dịch một câu. Chưa có bản dịch thì trả lại nguyên câu tiếng Việt.
  static String d(String cau) =>
      hien.value == 'en' ? (tuDienEn[cau] ?? cau) : cau;
}

/// Bọc quanh app để đổi ngôn ngữ là dựng lại toàn bộ.
class NguNghe extends StatelessWidget {
  const NguNghe({super.key, required this.con});

  final Widget Function(BuildContext) con;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: Ngu.hien,
    builder: (c, _, _) => con(c),
  );
}
