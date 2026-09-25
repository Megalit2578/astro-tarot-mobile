import 'package:astrotarot_mobile/core/api/token_store.dart';
import 'package:astrotarot_mobile/core/realtime/realtime_client.dart';
import 'package:astrotarot_mobile/features/astrology/astrology_repository.dart';
import 'package:astrotarot_mobile/features/astrology/astrology_screen.dart';
import 'package:astrotarot_mobile/features/readerapply/reader_apply_screen.dart';
import 'package:astrotarot_mobile/features/shop/product_detail_screen.dart';
import 'package:astrotarot_mobile/features/shop/shop_repository.dart';
import 'package:astrotarot_mobile/features/shop/shop_screen.dart';
import 'package:astrotarot_mobile/features/tarot/tarot_history_screen.dart';
import 'package:astrotarot_mobile/features/tarot/tarot_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/gia.dart';
import 'support/mau.dart';

void main() {
  group('Bản đồ sao', () {
    testWidgets('danh sách, thêm mới qua tra địa danh, sửa, xoá', (t) async {
      final m = MoiTruong(user: nguoiDung());
      m.mayChu.tra('GET /api/me/astrology/profiles', [mauHoSoSao()]);
      m.mayChu.tra('POST /api/me/astrology/profiles', mauHoSoSao());
      m.mayChu.tra('PUT /api/me/astrology/profiles/h1', mauHoSoSao());
      m.mayChu.tra('DELETE /api/me/astrology/profiles/h1', null);
      await m.dung(t, const AstrologyScreen());
      expect(find.text('Hồ sơ chính'), findsOneWidget);
      expect(find.text('25/09/2001'), findsOneWidget);
      expect(find.text('07:30'), findsOneWidget);
      expect(find.text('21.0285, 105.8542'), findsOneWidget);

      // Thêm mới.
      await bam(t, find.text('Thêm hồ sơ'));
      await bam(t, find.text('Tạo hồ sơ'));
      expect(find.text('Hãy chọn ngày sinh.'), findsOneWidget);
      await t.enterText(find.byKey(const ValueKey('o-tieu-de')), 'Của mẹ');
      await bam(t, find.byKey(const ValueKey('nut-ngay-sinh')));
      await bam(t, find.text('OK'));
      await bam(t, find.byKey(const ValueKey('nut-gio-sinh')));
      await bam(t, find.text('OK'));
      await t.enterText(find.byKey(const ValueKey('o-noi-sinh')), 'Hu');
      await t.pump(const Duration(milliseconds: 600));
      await xong(t);
      await bam(t, find.text('Tạo hồ sơ'));
      expect(find.textContaining('chọn nơi sinh trong danh sách gợi ý'),
          findsOneWidget);
      await bam(t, find.text('Huế, Thừa Thiên Huế'));
      await bam(t, find.text('Của tôi'));
      await bam(t, find.text('Cặp đôi').last);
      await bam(t, find.text('Đặt làm hồ sơ chính'));
      await bam(t, find.text('Tạo hồ sơ'));
      final g = m.mayChu.lanCuoi('POST /api/me/astrology/profiles')!;
      expect(g.than['title'], 'Của mẹ');
      expect(g.than['birthPlace'], 'Huế, Thừa Thiên Huế');
      expect(g.than['latitude'], 16.4637);
      expect(g.than['profileType'], 'COUPLE');
      expect(g.than['birthTime'], '12:00:00');
      expect(g.than['isPrimary'], isTrue);

      // Sửa: giữ toạ độ cũ, bỏ giờ sinh.
      await bam(t, find.byTooltip('Sửa Bản đồ sao của tôi'));
      await bam(t, find.text('Không biết giờ sinh'));
      await bam(t, find.text('Lưu'));
      final s = m.mayChu.lanCuoi('PUT /api/me/astrology/profiles/h1')!;
      expect(s.than['birthTime'], isNull);
      expect(s.than['latitude'], 21.0285);

      // Xoá.
      await bam(t, find.byTooltip('Xoá hồ sơ Bản đồ sao của tôi'));
      await bam(t, find.text('Xoá'));
      expect(m.mayChu.cacLan('DELETE /api/me/astrology/profiles/h1'),
          hasLength(1));
    });

    testWidgets('lưu lỗi, xoá lỗi, danh sách rỗng và lỗi', (t) async {
      final m = MoiTruong(user: nguoiDung());
      m.mayChu.tra('GET /api/me/astrology/profiles', [mauHoSoSao()]);
      m.mayChu.loi('PUT /api/me/astrology/profiles/h1', 'Title is required');
      m.mayChu.loi('DELETE /api/me/astrology/profiles/h1', 'Không xoá được');
      await m.dung(t, const AstrologyScreen());
      await bam(t, find.byTooltip('Sửa Bản đồ sao của tôi'));
      await bam(t, find.text('Lưu'));
      expect(find.text('Title is required'), findsOneWidget);
      await t.pageBack();
      await xong(t);
      await bam(t, find.byTooltip('Xoá hồ sơ Bản đồ sao của tôi'));
      await bam(t, find.text('Xoá'));
      expect(find.text('Không xoá được'), findsOneWidget);

      final m2 = MoiTruong(user: nguoiDung());
      m2.mayChu.tra('GET /api/me/astrology/profiles', []);
      await m2.dung(t, const AstrologyScreen());
      expect(find.text('Bạn chưa có hồ sơ chiêm tinh nào'), findsOneWidget);
      final m3 = MoiTruong(user: nguoiDung());
      m3.mayChu.loi('GET /api/me/astrology/profiles', 'Hỏng');
      await m3.dung(t, const AstrologyScreen());
      expect(find.text('Hỏng'), findsOneWidget);
    });

    test('model và tra địa danh', () async {
      expect(ngayViTuIso('2001-09-25'), '25/09/2001');
      expect(ngayViTuIso('lạ'), 'lạ');
      final h = HoSoSao.fromJson(const {'id': 'x', 'birthTime': '7'});
      expect(h.gioSinhNgan, '7');
      expect(await timDiaDanhNominatim('a'), isEmpty);

      final dio = Dio()..httpClientAdapter = MayChuGia();
      final ds = MayChuGia();
      ds.xuLy('GET /search', (_) => const TraLoi(200, [
            {'display_name': 'Đà Lạt', 'lat': '11.9', 'lon': '108.4'},
            {'display_name': 'Hỏng', 'lat': 'x', 'lon': '1'},
          ]));
      dio.httpClientAdapter = ds;
      final kq = await timDiaDanhNominatim('Đà Lạt', dio: dio);
      expect(kq.single.ten, 'Đà Lạt');
      ds.xuLy('GET /search', (_) => const TraLoi(500, {}));
      expect(await timDiaDanhNominatim('Đà Lạt', dio: dio), isEmpty);
      ds.xuLy('GET /search', (_) => const TraLoi(200, {'a': 1}));
      expect(await timDiaDanhNominatim('Đà Lạt', dio: dio), isEmpty);
    });
  });

  group('Gian hàng', () {
    void khai(MayChuGia m) {
      m.tra('GET /api/v1/shop/categories', [
        {'id': 'c1', 'name': 'Bộ bài', 'slug': 'bo-bai'},
        {'id': 'c2', 'name': 'Đá', 'slug': 'da'},
      ]);
      m.tra('GET /api/v1/shop/products', trang([
        mauSanPham(),
        mauSanPham(id: 'p2', slug: 'khong-link', coLink: false),
      ]));
      m.tra('GET /api/v1/shop/products/bo-bai-rider', mauSanPham());
      m.tra('POST /api/v1/shop/products/bo-bai-rider/click',
          {'url': 'https://shopee.vn/moi-nhat'});
    }

    testWidgets('lọc, tìm, mua gửi SLUG và mở đúng link máy chủ trả',
        (t) async {
      final m = MoiTruong(user: nguoiDung());
      khai(m.mayChu);
      await m.dung(t, const ShopScreen());
      expect(find.text('Món này chưa có liên kết mua.'), findsOneWidget);
      await bam(t, find.text('Đá'));
      expect(m.mayChu.lanCuoi('GET /api/v1/shop/products')!.query['category'],
          'da');
      await bam(t, find.text('Tất cả'));
      await t.enterText(find.byKey(const ValueKey('o-tim-san-pham')), 'rider');
      await t.pump(const Duration(milliseconds: 400));
      await xong(t);
      expect(m.mayChu.lanCuoi('GET /api/v1/shop/products')!.query['keyword'],
          'rider');
      await bam(t, find.text('Mua trên Shopee'));
      // Bản cũ gửi id → 404, mất số liệu hoa hồng.
      expect(m.mayChu.cacLan('POST /api/v1/shop/products/bo-bai-rider/click'),
          hasLength(1));
      expect(m.launcher.daMo, ['https://shopee.vn/moi-nhat']);
    });

    testWidgets('ghi nhận hỏng vẫn mở link cũ; mở không được thì báo',
        (t) async {
      final m = MoiTruong();
      khai(m.mayChu);
      m.mayChu.loi('POST /api/v1/shop/products/bo-bai-rider/click', 'Hỏng');
      m.launcher.moDuoc = false;
      await m.dung(t, const ShopScreen());
      await bam(t, find.text('Mua trên Shopee'));
      expect(m.launcher.daMo, ['https://shopee.vn/rider']);
      expect(find.text('Không mở được liên kết.'), findsOneWidget);
    });

    testWidgets('màn chi tiết sản phẩm', (t) async {
      final m = MoiTruong();
      khai(m.mayChu);
      await m.dung(t, const ShopScreen());
      await bam(t, find.text('Bộ bài kinh điển cho người mới.').first);
      expect(find.byType(ProductDetailScreen), findsOneWidget);
      expect(find.text('-17%'), findsOneWidget);
      expect(find.text('42 lượt xem trên sàn'), findsOneWidget);
      await bam(t, find.text('Mua trên Shopee'));
      expect(m.launcher.daMo, isNotEmpty);
    });

    testWidgets('chi tiết không tìm thấy rồi thử lại', (t) async {
      final m = MoiTruong();
      m.mayChu.loi('GET /api/v1/shop/products/mat', 'Không tìm thấy', ma: 404);
      await m.dung(t, const ProductDetailScreen(slug: 'mat'));
      expect(find.text('Không tìm thấy sản phẩm'), findsOneWidget);
      m.mayChu.tra('GET /api/v1/shop/products/mat',
          mauSanPham(slug: 'mat')..['imageUrl'] = null);
      await bam(t, find.text('Thử lại'));
      expect(find.text('Bộ bài Rider-Waite'), findsWidgets);
    });

    testWidgets('gian hàng rỗng, lọc không ra, lỗi', (t) async {
      final m = MoiTruong();
      m.mayChu.tra('GET /api/v1/shop/categories', []);
      m.mayChu.tra('GET /api/v1/shop/products', trang([]));
      await m.dung(t, const ShopScreen());
      expect(find.text('Gian hàng đang trống'), findsOneWidget);
      await t.enterText(find.byKey(const ValueKey('o-tim-san-pham')), 'x');
      await t.pump(const Duration(milliseconds: 400));
      await xong(t);
      expect(find.text('Không có sản phẩm phù hợp'), findsOneWidget);
      final m2 = MoiTruong();
      m2.mayChu.tra('GET /api/v1/shop/categories', []);
      m2.mayChu.loi('GET /api/v1/shop/products', 'Hỏng');
      await m2.dung(t, const ShopScreen());
      expect(find.text('Hỏng'), findsOneWidget);
    });

    test('model sản phẩm', () {
      final p = SanPham.fromJson(mauSanPham());
      expect(p.phanTramGiam, 17);
      expect(SanPham.fromJson({'price': 1}).phanTramGiam, isNull);
      expect(tenSan('LAZADA'), 'Lazada');
      expect(tenSan('TIKI'), 'Tiki');
      expect(tenSan('TIKTOK'), 'TikTok Shop');
      expect(tenSan(null), 'sàn liên kết');
      expect(tenSan('X'), 'X');
    });
  });

  group('Tarot AI', () {
    testWidgets('trải bài, hỏi tiếp; nhắc khai bản đồ sao', (t) async {
      final m = MoiTruong(user: nguoiDung());
      m.mayChu.loi('GET /api/me/astrology/profiles/primary', 'Chưa có', ma: 404);
      m.mayChu.tra('POST /api/ai-readings', {
        'readingId': 'rd9',
        'userQuestion': 'Công việc?',
        'spreadName': 'Ba lá',
        'drawnCards': [
          {'cardName': 'The Fool', 'position': 1, 'reversed': true},
          {'cardName': 'The Sun', 'position': 2, 'isReversed': false},
        ],
        'aiInterpretation': 'Một khởi đầu mới.',
        'readingTimestamp': iso(homNay),
      });
      m.mayChu.tra('POST /api/ai-readings/rd9/chat', {'reply': 'Lá The Sun là niềm vui.'});
      m.mayChu.tra('GET /api/ai-readings', trang([]));
      await m.dung(t, const TarotScreen());
      expect(find.text('Khai ngày giờ nơi sinh trước'), findsOneWidget);
      await bam(t, find.text('Trải bài'));
      expect(find.text('Hãy đặt một câu hỏi trước'), findsOneWidget);
      await t.enterText(find.byType(TextField).first, 'Công việc?');
      await bam(t, find.text('Năm lá'));
      await bam(t, find.text('Ba lá'));
      await bam(t, find.text('Cho phép bài ngược'));
      await bam(t, find.text('Trải bài'));
      final g = m.mayChu.lanCuoi('POST /api/ai-readings')!;
      expect(g.than['numberOfCards'], 3);
      expect(g.than['includeReversed'], isFalse);
      expect(find.text('Một khởi đầu mới.'), findsOneWidget);
      expect(find.text('ngược'), findsOneWidget);

      await cuonToi(t, find.byKey(const ValueKey('o-hoi-tiep')));
      await t.enterText(find.byKey(const ValueKey('o-hoi-tiep')), 'Còn lá Sun?');
      await bam(t, find.byTooltip('Gửi'));
      expect(m.mayChu.lanCuoi('POST /api/ai-readings/rd9/chat')!.than['message'],
          'Còn lá Sun?');
      expect(find.text('Lá The Sun là niềm vui.'), findsOneWidget);

      m.mayChu.loi('POST /api/ai-readings/rd9/chat', 'Hết lượt');
      await t.enterText(find.byKey(const ValueKey('o-hoi-tiep')), 'Nữa?');
      await bam(t, find.byTooltip('Gửi'));
      expect(find.text('Hết lượt'), findsOneWidget);
      expect(find.text('Nữa?'), findsOneWidget);

      m.mayChu.tra('POST /api/ai-readings/rd9/chat', {'reply': ''});
      await bam(t, find.byTooltip('Gửi'));
      expect(find.text('Mô hình không trả lời được câu này.'), findsOneWidget);

      await bam(t, find.text('Khai ngày giờ nơi sinh trước'));
      expect(find.text('Bản đồ sao'), findsOneWidget);
    });

    testWidgets('trải bài lỗi', (t) async {
      final m = MoiTruong(user: nguoiDung());
      m.mayChu.tra('GET /api/me/astrology/profiles/primary', mauHoSoSao());
      m.mayChu.loi('POST /api/ai-readings', 'Hết hạn mức hôm nay');
      await m.dung(t, const TarotScreen());
      await t.enterText(find.byType(TextField).first, 'Tình yêu?');
      await bam(t, find.text('Trải bài'));
      expect(find.text('Hết hạn mức hôm nay'), findsOneWidget);
    });

    testWidgets('lịch sử trải bài: mở một lượt xem lời giải', (t) async {
      final m = MoiTruong(user: nguoiDung());
      m.mayChu.tra('GET /api/ai-readings', trang([
        {'id': 'r1', 'mainQuestion': 'Sức khoẻ?', 'aiModelUsed': 'gemini', 'createdAt': iso(homNay)},
        {'id': 'r2', 'mainQuestion': 'Tiền?'},
        {'id': 'r3', 'mainQuestion': 'Nhà?'},
      ]));
      m.mayChu.tra('GET /api/ai-readings/r1/chat/messages', [
        {'id': 'x1', 'senderType': 'USER', 'content': 'Sức khoẻ?'},
        {'id': 'x2', 'senderType': 'AI', 'content': 'Nghỉ ngơi nhiều hơn.'},
      ]);
      m.mayChu.tra('GET /api/ai-readings/r2/chat/messages', {'content': []});
      m.mayChu.loi('GET /api/ai-readings/r3/chat/messages', 'Không đọc được');
      await m.dung(t, const TarotHistoryScreen());
      expect(find.textContaining('gemini'), findsOneWidget);
      await bam(t, find.text('Sức khoẻ?'));
      expect(find.text('Nghỉ ngơi nhiều hơn.'), findsOneWidget);
      await bam(t, find.text('Tiền?'));
      expect(find.text('Không có lời giải lưu lại cho lượt này.'), findsOneWidget);
      await bam(t, find.text('Nhà?'));
      expect(find.text('Không đọc được'), findsOneWidget);
      await bam(t, find.byTooltip('Trải bài mới'));
      expect(find.text('Tarot AI'), findsOneWidget);
    });

    testWidgets('lịch sử rỗng mời trải bài đầu tiên', (t) async {
      final m = MoiTruong(user: nguoiDung());
      m.mayChu.tra('GET /api/ai-readings', trang([]));
      await m.dung(t, const TarotHistoryScreen());
      await bam(t, find.text('Trải bài đầu tiên'));
      expect(find.text('Tarot AI'), findsOneWidget);
    });
  });

  group('Đăng ký làm Reader', () {
    testWidgets('chưa nộp: điền và gửi', (t) async {
      final m = MoiTruong(user: nguoiDung());
      m.mayChu.tra('GET /api/v1/readers/applications/me', null);
      m.mayChu.tra('POST /api/v1/readers/apply', 'SUBMITTED');
      m.mayChu.tra('GET /api/v1/me', {
        'userId': 'u', 'username': 'u', 'fullName': 'U', 'role': 'USER',
        'permissions': ['USER_BASIC'],
      });
      await m.dung(t, const ReaderApplyScreen(), quaDuong: true);
      await t.enterText(find.byKey(const ValueKey('o-gioi-thieu')), 'Tôi đọc Tarot');
      await t.enterText(find.byType(TextField).at(1), 'Tarot, , Chiêm tinh');
      await t.enterText(find.byType(TextField).at(2), '3');
      await bam(t, find.text('Gửi đơn đăng ký'));
      expect(m.mayChu.lanCuoi('POST /api/v1/readers/apply')!.than, {
        'bio': 'Tôi đọc Tarot',
        'experience': 3,
        'specialties': ['Tarot', 'Chiêm tinh'],
      });
      expect(find.text('Đã gửi đơn đăng ký Reader.'), findsOneWidget);
    });

    testWidgets('bị từ chối: điền sẵn, gửi lại; lỗi hiện câu máy chủ',
        (t) async {
      final m = MoiTruong(user: nguoiDung());
      m.mayChu.tra('GET /api/v1/readers/applications/me', {
        'status': 'REJECTED',
        'bio': 'Bản cũ',
        'experience': 1,
        'specialties': ['Tarot'],
        'rejectionReason': 'Thiếu kinh nghiệm',
      });
      m.mayChu.loi('POST /api/v1/readers/apply', 'Bạn vừa nộp đơn');
      await m.dung(t, const ReaderApplyScreen());
      expect(find.text('Thiếu kinh nghiệm'), findsOneWidget);
      expect(find.text('Bản cũ'), findsOneWidget);
      await bam(t, find.text('Gửi đơn đăng ký'));
      expect(find.text('Bạn vừa nộp đơn'), findsOneWidget);
    });

    testWidgets('đang chờ, đã duyệt, lỗi', (t) async {
      final m = MoiTruong(user: nguoiDung());
      m.mayChu.tra('GET /api/v1/readers/applications/me',
          {'status': 'PENDING', 'bio': 'Giới thiệu', 'createdAt': iso(homNay)});
      await m.dung(t, const ReaderApplyScreen(), quaDuong: true);
      expect(find.text('Đơn đang chờ duyệt'), findsOneWidget);
      await bam(t, find.text('Đóng'));
      final m2 = MoiTruong(user: nguoiDung());
      m2.mayChu.tra('GET /api/v1/readers/applications/me', {'status': 'APPROVED'});
      await m2.dung(t, const ReaderApplyScreen());
      expect(find.text('Đơn đã được duyệt'), findsOneWidget);
      final m3 = MoiTruong(user: nguoiDung());
      m3.mayChu.loi('GET /api/v1/readers/applications/me', 'Hỏng');
      await m3.dung(t, const ReaderApplyScreen());
      expect(find.text('Hỏng'), findsOneWidget);
    });
  });

  group('Realtime', () {
    test('sổ đăng ký sống qua lần nghe/huỷ; chưa nối thì gửi trả false', () {
      final rt = RealtimeClient(tokenStore: TokenStore());
      final huy1 = rt.nghe('/a', (_) {});
      final huy2 = rt.nghe('/a', (_) {});
      huy1();
      huy2();
      huy2();
      expect(rt.gui('/app/x', {'a': 1}), isFalse);
      expect(rt.dangNoi.value, isFalse);
      rt.ngat();
    });
  });
}
