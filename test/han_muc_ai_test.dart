import 'dart:io';

import 'package:astrotarot_mobile/features/goiai/goi_ai_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HanMucAi', () {
    test('đọc đủ năm con số từ máy chủ', () {
      final h = HanMucAi.fromJson({
        'tongHanMuc': 6,
        'tuGoi': 3,
        'tuGame': 3,
        'daDung': 2,
        'conLai': 4,
      });
      expect(h.tong, 6);
      expect(h.tuGoi, 3);
      expect(h.tuGame, 3);
      expect(h.daDung, 2);
      expect(h.conLai, 4);
    });

    test('thiếu trường thì về 0, không ném lỗi', () {
      // Máy chủ cũ chưa có đường này; app mới gọi vào bản backend cũ thì nhận
      // về một đối tượng rỗng. Ném lỗi ở đây là cả màn Gói AI trắng xoá.
      final h = HanMucAi.fromJson(const {});
      expect(h.tong, 0);
      expect(h.tuGame, 0);
      expect(h.conLai, 0);
    });

    test('nhận số thực từ JSON mà không ép kiểu hỏng', () {
      // Jackson có thể trả 6 hoặc 6.0 tuỳ cách cấu hình; `as int` thẳng sẽ
      // ném với cái thứ hai.
      final h = HanMucAi.fromJson({'tongHanMuc': 6.0, 'conLai': 4.0});
      expect(h.tong, 6);
      expect(h.conLai, 4);
    });
  });

  group('một nguồn cho hạn mức AI', () {
    test('ô "hạn mức hôm nay" không tự tính từ danh sách gói', () {
      // Bên web từng chép luật này ra ba chỗ, và bản sao ấy không biết gì về
      // lượt thưởng từ mini game: người chơi được 3 lượt mà huy hiệu vẫn ghi
      // "3/3". Con số phải tới từ máy chủ, không được dựng lại ở đây.
      //
      // Chỉ soi THÂN của `_HanMucHomNay`. Đọc `hanMucNgay` ở chỗ khác trong
      // cùng tệp là hợp lệ — thẻ giới thiệu gói phải hiện hạn mức của chính
      // gói đó, và phần gợi ý nâng cấp phải so hai gói với nhau.
      final src = File(
        'lib/features/goiai/goi_ai_screen.dart',
      ).readAsStringSync();

      final dau = src.indexOf('class _HanMucHomNay');
      expect(dau, greaterThan(-1), reason: 'không còn widget _HanMucHomNay');
      final sau = src.indexOf(RegExp(r'^class ', multiLine: true), dau + 1);
      final than = sau == -1 ? src.substring(dau) : src.substring(dau, sau);

      expect(
        than.contains('hanMucHomNayProvider'),
        isTrue,
        reason: 'ô này phải hỏi máy chủ qua hanMucHomNayProvider',
      );
      expect(
        than.contains('hanMucNgay'),
        isFalse,
        reason:
            'Lấy tổng hạn mức từ hanMucHomNayProvider, đừng đọc hanMucNgay '
            'của một gói — con số ấy không có phần thưởng từ mini game.',
      );
    });
  });
}
