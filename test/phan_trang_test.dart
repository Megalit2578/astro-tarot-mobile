import 'package:astrotarot_mobile/features/blog/blog_screen.dart';
import 'package:astrotarot_mobile/features/bookings/bookings_screen.dart';
import 'package:astrotarot_mobile/features/money/earnings_screen.dart';
import 'package:astrotarot_mobile/features/notifications/notifications_screen.dart';
import 'package:astrotarot_mobile/features/staff/staff_bookings_view.dart';
import 'package:astrotarot_mobile/features/staff/staff_support_view.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/gia.dart';
import 'support/mau.dart';

/// Những danh sách trước đây tải ĐÚNG MỘT TRANG rồi dừng.
///
/// Không có nút nào, không có dấu hiệu nào cho biết còn nữa — màn hình trông
/// bình thường, chỉ là thiếu. Đó là kiểu hỏng khó phát hiện nhất: người dùng
/// không báo lỗi vì họ không biết mình đang thiếu gì, và người kiểm thử cũng
/// không thấy gì sai vì dữ liệu thử luôn ít hơn hạn mức.
///
/// Mỗi phép kiểm ở đây dựng một danh sách CÓ trang hai, rồi đòi hỏi hai điều:
/// nút "Tải thêm" phải hiện ra, và bấm nó phải gọi đúng `page=1`.
void main() {
  /// Máy chủ giả trả hai trang cho một đường dẫn.
  ///
  /// Trang 0 mang [muc0], trang 1 mang [muc1]. Đọc thẳng tham số `page` của
  /// lời gọi, nên nếu màn hình quên tăng số trang thì nó nhận lại trang 0 và
  /// phép kiểm đỏ.
  void haiTrang(
    MayChuGia m,
    String route,
    List<Map<String, dynamic>> muc0,
    List<Map<String, dynamic>> muc1,
  ) {
    m.xuLy(route, (g) {
      final so = int.tryParse('${g.query['page'] ?? 0}') ?? 0;
      return TraLoi(200, {
        'success': true,
        'message': 'OK',
        'data': trang(
          so == 0 ? muc0 : muc1,
          so: so,
          tongTrang: 2,
          tong: muc0.length + muc1.length,
        ),
      });
    });
  }

  int soTrangDaGoi(MayChuGia m, String route) =>
      m.cacLan(route).map((g) => g.query['page']).toSet().length;

  group('Lịch hẹn của khách', () {
    testWidgets('có nút Tải thêm, và bấm thì xin đúng trang sau', (t) async {
      final m = MoiTruong(user: nguoiDung());
      haiTrang(
        m.mayChu,
        'GET /api/v1/bookings/me',
        [mauBooking()],
        [mauBooking(id: 'b9', trangThai: 'COMPLETED', traTien: 'PAID')],
      );
      await m.dung(t, const BookingsScreen());

      expect(find.text('Tải thêm'), findsOneWidget);
      await bam(t, find.text('Tải thêm'));

      expect(m.mayChu.lanCuoi('GET /api/v1/bookings/me')!.query['page'], '1');
      // Trang sau NỐI vào, không thay thế: mất trang đầu là người dùng cuộn
      // xuống rồi thấy danh sách nhảy về đầu với nội dung khác.
      expect(soTrangDaGoi(m.mayChu, 'GET /api/v1/bookings/me'), 2);
    });

    testWidgets('hết trang thì không còn nút Tải thêm', (t) async {
      final m = MoiTruong(user: nguoiDung());
      m.mayChu.tra('GET /api/v1/bookings/me', trang([mauBooking()]));
      await m.dung(t, const BookingsScreen());

      // Một trang duy nhất — hiện nút là hứa một thứ không tồn tại.
      expect(find.text('Tải thêm'), findsNothing);
    });
  });

  group('Lịch hẹn phía Reader', () {
    testWidgets('lọc gửi xuống máy chủ, và có Tải thêm', (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'STAFF'));
      haiTrang(
        m.mayChu,
        'GET /api/v1/bookings/reader',
        [mauBooking()],
        [mauBooking(id: 'b9')],
      );
      await m.dung(t, const StaffBookingsView());

      expect(find.text('Tải thêm'), findsOneWidget);

      await bam(t, find.text('Chờ nhận'));
      // Reader làm lâu sẽ có hàng trăm buổi. Lọc ở máy khách chỉ lọc được
      // trong hai mươi buổi gần nhất.
      expect(m.mayChu.lanCuoi('GET /api/v1/bookings/reader')!.query['status'],
          'PENDING');
      // Đổi bộ lọc là bắt đầu lại từ trang đầu.
      expect(
          m.mayChu.lanCuoi('GET /api/v1/bookings/reader')!.query['page'], '0');
    });
  });

  group('Thông báo', () {
    testWidgets('có Tải thêm và KHÔNG sắp lại ở máy khách', (t) async {
      final m = MoiTruong(user: nguoiDung());
      haiTrang(
        m.mayChu,
        'GET /api/v1/me/notifications',
        [
          {'id': 'n1', 'title': 'Tin ghim', 'read': true, 'pinned': true},
          {'id': 'n2', 'title': 'Tin thường', 'read': true, 'pinned': false},
        ],
        [
          {'id': 'n3', 'title': 'Tin ghim cũ', 'read': true, 'pinned': true},
        ],
      );
      m.mayChu.tra('GET /api/v1/me/notifications/unread-count', {'count': 0});
      await m.dung(t, const NotificationsScreen());

      await bam(t, find.text('Tải thêm'));

      // Tin ghim của TRANG HAI phải nằm DƯỚI tin thường của trang một.
      //
      // Nghe có vẻ ngược, nhưng đó mới đúng: máy chủ đã sắp ghim-trước trong
      // phạm vi toàn bộ danh sách, và trang hai là phần đuôi của thứ tự ấy.
      // Sắp lại ở máy khách sẽ kéo "Tin ghim cũ" lên đầu, tức là dựng ra một
      // thứ tự không có thật và khác hẳn thứ tự người dùng thấy trên web.
      final yThuong = t.getTopLeft(find.text('Tin thường')).dy;
      final yGhimCu = t.getTopLeft(find.text('Tin ghim cũ')).dy;
      expect(yThuong, lessThan(yGhimCu));
    });
  });

  group('Hàng chờ hỗ trợ', () {
    testWidgets('có Tải thêm', (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'STAFF'));
      haiTrang(
        m.mayChu,
        'GET /api/v1/support/queue',
        [
          {'id': 'tk1', 'subject': 'Phiếu mới', 'status': 'OPEN',
              'messageCount': 1},
        ],
        [
          {'id': 'tk9', 'subject': 'Phiếu cũ', 'status': 'OPEN',
              'messageCount': 3},
        ],
      );
      await m.dung(t, const StaffSupportView());

      expect(find.text('Tải thêm'), findsOneWidget);
      await bam(t, find.text('Tải thêm'));

      // Hàng chờ hỗ trợ là nơi dễ dồn lại nhất — ai cũng xử những phiếu trên
      // cùng, nên chính những phiếu cũ bị bỏ quên lại là những phiếu không
      // hiện ra.
      expect(find.text('Phiếu cũ'), findsOneWidget);
      expect(find.text('Phiếu mới'), findsOneWidget);
    });
  });

  group('Bài viết', () {
    testWidgets('có Tải thêm và nối trang sau vào cuối', (t) async {
      final m = MoiTruong(user: nguoiDung());
      haiTrang(
        m.mayChu,
        'GET /api/v1/blogs',
        [
          {'id': 'p1', 'title': 'Bài mới', 'slug': 'bai-moi'},
        ],
        [
          {'id': 'p2', 'title': 'Bài cũ', 'slug': 'bai-cu'},
        ],
      );
      await m.dung(t, const BlogScreen());

      await bam(t, find.text('Tải thêm'));

      expect(find.text('Bài mới'), findsOneWidget);
      expect(find.text('Bài cũ'), findsOneWidget);
    });
  });

  group('Thu nhập của Reader', () {
    /// Số dư đủ để màn hình dựng xong phần đầu.
    void khaiSoDu(MayChuGia m) {
      m.tra('GET /api/v1/me/escrow', {
        'balance': 900000,
        'pendingBalance': 0,
        'totalEarned': 900000,
        'totalWithdrawn': 0,
        'penaltyOwed': 0,
        'minimumPayout': 100000,
      });
    }

    testWidgets('sổ ký quỹ có Tải thêm và đếm đã hiện trên tổng', (t) async {
      final m = MoiTruong(user: nguoiDung(vaiTro: 'STAFF'));
      khaiSoDu(m.mayChu);
      m.mayChu.tra('GET /api/v1/me/payouts', trang([]));
      haiTrang(
        m.mayChu,
        'GET /api/v1/me/escrow/transactions',
        [
          {
            'id': 'g1',
            'kind': 'RELEASE',
            'amount': 850000,
            'balanceAfter': 850000,
            'pendingAfter': 0,
            'note': 'Buổi xem hoàn tất.',
          },
        ],
        [
          {
            'id': 'g2',
            'kind': 'HOLD',
            'amount': 100000,
            'balanceAfter': 850000,
            'pendingAfter': 100000,
            'note': 'Khách đã thanh toán.',
          },
        ],
      );
      await m.dung(t, const EarningsScreen());

      // "1/2" nói cho Reader biết họ đang nhìn một phần. Không có con số này
      // thì khi hết trang, nút biến mất và họ không biết mình đã xem hết hay
      // danh sách bị cắt.
      expect(find.text('1/2'), findsOneWidget);

      await bam(t, find.text('Tải thêm'));
      expect(
          m.mayChu.lanCuoi('GET /api/v1/me/escrow/transactions')!.query['page'],
          '1');
      expect(find.text('2/2'), findsOneWidget);
    });
  });
}
