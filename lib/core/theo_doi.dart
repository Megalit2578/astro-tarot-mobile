import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/api_client.dart';
import 'api/endpoints.dart';
import 'auth/auth_controller.dart';
import 'ma_khach.dart';

/// Ghi lại việc người dùng vừa LÀM, để biết khách đến từ kênh nào thì làm gì.
///
/// ## Vì sao app cũng phải ghi
///
/// Bảng `marketing_events` bên máy chủ dựng ra bảng "khách đến từ đâu, rồi
/// làm gì" ở trang quản trị. Trước đây chỉ web ghi vào đó. Nên một người xem
/// quảng cáo trên TikTok, tải app, rồi trải bài và đặt lịch trong app — toàn
/// bộ hành trình ấy biến mất khỏi báo cáo, và kênh TikTok trông như không
/// mang lại gì.
///
/// ## Vì sao không kèm UTM
///
/// Người cài app không mang theo tham số `utm_*` nào cả: họ đi qua CH Play,
/// không qua một đường link của mình. Gửi `utmSource` rỗng là **đúng** — máy
/// chủ gom những hàng ấy vào nhóm "(không rõ nguồn)".
///
/// Muốn tách riêng lưu lượng app thì đọc theo `path`: mọi sự kiện từ đây đều
/// mang tiền tố `app:`, không trùng với bất kỳ đường dẫn web nào.
///
/// ## Hỏng thì im lặng
///
/// Theo dõi là việc phụ. Mạng rớt, máy chủ ngủ, token hết hạn — không được
/// phép làm hỏng thao tác người dùng vừa làm, và càng không được hiện lỗi.
class TheoDoi {
  const TheoDoi(this._api, this._maKhach);

  final ApiClient _api;
  final MaKhach _maKhach;

  /// Ghi một lượt XEM MÀN HÌNH.
  ///
  /// Vì sao cần, dù đã có [ghi]: [ghi] chỉ chạy khi người dùng làm xong một
  /// việc cụ thể. Ai mở app, lướt vài màn rồi thoát — phần lớn phiên thật —
  /// không để lại dòng nào, nên hành trình của họ trống trơn.
  ///
  /// [tenMan] là NHÃN NGƯỜI ĐỌC ĐƯỢC, đúng chữ người dùng thấy trên thanh
  /// điều hướng ("Tài khoản", "Bàn làm việc"), vì nó được in thẳng ra bảng
  /// "Hành trình người dùng" ở trang quản trị. Đừng truyền khoá thô kiểu
  /// `mo_app` hay `tab_account`: trang quản trị không có bảng tra nào để dịch
  /// lại, nên người đọc báo cáo nhận đúng cái khoá ấy giữa màn.
  ///
  /// Và chỉ dùng cho MÀN THẬT. Một sự kiện không phải lượt xem màn thì gọi
  /// [ghi] với tên riêng của nó — xem [moApp].
  void xemMan(String tenMan) => ghi('xem_man', kem: {'man': tenMan});

  /// Ghi lượt MỞ APP.
  ///
  /// Vì sao không gọi [xemMan]: mở app không phải một màn hình. Chỗ này từng
  /// gọi `xemMan('mo_app')`, nên bảng "Hành trình người dùng" in ra dòng
  /// "Xem màn mo_app" — sai hai lần: vừa không phải lượt xem màn, vừa là khoá
  /// thô lọt ra trước mặt người đọc báo cáo. Bên web đã phải dựng một bảng
  /// đổi tên để che chỗ ấy, tức là nuôi một nguồn-thứ-hai cho thứ đáng ra chỉ
  /// cần gửi đúng từ đây.
  ///
  /// Cố ý KHÔNG kèm `man`: chính việc thiếu trường ấy là thứ phân biệt "mở
  /// app" với một lượt xem màn, ở cả hai phía.
  void moApp() => ghi('mo_app');

  /// Gọi SAU khi việc đó đã thành công.
  ///
  /// Đặt trước khi gọi API thì mỗi lần bấm hụt, hết hạn mức hay mạng rớt đều
  /// bị đếm như một lượt thật — và con số ấy không sửa lại được về sau.
  void ghi(String ten, {Map<String, Object?>? kem}) {
    if (ten.isEmpty) return;
    // Không await: người dùng không phải đợi một request thống kê.
    unawaited(_gui(ten, kem));
  }

  Future<void> _gui(String ten, Map<String, Object?>? kem) async {
    try {
      await _api.post<dynamic>(
        Endpoints.marketingEvents,
        body: {
          'eventName': ten,
          'path': 'app:$ten',
          // Nối các hành động của cùng một người. Rỗng thì máy chủ ghi NULL
          // và riêng hành trình của khách ấy không dựng được — mọi thứ khác
          // vẫn chạy.
          'visitorId': _maKhach.ma,
          'metadata': kem == null ? null : jsonEncode(kem),
        },
      );
    } catch (_) {
      // Cố ý nuốt. Xem phần "Hỏng thì im lặng" ở trên.
    }
  }
}

/// Mã khách dùng chung cho cả app — một bản duy nhất, nạp một lần.
final maKhachProvider = Provider<MaKhach>((ref) => MaKhach());

final theoDoiProvider = Provider<TheoDoi>(
  (ref) => TheoDoi(ref.read(apiClientProvider), ref.read(maKhachProvider)),
);
