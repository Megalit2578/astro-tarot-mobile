import 'package:astrotarot_mobile/features/bookings/booking.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/mau.dart';

Booking buoi({
  required String trangThai,
  required String traTien,
  required Duration lech,
}) => Booking.fromJson(
  mauBooking(
    trangThai: trangThai,
    traTien: traTien,
    batDau: DateTime.now().add(lech),
  ),
);

const truoc = Duration(days: -21);
const sau = Duration(days: 1);

void main() {
  group('buổi lỡ hẹn', () {
    test('DỰNG LẠI LỖI THẬT: buổi đã qua mà Reader chưa nhận', () {
      // Thấy trên máy thật ngày 29/10/2026: hai buổi hẹn 08/10 và 13/10 vẫn
      // ở trạng thái "Chờ Reader nhận" và vẫn mời "Đặt cọc 50%" / "Thanh
      // toán hết". App mời khách trả tiền cho buổi đã trôi qua ba tuần mà
      // chưa ai nhận — tiền đi ra, không đổi lấy gì.
      final b = buoi(trangThai: 'PENDING', traTien: 'UNPAID', lech: truoc);
      expect(b.daLoHen, isTrue);
      expect(b.conTraDuocKhoanDau, isFalse);
    });

    test('buổi sắp tới mà chưa ai nhận thì vẫn trả được', () {
      final b = buoi(trangThai: 'PENDING', traTien: 'UNPAID', lech: sau);
      expect(b.daLoHen, isFalse);
      expect(b.conTraDuocKhoanDau, isTrue);
    });

    test('đã qua giờ nhưng Reader ĐÃ nhận thì vẫn phải trả được', () {
      // Buổi có thể đã diễn ra xong và Reader còn đang chờ tiền. Chặn chỗ
      // này là quỵt công người ta — đây là cái bẫy dễ mắc nhất khi sửa lỗi
      // trên.
      final b = buoi(trangThai: 'CONFIRMED', traTien: 'UNPAID', lech: truoc);
      expect(b.daLoHen, isFalse);
      expect(b.conTraDuocKhoanDau, isTrue);
    });

    test('buổi đã hoàn tất mà chưa trả thì vẫn phải trả được', () {
      final b = buoi(trangThai: 'COMPLETED', traTien: 'UNPAID', lech: truoc);
      expect(b.conTraDuocKhoanDau, isTrue);
    });

    test('buổi đã huỷ thì không trả nữa, dù còn hạn', () {
      final b = buoi(trangThai: 'CANCELLED', traTien: 'UNPAID', lech: sau);
      expect(b.conTraDuocKhoanDau, isFalse);
    });

    test('đã trả rồi thì không mời trả lần nữa', () {
      final b = buoi(trangThai: 'CONFIRMED', traTien: 'PAID', lech: sau);
      expect(b.conTraDuocKhoanDau, isFalse);
    });

    test('đã cọc thì khoản ĐẦU không mời nữa — phần còn lại đi lối khác', () {
      final b = buoi(
        trangThai: 'CONFIRMED',
        traTien: 'DEPOSIT_PAID',
        lech: sau,
      );
      expect(b.conTraDuocKhoanDau, isFalse);
      expect(b.daCoc, isTrue);
    });
  });
}
