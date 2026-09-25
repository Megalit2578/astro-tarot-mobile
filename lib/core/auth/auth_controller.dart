import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/endpoints.dart';
import '../api/token_store.dart';
import '../realtime/realtime_client.dart';
import 'app_user.dart';

/// Trạng thái phiên đăng nhập.
enum TrangThaiPhien {
  /// Đang đọc token trong Keystore lúc mở app — chưa biết đã đăng nhập chưa.
  dangKhoiDong,
  chuaDangNhap,
  daDangNhap,
}

class AuthState {
  const AuthState({
    this.trangThai = TrangThaiPhien.dangKhoiDong,
    this.user,
    this.dangXuLy = false,
    this.loi,
  });

  final TrangThaiPhien trangThai;
  final AppUser? user;
  final bool dangXuLy;
  final String? loi;

  AuthState copy({
    TrangThaiPhien? trangThai,
    AppUser? user,
    bool? dangXuLy,
    String? loi,
    bool xoaLoi = false,
    bool xoaUser = false,
  }) =>
      AuthState(
        trangThai: trangThai ?? this.trangThai,
        user: xoaUser ? null : (user ?? this.user),
        dangXuLy: dangXuLy ?? this.dangXuLy,
        loi: xoaLoi ? null : (loi ?? this.loi),
      );
}

final tokenStoreProvider = Provider((_) => TokenStore());

final apiClientProvider = Provider<ApiClient>((ref) {
  final store = ref.watch(tokenStoreProvider);
  return ApiClient(
    tokenStore: store,
    khiPhienHong: () {
      // Refresh token chết hẳn: dọn phiên để bộ định tuyến đẩy về màn đăng
      // nhập. Gọi qua ref chứ không đụng thẳng vào state, để một chỗ duy nhất
      // quyết định "thế nào là đã đăng xuất".
      ref.read(authControllerProvider.notifier).phienHetHan();
    },
  );
});

final realtimeProvider = Provider<RealtimeClient>((ref) {
  final store = ref.watch(tokenStoreProvider);
  final rt = RealtimeClient(tokenStore: store);
  ref.onDispose(rt.ngat);
  return rt;
});

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Không await trong build() — Riverpod cần trả trạng thái ngay. Màn khởi
    // động hiển thị vòng quay cho tới khi khoiDong() xong.
    Future.microtask(khoiDong);
    return const AuthState();
  }

  ApiClient get _api => ref.read(apiClientProvider);
  TokenStore get _store => ref.read(tokenStoreProvider);

  /// Mở app: có token cũ thì hỏi máy chủ xem còn dùng được không.
  ///
  /// Hỏi `/me` chứ không tin token trong máy: token có thể đã bị thu hồi,
  /// hoặc vai trò đã đổi (được cất lên Nhân viên chẳng hạn) mà bản lưu trong
  /// máy vẫn là vai trò cũ. Tin bản cũ là bày sai menu cho tới lần đăng nhập
  /// kế tiếp.
  Future<void> khoiDong() async {
    await _store.nap();
    if (!_store.coPhien) {
      state = state.copy(trangThai: TrangThaiPhien.chuaDangNhap);
      return;
    }
    try {
      final me = await _api.get<Map<String, dynamic>>(Endpoints.me);
      _vaoPhien(AppUser.fromJson(me));
    } catch (_) {
      // Mạng hỏng lúc mở app KHÔNG được làm mất phiên. ApiClient chỉ xoá
      // token khi refresh bị từ chối thẳng; tới đây mà vẫn còn token nghĩa là
      // chưa kết luận được gì — cứ coi như chưa đăng nhập cho lượt này, lần
      // mở sau sẽ thử lại.
      // Token vẫn được GIỮ nguyên trong Keystore. ApiClient chỉ xoá nó khi
      // máy chủ từ chối thẳng refresh token; tới đây thì chưa kết luận được
      // gì, nên chỉ hiện màn đăng nhập cho lượt này và thử lại ở lần mở sau.
      state = state.copy(trangThai: TrangThaiPhien.chuaDangNhap);
    }
  }

  Future<bool> dangNhap(String email, String matKhau) async {
    state = state.copy(dangXuLy: true, xoaLoi: true);
    try {
      final data = await _api.post<Map<String, dynamic>>(
        Endpoints.login,
        body: {'email': email.trim(), 'password': matKhau},
      );
      await _store.luu(
        data['accessToken'] as String,
        data['refreshToken'] as String,
      );
      _vaoPhien(AppUser.fromJson(data));
      return true;
    } on ApiException catch (e) {
      state = state.copy(dangXuLy: false, loi: e.message);
      return false;
    } catch (_) {
      state = state.copy(dangXuLy: false, loi: 'Không đăng nhập được.');
      return false;
    }
  }

  /// Đăng ký. **Không** trả token — tài khoản phải xác minh email đã.
  ///
  /// Trả về câu cần nói với người dùng, hoặc ném [ApiException].
  Future<String> dangKy({
    required String email,
    required String matKhau,
    required String hoTen,
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      Endpoints.register,
      body: {
        'email': email.trim(),
        'password': matKhau,
        // camelCase. Backend nhận `fullName`; gửi `full_name` là bị bỏ qua
        // rồi báo "Họ tên là bắt buộc" dù người dùng đã điền.
        'fullName': hoTen.trim(),
      },
    );
    final daGui = data['verificationEmailSent'] == true;
    return daGui
        ? 'Đã gửi thư xác minh tới ${email.trim()}. Mở thư và bấm liên kết '
            'trong đó rồi quay lại đăng nhập.'
        : 'Đã tạo tài khoản. Hãy xác minh email rồi đăng nhập.';
  }

  /// Gửi thư đặt lại mật khẩu.
  ///
  /// Luôn báo thành công dù email có tồn tại hay không — đó là hành vi của
  /// backend, và cũng là điều đúng: trả lời khác nhau cho email có và không
  /// có là biến đây thành công cụ dò xem ai đã đăng ký.
  Future<void> quenMatKhau(String email) async {
    await _api.post(Endpoints.forgotPassword, body: {'email': email.trim()});
  }

  Future<void> dangXuat() async {
    // Báo máy chủ thu hồi phiên, nhưng KHÔNG để lỗi mạng chặn việc đăng xuất:
    // người dùng bấm đăng xuất là họ muốn rời máy này ngay, thường vì đang
    // đưa máy cho người khác.
    try {
      await _api.post(Endpoints.logout);
    } catch (_) {}
    await _donPhien();
  }

  /// Nạp lại thông tin người đang đăng nhập.
  ///
  /// Gọi sau khi sửa hồ sơ: tên và ảnh đại diện xuất hiện ở nhiều màn khác
  /// (thanh tài khoản, bong bóng chat), và nếu không nạp lại thì chúng vẫn là
  /// bản cũ cho tới lần mở app kế tiếp — người dùng tưởng lưu không ăn.
  ///
  /// Hỏng thì im lặng bỏ qua: đây là việc làm đẹp thêm, không được phép làm
  /// hỏng thao tác lưu vừa thành công.
  Future<void> lamMoiToi() async {
    try {
      final me = await _api.get<Map<String, dynamic>>(Endpoints.me);
      state = state.copy(user: AppUser.fromJson(me));
    } catch (_) {}
  }

  /// ApiClient gọi vào đây khi refresh token bị từ chối.
  void phienHetHan() {
    _donPhien();
  }

  void _vaoPhien(AppUser u) {
    state = AuthState(trangThai: TrangThaiPhien.daDangNhap, user: u);
    // Nối realtime SAU khi đã có token, không phải lúc mở app.
    ref.read(realtimeProvider).noi();
  }

  Future<void> _donPhien() async {
    ref.read(realtimeProvider).ngat();
    await _store.xoa();
    state = const AuthState(trangThai: TrangThaiPhien.chuaDangNhap);
  }
}
