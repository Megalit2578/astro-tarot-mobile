import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../api/api_client.dart';
import '../api/endpoints.dart';
import 'auth_controller.dart';

/// Đăng nhập bằng Google trên app.
///
/// ## Vì sao app không đi chung lối với web
///
/// Web chuyển hướng trình duyệt sang Google rồi nhận lại một mã. App không có
/// thanh địa chỉ để chuyển hướng về; thay vào đó thư viện lấy sẵn một **ID
/// token** ngay trên máy, và máy chủ chỉ việc xác minh token ấy với Google.
///
/// ## `serverClientId` là client WEB, không phải client Android
///
/// Chỗ này sai là lỗi khó tìm nhất của cả tính năng. Google cấp cho Android
/// một client ID riêng, nhưng ID token mà ta cần gửi về máy chủ phải mang
/// `aud` là client ID **WEB** — vì chính máy chủ web mới là bên xác minh nó.
/// Đưa nhầm client Android vào đây thì luồng trên máy chạy trơn tru, người
/// dùng chọn tài khoản xong xuôi, rồi máy chủ từ chối ở bước cuối với câu
/// "token không dành cho ứng dụng này".
const String _clientIdWeb =
    '777685600175-nrm4h4im160il6pm3jbjjqkmoaqgaph8.apps.googleusercontent.com';

/// Lỗi đã dịch sẵn sang câu nói được với người dùng.
class LoiDangNhapGoogle implements Exception {
  const LoiDangNhapGoogle(this.message);

  final String message;

  @override
  String toString() => message;
}

class DangNhapGoogle {
  const DangNhapGoogle(this._api);

  final ApiClient _api;

  /// Mở màn chọn tài khoản Google, rồi đổi ID token lấy token của hệ thống.
  ///
  /// Trả về thân phản hồi đăng nhập như `/auth/login`, để nơi gọi dùng lại
  /// đúng đường cũ.
  ///
  /// Ném [LoiDangNhapGoogle] khi người dùng bấm huỷ hoặc máy không hỗ trợ —
  /// hai trường hợp ấy KHÔNG phải lỗi hệ thống và không nên hiện như lỗi đỏ.
  Future<Map<String, dynamic>> dangNhap() async {
    final g = GoogleSignIn.instance;

    // initialize gọi được nhiều lần; thư viện tự bỏ qua lần thừa.
    await g.initialize(serverClientId: _clientIdWeb);

    if (!g.supportsAuthenticate()) {
      throw const LoiDangNhapGoogle(
        'Máy này không mở được đăng nhập Google. Hãy dùng email và mật khẩu.',
      );
    }

    final GoogleSignInAccount taiKhoan;
    try {
      taiKhoan = await g.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const LoiDangNhapGoogle('Đã huỷ đăng nhập Google.');
      }
      throw LoiDangNhapGoogle('Không mở được đăng nhập Google: ${e.code.name}');
    }

    final idToken = taiKhoan.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      // Gần như luôn là do serverClientId sai hoặc chưa khai SHA-1 của bản
      // dựng trong Google Console. Nói thẳng ra để khỏi đi tìm nhầm chỗ.
      throw const LoiDangNhapGoogle(
        'Google không trả về ID token. Kiểm serverClientId và vân tay SHA-1 '
        'của bản dựng trong Google Cloud Console.',
      );
    }

    return await _api.post<Map<String, dynamic>>(
      Endpoints.googleMobile,
      body: {'idToken': idToken},
    );
  }

  /// Quên tài khoản đã chọn, để lần sau Google hỏi lại.
  ///
  /// Gọi lúc đăng xuất. Không gọi thì người dùng bấm "Đăng nhập với Google"
  /// và vào thẳng tài khoản cũ mà không được hỏi — đúng thứ gây hoang mang
  /// khi máy dùng chung.
  Future<void> quenTaiKhoan() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Đăng xuất cục bộ không được phép hỏng vì chuyện này.
    }
  }
}

final dangNhapGoogleProvider = Provider<DangNhapGoogle>(
  (ref) => DangNhapGoogle(ref.read(apiClientProvider)),
);
