import 'package:flutter_test/flutter_test.dart';

import 'package:astrotarot_mobile/core/api/endpoints.dart';

/// Khoá lại bản đồ tiền tố của backend.
///
/// Backend có NĂM quy ước tiền tố (xem tài liệu ở đầu [Endpoints]), và đường
/// không tồn tại **không** trả 404 — nó rơi vào `.anyRequest().authenticated()`
/// rồi trả **401 "Phiên đăng nhập đã hết hạn hoặc chưa đăng nhập."**
///
/// Nghĩa là gõ sai một tiền tố thì triệu chứng trông y hệt lỗi xác thực. Đã
/// mắc đúng lỗi này một lần khi dựng app: dùng `/api/v1/auth/login` thay vì
/// `/auth/login`, rồi đi điều tra nhầm sang backend.
///
/// Test này rẻ và bắt được ngay tại chỗ, không cần chạy app.
void main() {
  test('nhom xac thuc dung tien to /auth, KHONG co /api/v1', () {
    const ds = [
      Endpoints.login,
      Endpoints.register,
      Endpoints.refresh,
      Endpoints.logout,
      Endpoints.forgotPassword,
      Endpoints.resetPassword,
    ];
    for (final d in ds) {
      expect(
        d.startsWith('/auth/'),
        isTrue,
        reason: 'AuthController map @RequestMapping("/auth"). Them /api/v1 '
            'vao la duong khong ton tai, va backend tra 401 "phien het han" '
            'chu khong phai 404 — rat de dieu tra nham. Duong sai: $d',
      );
    }
  });

  test('nhom /api/... KHONG duoc mang them v1', () {
    // Ba controller nay co that o /api/... khong co v1. Ai "sua cho dong bo"
    // bang cach them v1 vao se lam hong ca ba man hinh cung luc.
    const ds = [
      Endpoints.aiReadings,
      Endpoints.astrologyProfiles,
      Endpoints.astrologyPrimary,
    ];
    for (final d in ds) {
      expect(d.startsWith('/api/'), isTrue, reason: 'Duong sai: $d');
      expect(
        d.startsWith('/api/v1/'),
        isFalse,
        reason: 'AIReadingController o /api/ai-readings va AstrologyController '
            'o /api/me/astrology/profiles — ca hai deu KHONG co v1. '
            'Duong sai: $d',
      );
    }
  });

  test('nhom nghiep vu con lai CO tien to /api/v1', () {
    final ds = [
      Endpoints.me,
      Endpoints.notifications,
      Endpoints.readers,
      Endpoints.myBookings,
      Endpoints.readerBookings,
      Endpoints.bookings,
      Endpoints.support,
      Endpoints.iceConfig,
      Endpoints.reader('x'),
      Endpoints.readerSlots('x'),
      Endpoints.readerReviews('x'),
      Endpoints.booking('x'),
      Endpoints.bookingPayment('x'),
      Endpoints.bookingMessages('x'),
      Endpoints.bookingMessagesRead('x'),
      Endpoints.bookingConfirm('x'),
      Endpoints.bookingComplete('x'),
      Endpoints.bookingCancel('x'),
      Endpoints.bookingNote('x'),
    ];
    for (final d in ds) {
      expect(d.startsWith('/api/v1/'), isTrue, reason: 'Duong sai: $d');
    }
  });

  test('dich STOMP dung tien to /app va /user/queue', () {
    expect(Endpoints.stompChat('b1'), '/app/bookings/b1/chat');
    expect(Endpoints.stompCall('b1'), '/app/bookings/b1/call');
    for (final q in [
      Endpoints.queueChat,
      Endpoints.queueCall,
      Endpoints.queueErrors,
    ]) {
      expect(q.startsWith('/user/queue/'), isTrue, reason: 'Dich sai: $q');
    }
  });

  test('id duoc chen dung cho trong duong dan co tham so', () {
    const id = 'abc-123';
    expect(Endpoints.reader(id), '/api/v1/readers/$id');
    expect(Endpoints.bookingConfirm(id), '/api/v1/bookings/$id/confirm');
    expect(Endpoints.bookingMessagesRead(id),
        '/api/v1/bookings/$id/messages/read');
  });
}
