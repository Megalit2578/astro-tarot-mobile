import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Nơi cất token.
///
/// Dùng kho bảo mật của hệ điều hành (Keystore trên Android, Keychain trên
/// iOS) chứ không phải SharedPreferences. Bên web buộc phải dùng
/// localStorage — mọi script trong trang đều đọc được — còn ở đây ta có chỗ
/// tử tế hơn, không có lý do gì không dùng.
///
/// Giữ nguyên tên khoá giống bên web cho dễ đối chiếu khi gỡ lỗi, dù hai nơi
/// không chia sẻ dữ liệu gì với nhau.
class TokenStore {
  // Dùng thẳng cấu hình mặc định: từ bản 11, flutter_secure_storage đã mã
  // hoá bằng AES-GCM và bọc khoá bằng RSA sẵn. Các bản trước phải tự bật
  // `encryptedSharedPreferences: true`, và tham số ấy nay không còn — chép
  // lại đoạn cấu hình từ hướng dẫn cũ là lỗi biên dịch.
  TokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _accessKey = 'astrotarot_access_token';
  static const _refreshKey = 'astrotarot_refresh_token';

  final FlutterSecureStorage _storage;

  /// Bản sao trong bộ nhớ để mỗi lời gọi API không phải hỏi Keystore.
  ///
  /// Đọc Keystore là một chuyến sang tầng native; với màn hình gọi vài API
  /// cùng lúc thì độ trễ ấy nhìn thấy được.
  String? _access;
  String? _refresh;
  bool _daNap = false;

  Future<void> nap() async {
    if (_daNap) return;
    _access = await _storage.read(key: _accessKey);
    _refresh = await _storage.read(key: _refreshKey);
    _daNap = true;
  }

  String? get access => _access;
  String? get refresh => _refresh;
  bool get coPhien => _refresh != null && _refresh!.isNotEmpty;

  Future<void> luu(String access, String refresh) async {
    _access = access;
    _refresh = refresh;
    _daNap = true;
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  Future<void> xoa() async {
    _access = null;
    _refresh = null;
    _daNap = true;
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
