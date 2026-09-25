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

  /// Gốc của trang web, KHÁC gốc API.
  ///
  /// Ảnh sản phẩm trong gian hàng được backend trả về dưới dạng đường dẫn
  /// tương đối như `/products/thoth-tarot.jpg`. Trên web chúng tự khớp vì
  /// trang và ảnh cùng một tên miền; trong app thì không có "trang" nào để
  /// khớp, nên phải tự ghép. Ghép nhầm vào gốc API thì ảnh trả 401 — đúng,
  /// bốn-không-một chứ không phải 404, vì đường lạ ở API đòi đăng nhập.
  static const String webBaseUrl = String.fromEnvironment(
    'WEB_BASE_URL',
    defaultValue: 'https://astrotarot.date',
  );

  /// Ghép đường dẫn ảnh tương đối thành URL đầy đủ.
  static String? anh(String? duong) {
    if (duong == null || duong.trim().isEmpty) return null;
    final d = duong.trim();
    if (d.startsWith('http://') || d.startsWith('https://')) return d;
    return '$webBaseUrl${d.startsWith('/') ? '' : '/'}$d';
  }

  /// Bật log mạng. Chỉ khi chạy debug — bản phát hành in ra là rò token.
  static const bool logHttp = bool.fromEnvironment('LOG_HTTP', defaultValue: false);
}
