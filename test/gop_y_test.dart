import 'package:astrotarot_mobile/features/admin/gop_y_view.dart';
import 'package:flutter_test/flutter_test.dart';

/// Đọc phản hồi cho màn quản trị.
///
/// Phần đáng kiểm nhất là quy tắc ẩn danh: máy chủ VẪN gửi tên người gửi kèm
/// cờ `isAnonymous`. Bày tên ấy ra là phá đúng lời hứa của ô "gửi ẩn danh" mà
/// người dùng đã tick — và không có gì trên màn hình báo cho ai biết.
void main() {
  Map<String, dynamic> hang({
    bool anDanh = false,
    String? ten = 'Trần Duy Đạt',
    int? sao = 5,
  }) => {
    'id': 'f1',
    'rating': sao,
    'source': 'TAROT_AI',
    'comment': 'Tạm được',
    'isAnonymous': anDanh,
    'userFullName': ten,
    'username': 'dat',
    'createdAt': '2026-09-27T10:00:00Z',
  };

  group('GopY', () {
    test('đọc đủ các trường', () {
      final g = GopY.fromJson(hang());
      expect(g.sao, 5);
      expect(g.nguon, 'TAROT_AI');
      expect(g.noiDung, 'Tạm được');
      expect(g.tenNguoiGui, 'Trần Duy Đạt');
      expect(g.anDanh, isFalse);
      expect(g.luc, isNotNull);
    });

    test('gửi ẩn danh thì KHÔNG giữ tên, dù máy chủ có gửi', () {
      final g = GopY.fromJson(hang(anDanh: true));
      expect(g.anDanh, isTrue);
      expect(g.tenNguoiGui, isNull);
    });

    test('không có fullName thì lùi về username', () {
      final g = GopY.fromJson(hang(ten: null));
      expect(g.tenNguoiGui, 'dat');
    });

    test('thiếu sao hoặc ngày thì không ném', () {
      final g = GopY.fromJson({'id': 'f2', 'rating': null, 'createdAt': 'rac'});
      expect(g.sao, isNull);
      expect(g.luc, isNull);
      expect(g.noiDung, isNull);
    });
  });

  group('ThongKeGopY', () {
    test('đọc phân bổ sao với khoá dạng chuỗi', () {
      final t = ThongKeGopY.fromJson({
        'totalCount': 20,
        'averageRating': 4.2,
        'ratingDistribution': {'5': 8, '4': 5, '3': 1, '2': 2},
      });
      expect(t.tong, 20);
      expect(t.trungBinh, closeTo(4.2, 0.001));
      expect(t.theoSao[5], 8);
      expect(t.theoSao[2], 2);
      // Mức chưa ai chọn: không có trong phản hồi, màn hình tự hiện 0.
      expect(t.theoSao[1], isNull);
    });

    test('phản hồi rỗng thì về 0 chứ không ném', () {
      final t = ThongKeGopY.fromJson({});
      expect(t.tong, 0);
      expect(t.trungBinh, 0);
      expect(t.theoSao, isEmpty);
    });
  });
}
