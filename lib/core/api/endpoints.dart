/// Đường dẫn API, gom về một chỗ.
///
/// ## Backend có NĂM quy ước tiền tố, không phải một
///
/// Đây là phần duy nhất trong tệp này thật sự cần đọc kỹ. Khảo sát toàn bộ 27
/// controller ngày 2026-09-25:
///
/// | Tiền tố | Ai dùng |
/// |---|---|
/// | `/auth` | `AuthController` — đăng nhập, đăng ký, làm mới token |
/// | `/user/email` | `UserEmailController` |
/// | `/api/…` (không có v1) | `AIReadingController` + `AIChatController` (`/api/ai-readings`), `ChatController` (`/api/chat`), `AstrologyController` (`/api/me/astrology/profiles`), `OAuthExchangeController` (`/api/auth/oauth`) |
/// | `/api/v1/…` | phần lớn còn lại |
/// | `/api/v1/bookings/{id}` | `BookingChatController` — biến đường dẫn nằm ngay trong `@RequestMapping` |
///
/// ## Vì sao đoán sai tiền tố lại tốn thời gian
///
/// Đường không tồn tại **không** trả 404. Nó rơi vào
/// `.anyRequest().authenticated()` của `SecurityConfig` và trả **401 "Phiên
/// đăng nhập đã hết hạn hoặc chưa đăng nhập."** Câu đó nghe hệt lỗi phiên,
/// nên người đọc đi điều tra nhầm sang xác thực. Đã mất thời gian vì đúng
/// chuyện này một lần khi dựng app.
///
/// Cách tự kiểm một đường dẫn trong ba mươi giây:
/// ```
/// curl -i -X POST https://api.astrotarot.date/auth/login \
///   -H 'Content-Type: application/json' -d '{"email":"x@y.z","password":"sai"}'
/// ```
/// Đúng đường → `400 {"message":"Email hoặc mật khẩu không đúng"}`.
/// Sai đường → `401 {"error":{"code":"UNAUTHENTICATED", …}}`.
///
/// **Đừng suy ra tiền tố. Tra bảng trên, hoặc curl thử.**
class Endpoints {
  const Endpoints._();

  // ---- Xác thực: tiền tố /auth, KHÔNG có /api/v1 ----
  static const login = '/auth/login';
  static const register = '/auth/register';
  static const refresh = '/auth/refresh';
  static const logout = '/auth/logout';
  static const forgotPassword = '/auth/forgot-password';
  static const resetPassword = '/auth/reset-password';
  static const verifyEmail = '/auth/verify-email';
  static const resendVerification = '/auth/resend-verification';

  // ---- Tôi ----
  static const me = '/api/v1/me';
  static const notifications = '/api/v1/me/notifications';
  static const meAvatar = '/api/v1/me/avatar';
  static const meChangePassword = '/api/v1/me/change-password';

  // ---- Reader ----
  static const readers = '/api/v1/readers';
  static String reader(String id) => '/api/v1/readers/$id';
  static String readerSlots(String id) => '/api/v1/readers/$id/slots';
  static String readerReviews(String id) => '/api/v1/readers/$id/reviews';
  static String readerNextAvailable(String id) =>
      '/api/v1/readers/$id/slots/next-available';
  static const readerApply = '/api/v1/readers/apply';
  static const myReaderApplication = '/api/v1/readers/applications/me';
  static const unavailableDates = '/api/v1/unavailable-dates';

  // ---- Lịch hẹn ----
  static const myBookings = '/api/v1/bookings/me';
  static const readerBookings = '/api/v1/bookings/reader';
  static const bookings = '/api/v1/bookings';
  static String booking(String id) => '/api/v1/bookings/$id';
  static String bookingPayment(String id) => '/api/v1/bookings/$id/payment';
  static String bookingMessages(String id) => '/api/v1/bookings/$id/messages';
  static String bookingMessagesRead(String id) =>
      '/api/v1/bookings/$id/messages/read';

  // Bốn hành động dưới đây đều là PATCH, không phải POST.
  static String bookingConfirm(String id) => '/api/v1/bookings/$id/confirm';
  static String bookingComplete(String id) => '/api/v1/bookings/$id/complete';
  static String bookingCancel(String id) => '/api/v1/bookings/$id/cancel';
  static String bookingNote(String id) => '/api/v1/bookings/$id/note';

  /// Đánh giá là POST, khác bốn hành động PATCH ở trên.
  static String bookingReview(String id) => '/api/v1/bookings/$id/review';

  /// Kênh sự kiện chung (thông báo). Khác hai hàng đợi của buổi tư vấn.
  static const queueEvents = '/user/queue/events';

  // ---- Tarot AI: /api/ai-readings, KHÔNG có /v1 ----
  static const aiReadings = '/api/ai-readings';

  // ---- Bản đồ sao: /api/me/…, KHÔNG có /v1 ----
  static const astrologyProfiles = '/api/me/astrology/profiles';
  static const astrologyPrimary = '/api/me/astrology/profiles/primary';
  static String astrologyProfile(String id) =>
      '/api/me/astrology/profiles/$id';

  // ---- Quản trị ----
  static const adminStats = '/api/v1/admin/stats';
  static const adminUsers = '/api/v1/admin/users';
  static String adminUser(String id) => '/api/v1/admin/users/$id';
  static String adminUserRole(String id) => '/api/v1/admin/users/$id/role';
  static String adminUserStatus(String id) => '/api/v1/admin/users/$id/status';

  /// Đổi vai trò hàng loạt. Cùng tiền tố với [adminUserRole] nhưng không có
  /// id — đặt cạnh nhau để khỏi nhầm.
  static const adminUsersRoleBulk = '/api/v1/admin/users/role';
  static String adminUserRevokeSessions(String id) =>
      '/api/v1/admin/users/$id/sessions/revoke';
  static String adminUserPasswordReset(String id) =>
      '/api/v1/admin/users/$id/password-reset';
  static String adminUserResendVerification(String id) =>
      '/api/v1/admin/users/$id/resend-verification';
  static const adminActivityLogs = '/api/v1/admin/activity-logs';
  static const adminReaderApplications = '/api/v1/admin/readers/applications';
  static String adminReaderReview(String applicationId) =>
      '/api/v1/admin/readers/$applicationId/review';

  // MoneyController map @RequestMapping("/api/v1") rồi mới nối "/admin/...",
  // nên đường đầy đủ vẫn là /api/v1/admin/... như nhóm trên.
  static const adminPayments = '/api/v1/admin/payments';
  static String adminPaymentConfirm(String id) =>
      '/api/v1/admin/payments/$id/confirm';
  static String adminPaymentReject(String id) =>
      '/api/v1/admin/payments/$id/reject';
  static const adminPayouts = '/api/v1/admin/payouts';
  static String adminPayoutApprove(String id) =>
      '/api/v1/admin/payouts/$id/approve';
  static String adminPayoutReject(String id) =>
      '/api/v1/admin/payouts/$id/reject';
  static String adminPayoutPaid(String id) => '/api/v1/admin/payouts/$id/paid';
  static const adminReports = '/api/v1/admin/reports';
  static String adminReportHandle(String id) =>
      '/api/v1/admin/reports/$id/handle';

  /// Khách gửi báo cáo vi phạm. Cùng MoneyController nhưng KHÔNG có /admin.
  static const reports = '/api/v1/reports';

  // ShopAdminController cũng map @RequestMapping("/api/v1") rồi nối
  // "/admin/products" — khác gian hàng công khai ở /api/v1/shop.
  static const adminProducts = '/api/v1/admin/products';
  static String adminProduct(String id) => '/api/v1/admin/products/$id';
  static String adminProductActive(String id) =>
      '/api/v1/admin/products/$id/active';
  static const adminAffiliateStats = '/api/v1/admin/affiliate/stats';

  // ---- Hỗ trợ ----
  static const support = '/api/v1/support';

  // ---- Gian hàng (liên kết tiếp thị, không bán trong app) ----
  static const shopProducts = '/api/v1/shop/products';
  static const shopCategories = '/api/v1/shop/categories';
  static String shopProduct(String slug) => '/api/v1/shop/products/$slug';

  /// Ghi nhận một lượt bấm sang sàn liên kết. Công khai, không cần đăng nhập.
  ///
  /// Nhận **slug**, không phải id: gửi id là 404. Trả `{url}` để mở.
  static String shopClick(String slug) => '/api/v1/shop/products/$slug/click';

  // ---- Khảo sát ----
  static const feedback = '/api/v1/feedback';
  static const feedbackStatus = '/api/v1/feedback/me/status';

  // ---- Blog ----
  static const blogs = '/api/v1/blogs';
  static String blog(String slug) => '/api/v1/blogs/$slug';

  // ---- WebRTC ----
  static const iceConfig = '/api/v1/rtc/ice';

  // ---- Đích STOMP (không đi qua Dio) ----
  static String stompChat(String bookingId) => '/app/bookings/$bookingId/chat';
  static String stompCall(String bookingId) => '/app/bookings/$bookingId/call';
  static const queueChat = '/user/queue/booking-chat';
  static const queueCall = '/user/queue/booking-call';
  static const queueErrors = '/user/queue/errors';
}
