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
  void xemMan(String tenMan) => ghi('xem_man', kem: {'man': tenMan});

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
