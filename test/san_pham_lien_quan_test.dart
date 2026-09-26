import 'package:astrotarot_mobile/features/home/daily_card.dart';
import 'package:astrotarot_mobile/features/readerprofile/reader_profile_view.dart';
import 'package:astrotarot_mobile/features/readers/reader_detail_screen.dart';
import 'package:astrotarot_mobile/features/shop/san_pham_lien_quan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/gia.dart';
import 'support/mau.dart';

/// Khối gợi ý sản phẩm, khớp `RelatedProducts` của web.
///
/// Gian hàng là liên kết tiếp thị: mình giới thiệu, người ta mua trên sàn,
/// mình ăn hoa hồng. Nên khối này không phải trang trí — nó là một trong vài
/// chỗ dự án thật sự kiếm tiền, và web có nó ở ngay sau lá bài ngày.
void main() {
  group('Sản phẩm liên quan', () {
    testWidgets('lọc theo ĐÚNG danh mục được yêu cầu', (t) async {
      final m = MoiTruong(user: nguoiDung());
      m.mayChu.tra(
        'GET /api/v1/shop/products',
        trang([mauSanPham(ten: 'Bộ Rider-Waite')]),
      );
      await m.dung(
        t,
        const SanPhamLienQuan(
          danhMucSlug: 'bai-tarot',
          tieuDe: 'Muốn tự rút bài ở nhà?',
        ),
      );

      // Gợi ý sai danh mục là quảng cáo chen ngang: người vừa rút lá bài
      // không muốn thấy một cái khăn trải bàn.
      expect(
        m.mayChu.lanCuoi('GET /api/v1/shop/products')!.query['category'],
        'bai-tarot',
      );
      expect(find.text('Muốn tự rút bài ở nhà?'), findsOneWidget);
      expect(find.text('Bộ Rider-Waite'), findsOneWidget);
    });

    testWidgets('KHÔNG có sản phẩm nào thì ẩn hẳn, không chừa chỗ trống', (
      t,
    ) async {
      final m = MoiTruong(user: nguoiDung());
      m.mayChu.tra('GET /api/v1/shop/products', trang([]));
      await m.dung(t, const SanPhamLienQuan(tieuDe: 'Gợi ý cho bạn'));

      // Một tiêu đề đứng trên khoảng trống trông như lỗi tải, và nó đẩy phần
      // nội dung thật xuống dưới mép màn hình.
      expect(find.text('Gợi ý cho bạn'), findsNothing);
    });

    testWidgets('máy chủ lỗi thì cũng ẩn hẳn, không hiện khối lỗi', (t) async {
      final m = MoiTruong(user: nguoiDung());
      m.mayChu.loi('GET /api/v1/shop/products', 'Gian hàng đang bảo trì');
      await m.dung(t, const SanPhamLienQuan(tieuDe: 'Gợi ý cho bạn'));

      // Đây là khối PHỤ. Hiện "Gian hàng đang bảo trì" ngay dưới lá bài vừa
      // rút là biến một lỗi không liên quan thành thứ đập vào mắt người dùng.
      expect(find.text('Gợi ý cho bạn'), findsNothing);
      expect(find.text('Gian hàng đang bảo trì'), findsNothing);
    });

    testWidgets('cắt đúng số lượng, thừa thì bỏ', (t) async {
      final m = MoiTruong(user: nguoiDung());
      m.mayChu.tra(
        'GET /api/v1/shop/products',
        trang([
          mauSanPham(id: 'p1', ten: 'Bộ một', slug: 'bo-mot'),
          mauSanPham(id: 'p2', ten: 'Bộ hai', slug: 'bo-hai'),
          mauSanPham(id: 'p3', ten: 'Bộ ba', slug: 'bo-ba'),
        ]),
      );
      await m.dung(t, const SanPhamLienQuan(tieuDe: 'Gợi ý', soLuong: 2));

      // Hai thẻ vừa một hàng trên điện thoại. Thẻ thứ ba tràn ra ngoài mép.
      expect(find.text('Bộ một'), findsOneWidget);
      expect(find.text('Bộ hai'), findsOneWidget);
      expect(find.text('Bộ ba'), findsNothing);
    });

    testWidgets('chỉ có một sản phẩm thì không kéo thẻ ra rộng cả hàng', (
      t,
    ) async {
      final m = MoiTruong(user: nguoiDung());
      m.mayChu.tra(
        'GET /api/v1/shop/products',
        trang([mauSanPham(ten: 'Bộ duy nhất')]),
      );
      await m.dung(t, const SanPhamLienQuan(tieuDe: 'Gợi ý', soLuong: 2));

      final co = t.getSize(find.text('Bộ duy nhất'));
      // Chiếm nửa hàng chứ không phải cả hàng: màn rộng 420, trừ lề và khoảng
      // cách thì một nửa còn quãng 190. Kéo rộng cả hàng thì thẻ duy nhất
      // trông như một biểu ngữ quảng cáo.
      expect(co.width, lessThan(260));
    });
  });

  group('Lá bài ngày', () {
    testWidgets('rút xong thì hiện gợi ý bộ bài cùng dòng', (t) async {
      final m = MoiTruong(user: nguoiDung());
      m.mayChu.tra(
        'GET /api/v1/shop/products',
        trang([mauSanPham(ten: 'Bộ Rider-Waite')]),
      );
      await m.dung(t, const RutBaiHangNgay());

      // Chưa rút thì chưa gợi ý gì: liên hệ chỉ có thật SAU khi người dùng
      // nhìn thấy lá bài.
      expect(find.text('Muốn tự rút bài ở nhà?'), findsNothing);

      await bam(t, find.byKey(const ValueKey('la-up-0')));

      expect(find.text('Muốn tự rút bài ở nhà?'), findsOneWidget);
      expect(find.text('Bộ Rider-Waite'), findsOneWidget);
    });
  });

  group('Hồ sơ Reader', () {
    void khaiHoSo(MayChuGia m, {Map<String, dynamic>? hoSo}) {
      // Chưa có hồ sơ thì backend trả 404 — đó là trạng thái bình thường của
      // người chưa nộp đơn, không phải lỗi. Trả 200 kèm data rỗng là dựng một
      // tình huống không tồn tại ngoài đời.
      if (hoSo == null) {
        m.loi('GET /api/v1/readers/profile/me', 'Chưa có hồ sơ', ma: 404);
      } else {
        m.tra('GET /api/v1/readers/profile/me', hoSo);
      }
      m.tra('GET /api/v1/availability', []);
      m.tra('GET /api/v1/unavailable-dates', []);
    }

    testWidgets('chưa có hồ sơ thì có NÚT nộp đơn, không phải lời nhờ vả', (
      t,
    ) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'STAFF'));
      khaiHoSo(m.mayChu);
      m.mayChu.tra('GET /api/v1/readers/applications/me', null);
      await m.dung(t, const ReaderProfileView());

      // Trước đây chỗ này chỉ nói "màn nộp đơn chưa dựng trong app" và đẩy
      // người dùng sang website — trong khi màn nộp đơn đã có sẵn, chỉ là
      // không ai nối vào đây. Một ngõ cụt: nhân viên mở Hồ sơ Reader, đọc một
      // câu nhờ vả, rồi không có nút nào để bấm.
      expect(find.text('Bạn chưa có hồ sơ Reader'), findsOneWidget);
      expect(find.textContaining('chưa dựng trong app'), findsNothing);

      await bam(t, find.text('Nộp đơn làm Reader'));
      expect(find.text('Đăng ký làm Reader'), findsOneWidget);
    });

    testWidgets('ô giá để trống nói rõ là KHÔNG nhận mốc đó', (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'STAFF'));
      khaiHoSo(
        m.mayChu,
        hoSo: {
          'id': 'r1',
          'bio': 'Reader lâu năm',
          'specialties': ['Tarot'],
          'yearsExperience': 4,
          'pricePer15m': 100000,
          'pricePer30m': null,
          'pricePer60m': null,
          'isAvailable': true,
        },
      );
      await m.dung(t, const ReaderProfileView());

      // Một ô trống trông giống hệt một ô chưa kịp điền. Phải nói rõ rằng để
      // trống LÀ một lựa chọn có nghĩa, không phải việc còn dở.
      expect(find.text('Không nhận buổi này'), findsNWidgets(2));
      // Và số đã nhập hiện ra dưới dạng tiền: ô nhập là số trần, nên gõ thừa
      // một số 0 nhìn không khác gì đúng.
      expect(find.text('100.000 đ'), findsOneWidget);
    });

    testWidgets('gõ thêm số 0 thì dòng tiền đổi theo ngay', (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'STAFF'));
      khaiHoSo(
        m.mayChu,
        hoSo: {
          'id': 'r1',
          'bio': 'x',
          'specialties': ['Tarot'],
          'yearsExperience': 1,
          'pricePer15m': 60000,
          'pricePer30m': null,
          'pricePer60m': null,
          'isAvailable': true,
        },
      );
      await m.dung(t, const ReaderProfileView());
      expect(find.text('60.000 đ'), findsOneWidget);

      // Ô giá là ba ô cuối trong form; "60.000 đ" là dòng nhắc BÊN DƯỚI ô,
      // không nằm trong nó — nên không tìm bằng widgetWithText được.
      final oGia15 = find.byType(TextField).at(3);
      await t.enterText(oGia15, '600000');
      await xong(t);

      // Đây chính là lý do dòng này tồn tại: sáu trăm nghìn một buổi mười lăm
      // phút là một lỗi gõ, và nó phải đập vào mắt ngay lúc gõ.
      expect(find.text('600.000 đ'), findsOneWidget);
      expect(find.text('60.000 đ'), findsNothing);
    });
  });

  group('Hồ sơ Reader công khai', () {
    testWidgets('Reader chưa đặt giá nào thì nói rõ, không để ba mục rỗng', (
      t,
    ) async {
      final m = MoiTruong(user: nguoiDung());
      m.mayChu.tra(
        'GET /api/v1/readers/r1',
        mauReader(id: 'r1', gia15: null, gia30: null, gia60: null),
      );
      m.mayChu.tra('GET /api/v1/readers/r1/reviews', trang([]));
      await m.dung(t, const ReaderDetailScreen(readerId: 'r1'));

      // findBookable ở backend đã ẩn họ khỏi danh sách công khai, nhưng vẫn
      // tới được đây bằng đường dẫn trực tiếp — một liên kết chia sẻ từ trước,
      // hoặc chính Reader đang xem lại hồ sơ của mình.
      expect(find.textContaining('chưa đặt giá cho mốc nào'), findsOneWidget);
      // Ba mục liền nhau rỗng trơn trông như tải hỏng.
      expect(find.text('Ngày'), findsNothing);
      expect(find.text('Khung giờ còn trống'), findsNothing);
    });

    testWidgets('có giá thì hiện đủ mốc và phần chọn ngày', (t) async {
      final m = MoiTruong(user: nguoiDung());
      m.mayChu.tra('GET /api/v1/readers/r1', mauReader(id: 'r1'));
      m.mayChu.tra('GET /api/v1/readers/r1/reviews', trang([]));
      m.mayChu.tra('GET /api/v1/readers/r1/calendar', mauLich());
      m.mayChu.tra('GET /api/v1/readers/r1/slots/next-available', null);
      await m.dung(t, const ReaderDetailScreen(readerId: 'r1'));

      expect(find.textContaining('chưa đặt giá cho mốc nào'), findsNothing);
      expect(find.textContaining('Tháng '), findsOneWidget);
      expect(find.text('Khung giờ'), findsOneWidget);
    });
  });
}
