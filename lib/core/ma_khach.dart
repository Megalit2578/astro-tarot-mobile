import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Chỗ cất một chuỗi, đủ hẹp để bài kiểm thay được.
///
/// Không nhận thẳng `FlutterSecureStorage`: bài kiểm sẽ phải kế thừa lớp ấy
/// và khai lại đủ bảy tham số tuỳ chọn của `read`/`write`, mà chữ ký ấy đổi
/// giữa các phiên bản gói — nâng gói lên là test vỡ vì lý do chẳng liên quan
/// gì tới mã khách.
abstract interface class KhoChuoi {
  Future<String?> doc(String khoa);

  Future<void> ghi(String khoa, String giaTri);
}

/// Bản thật: kho bảo mật của hệ điều hành.
class KhoBaoMat implements KhoChuoi {
  const KhoBaoMat([this._kho = const FlutterSecureStorage()]);

  final FlutterSecureStorage _kho;

  @override
  Future<String?> doc(String khoa) => _kho.read(key: khoa);

  @override
  Future<void> ghi(String khoa, String giaTri) =>
      _kho.write(key: khoa, value: giaTri);
}

/// Mã khách ẩn danh, để nối các hành động của cùng một người lại với nhau.
///
/// ## Nó KHÔNG phải danh tính
///
/// Không tên, không email, không số điện thoại — chỉ một chuỗi ngẫu nhiên
/// sinh ngay trên máy. Gỡ app là mất, và không có cách nào từ mã này suy ra
/// người thật. Đúng mức cần để đọc được hành trình, không hơn.
///
/// ## Vì sao app cũng phải có
///
/// Trang quản trị dựng lại hành trình từng khách — "vào từ đâu, rồi bấm
/// những gì, theo thứ tự" — bằng cách gộp theo mã này. App không gửi mã thì
/// mọi hành động trong app không gộp được, và cả phần lưu lượng di động biến
/// mất khỏi bảng ấy.
///
/// ## Vì sao cất ở kho bảo mật, dù nó không phải bí mật
///
/// Không phải vì cần bảo mật, mà vì đó là kho duy nhất app này đã có. Thêm
/// `shared_preferences` chỉ để giữ một chuỗi là thêm một phụ thuộc cho việc
/// mà thứ sẵn có làm được.
class MaKhach {
  MaKhach({KhoChuoi? kho}) : _kho = kho ?? const KhoBaoMat();

  static const _khoa = 'astrotarot_ma_khach';

  final KhoChuoi _kho;

  /// Bản sao trong bộ nhớ: mỗi sự kiện đều cần mã, mà đọc kho bảo mật là một
  /// chuyến sang tầng native.
  String? _ma;

  /// Mã hiện tại, hoặc chuỗi rỗng nếu chưa nạp xong.
  ///
  /// Trả rỗng chứ không chờ: sự kiện được ghi ngay trong luồng người dùng
  /// đang thao tác, và một sự kiện thiếu mã còn hơn một thao tác bị khựng
  /// lại vì đợi kho bảo mật.
  String get ma => _ma ?? '';

  /// Đọc mã đã lưu, sinh mới nếu chưa có. Gọi một lần lúc khởi động.
  ///
  /// Nuốt mọi lỗi: kho hỏng, máy không mở khoá được, bộ nhớ đầy — đều ném.
  /// Theo dõi là việc phụ, không được phép chặn app khởi động.
  Future<void> nap() async {
    if (_ma != null) return;
    try {
      final daCo = await _kho.doc(_khoa);
      if (daCo != null && daCo.isNotEmpty) {
        _ma = daCo;
        return;
      }
      final moi = _sinhMa();
      await _kho.ghi(_khoa, moi);
      _ma = moi;
    } catch (_) {
      // Không lưu được thì vẫn dùng một mã cho phiên này. Hành trình trong
      // phiên vẫn nối được; chỉ là mở lại app thành khách mới.
      _ma ??= _sinhMa();
    }
  }

  /// Dạng UUID v4, ghép từ `Random.secure()`.
  ///
  /// Dart không có sẵn hàm sinh UUID, và kéo cả gói `uuid` về chỉ để dùng
  /// một chỗ là không đáng.
  static String _sinhMa() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    // Đặt đúng bit phiên bản (4) và biến thể (10xx) cho ra UUID v4 hợp lệ.
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;

    String hex(int from, int to) => b
        .sublist(from, to)
        .map((x) => x.toRadixString(16).padLeft(2, '0'))
        .join();

    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }
}
