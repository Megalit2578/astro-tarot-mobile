import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bộ đăng nhập mà máy ảo được mở kèm theo, để thử bốn vai trò cùng lúc.
@immutable
class BoDangNhapThu {
  const BoDangNhapThu({required this.email, required this.matKhau});

  final String email;
  final String matKhau;

  @override
  bool operator ==(Object other) =>
      other is BoDangNhapThu &&
      other.email == email &&
      other.matKhau == matKhau;

  @override
  int get hashCode => Object.hash(email, matKhau);
}

/// Đọc `extras` của intent đã mở app.
///
/// ## Vì sao có đường này
///
/// Token nằm trong Keystore, khoá theo tên gói, nên MỘT bản cài chỉ giữ được
/// MỘT phiên. Muốn xem khách đặt lịch rồi Reader nhận ở màn bên cạnh thì phải
/// có bốn máy ảo, mỗi máy một vai trò.
///
/// Trước đây `tool/chay.ps1` gõ hộ bằng `adb shell input tap` theo toạ độ cố
/// định. Cách ấy hỏng bất cứ khi nào bố cục xê dịch, độ phân giải khác đi, hay
/// bàn phím mở chậm hơn nửa giây — và khi hỏng thì nó gõ email vào chỗ trống
/// chứ không báo gì cả.
///
/// `--dart-define` không thay được: nó nướng thẳng vào apk, mà bốn vai trò cần
/// bốn giá trị khác nhau trên CÙNG một bản dựng.
///
/// ## Hai lớp chặn ở bản phát hành
///
/// Đây là một đường vòng qua màn đăng nhập, nên nó phải không tồn tại ở bản
/// phát hành. [kDebugMode] chặn ở đây, và `BuildConfig.DEBUG` chặn lần nữa ở
/// `MainActivity.kt` — hỏng một lớp thì vẫn còn lớp kia.
class DocBoDangNhapThu {
  const DocBoDangNhapThu([this.kenh = const MethodChannel(_ten)]);

  static const _ten = 'astrotarot/tu_dong_dang_nhap';

  final MethodChannel kenh;

  /// Hạn chờ cổng trả lời.
  ///
  /// Phải có, vì ở nơi KHÔNG có đầu nhận bên kia thì lời gọi không ném lỗi —
  /// nó im lặng không bao giờ hồi đáp. Gặp đúng chuyện ấy trong `flutter
  /// test`: `khoiDong()` kẹt lại giữa chừng, `state` không bao giờ chuyển
  /// sang `chuaDangNhap`, và app đứng ở vòng quay khởi động. Hai bài test
  /// đang xanh hoá đỏ, mà dấu hiệu lại là "không tìm thấy màn đăng nhập" —
  /// không hề giống một lời gọi bị treo.
  ///
  /// Trên máy thật, cổng trả lời trong vài mili giây. 200ms là rộng rãi, và
  /// chỉ tốn đúng một lần, chỉ khi chưa có phiên, chỉ ở bản gỡ lỗi.
  static const hanCho = Duration(milliseconds: 200);

  Future<BoDangNhapThu?> doc() async {
    if (!kDebugMode) return null;
    try {
      final ra = await kenh
          .invokeMapMethod<String, String>('layThongTin')
          .timeout(hanCho, onTimeout: () => null);
      final email = ra?['email'];
      final matKhau = ra?['matKhau'];
      if (email == null || matKhau == null) return null;
      if (email.isEmpty || matKhau.isEmpty) return null;
      return BoDangNhapThu(email: email, matKhau: matKhau);
    } on MissingPluginException {
      // Chạy trên iOS, trên máy thật chưa cài bản gỡ lỗi, hay trong test —
      // không có cổng nào trả lời. Đó là trạng thái bình thường, không phải
      // lỗi: cứ coi như không có bộ đăng nhập nào.
      return null;
    } on PlatformException {
      return null;
    }
  }
}

final docBoDangNhapThuProvider =
    Provider<DocBoDangNhapThu>((_) => const DocBoDangNhapThu());
