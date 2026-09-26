// Bộ đồ nghề test dùng chung: máy chủ giả chặn ngay ở tầng HTTP của Dio,
// phiên đăng nhập giả, realtime giả, và hàm dựng một màn hình trong
// ProviderScope đã thay hết các phần chạm ra ngoài.
//
// Chặn ở tầng HTTP (HttpClientAdapter) chứ không giả repository: như vậy
// test đi qua ĐÚNG đường thật — ApiClient, interceptor, bóc bao thư, dịch
// lỗi — và bắt được đúng loại lỗi đã từng xảy ra: sai phương thức (POST thay
// PATCH), sai tên trường (`reason` thay `rejectionReason`), sai đường dẫn.

import 'dart:convert';

import 'package:astrotarot_mobile/core/api/api_client.dart';
import 'package:astrotarot_mobile/core/api/token_store.dart';
import 'package:astrotarot_mobile/core/auth/app_user.dart';
import 'package:astrotarot_mobile/core/auth/auth_controller.dart';
import 'package:astrotarot_mobile/core/realtime/realtime_client.dart';
import 'package:astrotarot_mobile/features/astrology/astrology_repository.dart';
import 'package:astrotarot_mobile/theme.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Một lời gọi máy chủ giả đã nhận.
class LoiGoi {
  LoiGoi(this.phuongThuc, this.duong, this.query, this.than);
  final String phuongThuc;
  final String duong;
  final Map<String, dynamic> query;
  final dynamic than;

  @override
  String toString() => '$phuongThuc $duong $query $than';
}

/// Câu trả lời của máy chủ giả.
class TraLoi {
  const TraLoi(this.ma, this.than);
  final int ma;
  final dynamic than;
}

typedef XuLy = TraLoi Function(LoiGoi g);

/// Máy chủ giả.
///
/// Khai route bằng `"GET /api/v1/me"`. Dấu `*` khớp đúng một đoạn đường dẫn
/// (`"PATCH /api/v1/admin/users/*/role"`). Route chưa khai trả 404 kèm câu
/// nói rõ đường nào thiếu — test hỏng là biết ngay thiếu gì.
class MayChuGia implements HttpClientAdapter {
  final _route = <String, XuLy>{};
  final goi = <LoiGoi>[];

  /// Trả `{success, message, data}` như backend thật.
  void tra(String route, dynamic data, {int ma = 200, String? message}) {
    _route[route] = (_) => TraLoi(ma, {
          'success': ma < 400,
          'message': message ?? (ma < 400 ? 'OK' : 'Lỗi giả'),
          'data': data,
        });
  }

  /// Trả lỗi với câu máy chủ gửi.
  void loi(String route, String message, {int ma = 400}) =>
      tra(route, null, ma: ma, message: message);

  /// Tự xử lý (khi câu trả lời phụ thuộc vào thân yêu cầu).
  void xuLy(String route, XuLy f) => _route[route] = f;

  /// Mọi lời gọi khớp phương thức + đường dẫn (có thể chứa `*`).
  List<LoiGoi> cacLan(String route) =>
      goi.where((g) => _khop(route, g)).toList();

  LoiGoi? lanCuoi(String route) {
    final ds = cacLan(route);
    return ds.isEmpty ? null : ds.last;
  }

  static bool _khop(String route, LoiGoi g) {
    final i = route.indexOf(' ');
    if (route.substring(0, i) != g.phuongThuc) return false;
    final mau = route.substring(i + 1).split('/');
    final that = g.duong.split('/');
    if (mau.length != that.length) return false;
    for (var k = 0; k < mau.length; k++) {
      if (mau[k] != '*' && mau[k] != that[k]) return false;
    }
    return true;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final uri = options.uri;
    final g = LoiGoi(
      options.method,
      uri.path,
      {...uri.queryParameters},
      options.data is FormData ? '<form>' : options.data,
    );
    goi.add(g);
    XuLy? f = _route['${g.phuongThuc} ${g.duong}'];
    if (f == null) {
      for (final e in _route.entries) {
        if (_khop(e.key, g)) {
          f = e.value;
          break;
        }
      }
    }
    final tl = f?.call(g) ??
        TraLoi(404, {
          'success': false,
          'message': 'Không có route giả: ${g.phuongThuc} ${g.duong}',
        });
    return ResponseBody.fromString(
      jsonEncode(tl.than),
      tl.ma,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Realtime giả: không mở socket, cho test tự phát tin tới người nghe.
class RealtimeGia extends RealtimeClient {
  RealtimeGia() : super(tokenStore: TokenStore());

  final nguoiNghe = <String, List<RealtimeHandler>>{};
  final daGui = <(String, Map<String, dynamic>)>[];
  bool daNoi = false;

  /// Cho `gui` trả gì — false để ép đường lùi REST.
  bool guiDuoc = true;

  @override
  void noi() => daNoi = true;

  @override
  void ngat() => daNoi = false;

  @override
  VoidCallback nghe(String dich, RealtimeHandler handler) {
    nguoiNghe.putIfAbsent(dich, () => []).add(handler);
    return () => nguoiNghe[dich]?.remove(handler);
  }

  @override
  bool gui(String dich, Map<String, dynamic> body) {
    daGui.add((dich, body));
    return guiDuoc;
  }

  void phat(String dich, Map<String, dynamic> body) {
    for (final h in [...?nguoiNghe[dich]]) {
      h(body);
    }
  }
}

/// Phiên đã đăng nhập sẵn — bỏ qua bước đọc Keystore và gọi `/me`.
class AuthGia extends AuthController {
  AuthGia(this.u);
  final AppUser? u;

  @override
  AuthState build() => AuthState(
        trangThai:
            u == null ? TrangThaiPhien.chuaDangNhap : TrangThaiPhien.daDangNhap,
        user: u,
      );
}

/// Người dùng mẫu theo vai trò, quyền khớp CustomUserDetails của backend.
AppUser nguoiDung({
  String vaiTro = 'USER',
  Set<String>? quyen,
  String ten = 'Minh Anh',
}) {
  const bang = {
    'USER': ['USER_BASIC', 'READER_APPLY'],
    'STAFF': [
      'USER_BASIC', 'READER_APPLY', 'READER_MANAGE_PROFILE', 'SUPPORT_VIEW',
      'SUPPORT_RESPOND', 'PAYOUT_REQUEST', 'ADMIN_READERS_VIEW',
      'ADMIN_READERS_REVIEW',
    ],
    'MANAGER': [
      'USER_BASIC', 'SUPPORT_VIEW', 'STAFF_VIEW', 'STAFF_MANAGE',
      'ADMIN_READERS_VIEW', 'ADMIN_READERS_REVIEW', 'REPORT_REVIEW',
      'CATALOG_MANAGE',
    ],
    'ADMIN': [
      'USER_BASIC', 'READER_MANAGE_PROFILE', 'SUPPORT_VIEW', 'SUPPORT_RESPOND',
      'STAFF_VIEW', 'STAFF_MANAGE', 'ADMIN_READERS_VIEW',
      'ADMIN_READERS_REVIEW', 'CATALOG_MANAGE', 'ORDERS_MANAGE',
      'USERS_MANAGE', 'AUDIT_VIEW', 'PAYMENTS_MANAGE', 'PAYOUT_REVIEW',
      'REPORT_REVIEW',
    ],
  };
  return AppUser.fromJson({
    'userId': 'u-$vaiTro',
    'username': vaiTro.toLowerCase(),
    'fullName': ten,
    'email': '${vaiTro.toLowerCase()}@astrotarot.date',
    'role': vaiTro,
    'permissions': (quyen ?? bang[vaiTro]!.toSet()).toList(),
  });
}

/// url_launcher giả: ghi lại liên kết đã mở.
class LauncherGia extends UrlLauncherPlatform {
  final daMo = <String>[];
  bool moDuoc = true;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    daMo.add(url);
    return moDuoc;
  }
}

/// Mọi thứ một test màn hình cần.
class MoiTruong {
  MoiTruong({this.user, List<String>? token})
      : mayChu = MayChuGia(),
        realtime = RealtimeGia(),
        launcher = LauncherGia() {
    FlutterSecureStorage.setMockInitialValues({
      if (token != null) ...{
        'astrotarot_access_token': token[0],
        'astrotarot_refresh_token': token[1],
      },
    });
    UrlLauncherPlatform.instance = launcher;
    store = TokenStore();
    api = ApiClient(tokenStore: store, adapter: mayChu);
  }

  final MayChuGia mayChu;
  final RealtimeGia realtime;
  final LauncherGia launcher;
  final AppUser? user;
  late final TokenStore store;
  late final ApiClient api;

  /// Tra địa danh giả cho form bản đồ sao — không gọi Nominatim thật.
  List<DiaDanh> diaDanh = const [
    DiaDanh('Hà Nội, Việt Nam', 21.0285, 105.8542),
    DiaDanh('Huế, Thừa Thiên Huế', 16.4637, 107.5909),
  ];

  /// [thatAuth]: dùng AuthController thật (màn đăng nhập, khởi động app).
  List overrides({bool thatAuth = false}) => [
        tokenStoreProvider.overrideWithValue(store),
        apiClientProvider.overrideWithValue(api),
        realtimeProvider.overrideWithValue(realtime),
        timDiaDanhProvider.overrideWithValue((q) async => diaDanh),
        if (!thatAuth) authControllerProvider.overrideWith(() => AuthGia(user)),
      ];

  /// Nội dung clipboard giả.
  String? clipboard;

  /// Dựng [man] trong MaterialApp + ProviderScope, chờ các lượt gọi xong.
  ///
  /// [quaDuong]: dựng một màn gốc rồi ĐẨY [man] lên trên — dùng cho màn tự
  /// `pop` khi xong việc (form lưu xong đóng lại). Để [man] làm route gốc
  /// thì `pop` đẩy ra màn đen, không giống lúc chạy thật.
  Future<ProviderContainer> dung(
    WidgetTester tester,
    Widget man, {
    bool thatAuth = false,
    bool quaDuong = false,
    Size co = const Size(420, 900),
  }) async {
    tester.view.physicalSize = co;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String?;
        }
        if (call.method == 'Clipboard.getData') {
          return {'text': clipboard};
        }
        return null;
      },
    );
    late ProviderContainer c;
    await tester.pumpWidget(
      ProviderScope(
        // Khoá mới mỗi lần: dựng lại ProviderScope ở cùng chỗ thì Riverpod
        // giữ container cũ, và môi trường thứ hai trong cùng một test bị bỏ
        // qua lặng lẽ.
        key: UniqueKey(),
        // Tắt tự thử lại: test cần thấy lỗi ngay, không chờ backoff.
        retry: (_, _) => null,
        overrides: [...overrides(thatAuth: thatAuth)],
        child: Consumer(builder: (context, ref, _) {
          c = ProviderScope.containerOf(context);
          return MaterialApp(
            theme: buildTheme(),
            home: quaDuong
                ? Builder(
                    builder: (ctx) => Scaffold(
                      body: Center(
                        child: TextButton(
                          onPressed: () => Navigator.of(ctx)
                              .push(MaterialPageRoute(builder: (_) => man)),
                          child: const Text('MỞ MÀN'),
                        ),
                      ),
                    ),
                  )
                : man,
          );
        }),
      ),
    );
    await xong(tester);
    if (quaDuong) {
      await tester.tap(find.text('MỞ MÀN'));
      await xong(tester);
    }
    return c;
  }
}

/// Chờ các Future + khung hình xong. Không dùng pumpAndSettle trần vì vòng
/// quay chờ vô hạn sẽ làm nó treo — chạy tối đa một số khung hình rồi thôi.
Future<void> xong(WidgetTester tester, {int lan = 12}) async {
  for (var i = 0; i < lan; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Cuộn danh sách dọc cho tới khi [f] được dựng.
///
/// ListView chỉ dựng phần đang nằm trong màn; thứ ở dưới xa chưa tồn tại
/// trong cây widget nên không tìm thấy được cho tới khi cuộn tới.
Future<void> cuonToi(WidgetTester tester, Finder f) async {
  if (_coThay(f)) return;
  final doc = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down);
  for (final e in doc.evaluate().toList()) {
    // Thử cuộn xuống trước, rồi cuộn lên — thứ cần tìm có thể ở phía trên
    // nếu trước đó test đã cuộn danh sách xuống.
    for (final buoc in const [250.0, -250.0]) {
      try {
        await tester.scrollUntilVisible(f, buoc,
            scrollable: find.byElementPredicate((x) => x == e),
            maxScrolls: 40);
        return;
      } catch (_) {
        // Không thấy theo chiều này / trong danh sách này — thử tiếp.
      }
    }
  }
}

/// `finder.first` ném StateError khi rỗng thay vì trả rỗng — gói lại.
bool _coThay(Finder f) {
  try {
    return f.evaluate().isNotEmpty;
  } on StateError {
    return false;
  }
}

/// Bấm một widget, cuộn tới nó trước nếu cần.
///
/// Truyền finder trần, đừng `.first`: finder `.first` ném lỗi khi chưa có gì
/// (thứ nằm ngoài màn chưa được dựng) nên không cuộn tới được. Ở đây đã tự
/// lấy phần tử đầu.
Future<void> bam(WidgetTester tester, Finder f) async {
  await cuonToi(tester, f);
  // Đưa đích vào GIỮA màn: nằm sát mép thì cú chạm có thể rơi vào thanh
  // tiêu đề hay vùng kéo-để-tải-lại thay vì vào nút.
  final e = f.evaluate().first;
  if (Scrollable.maybeOf(e) != null) {
    await Scrollable.ensureVisible(e, alignment: 0.5);
    // `xong` chứ không phải một `pump` đơn.
    //
    // ensureVisible có thể kéo theo cả một chuỗi: cuộn xong thì bố cục dựng
    // lại, widget con đổi chỗ, RefreshIndicator bao ngoài chạy nốt hiệu ứng.
    // Một khung hình không đủ cho chuỗi ấy lắng xuống, nên toạ độ lúc chạm
    // là toạ độ của khung TRƯỚC — cú chạm rơi ra ngoài nút.
    //
    // Và nó trượt IM LẶNG vì warnIfMissed: false bên dưới. Bắt được lỗi này
    // đã mất một lúc: phép kiểm báo "không gọi máy chủ" trong khi nút vẫn
    // hiện ra đủ cả, chạm tay vào thì chạy bình thường. Chỉ lộ ra khi một
    // thay đổi giao diện làm form cao thêm vài chục điểm ảnh.
    await xong(tester);
  }
  await tester.tap(f.first, warnIfMissed: false);
  await xong(tester);
}

/// Một trang Spring rỗng/đầy.
Map<String, dynamic> trang(List<Map<String, dynamic>> muc,
        {int so = 0, int tongTrang = 1, int? tong}) =>
    {
      'content': muc,
      'number': so,
      'totalPages': tongTrang,
      'totalElements': tong ?? muc.length,
    };
