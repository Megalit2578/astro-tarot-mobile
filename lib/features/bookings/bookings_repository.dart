import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/api/trang.dart';
import '../../core/auth/auth_controller.dart';
import '../money/payment_sheet.dart';
import 'booking.dart';

class BookingsRepository {
  BookingsRepository(this._api);

  final ApiClient _api;

  /// Đặt một buổi.
  ///
  /// `startTime` gửi đi dạng ISO **UTC** có hậu tố Z. Gửi giờ địa phương
  /// không kèm múi là backend hiểu thành UTC và buổi hẹn lệch bảy tiếng.
  Future<Booking> dat({
    required String readerProfileId,
    required DateTime batDau,
    required int phut,
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      Endpoints.bookings,
      body: {
        'readerProfileId': readerProfileId,
        'startTime': batDau.toUtc().toIso8601String(),
        'durationMinutes': phut,
      },
    );
    return Booking.fromJson(data);
  }

  /// Lịch hẹn của khách, một trang.
  ///
  /// [loc] gửi thẳng xuống máy chủ chứ KHÔNG lọc ở máy khách. Lọc ở đây thì
  /// nó chỉ lọc trong trang đã tải: có 60 buổi, tải 20 buổi gần nhất, chọn
  /// "Đã huỷ" rồi thấy hai buổi — trong khi thật ra có mười. Màn hình trông
  /// vẫn chạy, chỉ là nói sai, nên rất lâu mới có người nhận ra.
  Future<Trang<Booking>> cuaToi({int trang = 0, TrangThaiBuoi? loc}) =>
      _trang(Endpoints.myBookings, trang, loc);

  Future<Trang<Booking>> cuaReader({int trang = 0, TrangThaiBuoi? loc}) =>
      _trang(Endpoints.readerBookings, trang, loc);

  /// Cả tháng, để vẽ lịch. Khác danh sách phân trang: một tháng phải đủ buổi.
  Future<List<Booking>> lichThang({
    required bool cuaReader,
    required int nam,
    required int thang,
  }) async {
    final data = await _api.get<List<dynamic>>(
      cuaReader
          ? Endpoints.readerBookingsCalendar
          : Endpoints.myBookingsCalendar,
      query: {'year': nam, 'month': thang},
    );
    return data
        .whereType<Map<String, dynamic>>()
        .map(Booking.fromJson)
        .toList();
  }

  static const _coTrang = 20;

  Future<Trang<Booking>> _trang(
    String duong,
    int trang,
    TrangThaiBuoi? loc,
  ) async {
    final ma = tenTrangThai(loc);
    final data = await _api.get<dynamic>(
      duong,
      query: {'page': trang, 'size': _coTrang, 'status': ?ma},
    );
    return Trang.tu(data, Booking.fromJson);
  }

  // ---- Hành động phía Reader ----
  //
  // Cả bốn đều là PATCH. Gửi POST thì backend trả 405, và câu báo lỗi không
  // nói gì về phương thức nên rất dễ tưởng là lỗi quyền.

  Future<Booking> nhanLich(String id) =>
      _hanhDong(Endpoints.bookingConfirm(id));

  Future<Booking> hoanTat(String id) =>
      _hanhDong(Endpoints.bookingComplete(id));

  Future<Booking> huy(String id, String? lyDo) =>
      _hanhDong(Endpoints.bookingCancel(id), body: {'reason': lyDo});

  Future<Booking> ghiChu(String id, String noiDung) =>
      _hanhDong(Endpoints.bookingNote(id), body: {'note': noiDung});

  /// Chấm điểm buổi đã hoàn tất. POST, không phải PATCH như bốn cái trên.
  Future<void> danhGia(String id, int diem, String? nhanXet) => _api.post(
    Endpoints.bookingReview(id),
    body: {
      'rating': diem,
      if (nhanXet != null && nhanXet.trim().isNotEmpty)
        'comment': nhanXet.trim(),
    },
  );

  Future<Booking> _hanhDong(String duong, {Object? body}) async {
    final data = await _api.patch<Map<String, dynamic>>(duong, body: body);
    return Booking.fromJson(data);
  }

  /// Tạo (hoặc lấy lại) giao dịch thanh toán cho một buổi.
  ///
  /// Có thể là PayOS (kèm link) hoặc chuyển khoản tay (chỉ có số tài khoản
  /// và nội dung). Gọi lại khi đã có giao dịch chờ thì máy chủ trả đúng giao
  /// dịch cũ, không tạo thêm.
  Future<HuongDanThanhToan> taoThanhToan(String bookingId) async =>
      HuongDanThanhToan.fromJson(
        await _api.post<Map<String, dynamic>>(
          Endpoints.bookingPayment(bookingId),
        ),
      );

  /// Báo cáo người kia trong một buổi xem. Người bị báo cáo không biết ai
  /// đã báo.
  Future<void> baoCao({
    required String nguoiBiBao,
    required String loai,
    String? moTa,
    String? bookingId,
  }) => _api.post(
    Endpoints.reports,
    body: {
      'reportedUserId': nguoiBiBao,
      'reportType': loai,
      if (moTa != null && moTa.trim().isNotEmpty) 'description': moTa.trim(),
      'bookingId': ?bookingId,
    },
  );
}

final bookingsRepositoryProvider = Provider(
  (ref) => BookingsRepository(ref.watch(apiClientProvider)),
);

/// Trang ĐẦU lịch hẹn của khách — dùng cho những chỗ chỉ cần biết "có gì sắp
/// tới không" (trang chủ, chấm đỏ). Danh sách đầy đủ đi qua
/// [DanhSachPhanTrang] với [BookingsRepository.cuaToi].
final myBookingsProvider = FutureProvider<List<Booking>>(
  (ref) async => (await ref.watch(bookingsRepositoryProvider).cuaToi()).muc,
);

final readerBookingsProvider = FutureProvider<List<Booking>>(
  (ref) async => (await ref.watch(bookingsRepositoryProvider).cuaReader()).muc,
);
