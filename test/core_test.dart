import 'package:astrotarot_mobile/core/api/api_client.dart';
import 'package:astrotarot_mobile/core/api/trang.dart';
import 'package:astrotarot_mobile/core/auth/auth_controller.dart';
import 'package:astrotarot_mobile/core/config.dart';
import 'package:astrotarot_mobile/core/format.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/gia.dart';

/// Adapter luôn ném một loại DioException — để test câu báo lỗi mạng.
class _AdapterNem implements HttpClientAdapter {
  _AdapterNem(this.loai);
  final DioExceptionType loai;

  @override
  Future<ResponseBody> fetch(options, requestStream, cancelFuture) async =>
      throw DioException(requestOptions: options, type: loai);

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiClient', () {
    test('bóc bao thư {success, data} và trả thẳng data', () async {
      final m = MoiTruong();
      m.mayChu.tra('GET /x', {'a': 1});
      expect(await m.api.get<Map<String, dynamic>>('/x'), {'a': 1});
    });

    test('thân không có data thì trả nguyên thân', () async {
      final m = MoiTruong();
      m.mayChu.xuLy('GET /tho', (_) => const TraLoi(200, [1, 2]));
      expect(await m.api.get<List<dynamic>>('/tho'), [1, 2]);
    });

    test('lỗi dùng đúng câu máy chủ gửi', () async {
      final m = MoiTruong();
      m.mayChu.loi('POST /y', 'Email hoặc mật khẩu không đúng');
      await expectLater(
        m.api.post('/y'),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', 'Email hoặc mật khẩu không đúng')
            .having((e) => e.statusCode, 'statusCode', 400)),
      );
    });

    test('đọc được bao thư lỗi dạng {error: {message}} của Spring Security',
        () async {
      final m = MoiTruong();
      m.mayChu.xuLy(
          'GET /z',
          (_) => const TraLoi(401, {
                'data': null,
                'error': {'code': 'UNAUTHENTICATED', 'message': 'Hết phiên'},
              }));
      await expectLater(
        m.api.get('/z'),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', 'Hết phiên')
            .having((e) => e.phienHong, 'phienHong', isTrue)),
      );
    });

    test('không có câu nào thì báo mã lỗi', () async {
      final m = MoiTruong();
      m.mayChu.xuLy('DELETE /k', (_) => const TraLoi(500, 'hỏng'));
      await expectLater(
        m.api.delete('/k'),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', 'Máy chủ trả lỗi 500.')),
      );
    });

    test('PUT và PATCH đi đúng phương thức', () async {
      final m = MoiTruong();
      m.mayChu.tra('PUT /p', 1);
      m.mayChu.tra('PATCH /p', 2);
      expect(await m.api.put<int>('/p', body: {'x': 1}), 1);
      expect(await m.api.patch<int>('/p'), 2);
      expect(m.mayChu.lanCuoi('PUT /p')!.than, {'x': 1});
    });

    test('gắn Bearer token khi đã có phiên', () async {
      final m = MoiTruong(token: ['acc', 'ref']);
      String? auth;
      m.mayChu.xuLy('GET /me', (g) {
        return const TraLoi(200, {'data': 'ok'});
      });
      m.api.dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
        auth = o.headers['Authorization'] as String?;
        h.next(o);
      }));
      await m.api.get('/me');
      expect(auth, 'Bearer acc');
    });

    test('401 thì làm mới token MỘT lần rồi thử lại', () async {
      final m = MoiTruong(token: ['cu', 'ref-cu']);
      var lan = 0;
      m.mayChu.xuLy('GET /a', (_) {
        lan++;
        return lan == 1
            ? const TraLoi(401, {'message': 'hết hạn'})
            : const TraLoi(200, {'data': 'mới'});
      });
      m.mayChu.tra('POST /auth/refresh',
          {'accessToken': 'acc-moi', 'refreshToken': 'ref-moi'});
      expect(await m.api.get<String>('/a'), 'mới');
      expect(m.store.access, 'acc-moi');
      expect(m.mayChu.lanCuoi('POST /auth/refresh')!.than,
          {'refreshToken': 'ref-cu'});
    });

    test('nhiều lời gọi cùng 401 chỉ làm mới đúng một lần', () async {
      final m = MoiTruong(token: ['cu', 'ref-cu']);
      final daThu = <String>{};
      m.mayChu.xuLy('GET /*', (g) {
        if (daThu.add(g.duong)) return const TraLoi(401, {});
        return TraLoi(200, {'data': g.duong});
      });
      m.mayChu.xuLy('POST /auth/refresh', (_) => const TraLoi(200, {
            'data': {'accessToken': 'a2', 'refreshToken': 'r2'},
          }));
      final kq = await Future.wait(
          [m.api.get('/b1'), m.api.get('/b2'), m.api.get('/b3')]);
      expect(kq, ['/b1', '/b2', '/b3']);
      expect(m.mayChu.cacLan('POST /auth/refresh'), hasLength(1));
    });

    test('refresh bị từ chối thì xoá phiên và báo tầng trên', () async {
      final m = MoiTruong(token: ['cu', 'ref-cu']);
      var daBao = false;
      final api = ApiClient(
        tokenStore: m.store,
        adapter: m.mayChu,
        khiPhienHong: () => daBao = true,
      );
      m.mayChu.xuLy('GET /c', (_) => const TraLoi(401, {}));
      m.mayChu.xuLy('POST /auth/refresh', (_) => const TraLoi(401, {}));
      await expectLater(api.get('/c'), throwsA(isA<ApiException>()));
      expect(daBao, isTrue);
      expect(m.store.coPhien, isFalse);
    });

    test('refresh lỗi 5xx thì GIỮ phiên — chỉ là gián đoạn', () async {
      final m = MoiTruong(token: ['cu', 'ref-cu']);
      m.mayChu.xuLy('GET /d', (_) => const TraLoi(403, {}));
      m.mayChu.xuLy('POST /auth/refresh', (_) => const TraLoi(503, {}));
      await expectLater(m.api.get('/d'), throwsA(isA<ApiException>()));
      expect(m.store.coPhien, isTrue);
    });

    test('refresh trả thiếu token thì coi như không làm mới được', () async {
      final m = MoiTruong(token: ['cu', 'ref-cu']);
      m.mayChu.xuLy('GET /e', (_) => const TraLoi(401, {}));
      m.mayChu.tra('POST /auth/refresh', {'accessToken': 'chi-mot'});
      await expectLater(m.api.get('/e'), throwsA(isA<ApiException>()));
      expect(m.store.access, 'cu');
    });

    test('không thử làm mới cho chính /auth/login', () async {
      final m = MoiTruong(token: ['cu', 'ref-cu']);
      m.mayChu.loi('POST /auth/login', 'Sai mật khẩu', ma: 401);
      await expectLater(m.api.post('/auth/login'), throwsA(isA<ApiException>()));
      expect(m.mayChu.cacLan('POST /auth/refresh'), isEmpty);
    });

    for (final (loai, mau) in [
      (DioExceptionType.connectionTimeout, 'Không mở được kết nối'),
      (DioExceptionType.sendTimeout, 'Không mở được kết nối'),
      (DioExceptionType.receiveTimeout, 'trả lời quá chậm'),
      (DioExceptionType.connectionError, 'Không kết nối được'),
      (DioExceptionType.badCertificate, 'Chứng chỉ'),
      (DioExceptionType.cancel, 'huỷ'),
      (DioExceptionType.unknown, 'Không gọi được'),
    ]) {
      test('lỗi mạng $loai có câu riêng', () async {
        final m = MoiTruong();
        final api =
            ApiClient(tokenStore: m.store, adapter: _AdapterNem(loai));
        await expectLater(
          api.get('/x'),
          throwsA(isA<ApiException>()
              .having((e) => e.message, 'message', contains(mau))),
        );
      });
    }

    test('ApiException.toString là câu thông báo', () {
      expect(ApiException('abc').toString(), 'abc');
    });
  });

  group('AuthController', () {
    ProviderContainer tao(MoiTruong m) {
      final c = ProviderContainer(overrides: [...m.overrides(thatAuth: true)]);
      // build() của AuthController tự lên lịch khoiDong(); phải để nó chạy
      // xong rồi mới huỷ container, không thì nó ghi vào notifier đã chết.
      addTearDown(() async {
        await pumpEventQueue();
        c.dispose();
      });
      return c;
    }

    const me = {
      'userId': 'u1',
      'username': 'an',
      'fullName': 'An',
      'role': 'USER',
      'permissions': ['USER_BASIC'],
    };

    test('mở app không có token → chưa đăng nhập', () async {
      final m = MoiTruong();
      final c = tao(m);
      c.read(authControllerProvider);
      await c.read(authControllerProvider.notifier).khoiDong();
      expect(c.read(authControllerProvider).trangThai,
          TrangThaiPhien.chuaDangNhap);
    });

    test('mở app có token còn hạn → vào phiên và nối realtime', () async {
      final m = MoiTruong(token: ['a', 'r']);
      m.mayChu.tra('GET /api/v1/me', me);
      final c = tao(m);
      c.read(authControllerProvider);
      await c.read(authControllerProvider.notifier).khoiDong();
      expect(c.read(authControllerProvider).user?.fullName, 'An');
      expect(m.realtime.daNoi, isTrue);
    });

    test('mở app mà /me hỏng → chưa đăng nhập nhưng GIỮ token', () async {
      final m = MoiTruong(token: ['a', 'r']);
      m.mayChu.xuLy('GET /api/v1/me', (_) => const TraLoi(500, {}));
      final c = tao(m);
      c.read(authControllerProvider);
      await c.read(authControllerProvider.notifier).khoiDong();
      expect(c.read(authControllerProvider).trangThai,
          TrangThaiPhien.chuaDangNhap);
      expect(m.store.coPhien, isTrue);
    });

    test('đăng nhập thành công lưu token', () async {
      final m = MoiTruong();
      m.mayChu.tra('POST /auth/login',
          {...me, 'accessToken': 'acc', 'refreshToken': 'ref'});
      final c = tao(m);
      final ok = await c
          .read(authControllerProvider.notifier)
          .dangNhap(' an@x.vn ', 'mk');
      expect(ok, isTrue);
      expect(m.store.refresh, 'ref');
      expect(m.mayChu.lanCuoi('POST /auth/login')!.than,
          {'email': 'an@x.vn', 'password': 'mk'});
    });

    test('đăng nhập sai giữ câu lỗi máy chủ', () async {
      final m = MoiTruong();
      m.mayChu.loi('POST /auth/login', 'Email hoặc mật khẩu không đúng');
      final c = tao(m);
      final ok =
          await c.read(authControllerProvider.notifier).dangNhap('a@b.c', 'x');
      expect(ok, isFalse);
      expect(c.read(authControllerProvider).loi,
          'Email hoặc mật khẩu không đúng');
    });

    test('đăng nhập mà máy chủ trả thiếu token → câu chung', () async {
      final m = MoiTruong();
      m.mayChu.tra('POST /auth/login', me);
      final c = tao(m);
      final ok =
          await c.read(authControllerProvider.notifier).dangNhap('a@b.c', 'x');
      expect(ok, isFalse);
      expect(c.read(authControllerProvider).loi, 'Không đăng nhập được.');
    });

    test('đăng ký gửi fullName camelCase và nói đã gửi thư', () async {
      final m = MoiTruong();
      m.mayChu.tra('POST /auth/register', {'verificationEmailSent': true});
      final c = tao(m);
      final cau = await c.read(authControllerProvider.notifier).dangKy(
          email: 'a@b.c', matKhau: '12345678', hoTen: ' Bình ');
      expect(cau, contains('Đã gửi thư xác minh tới a@b.c'));
      expect(m.mayChu.lanCuoi('POST /auth/register')!.than['fullName'], 'Bình');
    });

    test('đăng ký khi không gửi được thư', () async {
      final m = MoiTruong();
      m.mayChu.tra('POST /auth/register', {'verificationEmailSent': false});
      final c = tao(m);
      final cau = await c.read(authControllerProvider.notifier).dangKy(
          email: 'a@b.c', matKhau: '12345678', hoTen: 'B');
      expect(cau, contains('Hãy xác minh email'));
    });

    test('đăng xuất GỬI KÈM refresh token rồi dọn phiên', () async {
      final m = MoiTruong(token: ['a', 'ref-that']);
      m.mayChu.tra('POST /auth/logout', null);
      final c = tao(m);
      await m.store.nap();
      await c.read(authControllerProvider.notifier).dangXuat();
      // Bản cũ gửi thân rỗng → 400 → phiên trên máy chủ không bị thu hồi.
      expect(m.mayChu.lanCuoi('POST /auth/logout')!.than,
          {'refreshToken': 'ref-that'});
      expect(m.store.coPhien, isFalse);
      expect(c.read(authControllerProvider).trangThai,
          TrangThaiPhien.chuaDangNhap);
    });

    test('đăng xuất khi mạng hỏng vẫn dọn phiên', () async {
      final m = MoiTruong(token: ['a', 'r']);
      m.mayChu.xuLy('POST /auth/logout', (_) => const TraLoi(500, {}));
      final c = tao(m);
      await m.store.nap();
      await c.read(authControllerProvider.notifier).dangXuat();
      expect(m.store.coPhien, isFalse);
    });

    test('quên mật khẩu, gửi lại xác minh, xác minh, đặt lại', () async {
      final m = MoiTruong();
      m.mayChu.tra('POST /auth/forgot-password', null);
      m.mayChu.tra('POST /auth/resend-verification', null);
      m.mayChu.tra('POST /auth/verify-email', {'email': 'a@b.c'});
      m.mayChu.tra('POST /auth/reset-password', null);
      final n = tao(m).read(authControllerProvider.notifier);
      await n.quenMatKhau(' a@b.c ');
      await n.guiLaiXacMinh('a@b.c');
      expect(await n.xacMinhEmail('tok'), 'a@b.c');
      await n.datLaiMatKhau('tok2', 'matkhaumoi');
      expect(m.mayChu.lanCuoi('POST /auth/forgot-password')!.than,
          {'email': 'a@b.c'});
      expect(m.mayChu.lanCuoi('POST /auth/reset-password')!.than,
          {'token': 'tok2', 'newPassword': 'matkhaumoi'});
    });

    test('xác minh trả thân lạ thì email rỗng', () async {
      final m = MoiTruong();
      m.mayChu.tra('POST /auth/verify-email', 'ok');
      final n = tao(m).read(authControllerProvider.notifier);
      expect(await n.xacMinhEmail('t'), '');
    });

    test('làm mới /me; hỏng thì im lặng', () async {
      final m = MoiTruong(token: ['a', 'r']);
      m.mayChu.tra('GET /api/v1/me', {...me, 'fullName': 'An Mới'});
      final c = tao(m);
      final n = c.read(authControllerProvider.notifier);
      await n.lamMoiToi();
      expect(c.read(authControllerProvider).user?.fullName, 'An Mới');
      m.mayChu.xuLy('GET /api/v1/me', (_) => const TraLoi(500, {}));
      await n.lamMoiToi();
      expect(c.read(authControllerProvider).user?.fullName, 'An Mới');
    });

    test('phiên hết hạn dọn trạng thái', () async {
      final m = MoiTruong(token: ['a', 'r']);
      final c = tao(m);
      c.read(authControllerProvider.notifier).phienHetHan();
      await Future<void>.delayed(Duration.zero);
      expect(c.read(authControllerProvider).trangThai,
          TrangThaiPhien.chuaDangNhap);
    });

    test('AuthState.copy giữ và xoá đúng trường', () {
      const s = AuthState(loi: 'x');
      expect(s.copy(xoaLoi: true).loi, isNull);
      expect(s.copy(dangXuLy: true).loi, 'x');
      expect(s.copy(xoaUser: true).user, isNull);
    });
  });

  group('Trang', () {
    test('đọc trang Spring', () {
      final t = Trang.tu(trang([{'v': 1}], so: 0, tongTrang: 3, tong: 50),
          (j) => j['v'] as int);
      expect(t.muc, [1]);
      expect(t.conNua, isTrue);
      expect(t.tongSo, 50);
    });

    test('đọc mảng phẳng và thân lạ', () {
      expect(Trang.tu([{'v': 2}], (j) => j['v']).muc, [2]);
      expect(Trang.tu('lạ', (j) => j).muc, isEmpty);
      expect(Trang.tu({'content': 'x'}, (j) => j).muc, isEmpty);
    });

    test('nối trang', () {
      final a = Trang(muc: const [1], so: 0, tongTrang: 2, tongSo: 2);
      final b = Trang(muc: const [2], so: 1, tongTrang: 2, tongSo: 2);
      final n = a.noi(b);
      expect(n.muc, [1, 2]);
      expect(n.conNua, isFalse);
    });

    test('hàm đọc JSON lỏng', () {
      expect(chuoi('  '), isNull);
      expect(chuoi(null), isNull);
      expect(chuoi(12), '12');
      expect(soNguyen('7'), 7);
      expect(soNguyen(7.9), 7);
      expect(soNguyen(true), isNull);
      expect(soThuc('1.5'), 1.5);
      expect(soThuc(2), 2.0);
      expect(soThuc(null), isNull);
      expect(thoiDiem('2026-01-02T03:04:05Z')!.year, 2026);
      expect(thoiDiem(''), isNull);
    });
  });

  group('Dinh và AppConfig', () {
    test('định dạng tiền, ngày, giờ, điểm', () {
      expect(Dinh.tien(120000), '120.000 đ');
      expect(Dinh.tien(null), '—');
      final t = DateTime(2026, 9, 22, 14, 15);
      expect(Dinh.ngayGio(t), '22/09, 14:15');
      expect(Dinh.ngayGio(null), '');
      expect(Dinh.ngay(t), '22/09/2026');
      expect(Dinh.ngay(null), '');
      expect(Dinh.gio(t), '14:15');
      expect(Dinh.gio(null), '');
      expect(Dinh.diem(4.56, 3), '4.6');
      expect(Dinh.diem(0, 0), 'Chưa có');
    });

    test('ghép URL ảnh và suy URL WebSocket', () {
      expect(AppConfig.anh(null), isNull);
      expect(AppConfig.anh(' '), isNull);
      expect(AppConfig.anh('https://x/a.jpg'), 'https://x/a.jpg');
      expect(AppConfig.anh('/p.jpg'), '${AppConfig.webBaseUrl}/p.jpg');
      expect(AppConfig.anh('p.jpg'), '${AppConfig.webBaseUrl}/p.jpg');
      expect(AppConfig.wsUrl, startsWith('wss://'));
      expect(AppConfig.wsUrl, endsWith('/ws'));
    });
  });
}
