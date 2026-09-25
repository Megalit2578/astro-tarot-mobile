import 'package:astrotarot_mobile/features/admin/admin_hub.dart';
import 'package:astrotarot_mobile/features/admin/admin_repository.dart';
import 'package:astrotarot_mobile/features/admin/tai_khoan_chi_tiet_screen.dart';
import 'package:astrotarot_mobile/features/admin/tao_tai_khoan_screen.dart';
import 'package:astrotarot_mobile/features/admin/tong_quan_view.dart';
import 'package:astrotarot_mobile/features/admin/san_pham_admin_view.dart';
import 'package:astrotarot_mobile/widgets/dai_chon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/gia.dart';
import 'support/mau.dart';

/// Khai đủ route cho mọi mục quản trị.
void khaiQuanTri(MayChuGia m) {
  m.tra('GET /api/v1/admin/stats', mauThongKe());
  m.xuLy('GET /api/v1/admin/users', (g) => TraLoi(200, {
        'data': g.query['page'] == '1'
            ? trang([mauTaiKhoan(id: 't4')], so: 1, tongTrang: 2, tong: 4)
            : trang([
                mauTaiKhoan(id: 't1'),
                mauTaiKhoan(
                    id: 't2',
                    vaiTro: 'STAFF',
                    trangThai: 'BANNED',
                    daXacMinh: false),
                mauTaiKhoan(id: 't3', vaiTro: 'ADMIN', suaDuoc: false),
              ], tongTrang: 2, tong: 4),
      }));
  m.tra('GET /api/v1/admin/users/*', mauChiTietTaiKhoan());
  m.tra('GET /api/v1/admin/readers/applications', [
    {
      'id': 'a1',
      'fullName': 'Hoa',
      'email': 'hoa@x.vn',
      'bio': 'Tôi đọc Tarot 3 năm',
      'experience': 3,
      'specialties': ['Tarot'],
      'status': 'PENDING',
      'createdAt': iso(homNay),
    }
  ]);
  m.tra('GET /api/v1/admin/payments', trang([
    {
      'id': 'g1',
      'payerName': 'Khách A',
      'payerEmail': 'a@x.vn',
      'readerName': 'Lan',
      'amount': 180000,
      'paymentMethod': 'BANK_TRANSFER',
      'referenceCode': 'AT123',
      'status': 'PENDING',
      'bookingStartTime': iso(homNay),
      'createdAt': iso(homNay),
    }
  ]));
  m.tra('GET /api/v1/admin/payouts', trang([
    {
      'id': 'p1',
      'readerName': 'Lan',
      'readerEmail': 'lan@x.vn',
      'amount': 500000,
      'bankName': 'VCB',
      'bankAccountMasked': '****1234',
      'accountHolder': 'NGUYEN LAN',
      'status': 'PENDING',
      'requestedAt': iso(homNay),
    },
    {
      'id': 'p2',
      'readerName': 'Mai',
      'amount': 300000,
      'status': 'APPROVED',
      'rejectReason': null,
    },
  ]));
  m.tra('GET /api/v1/admin/reports', trang([
    {
      'id': 'bc1',
      'reporterName': 'Khách B',
      'reportedUserId': 'u9',
      'reportedName': 'Reader X',
      'reportedRole': 'STAFF',
      'bookingId': 'b1',
      'reportType': 'NO_SHOW',
      'description': 'Không vào buổi',
      'status': 'PENDING',
      'penaltyAmount': 0,
      'createdAt': iso(homNay),
    },
    {
      'id': 'bc2',
      'reporterName': 'Khách C',
      'reportedName': 'Reader Y',
      'reportType': 'RUDE',
      'status': 'RESOLVED',
      'penaltyAmount': 50000,
      'resolutionNote': 'Đã nhắc nhở',
      'handledByName': 'Admin',
    },
  ]));
  m.tra('GET /api/v1/admin/activity-logs', trang([
    {
      'id': 'l1',
      'actorName': 'Admin',
      'actorRole': 'ADMIN',
      'action': 'USER_ROLE_CHANGE',
      'entityType': 'USER',
      'entityId': 'u1',
      'changes': '{"from":"USER","to":"STAFF"}',
      'createdAt': iso(homNay),
    },
    {
      'id': 'l2',
      'actorName': 'Admin',
      'action': 'PRODUCT_UPDATE',
      'changes': '{"price":{"from":1,"to":2},"name":"x"}',
    },
  ]));
  m.tra('GET /api/v1/admin/products', trang([
    mauSanPham(),
    mauSanPham(id: 'p2', slug: 's2', coLink: false, dangBan: false),
  ]));
  m.tra('GET /api/v1/admin/affiliate/stats', {
    'totalClicks': 900,
    'clicksInPeriod': 300,
    'periodDays': 30,
    'productsWithLink': 18,
    'productsWithoutLink': 2,
    'estimatedCommission': 120000,
    'topProducts': [mauSanPham()],
  });
  m.tra('GET /api/v1/shop/categories', [
    {'id': 'c1', 'name': 'Bộ bài', 'slug': 'bo-bai'},
  ]);
}

/// Mở một mục trên dải chọn — cuộn ngang tới nó trước, vì dải chỉ dựng các
/// mục đang nằm trong màn.
Future<void> moTab(WidgetTester t, String nhan) async {
  final dai = find.byType(DaiChon);
  final muc = find.descendant(of: dai, matching: find.text(nhan));
  await t.scrollUntilVisible(muc, 120,
      scrollable: find.descendant(of: dai, matching: find.byType(Scrollable)));
  await bam(t, muc);
}

void main() {
  group('Khu quản trị', () {
    testWidgets('Quản trị viên thấy đủ chín mục', (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'ADMIN'));
      khaiQuanTri(m.mayChu);
      await m.dung(t, const AdminHub());
      expect(find.text('Quản trị'), findsOneWidget);
      expect(mucQuanTri(nguoiDung(vaiTro: 'ADMIN')).map((e) => e.nhan), [
        'Tổng quan', 'Tài khoản', 'Hồ sơ Reader', 'Thanh toán', 'Rút tiền',
        'Báo cáo vi phạm', 'Nhật ký', 'Phân quyền', 'Sản phẩm liên kết',
      ]);
      // Tổng quan: KPI + biểu đồ.
      expect(find.text('Hồ sơ Reader chờ duyệt'), findsOneWidget);
      await t.scrollUntilVisible(find.text('Token theo model AI'), 300,
          scrollable: find.descendant(
              of: find.byType(TongQuanView), matching: find.byType(Scrollable)));
      expect(find.text('gemini-2.5-flash'), findsOneWidget);
    });

    testWidgets('Quản lý chỉ thấy phần của mình và gọi là "Nhân sự"',
        (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'MANAGER'));
      khaiQuanTri(m.mayChu);
      await m.dung(t, const AdminHub());
      expect(find.text('Quản lý'), findsOneWidget);
      expect(find.text('Nhân sự'), findsWidgets);
      expect(find.text('Tổng quan'), findsNothing);
      expect(find.text('Thanh toán'), findsNothing);
      expect(find.text('Phân quyền'), findsNothing);
    });

    testWidgets('không có quyền nào thì nói thẳng', (t) async {
      final m = MoiTruong(user: nguoiDung(quyen: {'USER_BASIC'}));
      await m.dung(t, const AdminHub());
      expect(find.textContaining('không có quyền quản trị'), findsOneWidget);
    });

    testWidgets('mucQuanTri khớp đúng quyền', (t) async {
      expect(mucQuanTri(nguoiDung(quyen: {'REPORT_REVIEW'})).map((e) => e.nhan),
          ['Báo cáo vi phạm']);
      expect(
          mucQuanTri(nguoiDung(quyen: {'AUDIT_VIEW'})).map((e) => e.nhan),
          ['Tổng quan', 'Nhật ký']);
    });

    testWidgets('Tổng quan lỗi thì có nút thử lại', (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'ADMIN'));
      m.mayChu.loi('GET /api/v1/admin/stats', 'Không có quyền', ma: 403);
      await m.dung(t, const AdminHub());
      expect(find.text('Không có quyền'), findsOneWidget);
      m.mayChu.tra('GET /api/v1/admin/stats', {});
      await bam(t, find.text('Thử lại'));
      expect(find.text('Tài khoản theo vai trò'), findsOneWidget);
    });
  });

  group('Tài khoản', () {
    testWidgets('lọc, tìm, tải thêm, chọn nhiều và đổi vai trò hàng loạt',
        (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'ADMIN'));
      khaiQuanTri(m.mayChu);
      m.mayChu.tra('PATCH /api/v1/admin/users/role', []);
      await m.dung(t, const AdminHub());
      await moTab(t, 'Tài khoản');
      expect(find.text('Người t1'), findsOneWidget);
      expect(find.textContaining('chưa xác minh'), findsOneWidget);

      // Tải thêm trang 2.
      await t.scrollUntilVisible(find.text('Tải thêm'), 200,
          scrollable: find.byType(Scrollable).last);
      await bam(t, find.text('Tải thêm'));
      expect(m.mayChu.lanCuoi('GET /api/v1/admin/users')!.query['page'], '1');

      // Tìm theo từ khoá (chờ debounce 350ms).
      await t.enterText(find.byKey(const ValueKey('o-tim-tai-khoan')), 'lan');
      await t.pump(const Duration(milliseconds: 400));
      await xong(t);
      expect(m.mayChu.lanCuoi('GET /api/v1/admin/users')!.query['keyword'],
          'lan');

      // Giữ để chọn; đang chọn nhiều thì bấm hàng không sửa được không có
      // tác dụng — chọn nhầm nó là cả lượt đổi hàng loạt bị rollback.
      await t.longPress(find.text('Người t1'));
      await xong(t);
      await bam(t, find.text('Người t2'));
      await bam(t, find.text('Người t3'));
      expect(find.text('Đã chọn 2 tài khoản'), findsOneWidget);
      await bam(t, find.text('Người t2'));
      expect(find.text('Đã chọn 1 tài khoản'), findsOneWidget);
      await bam(t, find.text('Người t2'));
      await bam(t, find.text('Đổi vai trò'));
      await bam(t, find.text('Nhân viên').last);
      final g = m.mayChu.lanCuoi('PATCH /api/v1/admin/users/role')!;
      expect(g.than['role'], 'STAFF');
      expect((g.than['userIds'] as List).toSet(), {'t1', 't2'});
    });

    testWidgets('lọc theo vai trò gửi đúng tham số', (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'ADMIN'));
      khaiQuanTri(m.mayChu);
      await m.dung(t, const AdminHub());
      await moTab(t, 'Tài khoản');
      await bam(t, find.text('Mọi vai trò'));
      await bam(t, find.text('Quản lý').last);
      expect(m.mayChu.lanCuoi('GET /api/v1/admin/users')!.query['role'],
          'MANAGER');
      await bam(t, find.text('Mọi trạng thái'));
      await bam(t, find.text('Đã khoá').last);
      expect(m.mayChu.lanCuoi('GET /api/v1/admin/users')!.query['status'],
          'BANNED');
    });

    testWidgets('chi tiết: đổi vai trò, khoá, gửi mail, thu hồi, xoá',
        (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'ADMIN'));
      khaiQuanTri(m.mayChu);
      for (final r in [
        'PATCH /api/v1/admin/users/t1/role',
        'PATCH /api/v1/admin/users/t1/status',
        'POST /api/v1/admin/users/t1/password-reset',
        'POST /api/v1/admin/users/t1/resend-verification',
        'POST /api/v1/admin/users/t1/sessions/revoke',
        'PATCH /api/v1/admin/users/t1',
        'DELETE /api/v1/admin/users/t1',
      ]) {
        m.mayChu.tra(r, null);
      }
      await m.dung(
          t,
          const TaiKhoanChiTietScreen(
              id: 't1', vaiTroGanDuoc: ['USER', 'STAFF', 'MANAGER', 'ADMIN']),
          quaDuong: true);
      expect(find.text('0912345678'), findsOneWidget);
      expect(find.text('Đang chờ duyệt'), findsOneWidget);

      await bam(t, find.text('Đổi vai trò'));
      await bam(t, find.text('Quản lý').last);
      expect(m.mayChu.lanCuoi('PATCH /api/v1/admin/users/t1/role')!.than,
          {'role': 'MANAGER'});

      await bam(t, find.text('Khoá tài khoản'));
      await bam(t, find.text('Khoá').last);
      expect(m.mayChu.lanCuoi('PATCH /api/v1/admin/users/t1/status')!.than,
          {'status': 'BANNED'});

      await bam(t, find.text('Gửi liên kết đặt lại mật khẩu'));
      await bam(t, find.text('Gửi lại mail xác minh'));
      await bam(t, find.text('Buộc đăng xuất mọi thiết bị'));
      expect(m.mayChu.cacLan('POST /api/v1/admin/users/t1/sessions/revoke'),
          hasLength(1));

      await bam(t, find.text('Sửa thông tin'));
      await t.enterText(find.widgetWithText(TextFormField, 'Họ tên'), 'Tên Mới');
      await bam(t, find.text('Lưu'));
      expect(m.mayChu.lanCuoi('PATCH /api/v1/admin/users/t1')!.than['fullName'],
          'Tên Mới');

      await bam(t, find.text('Xoá tài khoản'));
      await bam(t, find.widgetWithText(FilledButton, 'Xoá tài khoản'));
      expect(m.mayChu.cacLan('DELETE /api/v1/admin/users/t1'), hasLength(1));
    });

    testWidgets('chi tiết tài khoản không sửa được thì chỉ xem', (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'MANAGER'));
      m.mayChu.tra('GET /api/v1/admin/users/t9',
          mauChiTietTaiKhoan(id: 't9', suaDuoc: false, trangThai: 'BANNED'));
      await m.dung(t,
          const TaiKhoanChiTietScreen(id: 't9', vaiTroGanDuoc: ['USER', 'STAFF']));
      expect(find.textContaining('Bạn không sửa được'), findsOneWidget);
      expect(find.text('Đổi vai trò'), findsNothing);
    });

    testWidgets('chi tiết lỗi rồi thử lại; thao tác hỏng báo lỗi', (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'ADMIN'));
      m.mayChu.loi('GET /api/v1/admin/users/t1', 'Không thấy', ma: 404);
      await m.dung(t,
          const TaiKhoanChiTietScreen(id: 't1', vaiTroGanDuoc: ['USER']));
      expect(find.text('Không thấy'), findsOneWidget);
      m.mayChu.tra('GET /api/v1/admin/users/t1',
          mauChiTietTaiKhoan(trangThai: 'BANNED'));
      await bam(t, find.text('Thử lại'));
      m.mayChu.loi('PATCH /api/v1/admin/users/t1/status', 'Không được');
      await bam(t, find.text('Mở khoá tài khoản'));
      await bam(t, find.text('Mở khoá').last);
      expect(find.text('Không được'), findsOneWidget);
      m.mayChu.loi('DELETE /api/v1/admin/users/t1', 'Không xoá được');
      await bam(t, find.text('Xoá tài khoản'));
      await bam(t, find.widgetWithText(FilledButton, 'Xoá tài khoản'));
      expect(find.text('Không xoá được'), findsOneWidget);
    });

    testWidgets('tạo tài khoản: kiểm dữ liệu rồi gửi', (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'ADMIN'));
      m.mayChu.tra('POST /api/v1/admin/users', mauTaiKhoan());
      await m.dung(t,
          const TaoTaiKhoanScreen(vaiTroGanDuoc: ['USER', 'STAFF', 'ADMIN']),
          quaDuong: true);
      await bam(t, find.widgetWithText(FilledButton, 'Tạo tài khoản'));
      expect(find.text('Email không hợp lệ'), findsOneWidget);
      expect(find.text('Họ tên là bắt buộc'), findsOneWidget);
      await t.enterText(find.byKey(const ValueKey('o-email')), 'moi@x.vn');
      await t.enterText(find.byKey(const ValueKey('o-ho-ten')), 'Người Mới');
      await bam(t, find.text('Nhân viên'));
      await bam(t, find.text('Quản trị viên').last);
      await bam(t, find.text('Đánh dấu email đã xác minh'));
      await bam(t, find.widgetWithText(FilledButton, 'Tạo tài khoản'));
      final g = m.mayChu.lanCuoi('POST /api/v1/admin/users')!;
      expect(g.than['role'], 'ADMIN');
      expect(g.than['markEmailVerified'], isTrue);
      expect(g.than.containsKey('phone'), isFalse);
    });

    testWidgets('tạo tài khoản lỗi thì hiện câu máy chủ', (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'MANAGER'));
      m.mayChu.loi('POST /api/v1/admin/users', 'Email đã tồn tại');
      await m.dung(t, const TaoTaiKhoanScreen(vaiTroGanDuoc: ['USER', 'STAFF']));
      await t.enterText(find.byKey(const ValueKey('o-email')), 'a@b.vn');
      await t.enterText(find.byKey(const ValueKey('o-ho-ten')), 'A');
      await bam(t, find.widgetWithText(FilledButton, 'Tạo tài khoản'));
      expect(find.text('Email đã tồn tại'), findsOneWidget);
    });

    testWidgets('bấm dòng mở chi tiết, nút tạo mở form', (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'ADMIN'));
      khaiQuanTri(m.mayChu);
      await m.dung(t, const AdminHub());
      await moTab(t, 'Tài khoản');
      await bam(t, find.text('Người t1'));
      expect(find.text('Vai trò này được làm gì'.toUpperCase()), findsOneWidget);
      await t.pageBack();
      await xong(t);
      await bam(t, find.byType(FloatingActionButton));
      expect(find.text('Tạo tài khoản'), findsWidgets);
    });
  });

  group('Hàng chờ', () {
    testWidgets('thanh toán: mặc định lọc chờ, xác nhận và từ chối', (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'ADMIN'));
      khaiQuanTri(m.mayChu);
      m.mayChu.tra('PATCH /api/v1/admin/payments/g1/confirm', null);
      m.mayChu.tra('PATCH /api/v1/admin/payments/g1/reject', null);
      await m.dung(t, const AdminHub());
      await moTab(t, 'Thanh toán');
      expect(m.mayChu.lanCuoi('GET /api/v1/admin/payments')!.query['status'],
          'PENDING');
      expect(find.text('Mã: AT123'), findsOneWidget);
      await bam(t, find.text('Mã: AT123'));
      expect(m.clipboard, 'AT123');

      await bam(t, find.text('Xác nhận đã nhận'));
      await bam(t, find.text('Đồng ý'));
      expect(m.mayChu.cacLan('PATCH /api/v1/admin/payments/g1/confirm'),
          hasLength(1));

      await bam(t, find.text('Từ chối'));
      await t.enterText(find.byType(TextField).last, 'Không khớp sao kê');
      await bam(t, find.text('Gửi'));
      expect(m.mayChu.lanCuoi('PATCH /api/v1/admin/payments/g1/reject')!.than,
          {'reason': 'Không khớp sao kê'});

      await bam(t, find.text('Chờ đối soát'));
      await bam(t, find.text('Tất cả').last);
      expect(
          m.mayChu.lanCuoi('GET /api/v1/admin/payments')!.query
              .containsKey('status'),
          isFalse);
    });

    testWidgets('rút tiền: duyệt, đã chi, từ chối', (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'ADMIN'));
      khaiQuanTri(m.mayChu);
      m.mayChu.tra('PATCH /api/v1/admin/payouts/*/approve', null);
      m.mayChu.tra('PATCH /api/v1/admin/payouts/*/paid', null);
      m.mayChu.tra('PATCH /api/v1/admin/payouts/*/reject', null);
      await m.dung(t, const AdminHub());
      await moTab(t, 'Rút tiền');
      expect(find.textContaining('****1234'), findsOneWidget);
      await bam(t, find.text('Duyệt'));
      expect(m.mayChu.cacLan('PATCH /api/v1/admin/payouts/p1/approve'),
          hasLength(1));
      await bam(t, find.text('Đã chuyển khoản'));
      await bam(t, find.text('Đã chuyển'));
      expect(m.mayChu.cacLan('PATCH /api/v1/admin/payouts/p2/paid'),
          hasLength(1));
      await bam(t, find.text('Từ chối').first);
      await bam(t, find.text('Gửi'));
      expect(m.mayChu.lanCuoi('PATCH /api/v1/admin/payouts/p1/reject')!.than,
          {'reason': null});
    });

    testWidgets('hồ sơ Reader: từ chối gửi rejectionReason', (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'ADMIN'));
      khaiQuanTri(m.mayChu);
      m.mayChu.tra('PATCH /api/v1/admin/readers/a1/review', null);
      await m.dung(t, const AdminHub());
      await moTab(t, 'Hồ sơ Reader');
      expect(find.text('Hoa · 3 năm kinh nghiệm'), findsOneWidget);
      await bam(t, find.text('Từ chối'));
      await t.enterText(find.byType(TextField).last, 'Thiếu kinh nghiệm');
      await bam(t, find.text('Gửi'));
      // Bản cũ gửi `reason` — backend bỏ qua, người nộp không đọc được lý do.
      expect(m.mayChu.lanCuoi('PATCH /api/v1/admin/readers/a1/review')!.than,
          {'action': 'REJECTED', 'rejectionReason': 'Thiếu kinh nghiệm'});
      await bam(t, find.text('Duyệt'));
      await bam(t, find.text('Duyệt').last);
      expect(m.mayChu.lanCuoi('PATCH /api/v1/admin/readers/a1/review')!.than,
          {'action': 'APPROVED', 'rejectionReason': null});
    });

    testWidgets('hồ sơ Reader: chỉ xem thì không có nút; rỗng; lỗi', (t) async {
      final m = MoiTruong(user: nguoiDung(quyen: {'ADMIN_READERS_VIEW'}));
      m.mayChu.tra('GET /api/v1/admin/readers/applications', []);
      await m.dung(t, const AdminHub());
      expect(find.text('Không có hồ sơ nào'), findsOneWidget);
      final m2 = MoiTruong(user: nguoiDung(quyen: {'ADMIN_READERS_VIEW'}));
      m2.mayChu.loi('GET /api/v1/admin/readers/applications', 'Hỏng');
      await m2.dung(t, const AdminHub());
      expect(find.text('Hỏng'), findsOneWidget);
    });

    testWidgets('báo cáo: kết luận kèm tiền phạt', (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'MANAGER'));
      khaiQuanTri(m.mayChu);
      m.mayChu.tra('PATCH /api/v1/admin/reports/bc1/handle', null);
      await m.dung(t, const AdminHub());
      await moTab(t, 'Báo cáo vi phạm');
      expect(find.text('Không có mặt đúng giờ hẹn'), findsOneWidget);
      expect(find.text('Đã phạt 50.000 đ'), findsOneWidget);
      await bam(t, find.text('Kết luận'));
      await t.enterText(find.byType(TextField).first, 'Đã xác minh');
      await t.enterText(find.byKey(const ValueKey('o-tien-phat')), '100000');
      await bam(t, find.text('Lưu kết luận'));
      expect(m.mayChu.lanCuoi('PATCH /api/v1/admin/reports/bc1/handle')!.than,
          {
            'status': 'RESOLVED',
            'resolutionNote': 'Đã xác minh',
            'penaltyAmount': 100000,
          });
      await bam(t, find.text('Kết luận'));
      await bam(t, find.byKey(const ValueKey('ket-luan-REJECTED')));
      await bam(t, find.text('Lưu kết luận'));
      expect(
          m.mayChu.lanCuoi('PATCH /api/v1/admin/reports/bc1/handle')!
              .than['penaltyAmount'],
          0);
    });

    testWidgets('nhật ký: diễn giải thay đổi và lọc', (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'ADMIN'));
      khaiQuanTri(m.mayChu);
      await m.dung(t, const AdminHub());
      await moTab(t, 'Nhật ký');
      expect(find.text('USER → STAFF'), findsOneWidget);
      expect(find.text('price: 1 → 2 · name: x'), findsOneWidget);
      await bam(t, find.text('Tất cả'));
      await bam(t, find.text('Xoá tài khoản').last);
      expect(m.mayChu.lanCuoi('GET /api/v1/admin/activity-logs')!.query['action'],
          'USER_DELETE');
    });

    testWidgets('phân quyền đọc từ máy chủ', (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'ADMIN'));
      m.mayChu.xuLy('GET /api/v1/admin/users', (g) {
        final vt = g.query['role'];
        if (vt == 'MANAGER') return TraLoi(200, {'data': trang([])});
        return TraLoi(200, {
          'data': trang([mauTaiKhoan(id: 'x$vt', vaiTro: '$vt')])
        });
      });
      m.mayChu.tra('GET /api/v1/admin/users/*', mauChiTietTaiKhoan());
      await m.dung(t, const AdminHub());
      await moTab(t, 'Phân quyền');
      expect(find.text('chưa có ai'), findsOneWidget);
      await bam(t, find.text('2 quyền').first);
      expect(find.text('READER_APPLY'), findsWidgets);
    });

    testWidgets('sản phẩm: thống kê, ẩn/hiện, thêm và sửa', (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'ADMIN'));
      khaiQuanTri(m.mayChu);
      m.mayChu.tra('PATCH /api/v1/admin/products/*/active', null);
      m.mayChu.tra('POST /api/v1/admin/products', mauSanPham());
      m.mayChu.tra('PUT /api/v1/admin/products/p1', mauSanPham());
      await m.dung(t, const AdminHub());
      await moTab(t, 'Sản phẩm liên kết');
      expect(find.text('Hoa hồng ước tính'), findsOneWidget);
      expect(find.text('Chưa có link'), findsOneWidget);

      await bam(t, find.byTooltip('Ẩn Bộ bài Rider-Waite'));
      expect(m.mayChu.lanCuoi('PATCH /api/v1/admin/products/p1/active')!.query,
          {'value': 'false'});

      await bam(t, find.byTooltip('Sửa Bộ bài Rider-Waite').first);
      await bam(t, find.text('Lưu'));
      expect(m.mayChu.lanCuoi('PUT /api/v1/admin/products/p1')!.than['price'],
          250000);
      expect(find.text('Đã cập nhật sản phẩm.'), findsOneWidget);
    });

    testWidgets('form sản phẩm mới: kiểm và tạo', (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'ADMIN'));
      khaiQuanTri(m.mayChu);
      m.mayChu.tra('POST /api/v1/admin/products', mauSanPham());
      await m.dung(t, const SanPhamFormScreen(), quaDuong: true);
      await bam(t, find.text('Tạo sản phẩm'));
      expect(find.text('Phải nhập tên sản phẩm'), findsOneWidget);
      await t.enterText(find.widgetWithText(TextFormField, 'Tên sản phẩm'), 'Đá');
      await t.enterText(
          find.widgetWithText(TextFormField, 'Giá tham khảo (đ)'), '99000');
      await t.enterText(
          find.widgetWithText(TextFormField, 'Liên kết tiếp thị'), 'shopee');
      await bam(t, find.text('Tạo sản phẩm'));
      expect(find.textContaining('http:// hoặc https://'), findsOneWidget);
      await t.enterText(find.widgetWithText(TextFormField, 'Liên kết tiếp thị'),
          'https://shopee.vn/da');
      await t.enterText(find.widgetWithText(TextFormField, 'Hoa hồng (%)'), '150');
      await bam(t, find.text('Tạo sản phẩm'));
      expect(find.text('Từ 0 đến 100'), findsOneWidget);
      await t.enterText(find.widgetWithText(TextFormField, 'Hoa hồng (%)'), '7');
      await bam(t, find.text('Ảnh minh hoạ'));
      await bam(t, find.text('Tạo sản phẩm'));
      final g = m.mayChu.lanCuoi('POST /api/v1/admin/products')!;
      expect(g.than['name'], 'Đá');
      expect(g.than['price'], 99000);
      expect(g.than['commissionPercent'], 7.0);
      expect(g.than['imageIsIllustrative'], isTrue);
    });
  });

  group('Model quản trị', () {
    test('nhãn và diễn giải lỏng', () {
      expect(tenLoaiViPham('SCAM'), 'Đòi tiền ngoài hệ thống');
      expect(tenLoaiViPham('LA'), 'LA');
      expect(NhatKy.fromJson({'changes': 'không phải json'}).moTaThayDoi,
          'không phải json');
      expect(NhatKy.fromJson({}).moTaThayDoi, '—');
      expect(NhatKy.fromJson({'changes': '5'}).moTaThayDoi, '5');
      expect(NhatKy.fromJson({'action': 'LA'}).tenHanhDongVi, 'LA');
      expect(DonReader.fromJson({'username': 'u'}).hoTen, 'u');
      expect(ThongKe(const {}).so('x', 'y'), 0);
      expect(ThongKe(const {'a': {'b': 'x'}}).bang('a', 'b'), isEmpty);
      expect(const ThongKe({}).coKhoi('ai'), isFalse);
      final tk = TaiKhoan.fromJson({'username': 'abc'});
      expect(tk.tenHienThi, 'abc');
      expect(tk.biKhoa, isFalse);
    });
  });
}
