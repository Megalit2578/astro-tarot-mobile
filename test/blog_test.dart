import 'package:astrotarot_mobile/features/admin/admin_hub.dart';
import 'package:astrotarot_mobile/features/blog/bai_viet_cua_toi_view.dart';
import 'package:astrotarot_mobile/features/blog/blog_repository.dart';
import 'package:astrotarot_mobile/features/blog/duyet_bai_view.dart';
import 'package:astrotarot_mobile/features/blog/soan_bai_screen.dart';
import 'package:astrotarot_mobile/features/staff/staff_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/gia.dart';
import 'support/mau.dart';

Map<String, dynamic> mauBai({
  String id = 'b1',
  String tieuDe = 'Ba lá hay gặp khi hỏi về công việc',
  String trangThai = 'DRAFT',
  String? lyDo,
  String noiDung = 'Nội dung đầy đủ của bài viết.',
}) =>
    {
      'id': id,
      'title': tieuDe,
      'slug': 'ba-la-hay-gap-khi-hoi-ve-cong-viec',
      'summary': 'Tóm tắt ngắn.',
      'content': noiDung,
      'status': trangThai,
      'author': {'id': 'u1', 'fullName': 'Minh Anh'},
      'rejectionReason': lyDo,
      'createdAt': iso(homNay),
      'updatedAt': iso(homNay),
    };

void main() {
  group('Đường dẫn sinh từ tiêu đề', () {
    test('bỏ dấu tiếng Việt, giữ đúng chữ đ', () {
      // `đ` không phải `d` có dấu, nên cách bỏ dấu kiểu tách tổ hợp Unicode
      // sẽ để lại nó rồi bị lọc mất — "đường" thành "ung".
      expect(tiengVietThanhSlug('Con đường của Lá Bài'),
          'con-duong-cua-la-bai');
      expect(tiengVietThanhSlug('Tử vi tháng 12'), 'tu-vi-thang-12');
    });

    test('gộp khoảng trắng, cắt gạch thừa hai đầu', () {
      expect(tiengVietThanhSlug('  Xem   bói  —  tarot!  '), 'xem-boi-tarot');
    });

    test('tiêu đề không còn chữ nào thì ra chuỗi rỗng, không ném', () {
      // Form bắt trường hợp này bằng câu "Đường dẫn trống — thử đổi tiêu đề".
      expect(tiengVietThanhSlug('🔮✨'), '');
    });
  });

  group('Ranh giới trạng thái', () {
    test('khớp đúng BlogServiceImpl', () {
      // Sửa được: DRAFT, PENDING, REJECTED. Gửi duyệt: DRAFT, REJECTED.
      // Tác giả tự xoá: chỉ DRAFT. Lệch khỏi đây là bày nút rồi nhận lỗi.
      expect(['DRAFT', 'PENDING', 'REJECTED'].every(suaDuocBai), isTrue);
      expect(suaDuocBai('APPROVED'), isFalse);
      expect(suaDuocBai('PUBLISHED'), isFalse);

      expect(guiDuyetDuoc('DRAFT'), isTrue);
      expect(guiDuyetDuoc('REJECTED'), isTrue);
      expect(guiDuyetDuoc('PENDING'), isFalse);

      expect(tacGiaXoaDuoc('DRAFT'), isTrue);
      expect(tacGiaXoaDuoc('PENDING'), isFalse);
    });
  });

  group('Bài của tôi', () {
    testWidgets('bản nháp: có Sửa, Gửi duyệt, Xoá', (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'STAFF'));
      m.mayChu.tra('GET /api/v1/staff/blogs/me', trang([mauBai()]));
      m.mayChu.tra('PATCH /api/v1/staff/blogs/b1/submit', mauBai(trangThai: 'PENDING'));
      await m.dung(t, const BaiVietCuaToiView());

      expect(find.text('Bản nháp'), findsOneWidget);
      expect(find.text('Sửa'), findsOneWidget);
      expect(find.text('Xoá'), findsOneWidget);

      await bam(t, find.text('Gửi duyệt'));
      expect(m.mayChu.lanCuoi('PATCH /api/v1/staff/blogs/*/submit'), isNotNull);
      expect(find.text('Đã gửi bài đi duyệt.'), findsOneWidget);
    });

    testWidgets('bài bị từ chối hiện lý do và nút Gửi lại', (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'STAFF'));
      m.mayChu.tra(
          'GET /api/v1/staff/blogs/me',
          trang([
            mauBai(trangThai: 'REJECTED', lyDo: 'Phần mở còn lan man.'),
          ]));
      await m.dung(t, const BaiVietCuaToiView());

      expect(find.text('Phần mở còn lan man.'), findsOneWidget);
      expect(find.text('Gửi lại'), findsOneWidget);
      // Bị từ chối thì chưa được xoá — backend chỉ cho tác giả xoá DRAFT.
      expect(find.text('Xoá'), findsNothing);
    });

    testWidgets('bài đã xuất bản thì không bày nút sửa hay xoá', (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'STAFF'));
      m.mayChu.tra('GET /api/v1/staff/blogs/me',
          trang([mauBai(trangThai: 'PUBLISHED')]));
      await m.dung(t, const BaiVietCuaToiView());

      expect(find.text('Đã xuất bản'), findsOneWidget);
      expect(find.text('Sửa'), findsNothing);
      expect(find.text('Gửi duyệt'), findsNothing);
      expect(find.text('Xoá'), findsNothing);
    });

    testWidgets('lỗi máy chủ dùng đúng câu máy chủ gửi', (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'STAFF'));
      m.mayChu.tra('GET /api/v1/staff/blogs/me', trang([mauBai()]));
      m.mayChu.loi('PATCH /api/v1/staff/blogs/b1/submit',
          'Bài viết chưa đủ 300 từ.');
      await m.dung(t, const BaiVietCuaToiView());

      await bam(t, find.text('Gửi duyệt'));
      expect(find.text('Bài viết chưa đủ 300 từ.'), findsOneWidget);
    });
  });

  group('Soạn bài', () {
    testWidgets('bài mới: slug chạy theo tiêu đề, lưu nháp gọi POST',
        (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'STAFF'));
      m.mayChu.tra('POST /api/v1/staff/blogs', mauBai());
      await m.dung(t, const SoanBaiScreen(), quaDuong: true);

      await t.enterText(
          find.byKey(const ValueKey('o-tieu-de')), 'Lá Bài Mặt Trời');
      await xong(t);
      expect(
        (t.widget<TextFormField>(find.byKey(const ValueKey('o-slug')))
            .controller!)
            .text,
        'la-bai-mat-troi',
      );

      await t.enterText(
          find.byKey(const ValueKey('o-noi-dung')), 'Nội dung bài.');
      await bam(t, find.text('Lưu nháp'));

      final g = m.mayChu.lanCuoi('POST /api/v1/staff/blogs');
      expect(g, isNotNull);
      expect((g!.than as Map)['slug'], 'la-bai-mat-troi');
      // Backend đặt @NotBlank trên title/slug/content; summary và thumbnail
      // để trống thì KHÔNG gửi, vì @Size(max) vẫn nhận chuỗi rỗng nhưng gửi
      // thừa khoá rỗng cho một bài mới là lưu một ô trống vào CSDL.
      expect((g.than as Map).containsKey('summary'), isFalse);
    });

    testWidgets('tiêu đề không ra được slug thì chặn ngay, không gọi máy chủ',
        (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'STAFF'));
      m.mayChu.tra('POST /api/v1/staff/blogs', mauBai());
      await m.dung(t, const SoanBaiScreen(), quaDuong: true);

      await t.enterText(find.byKey(const ValueKey('o-tieu-de')), '🔮✨');
      await t.enterText(
          find.byKey(const ValueKey('o-noi-dung')), 'Nội dung bài.');
      await bam(t, find.text('Lưu nháp'));

      expect(m.mayChu.cacLan('POST /api/v1/staff/blogs'), isEmpty);
      expect(find.textContaining('Đường dẫn trống'), findsOneWidget);
    });

    testWidgets('sửa bài cũ: slug KHÔNG tự đổi theo tiêu đề', (t) async {
      // Slug của bài đã có là địa chỉ người ta đã dán đi nơi khác; sửa một
      // chữ ở tiêu đề mà âm thầm đổi cả địa chỉ là làm hỏng mọi liên kết ấy.
      final m = MoiTruong(user: nguoiDung(vaiTro: 'STAFF'));
      m.mayChu.tra('PUT /api/v1/staff/blogs/b1', mauBai());
      await m.dung(
        t,
        SoanBaiScreen(bai: BaiVietQuanTri.fromJson(mauBai())),
        quaDuong: true,
      );

      await t.enterText(
          find.byKey(const ValueKey('o-tieu-de')), 'Tiêu đề hoàn toàn khác');
      await xong(t);
      await bam(t, find.text('Lưu nháp'));

      final g = m.mayChu.lanCuoi('PUT /api/v1/staff/blogs/*');
      expect(g, isNotNull);
      expect((g!.than as Map)['slug'], 'ba-la-hay-gap-khi-hoi-ve-cong-viec');
    });

    testWidgets('lưu được nhưng gửi duyệt hỏng thì nói rõ là đã lưu',
        (t) async {
      // Hai lời gọi liên tiếp. Báo chung chung "không lưu được" ở đây là đẩy
      // người viết đi gõ lại một bài đã nằm an toàn trên máy chủ.
      final m = MoiTruong(user: nguoiDung(vaiTro: 'STAFF'));
      m.mayChu.tra('POST /api/v1/staff/blogs', mauBai());
      m.mayChu.loi('PATCH /api/v1/staff/blogs/b1/submit', 'Hàng chờ đang khoá.');
      await m.dung(t, const SoanBaiScreen(), quaDuong: true);

      await t.enterText(find.byKey(const ValueKey('o-tieu-de')), 'Một bài');
      await t.enterText(
          find.byKey(const ValueKey('o-noi-dung')), 'Nội dung bài.');
      await bam(t, find.text('Lưu và gửi duyệt'));

      expect(find.textContaining('Đã lưu bài nhưng chưa gửi duyệt được'),
          findsOneWidget);
    });
  });

  group('Duyệt bài', () {
    testWidgets('bài chờ duyệt: duyệt gửi đúng action', (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'MANAGER'));
      m.mayChu.tra(
          'GET /api/v1/blogs/all', trang([mauBai(trangThai: 'PENDING')]));
      m.mayChu.tra('PATCH /api/v1/blogs/b1/review', mauBai(trangThai: 'APPROVED'));
      await m.dung(t, const Scaffold(body: DuyetBaiView()));

      await bam(t, find.text('Duyệt'));
      final g = m.mayChu.lanCuoi('PATCH /api/v1/blogs/*/review');
      expect((g!.than as Map)['action'], 'APPROVED');
      // Mặc định lọc PENDING — người mở màn này là để xử lý việc tồn đọng.
      expect(m.mayChu.lanCuoi('GET /api/v1/blogs/all')!.query['status'],
          'PENDING');
    });

    testWidgets('từ chối bắt nhập lý do, gửi đúng tên trường', (t) async {
      // Tên trường là `rejectionReason`; gửi `reason` thì máy chủ nhận 200
      // nhưng tác giả không bao giờ thấy lý do.
      final m = MoiTruong(user: nguoiDung(vaiTro: 'MANAGER'));
      m.mayChu.tra(
          'GET /api/v1/blogs/all', trang([mauBai(trangThai: 'PENDING')]));
      m.mayChu.tra('PATCH /api/v1/blogs/b1/review', mauBai(trangThai: 'REJECTED'));
      await m.dung(t, const Scaffold(body: DuyetBaiView()));

      await bam(t, find.text('Từ chối'));
      await t.enterText(find.byType(TextField).last, 'Phần mở còn lan man.');
      await xong(t);
      await bam(t, find.widgetWithText(FilledButton, 'Từ chối'));

      final g = m.mayChu.lanCuoi('PATCH /api/v1/blogs/*/review');
      expect((g!.than as Map)['action'], 'REJECTED');
      expect((g.than as Map)['rejectionReason'], 'Phần mở còn lan man.');
    });

    testWidgets('chỉ bài ĐÃ DUYỆT mới có nút Xuất bản', (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'MANAGER'));
      m.mayChu.tra(
          'GET /api/v1/blogs/all', trang([mauBai(trangThai: 'PENDING')]));
      await m.dung(t, const Scaffold(body: DuyetBaiView()));
      expect(find.text('Xuất bản'), findsNothing);

      final m2 = MoiTruong(user: nguoiDung(vaiTro: 'MANAGER'));
      m2.mayChu.tra(
          'GET /api/v1/blogs/all', trang([mauBai(trangThai: 'APPROVED')]));
      m2.mayChu.tra('PATCH /api/v1/blogs/b1/publish', mauBai(trangThai: 'PUBLISHED'));
      await m2.dung(t, const Scaffold(body: DuyetBaiView()));

      expect(find.text('Duyệt'), findsNothing);
      await bam(t, find.text('Xuất bản'));
      // Nút trong hộp thoại trùng chữ với nút trên thẻ, nên phải chỉ rõ cái
      // nằm trong hộp thoại — không thì cú chạm thứ hai rơi lại vào thẻ.
      await bam(
        t,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Xuất bản'),
        ),
      );
      expect(m2.mayChu.lanCuoi('PATCH /api/v1/blogs/*/publish'), isNotNull);
    });

    testWidgets('đọc được toàn bài ngay tại thẻ', (t) async {
      // Duyệt mà chỉ nhìn tiêu đề với tóm tắt thì nút "Duyệt" không có nghĩa.
      final m = MoiTruong(user: nguoiDung(vaiTro: 'MANAGER'));
      m.mayChu.tra(
          'GET /api/v1/blogs/all',
          trang([
            mauBai(trangThai: 'PENDING', noiDung: 'Thân bài nằm ở đây.'),
          ]));
      await m.dung(t, const Scaffold(body: DuyetBaiView()));

      expect(find.text('Thân bài nằm ở đây.'), findsNothing);
      await bam(t, find.text('Đọc toàn bài'));
      expect(find.text('Thân bài nằm ở đây.'), findsOneWidget);
    });
  });

  group('Ai thấy phần nào', () {
    testWidgets('Reader có mục Bài viết ở Bàn làm việc', (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'STAFF'));
      m.mayChu.tra('GET /api/v1/bookings/reader', trang([]));
      await m.dung(t, const StaffScreen());
      expect(find.text('Bài viết'), findsOneWidget);
    });

    testWidgets('Thành viên không có mục nào về bài viết', (t) async {
      // USER không mang BLOG_CREATE lẫn BLOG_REVIEW.
      final u = nguoiDung();
      expect(u.co('BLOG_CREATE'), isFalse);
      expect(mucQuanTri(u).map((e) => e.nhan), isEmpty);
    });

    testWidgets('Quản lý thấy Duyệt bài, Reader thì không', (t) async {
      expect(
        mucQuanTri(nguoiDung(vaiTro: 'MANAGER')).map((e) => e.nhan),
        contains('Duyệt bài'),
      );
      expect(
        mucQuanTri(nguoiDung(vaiTro: 'STAFF')).map((e) => e.nhan),
        isNot(contains('Duyệt bài')),
      );
    });
  });
}
