import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/auth/auth_controller.dart';
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

  Future<List<Booking>> cuaToi({int page = 0, int size = 20}) =>
      _trang(Endpoints.myBookings, page, size);

  Future<List<Booking>> cuaReader({int page = 0, int size = 20}) =>
      _trang(Endpoints.readerBookings, page, size);

  Future<List<Booking>> _trang(String duong, int page, int size) async {
    final data = await _api.get<Map<String, dynamic>>(
      duong,
      query: {'page': page, 'size': size},
    );
    final content = data['content'];
    if (content is! List) return const [];
    return content
        .whereType<Map<String, dynamic>>()
        .map(Booking.fromJson)
        .toList();
  }

  /// Tạo giao dịch thanh toán, trả về liên kết để mở trình duyệt.
  Future<String?> taoThanhToan(String bookingId) async {
    final data = await _api.post<Map<String, dynamic>>(
      Endpoints.bookingPayment(bookingId),
    );
    // Backend đặt tên trường khác nhau tuỳ cổng; nhận cả hai để khỏi phải sửa
    // khi đổi cổng thanh toán.
    return (data['checkoutUrl'] ?? data['paymentUrl'] ?? data['url'])
        as String?;
  }
}

final bookingsRepositoryProvider = Provider(
  (ref) => BookingsRepository(ref.watch(apiClientProvider)),
);

final myBookingsProvider = FutureProvider<List<Booking>>(
  (ref) => ref.watch(bookingsRepositoryProvider).cuaToi(),
);

final readerBookingsProvider = FutureProvider<List<Booking>>(
  (ref) => ref.watch(bookingsRepositoryProvider).cuaReader(),
);
