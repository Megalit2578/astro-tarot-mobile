import 'package:flutter_test/flutter_test.dart';

import 'package:astrotarot_mobile/core/api/endpoints.dart';

/// Canh đúng một thứ: nhóm xác thực KHÔNG mang tiền tố `/api/v1`.
///
/// Đây là lỗi đã mắc thật khi dựng khung app. Gõ `/api/v1/auth/login` thì
/// đường đó không tồn tại, rơi vào `.anyRequest().authenticated()` bên
/// SecurityConfig, và backend trả **401 "Phiên đăng nhập đã hết hạn hoặc chưa
/// đăng nhập."** chứ không phải 404.
///
/// Câu ấy nghe hệt lỗi phiên, nên người đọc đi điều tra nhầm sang backend —
/// mất thời gian rồi mới phát hiện chỉ là gõ sai đường. Test này bắt lỗi ngay
/// tại chỗ, không cần chạy app.
void main() {
  const duongXacThuc = [
    Endpoints.login,
    Endpoints.register,
    Endpoints.refresh,
    Endpoints.logout,
    Endpoints.forgotPassword,
    Endpoints.resetPassword,
  ];

  test('duong xac thuc KHONG co tien to /api/v1', () {
    for (final d in duongXacThuc) {
      expect(
        d.startsWith('/auth/'),
        isTrue,
        reason: 'AuthController ben backend map @RequestMapping("/auth"). '
            'Them /api/v1 vao la duong khong ton tai, va backend tra 401 '
            '"phien het han" chu khong phai 404 — rat de dieu tra nham. '
            'Duong sai: $d',
      );
    }
  });

  test('duong nghiep vu CO tien to /api/v1', () {
    final duongNghiepVu = [
      Endpoints.me,
      Endpoints.readers,
      Endpoints.myBookings,
      Endpoints.readerBookings,
      Endpoints.bookings,
      Endpoints.iceConfig,
      Endpoints.reader('x'),
      Endpoints.readerSlots('x'),
      Endpoints.booking('x'),
      Endpoints.bookingPayment('x'),
      Endpoints.bookingMessages('x'),
    ];
    for (final d in duongNghiepVu) {
      expect(d.startsWith('/api/v1/'), isTrue, reason: 'Duong sai: $d');
    }
  });

  test('dich STOMP dung tien to /app va /user/queue', () {
    expect(Endpoints.stompChat('b1'), '/app/bookings/b1/chat');
    expect(Endpoints.stompCall('b1'), '/app/bookings/b1/call');
    expect(Endpoints.queueChat.startsWith('/user/queue/'), isTrue);
    expect(Endpoints.queueCall.startsWith('/user/queue/'), isTrue);
  });
}
