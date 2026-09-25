/// Đường dẫn API, gom về một chỗ.
///
/// ## Cái bẫy: KHÔNG phải endpoint nào cũng có tiền tố `/api/v1`
///
/// Nhóm xác thực nằm ở `/auth/...` trần — `AuthController` bên backend map
/// `@RequestMapping("/auth")`. Mọi thứ còn lại mới ở `/api/v1/...`.
///
/// Vì sao phải ghi lại: đoán nhầm thành `/api/v1/auth/login` thì đường đó
/// không tồn tại, rơi vào `.anyRequest().authenticated()` của SecurityConfig,
/// và trả về **401 "Phiên đăng nhập đã hết hạn hoặc chưa đăng nhập."** chứ
/// không phải 404. Câu đó nghe như lỗi phiên nên rất dễ đi điều tra nhầm sang
/// backend, trong khi sự thật chỉ là gõ sai đường. Đã mất thời gian vì đúng
/// chuyện này một lần rồi.
///
/// Cách tự kiểm khi nghi ngờ một đường dẫn:
/// ```
/// curl -i -X POST https://api.astrotarot.date/auth/login \
///   -H 'Content-Type: application/json' -d '{"email":"x@y.z","password":"sai"}'
/// ```
/// Đúng đường thì ra `400 {"message":"Email hoặc mật khẩu không đúng"}`.
/// Sai đường thì ra `401 {"error":{"code":"UNAUTHENTICATED", ...}}`.
class Endpoints {
  const Endpoints._();

  // ---- Xác thực: KHÔNG có /api/v1 ----
  static const login = '/auth/login';
  static const register = '/auth/register';
  static const refresh = '/auth/refresh';
  static const logout = '/auth/logout';
  static const forgotPassword = '/auth/forgot-password';
  static const resetPassword = '/auth/reset-password';

  // ---- Phần còn lại: có /api/v1 ----
  static const me = '/api/v1/me';
  static const readers = '/api/v1/readers';
  static String reader(String id) => '/api/v1/readers/$id';
  static String readerSlots(String id) => '/api/v1/readers/$id/slots';
  static String readerReviews(String id) => '/api/v1/readers/$id/reviews';

  static const myBookings = '/api/v1/bookings/me';
  static const readerBookings = '/api/v1/bookings/reader';
  static const bookings = '/api/v1/bookings';
  static String booking(String id) => '/api/v1/bookings/$id';
  static String bookingPayment(String id) => '/api/v1/bookings/$id/payment';
  static String bookingMessages(String id) => '/api/v1/bookings/$id/messages';
  static String bookingMessagesRead(String id) =>
      '/api/v1/bookings/$id/messages/read';

  static const iceConfig = '/api/v1/rtc/ice';

  // ---- Đích STOMP (không đi qua Dio) ----
  static String stompChat(String bookingId) => '/app/bookings/$bookingId/chat';
  static String stompCall(String bookingId) => '/app/bookings/$bookingId/call';
  static const queueChat = '/user/queue/booking-chat';
  static const queueCall = '/user/queue/booking-call';
  static const queueErrors = '/user/queue/errors';
}
