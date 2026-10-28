import 'package:astrotarot_mobile/core/ngon_ngu.dart';
import 'package:astrotarot_mobile/features/bookings/booking.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => Ngu.hien.value = 'vi');
  tearDown(() => Ngu.hien.value = 'vi');

  group('tên tháng', () {
    test('tiếng Việt giữ nguyên lối viết có chữ "năm"', () {
      expect(tenThang(DateTime(2026, 10, 1)), 'Tháng 10 năm 2026');
      expect(tenThangNgan(DateTime(2026, 10, 1)), 'Tháng 10/2026');
    });

    test('tiếng Anh dùng tên tháng, KHÔNG dịch từng chữ', () {
      // Ghép kiểu "${Ngu.d('Tháng')} $thang $nam" sẽ ra "October 10 2026".
      // Hai thứ tiếng xếp khác nhau chứ không chỉ khác chữ.
      Ngu.hien.value = 'en';
      expect(tenThang(DateTime(2026, 10, 1)), 'October 2026');
      expect(tenThangNgan(DateTime(2026, 10, 1)), 'Oct 2026');
    });

    test('đủ mười hai tháng, không lệch chỉ số', () {
      Ngu.hien.value = 'en';
      expect(tenThang(DateTime(2026, 1, 1)), startsWith('January'));
      expect(tenThang(DateTime(2026, 12, 1)), startsWith('December'));
      expect(tenThangNgan(DateTime(2026, 1, 1)), startsWith('Jan'));
      expect(tenThangNgan(DateTime(2026, 12, 1)), startsWith('Dec'));
    });
  });

  group('viết tắt thứ', () {
    test('bảy ngày, bắt đầu từ thứ Hai, ở cả hai thứ tiếng', () {
      expect(thuVietTat, hasLength(7));
      expect(thuVietTat.first, 'T2');
      expect(thuVietTat.last, 'CN');
      Ngu.hien.value = 'en';
      expect(thuVietTat, hasLength(7));
      expect(thuVietTat.first, 'Mon');
      expect(thuVietTat.last, 'Sun');
    });
  });

  group('nhãn trạng thái buổi hẹn', () {
    test('dịch sang tiếng Anh', () {
      // Thấy trên máy thật: giữa một màn tiếng Anh vẫn ghi "Chờ Reader nhận".
      expect(nhanTrangThai(TrangThaiBuoi.pending), 'Chờ Reader nhận');
      Ngu.hien.value = 'en';
      expect(nhanTrangThai(TrangThaiBuoi.pending), 'Awaiting Reader');
      expect(nhanTrangThai(TrangThaiBuoi.confirmed), 'Accepted');
      expect(nhanTrangThai(TrangThaiBuoi.completed), 'Completed');
      expect(nhanTrangThai(TrangThaiBuoi.cancelled), 'Cancelled');
    });

    test('trạng thái lạ không ném lỗi', () {
      Ngu.hien.value = 'en';
      expect(() => nhanTrangThai(TrangThaiBuoi.khac), returnsNormally);
    });
  });
}
