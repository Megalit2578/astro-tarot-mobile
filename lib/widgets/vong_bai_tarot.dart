import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../features/home/daily_card.dart';
import '../theme.dart';

/// Vòng 22 lá Ẩn Chính xoay chậm — nền trang trí cho đầu trang chủ.
///
/// Chép lại ý của `TarotWheel.tsx` bên web, nơi nó là hình ảnh nhận diện của
/// trang. App trước đây chỉ có chữ trên nền đen trơn, nhìn không ra một sản
/// phẩm về Tarot.
///
/// ## Vì sao dùng lại ảnh của web thay vì đóng gói vào app
///
/// `LaAnChinh.anh` đã trỏ sẵn sang `${webBaseUrl}/tarot/<tệp>.jpg` — cùng bộ
/// Rider-Waite-Smith 1909 đã hết hạn bản quyền mà web đang dùng. Nhét hai mươi
/// hai tấm vào gói cài đặt chỉ để trang trí thì app nặng thêm mà chẳng được gì;
/// ảnh này cũng được bộ nhớ đệm của hệ điều hành giữ lại sau lần tải đầu.
///
/// ## Vì sao bấm chứ không phải rê chuột
///
/// Bản web dừng vòng khi rê chuột vào một lá. Điện thoại không có con trỏ, nên
/// ở đây là chạm: chạm một lá thì cả vòng dừng và lá đó sáng lên, chạm lần nữa
/// thì chạy tiếp. Không có cách dừng thì người ta không kịp nhìn lá mình đang
/// để ý — vòng quay vẫn kéo nó đi.
class VongBaiTarot extends StatefulWidget {
  const VongBaiTarot({super.key, this.duongKinh = 300, this.beRongLa = 44});

  /// Đường kính vành bài.
  final double duongKinh;

  /// Bề rộng một lá. Chu vi chia cho 22 phải còn khoảng thở, không thì các lá
  /// chạm nhau thành một bức tường kín và chữ ở giữa không đọc nổi.
  final double beRongLa;

  @override
  State<VongBaiTarot> createState() => _VongBaiTarotState();
}

class _VongBaiTarotState extends State<VongBaiTarot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _quay;
  int? _dangChon;

  @override
  void initState() {
    super.initState();
    // Hai phút một vòng. Nhanh hơn thì nó giành mất sự chú ý của chữ nằm trên,
    // mà đây chỉ là nền.
    _quay = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 120),
    )..repeat();
  }

  @override
  void dispose() {
    _quay.dispose();
    super.dispose();
  }

  void _cham(int i) {
    setState(() {
      if (_dangChon == i) {
        _dangChon = null;
        _quay.repeat();
      } else {
        _dangChon = i;
        _quay.stop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dungLai = _dangChon != null;

    return SizedBox.square(
      dimension: widget.duongKinh,
      child: AnimatedBuilder(
        animation: _quay,
        builder: (context, _) {
          return Transform.rotate(
            angle: _quay.value * 2 * math.pi,
            child: Stack(
              children: [
                for (var i = 0; i < anChinh.length; i++)
                  // Mỗi lá nằm trong một lớp phủ kín vòng rồi xoay cả lớp quanh
                  // tâm. Không dời chỗ từng lá bằng toạ độ: tính tay thì sai số
                  // dồn lại và vành bài méo.
                  Transform.rotate(
                    angle: i * 2 * math.pi / anChinh.length,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: _La(
                        la: anChinh[i],
                        beRong: widget.beRongLa,
                        sang: _dangChon == i,
                        mo: dungLai && _dangChon != i,
                        // Xoay ngược đúng bằng góc của lớp, để lá luôn đứng
                        // thẳng thay vì nằm nghiêng theo vành.
                        buGoc:
                            -(i * 2 * math.pi / anChinh.length) -
                            _quay.value * 2 * math.pi,
                        onTap: () => _cham(i),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _La extends StatelessWidget {
  const _La({
    required this.la,
    required this.beRong,
    required this.sang,
    required this.mo,
    required this.buGoc,
    required this.onTap,
  });

  final LaAnChinh la;
  final double beRong;
  final bool sang;
  final bool mo;
  final double buGoc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: buGoc,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: sang ? 1 : (mo ? 0.25 : 0.5),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 250),
            scale: sang ? 1.3 : 1,
            child: Container(
              width: beRong,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: Mau.vang.withValues(alpha: sang ? 0.95 : 0.35),
                ),
                boxShadow: sang
                    ? [
                        BoxShadow(
                          color: Mau.vang.withValues(alpha: 0.5),
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              clipBehavior: Clip.antiAlias,
              child: AspectRatio(
                // Tỉ lệ lá Tarot thật, để ảnh không bị bóp méo.
                aspectRatio: 0.58,
                child: Image.network(
                  la.anh,
                  fit: BoxFit.cover,
                  // Giải mã ở đúng cỡ cần dùng. Hai mươi hai ảnh 220px giải mã
                  // nguyên cỡ là mấy chục megabyte bộ nhớ cho một thứ trang trí.
                  cacheWidth: (beRong * 3).round(),
                  // Lá hỏng ảnh thì để trống hẳn, đừng hiện biểu tượng vỡ —
                  // đây là nền, không đáng để người dùng chú ý vào chỗ lỗi.
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
