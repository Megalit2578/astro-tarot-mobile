import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
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
      final me = await _api.get<Map<String, dynamic>>('/api/v1/me');
      _vaoPhien(AppUser.fromJson(me));
    } catch (_) {
      // Mạng hỏng lúc mở app KHÔNG được làm mất phiên. ApiClient chỉ xoá
      // token khi refresh bị từ chối thẳng; tới đây mà vẫn còn token nghĩa là
      // chưa kết luận được gì — cứ coi như chưa đăng nhập cho lượt này, lần
      // mở sau sẽ thử lại.
      state = state.copy(
        trangThai: _store.coPhien
            ? TrangThaiPhien.chuaDangNhap
            : TrangThaiPhien.chuaDangNhap,
      );
    }
  }

  Future<bool> dangNhap(String email, String matKhau) async {
    state = state.copy(dangXuLy: true, xoaLoi: true);
    try {
      final data = await _api.post<Map<String, dynamic>>(
        '/api/v1/auth/login',
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

  Future<void> dangXuat() async {
    // Báo máy chủ thu hồi phiên, nhưng KHÔNG để lỗi mạng chặn việc đăng xuất:
    // người dùng bấm đăng xuất là họ muốn rời máy này ngay, thường vì đang
    // đưa máy cho người khác.
    try {
      await _api.post('/api/v1/auth/logout');
    } catch (_) {}
    await _donPhien();
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
