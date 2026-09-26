import 'dart:io';

import 'package:astrotarot_mobile/features/account/account_screen.dart';
import 'package:astrotarot_mobile/features/blog/blog_screen.dart';
import 'package:astrotarot_mobile/features/bookings/bookings_screen.dart';
import 'package:astrotarot_mobile/features/feedback/feedback_screen.dart';
import 'package:astrotarot_mobile/features/home/daily_card.dart';
import 'package:astrotarot_mobile/features/home/home_screen.dart';
import 'package:astrotarot_mobile/features/notifications/notifications_screen.dart';
import 'package:astrotarot_mobile/features/profile/change_password_screen.dart';
import 'package:astrotarot_mobile/features/profile/profile_screen.dart';
import 'package:astrotarot_mobile/features/readerapply/reader_apply_screen.dart';
import 'package:astrotarot_mobile/features/shell/home_shell.dart';
import 'package:astrotarot_mobile/features/staff/staff_screen.dart';
import 'package:astrotarot_mobile/features/support/support_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'dart:math';

import 'support/gia.dart';
import 'support/mau.dart';

class PickerGia extends ImagePickerPlatform {
  PickerGia(this.duong);
  final String? duong;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async =>
      duong == null ? null : XFile(duong!);
}

const _hoSo = {
  'id': 'u-USER',
  'username': 'user',
  'fullName': 'Minh Anh',
  'email': 'user@astrotarot.date',
  'phone': '0900000000',
  'gender': 'FEMALE',
  'dateOfBirth': '2001-09-25',
  'bio': 'Thích Tarot',
  'address': '1 Lê Lợi',
  'city': 'Huế',
  'country': 'VN',
  'avatar': null,
  'emailVerified': true,
  'role': 'USER',
};

void khaiTrangChu(MayChuGia m) {
  m.tra('GET /api/v1/bookings/me', trang([
    mauBooking(batDau: homNay.add(const Duration(hours: 5))),
    mauBooking(id: 'b0', trangThai: 'COMPLETED',
        batDau: homNay.subtract(const Duration(days: 2))),
  ]));
  m.tra('GET /api/ai-readings', trang([
    {'id': 'rd1', 'mainQuestion': 'Công việc tháng này?', 'createdAt': iso(homNay)},
  ]));
  m.tra('GET /api/me/astrology/profiles/primary', mauHoSoSao());
  m.tra('GET /api/v1/me/notifications/unread-count', {'count': 3});
  m.tra('GET /api/v1/readers/applications/me',
      {'status': 'REJECTED', 'rejectionReason': 'Thiếu kinh nghiệm'});
}

void main() {
  group('Khung chính và trang chủ', () {
    test('chào bằng tên gọi; ngày giờ sinh viết kiểu Việt', () {
      expect(tenGoi('Hoàng  Văn An '), 'An');
      expect(tenGoi(''), 'bạn');
      expect(tenGoi(null), 'bạn');
      expect(ngayIso('1998-04-10'), '10/04/1998');
      expect(ngayIso('10/04/1998'), '10/04/1998');
      expect(ngayIso(null), isNull);
      expect(gioNgan('09:30:00'), '09:30');
      expect(gioNgan('sáng'), 'sáng');
      expect(gioNgan(null), isNull);
    });

    testWidgets('lối tắt trên trang chủ mở đúng màn', (t) async {
      final m = MoiTruong(user: nguoiDung());
      khaiTrangChu(m.mayChu);
      m.mayChu.tra('GET /api/v1/shop/categories', []);
      m.mayChu.tra('GET /api/v1/shop/products', trang([]));
      await m.dung(t, const HomeScreen());
      await bam(t, find.text('Gian hàng'));
      expect(find.text('Gian hàng đang trống'), findsOneWidget);
    });

    testWidgets('người dùng: bốn tab, trang chủ đủ khối', (t) async {
      final m = MoiTruong(user: nguoiDung());
      khaiTrangChu(m.mayChu);
      m.mayChu.tra('GET /api/v1/readers', [mauReader()]);
      await m.dung(t, const HomeShell());
      expect(find.text('Chào Anh,'), findsOneWidget);
      expect(find.text('Bàn làm việc'), findsNothing);
      expect(find.text('3'), findsOneWidget); // chấm chưa đọc
      expect(find.text('Đơn làm Reader chưa được duyệt'), findsOneWidget);
      // Lý do từ chối hiện luôn trên trang chủ, như web.
      expect(find.textContaining('Thiếu kinh nghiệm'), findsOneWidget);
      for (final n in ['Lịch sử bài', 'Bản đồ sao', 'Gian hàng', 'Bài viết']) {
        expect(find.text(n), findsWidgets, reason: n);
      }
      await cuonToi(t, find.text('Công việc tháng này?'));
      expect(find.text('Công việc tháng này?'), findsOneWidget);
      await cuonToi(t, find.text('Hà Nội'));
      expect(find.text('Hà Nội'), findsOneWidget);

      // Sự kiện realtime làm tươi số chưa đọc.
      m.mayChu.tra('GET /api/v1/me/notifications/unread-count', {'count': 5});
      m.realtime.phat('/user/queue/events', {'type': 'BOOKING_CONFIRMED'});
      await xong(t);
      expect(find.text('5'), findsOneWidget);

      await bam(t, find.text('Reader'));
      expect(find.text('Lan Hương'), findsOneWidget);
    });

    testWidgets('nhân sự có thêm Bàn làm việc', (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'STAFF'));
      khaiTrangChu(m.mayChu);
      await m.dung(t, const HomeShell());
      expect(find.text('Bàn làm việc'), findsOneWidget);
    });

    testWidgets('trang chủ khi lịch hẹn lỗi vẫn hiện, chưa có bản đồ sao',
        (t) async {
      final m = MoiTruong(user: nguoiDung());
      m.mayChu.loi('GET /api/v1/bookings/me', 'Hỏng');
      m.mayChu.loi('GET /api/ai-readings', 'Hỏng');
      m.mayChu.loi('GET /api/me/astrology/profiles/primary', 'Chưa có', ma: 404);
      m.mayChu.loi('GET /api/v1/me/notifications/unread-count', 'Hỏng');
      m.mayChu.tra('GET /api/v1/readers/applications/me', null);
      await m.dung(t, const HomeScreen());
      // Bản cũ sập ở đây (sort trên const []).
      expect(find.text('Chào Anh,'), findsOneWidget);
      expect(find.text('Bạn chưa khai ngày giờ nơi sinh'), findsOneWidget);
      await bam(t, find.text('Khai ngày giờ nơi sinh'));
      expect(find.text('Bản đồ sao'), findsOneWidget);
    });

    testWidgets('mở các lối từ trang chủ', (t) async {
      final m = MoiTruong(user: nguoiDung());
      khaiTrangChu(m.mayChu);
      m.mayChu.tra('GET /api/v1/readers/applications/me', {'status': 'PENDING'});
      m.mayChu.tra('GET /api/v1/me/notifications', trang([]));
      await m.dung(t, const HomeScreen());
      expect(find.text('Đơn làm Reader đang chờ duyệt'), findsOneWidget);
      await bam(t, find.text('Trải bài Tarot ngay'));
      expect(find.text('Tarot AI'), findsOneWidget);
      await t.pageBack();
      await xong(t);
      await bam(t, find.byIcon(Icons.notifications_none));
      expect(find.text('Thông báo'), findsOneWidget);
      await t.pageBack();
      await xong(t);
      await bam(t, find.text('Xem tất cả'));
      expect(find.text('Lịch sử trải bài'), findsOneWidget);
      await t.pageBack();
      await xong(t);
      await bam(t, find.text('Quản lý'));
      expect(find.text('Bản đồ sao'), findsOneWidget);
    });

    testWidgets('buổi sắp tới có nút nhắn tin', (t) async {
      final m = MoiTruong(user: nguoiDung());
      khaiTrangChu(m.mayChu);
      m.mayChu.tra('GET /api/v1/bookings/b1/messages', trang([]));
      await m.dung(t, const HomeScreen());
      await cuonToi(t, find.textContaining('Chưa thanh toán'));
      expect(find.textContaining('Chưa thanh toán'), findsOneWidget);
      await bam(t, find.text('Nhắn tin'));
      expect(find.text('Nhắn gì đó…'), findsOneWidget);
    });

    testWidgets('rút một lá hằng ngày', (t) async {
      final m = MoiTruong(user: nguoiDung());
      await m.dung(t, Scaffold(body: RutBaiHangNgay(ngauNhien: Random(1))));
      await bam(t, find.byKey(const ValueKey('la-up-1')));
      expect(find.text('Rút lại'), findsOneWidget);
      expect(anChinh, hasLength(22));
      expect(anChinh.first.anh, endsWith('/tarot/00-fool.jpg'));
      await bam(t, find.text('Rút lại'));
      expect(find.text('Hôm nay vũ trụ muốn nói gì với bạn?'), findsOneWidget);
      await bam(t, find.byKey(const ValueKey('la-up-0')));
      await bam(t, find.text('Trải bài đầy đủ'));
      expect(find.text('Tarot AI'), findsOneWidget);
    });
  });

  group('Thông báo', () {
    void khai(MayChuGia m) {
      // ThỨ TỰ ĐÚNG NHƯ MÁY CHỦ TRẢ: ghim trước, rồi mới tới thời gian giảm
      // dần. Backend làm việc này bằng chính tên truy vấn
      // (`findByUserIdOrderByPinnedDescCreatedAtDesc`), và controller truyền
      // `PageRequest.of(page, size)` không kèm Sort riêng nên thứ tự ấy là
      // bảo đảm.
      //
      // Dữ liệu giả trước đây đặt tin ghim ở giữa, và phép kiểm vẫn xanh vì
      // màn hình tự sắp lại ở máy khách — tức là nó đang kiểm miếng vá, không
      // kiểm hành vi thật. Sắp lại ở máy khách còn sai khi có nhiều trang: một
      // tin ghim nằm ở trang hai sẽ bị xếp xuống dưới tin thường của trang một.
      m.tra('GET /api/v1/me/notifications', trang([
        {
          'id': 'n2',
          'title': 'Tin ghim',
          'message': '',
          'type': null,
          'read': true,
          'pinned': true,
          'createdAt': iso(homNay.subtract(const Duration(days: 1))),
        },
        {
          'id': 'n1',
          'title': 'Reader đã nhận lịch',
          'message': 'Buổi 20:00 đã xác nhận',
          'type': 'BOOKING_CONFIRMED',
          'read': false,
          'pinned': false,
          'createdAt': iso(homNay),
        },
        {
          'id': 'n3',
          'title': 'Phản hồi hỗ trợ',
          'type': 'SUPPORT_REPLY',
          'read': true,
          'pinned': false,
        },
      ]));
      m.tra('GET /api/v1/me/notifications/unread-count', {'count': 1});
      m.tra('PATCH /api/v1/me/notifications/*/read', null);
      m.tra('PATCH /api/v1/me/notifications/read-all', {'updated': 1});
      m.tra('PATCH /api/v1/me/notifications/*/pin', null);
      m.tra('DELETE /api/v1/me/notifications/read', {'deleted': 2});
      m.tra('DELETE /api/v1/me/notifications', {'deleted': 1});
      m.tra('GET /api/v1/bookings/me', trang([]));
      m.tra('GET /api/v1/support/tickets/mine', trang([]));
    }

    testWidgets('đọc (PATCH), mở màn liên quan, đọc hết, ghim, xoá',
        (t) async {
      final m = MoiTruong(user: nguoiDung());
      khai(m.mayChu);
      await m.dung(t, const NotificationsScreen());
      // Tin ghim đứng đầu — theo thứ tự máy chủ trả, không phải do màn hình
      // tự sắp lại.
      final y1 = t.getTopLeft(find.text('Tin ghim')).dy;
      final y2 = t.getTopLeft(find.text('Reader đã nhận lịch')).dy;
      expect(y1, lessThan(y2));

      await bam(t, find.text('Reader đã nhận lịch'));
      // Bản cũ gọi POST — backend map PATCH, chấm đỏ không bao giờ tắt.
      expect(m.mayChu.cacLan('PATCH /api/v1/me/notifications/n1/read'),
          hasLength(1));
      expect(find.text('Lịch hẹn của tôi'), findsOneWidget);
      await t.pageBack();
      await xong(t);

      await bam(t, find.text('Phản hồi hỗ trợ'));
      expect(find.text('Hỗ trợ'), findsOneWidget);
      await t.pageBack();
      await xong(t);

      await bam(t, find.text('Đọc hết'));
      expect(m.mayChu.cacLan('PATCH /api/v1/me/notifications/read-all'),
          hasLength(1));

      await t.longPress(find.text('Reader đã nhận lịch'));
      await xong(t);
      await bam(t, find.text('Ghim lên đầu'));
      expect(m.mayChu.lanCuoi('PATCH /api/v1/me/notifications/n1/pin')!.than,
          {'pinned': true});

      await t.longPress(find.text('Reader đã nhận lịch'));
      await xong(t);
      await bam(t, find.text('Xoá thông báo'));
      expect(m.mayChu.lanCuoi('DELETE /api/v1/me/notifications')!.than,
          {'ids': ['n1']});

      await t.longPress(find.text('Tin ghim'));
      await xong(t);
      expect(find.text('Xoá thông báo'), findsNothing);
      await bam(t, find.text('Bỏ ghim'));

      await bam(t, find.byTooltip('Thêm'));
      await bam(t, find.text('Xoá thông báo đã đọc (trừ tin ghim)'));
      expect(find.text('Đã xoá 2 thông báo.'), findsOneWidget);
    });

    testWidgets('đọc hết lỗi thì báo; rỗng; lỗi tải', (t) async {
      final m = MoiTruong(user: nguoiDung());
      khai(m.mayChu);
      m.mayChu.loi('PATCH /api/v1/me/notifications/read-all', 'Không được');
      await m.dung(t, const NotificationsScreen());
      await bam(t, find.text('Đọc hết'));
      expect(find.text('Không được'), findsOneWidget);
      final m2 = MoiTruong(user: nguoiDung());
      m2.mayChu.tra('GET /api/v1/me/notifications', trang([]));
      await m2.dung(t, const NotificationsScreen());
      expect(find.text('Chưa có thông báo nào'), findsOneWidget);
      final m3 = MoiTruong(user: nguoiDung());
      m3.mayChu.loi('GET /api/v1/me/notifications', 'Hỏng');
      await m3.dung(t, const NotificationsScreen());
      expect(find.text('Hỏng'), findsOneWidget);
    });

    /// Một tin, chỉ khai loại và metadata — phần còn lại không ảnh hưởng đích.
    ThongBao tin(String? loai, {String? meta}) => ThongBao.fromJson({
          'id': 'n1',
          'title': 'T',
          'message': '',
          'read': false,
          'pinned': false,
          'type': loai,
          'metadata': ?meta,
        });

    /// Đích của một tin, kèm tab nếu đó là Bàn làm việc.
    ///
    /// Trước đây phép kiểm ở đây chỉ đòi `isNotNull`. Nó xanh kể cả khi tin
    /// mở NHẦM màn — mà mở nhầm màn chính là lỗi người dùng báo.
    (Type, String?) dich(ThongBao t) {
      final w = manChoThongBao(t);
      return (w.runtimeType, w is StaffScreen ? w.tabDau : null);
    }

    test('tin phía Reader mở Bàn làm việc, không mở màn phía khách', () {
      // Đây chính là lỗi được báo: Reader nhận "Có lịch hẹn mới", bấm vào, và
      // thấy một danh sách trống — trống đúng, vì chính họ không đặt gì cả.
      expect(dich(tin('BOOKING_CREATED', meta: '{"side":"reader"}')),
          (StaffScreen, 'bookings'));
      expect(dich(tin('BOOKING_CONFIRMED', meta: '{"side":"customer"}')),
          (BookingsScreen, null));
    });

    test('CÙNG một loại đi hai nơi khác nhau tuỳ phía', () {
      // BOOKING_CANCELLED gửi cho BÊN KIA: khách huỷ thì Reader nhận, Reader
      // huỷ thì khách nhận. Suy từ loại là không thể.
      expect(dich(tin('BOOKING_CANCELLED', meta: '{"side":"reader"}')),
          (StaffScreen, 'bookings'));
      expect(dich(tin('BOOKING_CANCELLED', meta: '{"side":"customer"}')),
          (BookingsScreen, null));
    });

    test('tin cũ chưa có khoá side thì suy theo loại', () {
      // Tin đã nằm sẵn trong hộp trước khi backend ghi "side" không tự sửa
      // được. Chỗ nào suy chắc chắn thì vẫn phải đi đúng.
      expect(dich(tin('BOOKING_CREATED')), (StaffScreen, 'bookings'));
      expect(dich(tin('REVIEW_RECEIVED')), (StaffScreen, 'bookings'));
      expect(dich(tin('BOOKING_CONFIRMED')), (BookingsScreen, null));
      // Lệnh rút là tiền của Reader — nó không có mặt ở màn lịch hẹn phía
      // khách dưới bất kỳ hình thức nào.
      expect(dich(tin('PAYOUT_PAID')), (StaffScreen, 'earnings'));
      expect(dich(tin('SUPPORT_MESSAGE')), (StaffScreen, 'support'));
      expect(dich(tin('SUPPORT_REPLY')), (SupportScreen, null));
      expect(dich(tin('READER_APPLICATION_APPROVED')),
          (ReaderApplyScreen, null));
    });

    test('metadata hỏng thì rơi về suy theo loại, không ném lỗi', () {
      // Một chuỗi hỏng ở MỘT dòng không được phép làm sập cả hộp thông báo.
      expect(dich(tin('BOOKING_CREATED', meta: '{')),
          (StaffScreen, 'bookings'));
      expect(dich(tin('BOOKING_CONFIRMED', meta: '"x"')),
          (BookingsScreen, null));
      expect(dich(tin('BOOKING_CONFIRMED', meta: '{"side":"admin"}')),
          (BookingsScreen, null));
    });

    test('không có loại thì không đi đâu cả', () {
      expect(manChoThongBao(tin(null)), isNull);
      expect(manChoThongBao(tin('LẠ')), isNull);
    });
  });

  group('Tài khoản và hồ sơ', () {
    testWidgets('tài khoản thường: các lối vào và đăng xuất', (t) async {
      final m = MoiTruong(user: nguoiDung(), token: ['a', 'r']);
      m.mayChu.tra('GET /api/v1/feedback/me/status',
          {'submitted': false, 'total': 5, 'goal': 20, 'goalMet': false});
      m.mayChu.tra('POST /auth/logout', null);
      await m.store.nap();
      await m.dung(t, const AccountScreen());
      expect(find.text('Khu quản trị'), findsNothing);
      for (final n in [
        'Hồ sơ cá nhân', 'Bản đồ sao', 'Lịch sử trải bài',
        'Đăng ký làm Reader', 'Bài viết', 'Gian hàng', 'Hỗ trợ', 'Góp ý',
      ]) {
        await cuonToi(t, find.text(n));
        expect(find.text(n), findsOneWidget, reason: n);
      }
      await bam(t, find.text('Đăng xuất'));
      expect(m.mayChu.lanCuoi('POST /auth/logout')!.than,
          {'refreshToken': 'r'});
    });

    testWidgets('quản trị viên và quản lý thấy khu riêng', (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'ADMIN'));
      m.mayChu.tra('GET /api/v1/feedback/me/status', {'submitted': true});
      m.mayChu.tra('GET /api/v1/admin/stats', {});
      await m.dung(t, const AccountScreen());
      expect(find.text('Khu quản trị'), findsOneWidget);
      expect(find.text('Góp ý'), findsNothing);
      expect(find.text('Đăng ký làm Reader'), findsNothing);
      await bam(t, find.text('Khu quản trị'));
      expect(find.text('Quản trị'), findsOneWidget);
      final m2 = MoiTruong(user: nguoiDung(vaiTro: 'MANAGER'));
      await m2.dung(t, const AccountScreen());
      expect(find.text('Khu quản lý'), findsOneWidget);
    });

    testWidgets('sửa hồ sơ và lưu', (t) async {
      final m = MoiTruong(user: nguoiDung());
      m.mayChu.tra('GET /api/v1/me', _hoSo);
      m.mayChu.xuLy('PATCH /api/v1/me', (g) => TraLoi(200, {
            'data': {..._hoSo, ...(g.than as Map<String, dynamic>)},
          }));
      await m.dung(t, const ProfileScreen());
      expect(find.text('Thích Tarot'), findsOneWidget);
      await t.enterText(find.widgetWithText(TextFormField, 'Thích Tarot'),
          'Thích chiêm tinh');
      await bam(t, find.text('Lưu hồ sơ'));
      final g = m.mayChu.lanCuoi('PATCH /api/v1/me')!;
      expect(g.than['bio'], 'Thích chiêm tinh');
      expect(g.than['dateOfBirth'], '2001-09-25');
      expect(find.text('Đã lưu hồ sơ'), findsOneWidget);
    });

    testWidgets('lưu hồ sơ lỗi; tải lỗi', (t) async {
      final m = MoiTruong(user: nguoiDung());
      m.mayChu.tra('GET /api/v1/me', _hoSo);
      m.mayChu.loi('PATCH /api/v1/me', 'Số điện thoại không hợp lệ');
      await m.dung(t, const ProfileScreen());
      await bam(t, find.text('Lưu hồ sơ'));
      expect(find.text('Số điện thoại không hợp lệ'), findsOneWidget);
      final m2 = MoiTruong(user: nguoiDung());
      m2.mayChu.loi('GET /api/v1/me', 'Hỏng');
      await m2.dung(t, const ProfileScreen());
      expect(find.text('Hỏng'), findsOneWidget);
    });

    testWidgets('đổi ảnh đại diện; huỷ chọn thì không gửi', (t) async {
      final tep = File('${Directory.systemTemp.path}/anh_test.jpg')
        ..writeAsBytesSync([0xFF, 0xD8, 0xFF]);
      addTearDown(() => tep.deleteSync());
      final m = MoiTruong(user: nguoiDung());
      m.mayChu.tra('GET /api/v1/me', _hoSo);
      m.mayChu.tra('POST /api/v1/me/avatar', {..._hoSo, 'avatar': 'x'});
      ImagePickerPlatform.instance = PickerGia(null);
      await m.dung(t, const ProfileScreen());
      await bam(t, find.text('Đổi ảnh'));
      expect(m.mayChu.cacLan('POST /api/v1/me/avatar'), isEmpty);
      ImagePickerPlatform.instance = PickerGia(tep.path);
      await t.runAsync(() async {
        await t.tap(find.text('Đổi ảnh'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await xong(t);
      expect(m.mayChu.lanCuoi('POST /api/v1/me/avatar')!.than, '<form>');
    });

    testWidgets('đổi mật khẩu', (t) async {
      final m = MoiTruong(user: nguoiDung());
      m.mayChu.tra('POST /api/v1/me/change-password', null);
      await m.dung(t, const ChangePasswordScreen(), quaDuong: true);
      await bam(t, find.widgetWithText(FilledButton, 'Đổi mật khẩu'));
      expect(m.mayChu.goi, isEmpty);
      final o = find.byType(TextFormField);
      await t.enterText(o.at(0), 'cu123456');
      await t.enterText(o.at(1), 'moi12345');
      await t.enterText(o.at(2), 'moi12345');
      await bam(t, find.byTooltip('Hiện'));
      await bam(t, find.widgetWithText(FilledButton, 'Đổi mật khẩu'));
      expect(m.mayChu.lanCuoi('POST /api/v1/me/change-password')!.than,
          {'currentPassword': 'cu123456', 'newPassword': 'moi12345'});
    });

    testWidgets('đổi mật khẩu sai mật khẩu cũ', (t) async {
      final m = MoiTruong(user: nguoiDung());
      m.mayChu.loi('POST /api/v1/me/change-password', 'Mật khẩu hiện tại không đúng');
      await m.dung(t, const ChangePasswordScreen());
      final o = find.byType(TextFormField);
      await t.enterText(o.at(0), 'sai');
      await t.enterText(o.at(1), 'moi12345');
      await t.enterText(o.at(2), 'moi12345');
      await bam(t, find.widgetWithText(FilledButton, 'Đổi mật khẩu'));
      expect(find.text('Mật khẩu hiện tại không đúng'), findsOneWidget);
    });
  });

  group('Bài viết, hỗ trợ, góp ý', () {
    testWidgets('danh sách và chi tiết bài viết', (t) async {
      final m = MoiTruong(user: nguoiDung());
      m.mayChu.tra('GET /api/v1/blogs', trang([
        {
          'id': 'bv1',
          'title': 'Ý nghĩa lá The Fool',
          'slug': 'the-fool',
          'summary': 'Khởi đầu mới',
          'thumbnailUrl': '/blog/fool.jpg',
          'author': {'fullName': 'Lan'},
          'createdAt': iso(homNay),
        }
      ]));
      m.mayChu.tra('GET /api/v1/blogs/the-fool', {
        'id': 'bv1',
        'title': 'Ý nghĩa lá The Fool',
        'slug': 'the-fool',
        'content': 'Nội dung đầy đủ.',
        'author': {'username': 'lan'},
      });
      await m.dung(t, const BlogScreen());
      expect(find.text('Khởi đầu mới'), findsOneWidget);
      await bam(t, find.text('Ý nghĩa lá The Fool'));
      expect(find.text('Nội dung đầy đủ.'), findsOneWidget);
    });

    testWidgets('bài viết rỗng và lỗi', (t) async {
      final m = MoiTruong(user: nguoiDung());
      m.mayChu.tra('GET /api/v1/blogs', trang([]));
      await m.dung(t, const BlogScreen());
      final m2 = MoiTruong(user: nguoiDung());
      m2.mayChu.loi('GET /api/v1/blogs', 'Hỏng');
      await m2.dung(t, const BlogScreen());
      expect(find.text('Hỏng'), findsOneWidget);
    });

    testWidgets('hỗ trợ: gửi yêu cầu, mở phiếu, trả lời', (t) async {
      final m = MoiTruong(user: nguoiDung());
      m.mayChu.tra('GET /api/v1/support/tickets/mine', trang([
        {
          'id': 'tk1',
          'subject': 'Không thanh toán được',
          'status': 'PENDING',
          'messageCount': 2,
          'createdAt': iso(homNay),
        }
      ]));
      m.mayChu.tra('POST /api/v1/support/tickets', null);
      m.mayChu.tra('GET /api/v1/support/tickets/tk1', {
        'id': 'tk1',
        'status': 'PENDING',
        'messages': [
          {'id': 'x1', 'senderName': 'Tôi', 'fromStaff': false, 'body': 'Giúp em'},
          {'id': 'x2', 'senderName': 'Hỗ trợ', 'fromStaff': true, 'body': 'Bạn thử lại nhé'},
        ],
      });
      m.mayChu.tra('POST /api/v1/support/tickets/tk1/messages', null);
      await m.dung(t, const SupportScreen());
      // PENDING là chờ KHÁCH trả lời.
      expect(find.textContaining('Chờ bạn phản hồi'), findsOneWidget);
      await bam(t, find.text('Gửi yêu cầu'));
      final o = find.byType(TextField);
      await t.enterText(o.at(0), 'Lỗi đăng nhập');
      await t.enterText(o.at(1), 'Không vào được');
      await bam(t, find.text('Gửi'));
      expect(m.mayChu.lanCuoi('POST /api/v1/support/tickets')!.than,
          {'subject': 'Lỗi đăng nhập', 'body': 'Không vào được'});
      await bam(t, find.text('Không thanh toán được'));
      expect(find.text('Bạn thử lại nhé'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'Vẫn lỗi');
      await bam(t, find.byIcon(Icons.send));
      expect(m.mayChu.lanCuoi('POST /api/v1/support/tickets/tk1/messages')!.than,
          {'body': 'Vẫn lỗi'});
    });

    testWidgets('hỗ trợ: phiếu đã đóng, trả lời lỗi, danh sách lỗi', (t) async {
      final m = MoiTruong(user: nguoiDung());
      m.mayChu.tra('GET /api/v1/support/tickets/mine', trang([
        {'id': 'tk2', 'subject': 'Cũ', 'status': 'CLOSED'},
        {'id': 'tk3', 'subject': 'Mở', 'status': 'OPEN'},
      ]));
      m.mayChu.tra('GET /api/v1/support/tickets/tk2',
          {'id': 'tk2', 'status': 'CLOSED', 'messages': []});
      m.mayChu.tra('GET /api/v1/support/tickets/tk3',
          {'id': 'tk3', 'status': 'OPEN', 'messages': []});
      m.mayChu.loi('POST /api/v1/support/tickets/tk3/messages', 'Quá dài');
      await m.dung(t, const SupportScreen());
      await bam(t, find.text('Cũ'));
      expect(find.textContaining('Phiếu đã đóng'), findsOneWidget);
      expect(find.text('Phiếu này chưa có nội dung nào.'), findsOneWidget);
      await t.pageBack();
      await xong(t);
      await bam(t, find.text('Mở'));
      await t.enterText(find.byType(TextField), 'x');
      await bam(t, find.byIcon(Icons.send));
      expect(find.text('Quá dài'), findsOneWidget);
      final m2 = MoiTruong(user: nguoiDung());
      m2.mayChu.loi('GET /api/v1/support/tickets/mine', 'Hỏng');
      await m2.dung(t, const SupportScreen());
      expect(find.text('Hỏng'), findsOneWidget);
      final m3 = MoiTruong(user: nguoiDung());
      m3.mayChu.tra('GET /api/v1/support/tickets/mine', trang([]));
      m3.mayChu.loi('POST /api/v1/support/tickets', 'Thiếu tiêu đề');
      await m3.dung(t, const SupportScreen());
      await bam(t, find.text('Gửi yêu cầu'));
      await t.enterText(find.byType(TextField).at(0), 'a');
      await t.enterText(find.byType(TextField).at(1), 'b');
      await bam(t, find.text('Gửi'));
      expect(find.text('Thiếu tiêu đề'), findsOneWidget);
    });

    testWidgets('góp ý NPS', (t) async {
      final m = MoiTruong(user: nguoiDung());
      m.mayChu.tra('GET /api/v1/feedback/me/status', {'submitted': false});
      m.mayChu.tra('POST /api/v1/feedback', null);
      await m.dung(t, const FeedbackScreen(), quaDuong: true);
      await bam(t, find.text('Gửi phản hồi'));
      expect(find.text('Chọn điểm từ 0 đến 10 trước.'), findsOneWidget);
      await bam(t, find.byKey(const ValueKey('o-diem-9-false')));
      await bam(t, find.byKey(const ValueKey('o-diem-4-false')).last);
      await t.enterText(find.byType(TextField), 'Thêm nhiều Reader');
      await bam(t, find.text('Gửi phản hồi'));
      final g = m.mayChu.lanCuoi('POST /api/v1/feedback')!;
      expect(g.than['nps'], 9);
      expect(g.than['rating'], 4);
      expect(g.than['comment'], 'Thêm nhiều Reader');
    });

    testWidgets('góp ý đã gửi rồi; gửi lỗi', (t) async {
      final m = MoiTruong(user: nguoiDung());
      m.mayChu.tra('GET /api/v1/feedback/me/status', {'submitted': true});
      await m.dung(t, const FeedbackScreen());
      expect(find.textContaining('Bạn đã gửi phản hồi rồi'), findsOneWidget);
      final m2 = MoiTruong(user: nguoiDung());
      m2.mayChu.loi('GET /api/v1/feedback/me/status', 'x');
      m2.mayChu.loi('POST /api/v1/feedback', 'Bạn đã gửi rồi');
      await m2.dung(t, const FeedbackScreen());
      await bam(t, find.byKey(const ValueKey('o-diem-10-false')));
      await bam(t, find.text('Gửi phản hồi'));
      expect(find.text('Bạn đã gửi rồi'), findsOneWidget);
    });
  });
}
