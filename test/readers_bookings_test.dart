import 'package:astrotarot_mobile/features/bookings/booking.dart';
import 'package:astrotarot_mobile/features/bookings/bookings_screen.dart';
import 'package:astrotarot_mobile/features/bookings/call_controller.dart';
import 'package:astrotarot_mobile/features/bookings/call_panel.dart';
import 'package:astrotarot_mobile/features/bookings/chat_screen.dart';
import 'package:astrotarot_mobile/features/readers/reader_detail_screen.dart';
import 'package:astrotarot_mobile/features/readers/reader_reviews.dart';
import 'package:astrotarot_mobile/features/readers/readers_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/gia.dart';
import 'support/mau.dart';
import 'support/webrtc_gia.dart';

void khaiReader(MayChuGia m, {int soDanhGia = 12}) {
  m.tra('GET /api/v1/readers', [
    mauReader(),
    mauReader(id: 'r2', ten: 'Minh Tâm', nhanLich: false, soDanhGia: 0),
  ]);
  m.tra('GET /api/v1/readers/r1', mauReader(soDanhGia: soDanhGia));
  m.tra(
    'GET /api/v1/readers/r1/calendar',
    mauLich(
      oHomNay: [
        mauSlot(homNay.add(const Duration(hours: 3))),
        mauSlot(homNay.add(const Duration(hours: 4))),
        mauSlot(homNay.subtract(const Duration(hours: 2)), trang: 'PAST'),
      ],
    ),
  );
  m.tra(
    'GET /api/v1/readers/r1/slots/next-available',
    homNay.add(const Duration(days: 3)).toIso8601String().substring(0, 10),
  );
  m.tra(
    'GET /api/v1/readers/r1/reviews',
    trang([
      for (var i = 0; i < 3; i++)
        {
          'id': 'rv$i',
          'authorName': 'Khách $i',
          'rating': 5 - i,
          'comment': i == 0 ? 'Rất hay' : null,
          'createdAt': iso(homNay),
        },
    ], tong: soDanhGia),
  );
}

void main() {
  group('Tìm Reader', () {
    testWidgets('danh sách, tìm theo từ khoá, mở hồ sơ', (t) async {
      final m = MoiTruong(user: nguoiDung());
      khaiReader(m.mayChu);
      await m.dung(t, const ReadersScreen());
      expect(find.text('Lan Hương'), findsOneWidget);
      expect(find.text('Minh Tâm'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'chiêm tinh');
      await xong(t);
      await t.enterText(find.byType(TextField), 'không-ai');
      await xong(t);
      expect(find.text('Không có Reader nào khớp'), findsOneWidget);
      await t.enterText(find.byType(TextField), '');
      await xong(t);
      await bam(t, find.text('Lan Hương'));
      expect(find.byType(ReaderDetailScreen), findsOneWidget);
    });

    testWidgets('rỗng và lỗi', (t) async {
      final m = MoiTruong();
      m.mayChu.tra('GET /api/v1/readers', []);
      await m.dung(t, const ReadersScreen());
      expect(find.text('Chưa có Reader nào'), findsOneWidget);
      final m2 = MoiTruong();
      m2.mayChu.loi('GET /api/v1/readers', 'Máy chủ bận', ma: 503);
      await m2.dung(t, const ReadersScreen());
      expect(find.text('Máy chủ bận'), findsOneWidget);
      m2.mayChu.tra('GET /api/v1/readers', [mauReader()]);
      await bam(t, find.text('Thử lại'));
      expect(find.text('Lan Hương'), findsOneWidget);
    });
  });

  group('Hồ sơ Reader và đặt lịch', () {
    testWidgets('chọn thời lượng, ngày, giờ rồi đặt', (t) async {
      final m = MoiTruong(user: nguoiDung());
      khaiReader(m.mayChu);
      m.mayChu.tra('POST /api/v1/bookings', mauBooking(trangThai: 'PENDING'));
      m.mayChu.tra('GET /api/v1/bookings/me', trang([]));
      await m.dung(t, const ReaderDetailScreen(readerId: 'r1'), quaDuong: true);
      expect(find.text('Đọc bài theo hướng chữa lành.'), findsOneWidget);
      expect(find.text('Chiêm tinh'), findsOneWidget);
      await bam(t, find.textContaining('15 phút'));
      expect(
        m.mayChu.lanCuoi('GET /api/v1/readers/r1/calendar')!.query['duration'],
        '15',
      );
      await bam(t, find.textContaining('30 phút'));
      // Ngày trống gần nhất → nhảy tới ngày đó.
      await bam(t, find.textContaining('Ngày trống gần nhất'));
      await bam(t, find.text('Nay'));
      // Đánh giá.
      expect(find.text('Rất hay'), findsOneWidget);
      expect(find.text('Xem tất cả 12 đánh giá'), findsOneWidget);
      // Chọn giờ rồi đặt.
      final gio = find
          .textContaining(':')
          .evaluate()
          .map((e) => (e.widget as Text).data)
          .toList();
      expect(gio, isNotEmpty);
      await t.scrollUntilVisible(
        find.byType(InkWell).last,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      final oGio = find.byWidgetPredicate(
        (w) => w is Text && RegExp(r'^\d\d:\d\d$').hasMatch(w.data ?? ''),
      );
      await bam(t, oGio.first);
      await bam(t, find.widgetWithText(FilledButton, 'Đặt lịch'));
      expect(
        m.mayChu.lanCuoi('POST /api/v1/bookings')!.than['durationMinutes'],
        30,
      );
      expect(find.text('Đã đặt lịch'), findsOneWidget);
      await bam(t, find.text('Đã hiểu'));
      expect(find.text('MỞ MÀN'), findsOneWidget);
    });

    testWidgets('đặt lỗi hiện câu máy chủ', (t) async {
      final m = MoiTruong(user: nguoiDung());
      khaiReader(m.mayChu);
      m.mayChu.loi('POST /api/v1/bookings', 'Khung giờ vừa có người đặt');
      await m.dung(t, const ReaderDetailScreen(readerId: 'r1'));
      final oGio = find.byWidgetPredicate(
        (w) => w is Text && RegExp(r'^\d\d:\d\d$').hasMatch(w.data ?? ''),
      );
      await bam(t, oGio.first);
      await bam(t, find.widgetWithText(FilledButton, 'Đặt lịch'));
      expect(find.text('Khung giờ vừa có người đặt'), findsOneWidget);
    });

    testWidgets('khách chưa đăng nhập thì được mời đăng nhập', (t) async {
      final m = MoiTruong();
      khaiReader(m.mayChu);
      await m.dung(t, const ReaderDetailScreen(readerId: 'r1'));
      final oGio = find.byWidgetPredicate(
        (w) => w is Text && RegExp(r'^\d\d:\d\d$').hasMatch(w.data ?? ''),
      );
      await bam(t, oGio.first);
      expect(find.text('Quay lại đăng nhập'), findsOneWidget);
    });

    testWidgets('khung giờ lỗi rồi thử lại; không còn giờ trống', (t) async {
      final m = MoiTruong(user: nguoiDung());
      khaiReader(m.mayChu);
      m.mayChu.loi('GET /api/v1/readers/r1/calendar', 'Không tải được giờ');
      await m.dung(t, const ReaderDetailScreen(readerId: 'r1'));
      expect(find.text('Không tải được giờ'), findsOneWidget);
      m.mayChu.tra('GET /api/v1/readers/r1/calendar', mauLich());
      await bam(t, find.text('Thử lại'));
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && RegExp(r'^\d\d:\d\d$').hasMatch(w.data ?? ''),
        ),
        findsNothing,
      );
    });

    testWidgets('hồ sơ lỗi; Reader tạm ngưng; chưa có đánh giá', (t) async {
      final m = MoiTruong(user: nguoiDung());
      m.mayChu.loi('GET /api/v1/readers/r1', 'Không thấy Reader', ma: 404);
      await m.dung(t, const ReaderDetailScreen(readerId: 'r1'));
      expect(find.text('Không thấy Reader'), findsOneWidget);
      khaiReader(m.mayChu, soDanhGia: 0);
      m.mayChu.tra(
        'GET /api/v1/readers/r1',
        mauReader(nhanLich: false, soDanhGia: 0),
      );
      m.mayChu.tra('GET /api/v1/readers/r1/reviews', trang([]));
      await bam(t, find.text('Thử lại'));
      expect(find.text('Reader này đang tạm ngưng nhận lịch.'), findsOneWidget);
      await t.scrollUntilVisible(
        find.text('Chưa có đánh giá nào.'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Chưa có đánh giá nào.'), findsOneWidget);
    });

    testWidgets('màn tất cả đánh giá', (t) async {
      final m = MoiTruong();
      khaiReader(m.mayChu);
      await m.dung(t, const DanhGiaReaderScreen(readerId: 'r1', ten: 'Lan'));
      expect(find.text('Đánh giá · Lan'), findsOneWidget);
      expect(find.text('Khách 2'), findsOneWidget);
    });
  });

  group('Lịch hẹn của tôi', () {
    testWidgets('thanh toán chuyển khoản hiện số tài khoản và chép được', (
      t,
    ) async {
      final m = MoiTruong(user: nguoiDung());
      m.mayChu.tra('GET /api/v1/bookings/me', trang([mauBooking()]));
      m.mayChu.tra('POST /api/v1/bookings/b1/payment', {
        'amount': 180000,
        'paymentMethod': 'BANK_TRANSFER',
        'referenceCode': 'AT9',
        'transferContent': 'AT9',
        'bankName': 'VCB',
        'bankAccountNumber': '0123456789',
        'bankAccountHolder': 'CONG TY',
      });
      await m.dung(t, const BookingsScreen());
      expect(find.text('Lan Hương'), findsOneWidget);
      await bam(t, find.text('Thanh toán'));
      expect(find.text('Chuyển khoản'), findsOneWidget);
      expect(find.text('0123456789'), findsOneWidget);
      await bam(t, find.byTooltip('Chép Số tài khoản'));
      expect(m.clipboard, '0123456789');
      await bam(t, find.text('Tôi đã chuyển khoản'));
      expect(find.text('Chuyển khoản'), findsNothing);
    });

    testWidgets('thanh toán PayOS mở trình duyệt', (t) async {
      final m = MoiTruong(user: nguoiDung());
      m.mayChu.tra('GET /api/v1/bookings/me', trang([mauBooking()]));
      m.mayChu.tra('POST /api/v1/bookings/b1/payment', {
        'amount': 180000,
        'paymentMethod': 'PAYOS',
        'referenceCode': '123',
        'checkoutUrl': 'https://pay.payos.vn/x',
        'bankAccountNumber': 'Chưa cấu hình',
      });
      await m.dung(t, const BookingsScreen());
      await bam(t, find.text('Thanh toán'));
      expect(find.text('Thanh toán PayOS'), findsOneWidget);
      await bam(t, find.text('Thanh toán với PayOS'));
      expect(m.launcher.daMo, ['https://pay.payos.vn/x']);
    });

    testWidgets('thanh toán: chưa cấu hình tài khoản, và lỗi máy chủ', (
      t,
    ) async {
      final m = MoiTruong(user: nguoiDung());
      m.mayChu.tra('GET /api/v1/bookings/me', trang([mauBooking()]));
      m.mayChu.tra('POST /api/v1/bookings/b1/payment', {
        'amount': 1,
        'referenceCode': 'R',
        'bankAccountNumber': 'Chưa cấu hình',
      });
      await m.dung(t, const BookingsScreen());
      await bam(t, find.text('Thanh toán'));
      expect(
        find.textContaining('chưa cấu hình tài khoản nhận tiền'),
        findsOneWidget,
      );
      await bam(t, find.text('Tôi đã chuyển khoản'));
      m.mayChu.loi(
        'POST /api/v1/bookings/b1/payment',
        'Lịch hẹn này đã thanh toán rồi',
      );
      await bam(t, find.text('Thanh toán'));
      expect(find.text('Lịch hẹn này đã thanh toán rồi'), findsOneWidget);
    });

    testWidgets('buổi đã xong: đánh giá và báo cáo', (t) async {
      final m = MoiTruong(user: nguoiDung());
      m.mayChu.tra(
        'GET /api/v1/bookings/me',
        trang([
          mauBooking(trangThai: 'COMPLETED', traTien: 'PAID', chatMo: false),
          mauBooking(
            id: 'b2',
            trangThai: 'COMPLETED',
            traTien: 'PAID',
            daDanhGia: true,
            chatMo: false,
          ),
        ]),
      );
      m.mayChu.tra('POST /api/v1/bookings/b1/review', null);
      m.mayChu.tra('POST /api/v1/reports', null);
      await m.dung(t, const BookingsScreen());
      expect(find.text('Bạn đã đánh giá buổi này'), findsOneWidget);

      await bam(t, find.text('Đánh giá'));
      await bam(t, find.byIcon(Icons.star_border).last);
      await t.enterText(find.byType(TextField).last, 'Tuyệt');
      await bam(t, find.text('Gửi đánh giá'));
      expect(m.mayChu.lanCuoi('POST /api/v1/bookings/b1/review')!.than, {
        'rating': 5,
        'comment': 'Tuyệt',
      });

      await bam(t, find.text('Báo cáo').first);
      expect(find.textContaining('không biết ai đã báo'), findsOneWidget);
      await bam(t, find.byKey(const ValueKey('loai-SCAM')));
      await t.enterText(find.byType(TextField).last, 'Đòi chuyển khoản riêng');
      await bam(t, find.text('Gửi báo cáo'));
      expect(m.mayChu.lanCuoi('POST /api/v1/reports')!.than, {
        'reportedUserId': 'u-r1',
        'reportType': 'SCAM',
        'description': 'Đòi chuyển khoản riêng',
        'bookingId': 'b1',
      });
    });

    testWidgets('gửi báo cáo lỗi', (t) async {
      final m = MoiTruong(user: nguoiDung());
      m.mayChu.tra(
        'GET /api/v1/bookings/me',
        trang([
          mauBooking(trangThai: 'COMPLETED', traTien: 'PAID', daDanhGia: true),
        ]),
      );
      m.mayChu.loi('POST /api/v1/reports', 'Bạn đã báo cáo buổi này');
      await m.dung(t, const BookingsScreen());
      await bam(t, find.text('Báo cáo'));
      await bam(t, find.text('Gửi báo cáo'));
      expect(find.text('Bạn đã báo cáo buổi này'), findsOneWidget);
    });

    testWidgets('lọc theo trạng thái; khách huỷ buổi chưa diễn ra', (t) async {
      final m = MoiTruong(user: nguoiDung());

      // BỘ LỌC ĐI XUỐNG MÁY CHỦ, không lọc trong trang đã tải.
      //
      // Máy chủ giả ở đây trả lời theo đúng tham số `status` — nếu màn hình
      // quên gửi nó và lọc ở máy khách, phép kiểm này đỏ ngay. Đó là điểm
      // chính: lọc ở máy khách chỉ lọc được trong hai mươi buổi gần nhất, nên
      // người có nhiều lịch hẹn sẽ thấy ít hơn thật mà không có dấu hiệu gì.
      m.mayChu.xuLy('GET /api/v1/bookings/me', (g) {
        final loc = g.query['status'];
        final tatCa = [
          mauBooking(),
          mauBooking(
            id: 'b2',
            trangThai: 'COMPLETED',
            traTien: 'PAID',
            chatMo: false,
          ),
        ];
        final hop = loc == null
            ? tatCa
            : [
                for (final b in tatCa)
                  if (b['status'] == loc) b,
              ];
        return TraLoi(200, {
          'success': true,
          'message': 'OK',
          'data': trang(hop),
        });
      });
      m.mayChu.tra(
        'PATCH /api/v1/bookings/b1/cancel',
        mauBooking(trangThai: 'CANCELLED'),
      );
      await m.dung(t, const BookingsScreen());
      // Buổi đã xong thì không còn nút huỷ.
      expect(find.text('Huỷ lịch'), findsOneWidget);

      await bam(t, find.text('Hoàn tất'));
      expect(
        m.mayChu.lanCuoi('GET /api/v1/bookings/me')!.query['status'],
        'COMPLETED',
      );
      expect(find.text('Huỷ lịch'), findsNothing);
      expect(find.text('Đánh giá'), findsOneWidget);

      await bam(t, find.text('Đã huỷ'));
      expect(find.text('Không có buổi nào "Đã huỷ"'), findsOneWidget);

      await bam(t, find.text('Tất cả'));
      // "Tất cả" phải BỎcK HẴN tham số lọc, không gửi chuỗi rỗng:
      // backend ném 400 cho một trạng thái rỗng.
      expect(
        m.mayChu.lanCuoi('GET /api/v1/bookings/me')!.query['status'],
        isNull,
      );

      // Bấm Thoát thì giữ lịch, không gọi máy chủ.
      await bam(t, find.text('Huỷ lịch'));
      await bam(t, find.text('Thoát'));
      expect(m.mayChu.lanCuoi('PATCH /api/v1/bookings/b1/cancel'), isNull);

      await bam(t, find.text('Huỷ lịch'));
      await t.enterText(find.byType(TextField).last, '  Bận đột xuất ');
      await bam(t, find.text('Xác nhận huỷ'));
      expect(m.mayChu.lanCuoi('PATCH /api/v1/bookings/b1/cancel')!.than, {
        'reason': 'Bận đột xuất',
      });
      expect(find.text('Đã huỷ lịch hẹn'), findsOneWidget);
    });

    testWidgets('huỷ không ghi lý do; máy chủ từ chối', (t) async {
      final m = MoiTruong(user: nguoiDung());
      m.mayChu.tra(
        'GET /api/v1/bookings/me',
        trang([mauBooking(trangThai: 'PENDING')]),
      );
      m.mayChu.loi('PATCH /api/v1/bookings/b1/cancel', 'Quá hạn huỷ');
      await m.dung(t, const BookingsScreen());
      await bam(t, find.text('Huỷ lịch'));
      await bam(t, find.text('Xác nhận huỷ'));
      expect(m.mayChu.lanCuoi('PATCH /api/v1/bookings/b1/cancel')!.than, {
        'reason': null,
      });
      expect(find.text('Quá hạn huỷ'), findsOneWidget);
    });

    testWidgets('rỗng và lỗi', (t) async {
      final m = MoiTruong(user: nguoiDung());
      m.mayChu.tra('GET /api/v1/bookings/me', trang([]));
      await m.dung(t, const BookingsScreen());
      expect(find.text('Chưa có lịch hẹn nào'), findsOneWidget);
      final m2 = MoiTruong(user: nguoiDung());
      m2.mayChu.loi('GET /api/v1/bookings/me', 'Hỏng');
      await m2.dung(t, const BookingsScreen());
      expect(find.text('Hỏng'), findsOneWidget);
    });

    test('nhãn trạng thái buổi', () {
      expect(nhanTrangThai(TrangThaiBuoi.pending), 'Chờ Reader nhận');
      expect(nhanTrangThai(TrangThaiBuoi.khac), '—');
      expect(trangThaiTu('LẠ'), TrangThaiBuoi.khac);
      expect(trangThaiTraTu('REFUNDED'), TrangThaiTra.refunded);
      expect(trangThaiTraTu(null), TrangThaiTra.khac);
    });
  });

  group('Trò chuyện và cuộc gọi', () {
    Future<(MoiTruong, WebRtcGia)> moChat(
      WidgetTester t, {
      bool coTin = true,
    }) async {
      final w = WebRtcGia(t)..batDau();
      final m = MoiTruong(user: nguoiDung());
      m.mayChu.tra(
        'GET /api/v1/bookings/b1/messages',
        trang([
          if (coTin) ...[
            {
              'id': 'm2',
              'bookingId': 'b1',
              'senderId': 'u-r1',
              'senderName': 'Lan',
              'body': 'Chào bạn',
              'createdAt': iso(homNay),
            },
            {
              'id': 'm1',
              'bookingId': 'b1',
              'senderId': 'u-USER',
              'senderName': 'Minh Anh',
              'body': 'Em chào chị',
              'createdAt': iso(homNay.subtract(const Duration(minutes: 1))),
            },
          ],
        ]),
      );
      m.mayChu.tra('POST /api/v1/bookings/b1/messages/read', null);
      m.mayChu.tra('POST /api/v1/bookings/b1/messages', null);
      m.mayChu.tra('GET /api/v1/rtc/ice', {
        'iceServers': [
          {
            'urls': ['stun:x'],
          },
        ],
        'hasTurn': false,
      });
      await m.dung(t, ChatScreen(booking: Booking.fromJson(mauBooking())));
      return (m, w);
    }

    testWidgets('tải tin, nhận tin realtime, gửi qua socket và REST', (
      t,
    ) async {
      final (m, _) = await moChat(t);
      expect(find.text('Chào bạn'), findsOneWidget);
      expect(find.text('Em chào chị'), findsOneWidget);
      expect(
        m.mayChu.cacLan('POST /api/v1/bookings/b1/messages/read'),
        hasLength(1),
      );

      m.realtime.phat('/user/queue/booking-chat', {
        'id': 'm3',
        'bookingId': 'b1',
        'senderId': 'u-r1',
        'body': 'Hẹn mai nhé',
        'createdAt': iso(homNay),
      });
      // Tin của buổi khác không được lẫn vào.
      m.realtime.phat('/user/queue/booking-chat', {
        'id': 'm4',
        'bookingId': 'khac',
        'body': 'Tin lạc',
      });
      // Tin trùng id (dội về từ thiết bị khác) chỉ hiện một lần.
      m.realtime.phat('/user/queue/booking-chat', {
        'id': 'm3',
        'bookingId': 'b1',
        'body': 'Hẹn mai nhé',
      });
      await xong(t);
      expect(find.text('Hẹn mai nhé'), findsOneWidget);
      expect(find.text('Tin lạc'), findsNothing);

      await t.enterText(find.byType(TextField), 'Dạ vâng');
      await bam(t, find.byIcon(Icons.send));
      expect(m.realtime.daGui.last.$1, '/app/bookings/b1/chat');
      expect(m.realtime.daGui.last.$2, {'body': 'Dạ vâng'});

      // Socket đứt → lùi về REST.
      m.realtime.guiDuoc = false;
      await t.enterText(find.byType(TextField), 'Qua REST');
      await bam(t, find.byIcon(Icons.send));
      expect(m.mayChu.lanCuoi('POST /api/v1/bookings/b1/messages')!.than, {
        'body': 'Qua REST',
      });
    });

    testWidgets('tải tin lỗi thì có thử lại; rỗng thì mời chào', (t) async {
      final w = WebRtcGia(t)..batDau();
      final m = MoiTruong(user: nguoiDung());
      m.mayChu.loi(
        'GET /api/v1/bookings/b1/messages',
        'Hội thoại đã đóng',
        ma: 403,
      );
      m.mayChu.loi('GET /api/v1/rtc/ice', 'x');
      await m.dung(t, ChatScreen(booking: Booking.fromJson(mauBooking())));
      expect(find.text('Hội thoại đã đóng'), findsOneWidget);
      m.mayChu.tra('GET /api/v1/bookings/b1/messages', trang([]));
      await bam(t, find.text('Thử lại'));
      expect(find.text('Hội thoại đã đóng'), findsNothing);
      expect(w.goi, contains('createVideoRenderer'));
    });

    testWidgets('gọi thoại: đổ chuông, được trả lời, nối, cúp máy', (t) async {
      final (m, w) = await moChat(t);
      await bam(t, find.byIcon(Icons.call).first);
      expect(
        w.goi,
        containsAll([
          'getUserMedia',
          'createPeerConnection',
          'createOffer',
          'setLocalDescription',
        ]),
      );
      final offer = m.realtime.daGui.firstWhere((g) => g.$2['type'] == 'OFFER');
      expect(offer.$1, '/app/bookings/b1/call');
      expect(offer.$2['video'], isFalse);

      // ICE tới trước ANSWER → giữ lại, xả sau khi có remote description.
      m.realtime.phat('/user/queue/booking-call', {
        'bookingId': 'b1',
        'type': 'ICE',
        'payload': '{"candidate":"c","sdpMid":"0","sdpMLineIndex":0}',
      });
      m.realtime.phat('/user/queue/booking-call', {
        'bookingId': 'b1',
        'type': 'ANSWER',
        'payload': '{"sdp":"v=0","type":"answer"}',
      });
      await xong(t);
      expect(w.goi, contains('addCandidate'));
      await w.phatSuKien({
        'event': 'peerConnectionState',
        'state': 'connected',
      });
      await w.phatSuKien({
        'event': 'onCandidate',
        'candidate': {'candidate': 'c2', 'sdpMid': '0', 'sdpMLineIndex': 0},
      });
      await xong(t);
      expect(m.realtime.daGui.any((g) => g.$2['type'] == 'ICE'), isTrue);
      // ICE sau khi đã có remote description thì thêm ngay.
      m.realtime.phat('/user/queue/booking-call', {
        'bookingId': 'b1',
        'type': 'ICE',
        'payload': '{"candidate":"c3","sdpMid":"0","sdpMLineIndex":0}',
      });
      await xong(t);
      await bam(t, find.byIcon(Icons.mic));
      await bam(t, find.byIcon(Icons.call_end));
      expect(m.realtime.daGui.last.$2, {'type': 'HANGUP'});
    });

    testWidgets(
      'có người gọi video tới: nhận máy; đang trong cuộc thì báo bận',
      (t) async {
        final (m, w) = await moChat(t);
        m.realtime.phat('/user/queue/booking-call', {
          'bookingId': 'b1',
          'type': 'OFFER',
          'payload': '{"sdp":"v=0","type":"offer"}',
          'fromName': 'Lan',
          'video': true,
        });
        await xong(t);
        expect(m.realtime.daGui.last.$2, {'type': 'RINGING'});
        expect(find.textContaining('Lan'), findsWidgets);
        // Cuộc thứ hai tới khi đang có chuông → bận.
        m.realtime.phat('/user/queue/booking-call', {
          'bookingId': 'b1',
          'type': 'OFFER',
          'payload': '{}',
        });
        await xong(t);
        expect(m.realtime.daGui.last.$2, {'type': 'BUSY'});
        // Chuông của buổi khác không reo ở đây.
        m.realtime.phat('/user/queue/booking-call', {
          'bookingId': 'khac',
          'type': 'HANGUP',
        });
        await bam(
          t,
          find.descendant(
            of: find.byType(CallPanel),
            matching: find.byIcon(Icons.call),
          ),
        );
        expect(w.goi, contains('createAnswer'));
        expect(m.realtime.daGui.any((g) => g.$2['type'] == 'ANSWER'), isTrue);
        await bam(
          t,
          find.descendant(
            of: find.byType(CallPanel),
            matching: find.byIcon(Icons.videocam),
          ),
        );
        await w.phatSuKien({'event': 'peerConnectionState', 'state': 'failed'});
        await xong(t);
        expect(find.textContaining('chuyển sang wifi'), findsOneWidget);
        await bam(t, find.text('Đóng'));
      },
    );

    testWidgets('phía kia cúp máy và báo bận', (t) async {
      final (m, _) = await moChat(t);
      await bam(t, find.byIcon(Icons.videocam).first);
      m.realtime.phat('/user/queue/booking-call', {'type': 'BUSY'});
      await xong(t);
      expect(find.text('Người kia đang bận.'), findsOneWidget);
      await bam(t, find.byIcon(Icons.call).first);
      m.realtime.phat('/user/queue/booking-call', {'type': 'HANGUP'});
      await xong(t);
      expect(find.byIcon(Icons.call_end), findsNothing);
    });

    for (final (ma, mau) in [
      ('NotAllowedError', 'chưa cho phép dùng micro/camera'),
      ('NotFoundError', 'Không tìm thấy micro'),
      ('NotReadableError', 'đang bị ứng dụng khác chiếm'),
      ('Khac', 'Không bắt đầu được cuộc gọi'),
    ]) {
      testWidgets('lỗi thiết bị $ma có câu hướng dẫn riêng', (t) async {
        final (_, w) = await moChat(t);
        w.loiGetUserMedia = ma;
        await bam(t, find.byIcon(Icons.call).first);
        expect(find.textContaining(mau), findsOneWidget);
      });
    }

    testWidgets('xin quyền treo quá hạn thì nói rõ là chờ cấp quyền', (
      t,
    ) async {
      final (m, w) = await moChat(t);
      w.treoGetUserMedia = true;
      await bam(t, find.byIcon(Icons.call).first);
      await t.pump(const Duration(seconds: 61));
      await xong(t);
      expect(find.textContaining('cho phép dùng micro/camera'), findsOneWidget);
      expect(m.realtime.daGui.last.$2, {'type': 'HANGUP'});
    });

    testWidgets('không ai bắt máy quá hạn', (t) async {
      final (_, _) = await moChat(t);
      await bam(t, find.byIcon(Icons.call).first);
      await t.pump(const Duration(seconds: 61));
      await xong(t);
      expect(find.textContaining('Không nối được cuộc gọi'), findsOneWidget);
    });

    test('trạng thái rỗng lúc đầu', () {
      expect(TrangThaiGoi.values, contains(TrangThaiGoi.rong));
    });
  });
}
