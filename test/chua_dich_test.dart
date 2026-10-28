import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Chốt chặn chuỗi chưa dịch.
///
/// ## Vì sao cần
///
/// App có hai thứ tiếng, nhưng cách dịch là gọi `Ngu.d('câu tiếng Việt')` ở
/// từng chỗ. Quên gọi thì KHÔNG có gì báo: màn vẫn chạy, chữ vẫn hiện, chỉ
/// là người dùng tiếng Anh thấy một câu tiếng Việt giữa màn tiếng Anh.
///
/// Chạy tay ngày 29/10/2026 bắt được bằng cách ấy: nút chat ghi "Nhắn tin
/// với Đạt Trần", mục quyền ghi "Quyền máy chủ cấp cho phiên này (3)", cả
/// khối lịch ghi "Tháng 10 năm 2026" và "T2".."CN", và nhãn trạng thái buổi
/// hẹn ghi "Chờ Reader nhận" — tất cả giữa một màn tiếng Anh.
///
/// ## Vì sao là bánh cóc chứ không phải cấm tiệt
///
/// Lúc viết test này còn [nguong] chỗ như vậy, phần lớn nằm ở các màn quản
/// trị và bàn làm việc — những màn chỉ người Việt trong nhóm dùng, nên chưa
/// gấp. Bắt phải về 0 ngay thì test đỏ suốt và sẽ bị ai đó tắt đi.
///
/// Nên luật ở đây là: **con số chỉ được giảm**. Thêm một chuỗi chưa dịch vào
/// là test đỏ ngay; dịch bớt đi thì hạ [nguong] xuống theo.
void main() {
  const dauTiengViet =
      'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡ'
      'ùúụủũưừứựửữỳýỵỷỹđÀÁẠẢÃÂĂÈÉẸÊÌÍÒÓỌÔƠÙÚƯỲÝĐ';

  /// Số chỗ còn lại lúc viết test. CHỈ ĐƯỢC GIẢM.
  const nguong = 210;

  final mau = RegExp(
    r"(?:Text\(\s*|tooltip:\s*|hintText:\s*|label:\s*Text\(\s*)'([^']{3,80})'",
  );

  test('không thêm chuỗi tiếng Việt vẽ thẳng, không qua Ngu.d', () {
    final pham = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      for (final m in mau.allMatches(src)) {
        final cau = m.group(1)!;
        if (cau.split('').any(dauTiengViet.contains)) {
          pham.add('${f.path}: $cau');
        }
      }
    }

    expect(
      pham.length,
      lessThanOrEqualTo(nguong),
      reason:
          'Có ${pham.length} chỗ vẽ thẳng chuỗi tiếng Việt, nhiều hơn mốc '
          '$nguong. Bọc câu mới bằng Ngu.d() và thêm bản dịch vào '
          'tu_dien_en.dart.\n\nMấy chỗ đầu:\n${pham.take(10).join('\n')}',
    );

    // Giảm được thì hạ mốc xuống, nếu không bánh cóc hở ra đúng bằng phần
    // vừa dọn và lần sau lại thêm vào được chừng ấy mà không ai biết.
    expect(
      pham.length,
      greaterThanOrEqualTo(nguong),
      reason:
          'Đã dọn bớt còn ${pham.length} chỗ — hạ `nguong` trong tệp này '
          'xuống ${pham.length}.',
    );
  });
}
