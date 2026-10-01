import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Một cung hoàng đạo.
class Cung {
  const Cung(
    this.ky,
    this.ten,
    this.tuThang,
    this.tuNgay,
    this.denThang,
    this.denNgay,
  );

  /// Ký hiệu chiêm tinh.
  final String ky;

  /// Tên tiếng Việt.
  final String ten;

  final int tuThang;
  final int tuNgay;
  final int denThang;
  final int denNgay;

  String get khoangNgay => '$tuNgay/$tuThang – $denNgay/$denThang';
}

/// Mười hai cung, xếp theo thứ tự vòng hoàng đạo bắt đầu từ Bạch Dương.
///
/// Ngày tháng chép ĐÚNG từ `ZodiacCalculator.java` của backend. Hai nơi lệch
/// nhau một ngày thôi là người sinh đúng hôm giao cung sẽ thấy app nói một
/// đằng, câu giải của AI nói một nẻo — và không ai lần ra vì sao.
const vongCung = <Cung>[
  Cung('♈', 'Bạch Dương', 3, 21, 4, 19),
  Cung('♉', 'Kim Ngưu', 4, 20, 5, 20),
  Cung('♊', 'Song Tử', 5, 21, 6, 20),
  Cung('♋', 'Cự Giải', 6, 21, 7, 22),
  Cung('♌', 'Sư Tử', 7, 23, 8, 22),
  Cung('♍', 'Xử Nữ', 8, 23, 9, 22),
  Cung('♎', 'Thiên Bình', 9, 23, 10, 22),
  Cung('♏', 'Thiên Yết', 10, 23, 11, 21),
  Cung('♐', 'Nhân Mã', 11, 22, 12, 21),
  Cung('♑', 'Ma Kết', 12, 22, 1, 19),
  Cung('♒', 'Bảo Bình', 1, 20, 2, 18),
  Cung('♓', 'Song Ngư', 2, 19, 3, 20),
];

/// Cung mặt trời của một ngày sinh, hoặc null nếu ngày không hợp lệ.
///
/// Tính ở máy thay vì xin máy chủ: đây là một phép tra bảng thuần theo ngày
/// tháng, không cần mạng, và màn hình không phải chờ thêm một lượt gọi chỉ để
/// biết một chữ. Bảng ở trên đã khớp với backend nên hai bên không thể lệch.
Cung? cungMatTroi(DateTime? ngaySinh) {
  if (ngaySinh == null) return null;
  for (final c in vongCung) {
    final batDau = (c.tuThang, c.tuNgay);
    final ketThuc = (c.denThang, c.denNgay);
    final nay = (ngaySinh.month, ngaySinh.day);
    bool sauHoacBang((int, int) a, (int, int) b) =>
        a.$1 > b.$1 || (a.$1 == b.$1 && a.$2 >= b.$2);
    bool truocHoacBang((int, int) a, (int, int) b) =>
        a.$1 < b.$1 || (a.$1 == b.$1 && a.$2 <= b.$2);

    // Ma Kết vắt qua giao thừa (22/12 – 19/1) nên phải xét kiểu "hoặc".
    final vatQuaNam = c.tuThang > c.denThang;
    final trong = vatQuaNam
        ? sauHoacBang(nay, batDau) || truocHoacBang(nay, ketThuc)
        : sauHoacBang(nay, batDau) && truocHoacBang(nay, ketThuc);
    if (trong) return c;
  }
  return null;
}

/// Vòng mười hai cung hoàng đạo, tô sáng cung mặt trời của người dùng.
///
/// ## Vì sao là vòng CUNG chứ không phải bản đồ sao có hành tinh
///
/// Backend chỉ tính được cung mặt trời từ ngày sinh:
///
///     .sunSign(sunSign)
///     .moonSign(null)
///     .risingSign(null)
///     .natalPlanetPositions(null)
///
/// Không có thư viện lịch thiên văn trong dự án, nên không có vị trí hành tinh
/// nào là thật. Vẽ một vòng có Sao Kim ở 200 độ thì con số ấy do mình bịa, trên
/// một sản phẩm bán dịch vụ xem chiêm tinh. Vòng cung thì mọi thứ hiện ra đều
/// có thật và kiểm được.
///
/// ## Vì sao đứng yên
///
/// Vòng bài ở trang chủ xoay vì nó là nền trang trí. Vòng này là thông tin —
/// người ta mở ra để đọc cung của mình. Xoay thì chữ chạy, phải đuổi theo mới
/// đọc được.
class VongHoangDao extends StatelessWidget {
  const VongHoangDao({super.key, required this.ngaySinh, this.duongKinh = 240});

  final DateTime? ngaySinh;
  final double duongKinh;

  @override
  Widget build(BuildContext context) {
    final cung = cungMatTroi(ngaySinh);
    return SizedBox.square(
      dimension: duongKinh,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(duongKinh),
            painter: _VeVong(cungSang: cung),
          ),
          if (cung != null)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  cung.ky,
                  style: const TextStyle(fontSize: 34, color: Mau.vang),
                ),
                const SizedBox(height: 2),
                Text(
                  cung.ten,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Mau.vangNhat,
                  ),
                ),
                Text(
                  cung.khoangNgay,
                  style: const TextStyle(fontSize: 11, color: Mau.chuMo),
                ),
              ],
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                'Khai ngày sinh để biết cung của bạn',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Mau.chuMo),
              ),
            ),
        ],
      ),
    );
  }
}

class _VeVong extends CustomPainter {
  _VeVong({required this.cungSang});

  final Cung? cungSang;

  @override
  void paint(Canvas canvas, Size size) {
    final tam = Offset(size.width / 2, size.height / 2);
    final rNgoai = size.width / 2 - 2;
    final rTrong = rNgoai - 34;

    final vien = Paint()
      ..style = PaintingStyle.stroke
      ..color = Mau.vang.withValues(alpha: 0.5)
      ..strokeWidth = 1.2;
    canvas.drawCircle(tam, rNgoai, vien);
    canvas.drawCircle(
      tam,
      rTrong,
      vien..color = Mau.vang.withValues(alpha: 0.3),
    );

    const soCung = 12;
    const mot = 2 * math.pi / soCung;

    for (var i = 0; i < soCung; i++) {
      // Bạch Dương bắt đầu ở đỉnh, chạy theo chiều kim đồng hồ.
      final gocDau = -math.pi / 2 + i * mot;
      final c = vongCung[i];
      final sang = cungSang != null && c.ten == cungSang!.ten;

      if (sang) {
        // Tô cả múi của cung mình, để mắt bắt được ngay mà không phải dò.
        canvas.drawArc(
          Rect.fromCircle(center: tam, radius: (rNgoai + rTrong) / 2),
          gocDau,
          mot,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = rNgoai - rTrong
            ..color = Mau.vang.withValues(alpha: 0.18),
        );
      }

      // Vạch ngăn giữa hai cung.
      final v1 = tam + Offset(math.cos(gocDau), math.sin(gocDau)) * rTrong;
      final v2 = tam + Offset(math.cos(gocDau), math.sin(gocDau)) * rNgoai;
      canvas.drawLine(
        v1,
        v2,
        Paint()
          ..color = Mau.vang.withValues(alpha: 0.35)
          ..strokeWidth = 1,
      );

      // Ký hiệu đặt giữa múi.
      final gocGiua = gocDau + mot / 2;
      final viTri =
          tam +
          Offset(math.cos(gocGiua), math.sin(gocGiua)) *
              ((rNgoai + rTrong) / 2);
      final chu = TextPainter(
        text: TextSpan(
          text: c.ky,
          style: TextStyle(
            fontSize: sang ? 20 : 16,
            color: sang ? Mau.vangNhat : Mau.vang.withValues(alpha: 0.75),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      chu.paint(canvas, viTri - Offset(chu.width / 2, chu.height / 2));
    }
  }

  @override
  bool shouldRepaint(_VeVong cu) => cu.cungSang?.ten != cungSang?.ten;
}
