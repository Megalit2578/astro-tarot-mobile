import 'package:flutter_test/flutter_test.dart';

import 'package:astrotarot_mobile/core/realtime/dinh_tuyen_su_kien.dart';

/// Gói realtime nói phần dữ liệu nào đã cũ.
///
/// Kiểu hỏng mà những bài kiểm này canh: app nhận được gói tin, chấm đỏ trên
/// chuông sáng lên, nhưng số dư ví và danh sách lịch hẹn vẫn là số cũ. Người
/// dùng thấy thông báo rồi mở màn tương ứng, thấy chưa đổi gì, và kết luận
/// app hỏng — chứ không nghĩ là phải kéo xuống để tải lại.
void main() {
  group('tiền và lịch hẹn', () {
    test('tiền về thì làm mới CẢ ví lẫn lịch hẹn', () {
      // Lịch hẹn phải nằm trong đây: trả tiền xong mà thẻ lịch hẹn vẫn ghi
      // "chờ thanh toán" thì người dùng trả thêm lần nữa.
      expect(
        phanDaCu({'type': 'PAYMENT_SUCCESS'}),
        {PhanDuLieu.tien, PhanDuLieu.lichHen},
      );
    });

    test('Reader được chi tiền cũng là họ tiền', () {
      expect(phanDaCu({'type': 'PAYOUT_PAID'}), contains(PhanDuLieu.tien));
    });

    test('đặt lịch chỉ làm mới lịch hẹn, không đụng ví', () {
      expect(phanDaCu({'type': 'BOOKING_CONFIRMED'}), {PhanDuLieu.lichHen});
    });

    test('nhận đánh giá cũng làm mới lịch hẹn', () {
      // Sao vừa chấm hiện ngay trên thẻ buổi hẹn đã xong.
      expect(phanDaCu({'type': 'REVIEW_RECEIVED'}), {PhanDuLieu.lichHen});
    });

    test('phiếu hỗ trợ', () {
      expect(phanDaCu({'type': 'SUPPORT_REPLIED'}), {PhanDuLieu.hoTro});
    });
  });

  group('so theo tiền tố, không liệt kê từng tên', () {
    test('loại mới thuộc họ cũ vẫn được xử lý đúng', () {
      // Đây là lý do dùng startsWith. Liệt kê từng tên thì mỗi lần backend
      // thêm một loại là app lặng lẽ bỏ sót, không có gì báo lỗi cả.
      for (final loai in [
        'BOOKING_MOT_LOAI_CHUA_TON_TAI',
        'PAYMENT_MOT_LOAI_CHUA_TON_TAI',
        'SUPPORT_MOT_LOAI_CHUA_TON_TAI',
      ]) {
        expect(
          phanDaCu({'type': loai}),
          isNotEmpty,
          reason: 'loại mới thuộc họ cũ phải được nhận ra: $loai',
        );
      }
    });

    test('họ lạ hẳn thì không làm mới gì thêm', () {
      // Chuông vẫn được làm mới ở nơi gọi; chỗ này chỉ nói "không có phần
      // nào khác cũ đi". Làm mới bừa mọi thứ là bắn một loạt request mỗi
      // lần có thông báo.
      expect(phanDaCu({'type': 'ACCOUNT_ROLE_CHANGED'}), isEmpty);
    });
  });

  group('đọc loại sự kiện', () {
    test('lấy ở trường ngoài khi có', () {
      expect(loaiSuKien({'type': 'BOOKING_CONFIRMED'}), 'BOOKING_CONFIRMED');
    });

    test('rơi về notification.type khi trường ngoài rỗng', () {
      // Một số đường đi bên máy chủ chỉ điền type bên trong notification.
      // Đọc thiếu chỗ này là cả họ sự kiện im lặng không được xử lý.
      expect(
        loaiSuKien({
          'type': '',
          'notification': {'type': 'PAYMENT_SUCCESS'},
        }),
        'PAYMENT_SUCCESS',
      );
      expect(
        phanDaCu({
          'notification': {'type': 'PAYMENT_SUCCESS'},
        }),
        contains(PhanDuLieu.tien),
      );
    });

    test('gói méo mó không làm chết kênh', () {
      // Gói tin tới từ mạng, không được tin. Ném ở đây là chết cả luồng
      // nghe, và mọi sự kiện SAU đó cũng mất theo.
      expect(() => phanDaCu({}), returnsNormally);
      expect(() => phanDaCu({'type': 123}), returnsNormally);
      expect(() => phanDaCu({'notification': 'không phải map'}), returnsNormally);
      expect(() => phanDaCu({'notification': {'type': null}}), returnsNormally);

      expect(phanDaCu({}), isEmpty);
      expect(phanDaCu({'type': 123}), isEmpty);
    });
  });
}
