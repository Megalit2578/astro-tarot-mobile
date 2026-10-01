import 'package:astrotarot_mobile/widgets/vong_hoang_dao.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ranh giới cung phải khớp `ZodiacCalculator.java` của backend.
///
/// Lệch một ngày thôi là người sinh đúng hôm giao cung thấy app nói một đằng,
/// câu giải của AI nói một nẻo — và không ai lần ra vì sao. Nên kiểm đúng hai
/// đầu của mọi cung, không kiểm ngày giữa cho có.
void main() {
  group('cung mặt trời', () {
    test('mười hai cung đều đủ hai đầu', () {
      // (tháng, ngày đầu, ngày cuối, tên)
      const moc = [
        (3, 21, 4, 19, 'Bạch Dương'),
        (4, 20, 5, 20, 'Kim Ngưu'),
        (5, 21, 6, 20, 'Song Tử'),
        (6, 21, 7, 22, 'Cự Giải'),
        (7, 23, 8, 22, 'Sư Tử'),
        (8, 23, 9, 22, 'Xử Nữ'),
        (9, 23, 10, 22, 'Thiên Bình'),
        (10, 23, 11, 21, 'Thiên Yết'),
        (11, 22, 12, 21, 'Nhân Mã'),
        (1, 20, 2, 18, 'Bảo Bình'),
        (2, 19, 3, 20, 'Song Ngư'),
      ];
      for (final (thangDau, ngayDau, thangCuoi, ngayCuoi, ten) in moc) {
        expect(
          cungMatTroi(DateTime(2000, thangDau, ngayDau))?.ten,
          ten,
          reason: 'ngày đầu của $ten',
        );
        expect(
          cungMatTroi(DateTime(2000, thangCuoi, ngayCuoi))?.ten,
          ten,
          reason: 'ngày cuối của $ten',
        );
      }
    });

    test('Ma Kết vắt qua giao thừa', () {
      // Cung duy nhất có khoảng ngày chạy ngược năm (22/12 – 19/1). Nếu so
      // sánh theo kiểu "và" như mười một cung kia thì cả tháng này rơi ra
      // ngoài và hàm trả null.
      expect(cungMatTroi(DateTime(2000, 12, 22))?.ten, 'Ma Kết');
      expect(cungMatTroi(DateTime(2000, 12, 31))?.ten, 'Ma Kết');
      expect(cungMatTroi(DateTime(2001, 1, 1))?.ten, 'Ma Kết');
      expect(cungMatTroi(DateTime(2001, 1, 19))?.ten, 'Ma Kết');
      // Ngay sau đó phải sang cung khác, không được dính lại.
      expect(cungMatTroi(DateTime(2001, 1, 20))?.ten, 'Bảo Bình');
      expect(cungMatTroi(DateTime(2000, 12, 21))?.ten, 'Nhân Mã');
    });

    test('mọi ngày trong năm đều ra đúng một cung', () {
      // Không ngày nào được rơi vào khe hở giữa hai cung. 2000 là năm nhuận
      // nên bao luôn 29/2.
      for (var d = DateTime(2000, 1, 1);
          d.year == 2000;
          d = d.add(const Duration(days: 1))) {
        expect(cungMatTroi(d), isNotNull, reason: '$d không ra cung nào');
      }
    });

    test('không có ngày sinh thì không đoán bừa', () {
      expect(cungMatTroi(null), isNull);
    });
  });
}
