/// Cấu hình theo môi trường.
///
/// Không nhúng cứng URL vào mã: truyền lúc build bằng
/// `flutter run --dart-define=API_BASE_URL=...`.
///
/// Vài giá trị hay dùng:
/// - Máy thật / bản phát hành: `https://api.astrotarot.date` (mặc định)
/// - Máy ảo Android chạy BE ở máy này: `http://10.0.2.2:8080`
///   (KHÔNG phải `localhost` — trong máy ảo, `localhost` là chính máy ảo đó,
///   không phải máy tính của bạn. Đây là chỗ hay mất cả buổi để nhận ra.)
/// - Máy ảo iOS: `http://localhost:8080` thì lại đúng.
library;

class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.astrotarot.date',
  );

  /// Gốc WebSocket suy ra từ URL API, đổi http→ws.
  ///
  /// Tự suy thay vì thêm một biến nữa: hai giá trị này luôn trỏ cùng một máy
  /// chủ, mà để rời nhau thì sớm muộn có người đổi một cái quên cái kia, và
  /// lỗi hiện ra là "chat không chạy" chứ không nói gì tới cấu hình.
  static String get wsUrl {
    final u = Uri.parse(apiBaseUrl);
    final scheme = u.scheme == 'https' ? 'wss' : 'ws';
    return u.replace(scheme: scheme, path: '/ws').toString();
  }

  /// Bật log mạng. Chỉ khi chạy debug — bản phát hành in ra là rò token.
  static const bool logHttp = bool.fromEnvironment('LOG_HTTP', defaultValue: false);
}
