import 'package:astrotarot_mobile/features/admin/ga4_view.dart';
import 'package:astrotarot_mobile/features/admin/goi_ai_admin_view.dart';
import 'package:astrotarot_mobile/features/admin/khuyen_mai_view.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ba mục vừa đưa từ web sang: Khuyến mãi, Gói AI, Lưu lượng & GA4.
///
/// Chỉ kiểm phần ĐỌC dữ liệu. Đó là chỗ một thay đổi nhỏ ở máy chủ làm hỏng
/// lặng lẽ: tên trường đổi thì màn vẫn dựng ra, chỉ là mọi con số về 0 — và
/// ảnh chụp màn hình trông vẫn bình thường.
void main() {
  group('KhuyenMai', () {
    test('giảm theo phần trăm, có trần', () {
      final k = KhuyenMai.fromJson({
        'id': 'k1',
        'ten': 'Tết 2027',
        'loaiGiam': 'PHAN_TRAM',
        'giaTri': 30,
        'giamToiDa': 50000,
        'batDau': '2027-01-20T00:00:00Z',
        'ketThuc': '2027-02-05T00:00:00Z',
        'dangBat': true,
        'dangChay': false,
      });
      expect(k.ten, 'Tết 2027');
      expect(k.mucGiam, '30% (tối đa 50.000 ₫)');
      expect(k.dangBat, isTrue);
      // Bật nhưng CHƯA chạy — máy chủ tính, không suy ở máy.
      expect(k.dangChay, isFalse);
    });

    test('giảm theo số tiền thì không nhắc trần', () {
      final k = KhuyenMai.fromJson({
        'id': 'k2',
        'ten': 'Giỗ Tổ',
        'loaiGiam': 'SO_TIEN',
        'giaTri': 20000,
        'dangBat': true,
        'dangChay': true,
      });
      expect(k.mucGiam, '20.000 ₫');
      expect(k.giamToiDa, isNull);
    });

    test('thiếu trường thì về mặc định chứ không ném', () {
      final k = KhuyenMai.fromJson({'id': 'k3'});
      expect(k.ten, '');
      expect(k.giaTri, 0);
      expect(k.batDau, isNull);
      expect(k.dangBat, isFalse);
    });
  });

  group('GoiAi', () {
    test('đọc đủ các trường', () {
      final g = GoiAi.fromJson({
        'id': 'p1',
        'name': 'Gói tháng',
        'dailyQuota': 20,
        'price': 99000,
        'durationDays': 30,
        'isActive': true,
        'description': 'Hai mươi lượt mỗi ngày',
      });
      expect(g.ten, 'Gói tháng');
      expect(g.hanMucNgay, 20);
      expect(g.gia, 99000);
      expect(g.soNgay, 30);
      expect(g.dangBan, isTrue);
    });

    /// Jackson đặt tên trường boolean theo hai kiểu tuỳ cấu hình. Nhận một
    /// kiểu rồi đoán kiểu kia là để ngỏ một lỗi im lặng: gói đang bán hiện
    /// thành đã ngừng, và không có gì báo.
    /// Gói miễn phí đặt thời hạn 36500 ngày để nghĩa là "mãi mãi". In thẳng
    /// con số ấy ra thì người đọc phải tự nhẩm, và dễ tưởng là lỗi nhập liệu.
    test('thời hạn 100 năm đọc là không giới hạn', () {
      expect(
        GoiAi.fromJson({'id': 'f', 'durationDays': 36500}).moTaThoiHan,
        'không giới hạn',
      );
      expect(
        GoiAi.fromJson({'id': 'm', 'durationDays': 30}).moTaThoiHan,
        '30 ngày',
      );
    });

    test('nhận cả isActive lẫn active', () {
      expect(GoiAi.fromJson({'id': 'a', 'active': true}).dangBan, isTrue);
      expect(GoiAi.fromJson({'id': 'b', 'isActive': true}).dangBan, isTrue);
      expect(GoiAi.fromJson({'id': 'c'}).dangBan, isFalse);
    });
  });

  group('BaoCaoGa4', () {
    test('đọc tổng quan và nguồn truy cập', () {
      final b = BaoCaoGa4.fromJson({
        'configured': true,
        'overview': {
          'activeUsers': 16,
          'newUsers': 16,
          'sessions': 32,
          'screenPageViews': 147,
          'bounceRate': 0.25,
          'averageSessionDuration': 95.0,
        },
        'trafficSources': [
          {
            'source': 'facebook',
            'medium': 'referral',
            'sessions': 21,
            'activeUsers': 4,
          },
        ],
        'realtimeActiveUsers': 1,
      });
      expect(b.daCauHinh, isTrue);
      expect(b.nguoiDung, 16);
      expect(b.luotXem, 147);
      expect(b.dangOnline, 1);
      expect(b.nguon, hasLength(1));
      expect(b.nguon.first.nguon, 'facebook');
    });

    /// -1 nghĩa là KHÔNG hỏi được, 0 là hỏi được và đúng là không có ai. Gộp
    /// hai thứ ấy lại là bày số 0 cho một lượt gọi đã hỏng.
    test('phân biệt không hỏi được với không có ai', () {
      expect(BaoCaoGa4.fromJson({'realtimeActiveUsers': -1}).dangOnline, -1);
      expect(BaoCaoGa4.fromJson({'realtimeActiveUsers': 0}).dangOnline, 0);
      // Thiếu hẳn trường cũng là không hỏi được.
      expect(BaoCaoGa4.fromJson({}).dangOnline, -1);
    });

    test('chưa cấu hình thì nói rõ, không coi là lỗi', () {
      final b = BaoCaoGa4.fromJson({
        'configured': false,
        'message': 'Chưa đặt GA4_PROPERTY_ID',
      });
      expect(b.daCauHinh, isFalse);
      expect(b.thongDiep, 'Chưa đặt GA4_PROPERTY_ID');
      expect(b.nguon, isEmpty);
    });
  });
}
