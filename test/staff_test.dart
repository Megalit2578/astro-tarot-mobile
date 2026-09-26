import 'package:astrotarot_mobile/features/money/money_repository.dart';
import 'package:astrotarot_mobile/features/staff/staff_screen.dart';
import 'package:astrotarot_mobile/features/support/support_repository.dart';
import 'package:astrotarot_mobile/features/support/support_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/gia.dart';
import 'support/mau.dart';
import 'support/webrtc_gia.dart';

void khaiBanLamViec(MayChuGia m) {
  m.tra('GET /api/v1/bookings/reader', trang([
    mauBooking(id: 'k1', trangThai: 'PENDING'),
    mauBooking(id: 'k2', trangThai: 'CONFIRMED', traTien: 'PAID'),
    mauBooking(
        id: 'k3',
        trangThai: 'COMPLETED',
        traTien: 'PAID',
        chatMo: false,
        batDau: homNay.subtract(const Duration(days: 1)),
        ghiChu: 'Đã xem xong'),
  ]));
  for (final a in ['confirm', 'complete', 'cancel', 'note']) {
    m.tra('PATCH /api/v1/bookings/*/$a', mauBooking());
  }
  m.tra('GET /api/v1/support/queue', trang([
    {
      'id': 'q1',
      'subject': 'Khách cần hỗ trợ',
      'status': 'OPEN',
      'assignedToName': null,
      'createdAt': iso(homNay),
    },
    {'id': 'q2', 'subject': 'Đã nhận', 'status': 'PENDING', 'assignedToName': 'Lan'},
  ]));
  m.tra('GET /api/v1/support/tickets/q1', {
    'id': 'q1',
    'status': 'OPEN',
    'messages': [
      {'id': 'x', 'senderName': 'Khách', 'fromStaff': false, 'body': 'Giúp với'},
    ],
  });
  m.tra('PATCH /api/v1/support/tickets/q1/status', null);
  m.tra('POST /api/v1/support/tickets/q1/messages', null);
  m.tra('GET /api/v1/readers/profile/me', {
    'id': 'rp1',
    'bio': 'Reader lâu năm',
    'specialties': ['Tarot'],
    'yearsExperience': 4,
    'pricePer15m': 100000,
    'pricePer30m': null,
    'pricePer60m': null,
    'isAvailable': true,
  });
  m.tra('PATCH /api/v1/readers/profile', null);
  m.tra('GET /api/v1/availability', [
    {'id': 'av2', 'dayOfWeek': 3, 'startTime': '19:00:00', 'endTime': '21:00:00'},
    {'id': 'av1', 'dayOfWeek': 1, 'startTime': '09:00:00', 'endTime': '11:00:00'},
  ]);
  m.tra('POST /api/v1/availability', null);
  m.tra('DELETE /api/v1/availability/*', null);
  m.tra('GET /api/v1/unavailable-dates', [
    {'id': 'nd1', 'unavailableDate': '2026-12-24', 'reason': 'Nghỉ lễ'},
  ]);
  m.tra('POST /api/v1/unavailable-dates', null);
  m.tra('DELETE /api/v1/unavailable-dates/*', null);
  m.tra('GET /api/v1/me/escrow', {
    'balance': 600000,
    'pendingBalance': 180000,
    'totalEarned': 900000,
    'totalWithdrawn': 300000,
    'minimumPayout': 100000,
    'penaltyOwed': 50000,
  });
  m.tra('GET /api/v1/me/escrow/transactions', trang([
    {'id': 'e1', 'kind': 'RELEASE', 'amount': 144000, 'note': 'Buổi 20/9'},
    {'id': 'e2', 'kind': 'PENALTY', 'amount': 50000},
    {'id': 'e3', 'kind': 'HOLD', 'amount': 180000, 'createdAt': iso(homNay)},
  ]));
  m.tra('GET /api/v1/me/payouts', trang([
    {
      'id': 'po1',
      'amount': 300000,
      'status': 'REJECTED',
      'bankName': 'VCB',
      'bankAccountMasked': '****9876',
      'rejectReason': 'Sai tên chủ tài khoản',
      'requestedAt': iso(homNay),
    },
  ]));
  m.tra('POST /api/v1/me/payouts', null);
}

Future<void> moMuc(WidgetTester t, String nhan) async {
  await t.tap(find.descendant(
      of: find.byType(AppBar), matching: find.text(nhan)));
  await xong(t);
}

void main() {
  group('Bàn làm việc', () {
    testWidgets('Nhân viên thấy đủ bốn mục; lịch hẹn: nhận, xong, huỷ, ghi chú',
        (t) async {
      WebRtcGia(t).batDau();
      final m = MoiTruong(user: nguoiDung(vaiTro: 'STAFF'));
      khaiBanLamViec(m.mayChu);
      await m.dung(t, const StaffScreen());
      for (final n in ['Lịch hẹn', 'Hỗ trợ', 'Hồ sơ', 'Thu nhập']) {
        expect(find.descendant(of: find.byType(AppBar), matching: find.text(n)),
            findsOneWidget, reason: n);
      }
      expect(find.text('Khách chưa thanh toán'), findsOneWidget);
      await bam(t, find.text('Nhận lịch'));
      expect(m.mayChu.cacLan('PATCH /api/v1/bookings/k1/confirm'), hasLength(1));
      await bam(t, find.text('Đánh dấu hoàn tất'));
      expect(m.mayChu.cacLan('PATCH /api/v1/bookings/k2/complete'),
          hasLength(1));
      await bam(t, find.text('Huỷ lịch'));
      await t.enterText(find.byType(TextField).last, 'Bận đột xuất');
      await bam(t, find.text('Xong'));
      expect(m.mayChu.lanCuoi('PATCH /api/v1/bookings/*/cancel')!.than,
          {'reason': 'Bận đột xuất'});
      await bam(t, find.text('Sửa ghi chú'));
      await t.enterText(find.byType(TextField).last, 'Tóm tắt mới');
      await bam(t, find.text('Xong'));
      expect(m.mayChu.lanCuoi('PATCH /api/v1/bookings/k3/note')!.than,
          {'note': 'Tóm tắt mới'});
      m.mayChu.loi('PATCH /api/v1/bookings/*/confirm', 'Đã quá giờ');
      await bam(t, find.text('Nhận lịch'));
      expect(find.text('Đã quá giờ'), findsOneWidget);
      m.mayChu.tra('GET /api/v1/bookings/k1/messages', trang([]));
      await bam(t, find.text('Nhắn tin'));
      expect(find.text('Nhắn gì đó…'), findsOneWidget);
    });

    testWidgets('mở thẳng tới một tab bằng khoá, không phải bằng chỉ số',
        (t) async {
      // Thông báo phải mở được ĐÚNG tab. Chỉ số không dùng được: danh sách tab
      // dựng theo quyền, nên cùng một con số trỏ vào tab khác nhau tuỳ tài
      // khoản.
      final m = MoiTruong(user: nguoiDung(vaiTro: 'STAFF'));
      khaiBanLamViec(m.mayChu);
      await m.dung(t, const StaffScreen(tabDau: 'earnings'));
      expect(find.text('Rút được ngay'), findsOneWidget);

      // Reader không làm hỗ trợ: 'earnings' ở đây là mục thứ BA, không phải
      // thứ tư như tài khoản trên.
      final m2 = MoiTruong(
          user: nguoiDung(quyen: {
        'USER_BASIC',
        'READER_MANAGE_PROFILE',
        'PAYOUT_REQUEST',
      }));
      khaiBanLamViec(m2.mayChu);
      await m2.dung(t, const StaffScreen(tabDau: 'earnings'));
      expect(find.text('Rút được ngay'), findsOneWidget);
    });

    testWidgets('khoá trỏ tới tab bị ẩn vì thiếu quyền thì rơi về tab đầu',
        (t) async {
      // Một thông báo cũ còn nằm trong hộp sau khi quyền bị gỡ. Rơi về tab đầu
      // còn hơn để màn trắng, hoặc tệ hơn là đổ vì chỉ số -1.
      final m = MoiTruong(user: nguoiDung(quyen: {
        'USER_BASIC',
        'READER_MANAGE_PROFILE',
      }));
      khaiBanLamViec(m.mayChu);
      await m.dung(t, const StaffScreen(tabDau: 'earnings'));
      expect(find.text('Rút được ngay'), findsNothing);
      expect(find.text('Khách chưa thanh toán'), findsOneWidget);
    });

    testWidgets('không có quyền nào; chỉ một mục thì không có dải chọn',
        (t) async {
      final m = MoiTruong(user: nguoiDung(quyen: {'USER_BASIC'}));
      await m.dung(t, const StaffScreen());
      expect(find.textContaining('chưa có phần việc nào'), findsOneWidget);
      final m2 = MoiTruong(user: nguoiDung(quyen: {'SUPPORT_VIEW', 'STAFF_VIEW'}));
      khaiBanLamViec(m2.mayChu);
      await m2.dung(t, const StaffScreen());
      expect(find.text('Khách cần hỗ trợ'), findsOneWidget);
    });

    testWidgets('lịch hẹn Reader rỗng và lỗi', (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'STAFF'));
      khaiBanLamViec(m.mayChu);
      m.mayChu.tra('GET /api/v1/bookings/reader', trang([]));
      await m.dung(t, const StaffScreen());
      final m2 = MoiTruong(user: nguoiDung(vaiTro: 'STAFF'));
      khaiBanLamViec(m2.mayChu);
      m2.mayChu.loi('GET /api/v1/bookings/reader', 'Hỏng lịch');
      await m2.dung(t, const StaffScreen());
      expect(find.text('Hỏng lịch'), findsOneWidget);
    });

    testWidgets('hỗ trợ: đổi trạng thái phiếu và trả lời', (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'STAFF'));
      khaiBanLamViec(m.mayChu);
      await m.dung(t, const StaffScreen());
      await moMuc(t, 'Hỗ trợ');
      expect(find.textContaining('chưa ai nhận'), findsOneWidget);
      expect(find.textContaining('Chờ khách phản hồi'), findsOneWidget);
      await bam(t, find.text('Khách cần hỗ trợ'));
      await bam(t, find.byTooltip('Đổi trạng thái'));
      await bam(t, find.text('Đã giải quyết'));
      expect(m.mayChu.lanCuoi('PATCH /api/v1/support/tickets/q1/status')!.than,
          {'status': 'RESOLVED'});
      m.mayChu.loi('PATCH /api/v1/support/tickets/q1/status', 'Không được');
      await bam(t, find.byTooltip('Đổi trạng thái'));
      await bam(t, find.text('Đã đóng'));
      expect(find.text('Không được'), findsOneWidget);
    });

    testWidgets('quản lý chỉ giám sát phiếu, không trả lời', (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'MANAGER'));
      khaiBanLamViec(m.mayChu);
      await m.dung(
          t,
          TicketDetailScreen(
              ticket: Ticket.fromJson(const {'id': 'q1', 'subject': 'S'}),
              nhanVien: true));
      expect(find.textContaining('chế độ giám sát'), findsOneWidget);
      expect(find.byTooltip('Đổi trạng thái'), findsNothing);
    });

    testWidgets('hàng chờ hỗ trợ rỗng và lỗi', (t) async {
      final m = MoiTruong(user: nguoiDung(quyen: {'SUPPORT_VIEW'}));
      m.mayChu.tra('GET /api/v1/support/queue', trang([]));
      await m.dung(t, const StaffScreen());
      expect(find.text('Hàng chờ trống'), findsOneWidget);
      final m2 = MoiTruong(user: nguoiDung(quyen: {'SUPPORT_VIEW'}));
      m2.mayChu.loi('GET /api/v1/support/queue', 'Hỏng');
      await m2.dung(t, const StaffScreen());
      expect(find.text('Hỏng'), findsOneWidget);
    });

    testWidgets('hồ sơ Reader: lưu không gửi `available`, thêm/xoá khung giờ',
        (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'STAFF'));
      khaiBanLamViec(m.mayChu);
      await m.dung(t, const StaffScreen());
      await moMuc(t, 'Hồ sơ');
      expect(find.text('Reader lâu năm'), findsOneWidget);
      expect(find.text('Đang nhận lịch'), findsNothing);
      await t.enterText(find.widgetWithText(TextField, 'Tarot'), 'Tarot, Bài Oracle');
      await bam(t, find.text('Lưu hồ sơ'));
      final g = m.mayChu.lanCuoi('PATCH /api/v1/readers/profile')!;
      expect(g.than.containsKey('available'), isFalse);
      expect(g.than['specialties'], ['Tarot', 'Bài Oracle']);

      // Khung giờ sắp theo thứ.
      await cuonToi(t, find.text('Thêm khung giờ'));
      final y1 = t.getTopLeft(find.textContaining('Thứ Hai')).dy;
      final y3 = t.getTopLeft(find.textContaining('Thứ Tư')).dy;
      expect(y1, lessThan(y3));

      await bam(t, find.text('Thêm khung giờ'));
      await bam(t, find.text('T6'));
      await bam(t, find.text('Thêm'));
      final k = m.mayChu.lanCuoi('POST /api/v1/availability')!;
      expect(k.than['dayOfWeek'], 5);
      expect(k.than['startTime'], matches(RegExp(r'^\d\d:\d\d:00$')));

      await bam(t, find.byTooltip('Xoá khung này'));
      expect(m.mayChu.cacLan('DELETE /api/v1/availability/*'), hasLength(1));
    });

    testWidgets('ngày nghỉ: thêm kèm lý do, bỏ', (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'STAFF'));
      khaiBanLamViec(m.mayChu);
      await m.dung(t, const StaffScreen());
      await moMuc(t, 'Hồ sơ');
      await cuonToi(t, find.text('24/12/2026'));
      expect(find.text('Nghỉ lễ'), findsOneWidget);
      await bam(t, find.text('Thêm ngày nghỉ'));
      await bam(t, find.text('OK'));
      await t.enterText(find.byType(TextField).last, 'Đi xa');
      await bam(t, find.text('Thêm'));
      final g = m.mayChu.lanCuoi('POST /api/v1/unavailable-dates')!;
      expect(g.than['reason'], 'Đi xa');
      expect(g.than['unavailableDate'], matches(RegExp(r'^\d{4}-\d\d-\d\d$')));
      await bam(t, find.byTooltip('Bỏ ngày nghỉ 2026-12-24'));
      expect(m.mayChu.cacLan('DELETE /api/v1/unavailable-dates/nd1'),
          hasLength(1));
      m.mayChu.loi('DELETE /api/v1/unavailable-dates/*', 'Không bỏ được');
      await bam(t, find.byTooltip('Bỏ ngày nghỉ 2026-12-24'));
      expect(find.text('Không bỏ được'), findsOneWidget);
    });

    testWidgets('hồ sơ Reader chưa có (404) và lỗi', (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'STAFF'));
      khaiBanLamViec(m.mayChu);
      m.mayChu.loi('GET /api/v1/readers/profile/me', 'Không có', ma: 404);
      m.mayChu.loi('GET /api/v1/unavailable-dates', 'Hỏng');
      await m.dung(t, const StaffScreen());
      await moMuc(t, 'Hồ sơ');
      expect(find.byType(StaffScreen), findsOneWidget);
      final m2 = MoiTruong(user: nguoiDung(vaiTro: 'STAFF'));
      khaiBanLamViec(m2.mayChu);
      m2.mayChu.loi('GET /api/v1/readers/profile/me', 'Hỏng hồ sơ', ma: 500);
      m2.mayChu.loi('PATCH /api/v1/readers/profile', 'x');
      await m2.dung(t, const StaffScreen());
      await moMuc(t, 'Hồ sơ');
      expect(find.text('Hỏng hồ sơ'), findsOneWidget);
    });

    testWidgets('thu nhập: sổ ký quỹ đúng hướng tiền, lịch sử rút đủ thông tin',
        (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'STAFF'));
      khaiBanLamViec(m.mayChu);
      await m.dung(t, const StaffScreen());
      await moMuc(t, 'Thu nhập');
      expect(find.text('+144.000 đ'), findsOneWidget);
      // Bản cũ hiện "+" xanh cho cả tiền phạt.
      expect(find.text('−50.000 đ'), findsOneWidget);
      expect(find.text('180.000 đ'), findsWidgets);
      expect(find.text('Trừ do vi phạm'), findsOneWidget);
      await cuonToi(t, find.textContaining('****9876'));
      expect(find.textContaining('****9876'), findsOneWidget);
      expect(find.text('Lý do: Sai tên chủ tài khoản'), findsOneWidget);
    });

    testWidgets('yêu cầu rút tiền: kiểm số tiền rồi gửi', (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'STAFF'));
      khaiBanLamViec(m.mayChu);
      await m.dung(t, const StaffScreen());
      await moMuc(t, 'Thu nhập');
      await bam(t, find.text('Yêu cầu rút tiền'));
      final o = find.byType(TextFormField);
      await t.enterText(o.at(0), '900000');
      await bam(t, find.text('Gửi yêu cầu'));
      expect(find.text('Vượt quá số dư rút được'), findsOneWidget);
      await t.enterText(o.at(0), '50000');
      await bam(t, find.text('Gửi yêu cầu'));
      expect(find.textContaining('Tối thiểu'), findsOneWidget);
      await t.enterText(o.at(0), '0');
      await bam(t, find.text('Gửi yêu cầu'));
      expect(find.text('Số tiền phải lớn hơn 0'), findsOneWidget);
      await t.enterText(o.at(0), '500000');
      await t.enterText(o.at(1), 'Vietcombank');
      await t.enterText(o.at(2), '0123456789');
      await t.enterText(o.at(3), 'NGUYEN LAN');
      m.mayChu.loi('POST /api/v1/me/payouts', 'Đang có yêu cầu chờ duyệt');
      await bam(t, find.text('Gửi yêu cầu'));
      expect(find.text('Đang có yêu cầu chờ duyệt'), findsOneWidget);
      m.mayChu.tra('POST /api/v1/me/payouts', null);
      await bam(t, find.text('Gửi yêu cầu'));
      expect(m.mayChu.lanCuoi('POST /api/v1/me/payouts')!.than['amount'],
          500000);
    });

    testWidgets('thu nhập lỗi; chưa đủ điều kiện rút', (t) async {
      final m = MoiTruong(user: nguoiDung(quyen: {'PAYOUT_REQUEST'}));
      m.mayChu.loi('GET /api/v1/me/escrow', 'Hỏng ví');
      m.mayChu.tra('GET /api/v1/me/escrow/transactions', trang([]));
      m.mayChu.tra('GET /api/v1/me/payouts', trang([]));
      await m.dung(t, const StaffScreen());
      expect(find.text('Hỏng ví'), findsOneWidget);
      final m2 = MoiTruong(user: nguoiDung(quyen: {'PAYOUT_REQUEST'}));
      m2.mayChu.tra('GET /api/v1/me/escrow',
          {'balance': 1000, 'minimumPayout': 100000});
      m2.mayChu.tra('GET /api/v1/me/escrow/transactions', trang([]));
      m2.mayChu.tra('GET /api/v1/me/payouts', trang([]));
      await m2.dung(t, const StaffScreen());
      expect(find.text('Chưa có giao dịch nào.'), findsOneWidget);
    });

    test('nhãn tiền và hướng tiền', () {
      expect(huongTien('RELEASE'), 1);
      expect(huongTien('PAYOUT_RESERVE'), -1);
      expect(huongTien('HOLD'), 0);
      expect(nhanLoaiGiaoDich('PAYOUT_SETTLE'), 'Đã chuyển khoản');
      expect(nhanLoaiGiaoDich('LA'), 'LA');
      expect(nhanTrangThaiRut('PAID'), 'Đã chi');
      expect(nhanTrangThaiRut('X'), 'X');
      expect(nhanTrangThaiTicket('RESOLVED'), 'Đã giải quyết');
      expect(nhanTrangThaiTicket('X'), 'X');
    });
  });
}
