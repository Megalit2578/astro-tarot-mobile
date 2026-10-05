import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../features/home/daily_card.dart';
import '../theme.dart';

/// Quạt bài Tarot xoè ra như cầm trên tay — hình ảnh mở đầu trang chủ.
///
/// ## Vì sao không chép vòng tròn của web
///
/// Bản trước chép y nguyên `TarotWheel.tsx`: một vành tròn trọn vẹn với cả hai
/// mươi hai lá. Trên web vành ấy rộng tới 760px, chu vi 2388, nên mỗi lá được
/// 108px chỗ và hiện ở bề rộng 72px — đủ to để nhìn ra đó là lá bài.
///
/// Trên điện thoại khung chỉ cao 252px. Vành 252 có chu vi 790, chia cho hai
/// mươi hai lá còn 36px mỗi lá, nên lá phải thu xuống 28px. Một lá
/// Rider-Waite ở cỡ 28×48 là một vệt màu, không ai nhận ra là Tarot. Kết quả
/// nhìn ra một vòng hạt cườm.
///
/// Bố cục vòng tròn trọn vẹn đơn giản là không thu nhỏ xuống điện thoại được:
/// muốn lá to thì phải bớt lá, mà bớt lá thì không còn là vòng. Nên đổi hình:
/// quạt bài chỉ bày BẢY lá, mỗi lá rộng 76px — to gấp 2,7 lần bản vòng — và
/// chồng lên nhau đúng như một cỗ bài xoè trên tay.
///
/// ## Vì sao bảy lá, chồng một phần ba
///
/// Khoảng hở giữa hai lá bằng bán kính nhân góc cách nhau. Bảy lá trải trong
/// 60 độ thì cách nhau 10 độ; với bán kính 195 là hở 34px trên bề rộng 76px,
/// tức thấy được gần nửa mỗi lá. Thưa hơn thì rời rạc không ra cỗ bài, dày hơn
/// thì chỉ còn thấy rìa lá.
///
/// ## Vì sao tâm xoay nằm dưới khung
///
/// Quạt cần bán kính lớn mới hở đủ, nhưng bán kính lớn mà tâm nằm trong khung
/// thì quạt bị đẩy lên mất. Nên tâm đặt hẳn dưới đáy khung bằng [OverflowBox]:
/// bán kính vẫn lớn mà quạt vẫn nằm gọn trong phần nhìn thấy.
class QuatBaiTarot extends StatefulWidget {
  const QuatBaiTarot({
    super.key,
    this.cao = 196,
    this.onChon,
    this.homNay,
  });

  /// Chiều cao phần nhìn thấy.
  final double cao;

  /// Gọi khi người dùng chạm vào một lá, hoặc chạm lần nữa để bỏ chọn.
  final ValueChanged<LaAnChinh?>? onChon;

  /// Ngày dùng để chọn bộ bài. Chỉ để test cố định kết quả.
  final DateTime? homNay;

  @override
  State<QuatBaiTarot> createState() => _QuatBaiTarotState();
}

/// Số lá bày ra.
const _soLa = 7;

/// Nửa góc xoè, tính bằng độ.
const _nuaGoc = 30.0;

const _rongLa = 76.0;

/// Tỉ lệ lá Tarot thật. Lệch tỉ lệ này là ảnh bị bóp méo.
const _tiLeLa = 0.58;
const _caoLa = _rongLa / _tiLeLa;

/// Khoảng từ tâm xoay tới ĐÁY lá.
const _banKinh = 130.0;

/// Chừa trống phía trên quạt.
///
/// Lá nổi bật nhô lên khỏi hàng; không chừa chỗ thì phần nhô ra bị [ClipRect]
/// cắt mất, và viền vàng — thứ đáng ra chỉ cho mắt biết dừng ở đâu — biến mất.
const _dinh = 20.0;

class _QuatBaiTarotState extends State<QuatBaiTarot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dua;
  int? _dangChon;

  @override
  void initState() {
    super.initState();
    // Đu đưa rất chậm, mỗi chiều mười một giây. Đây là nền cho lời chào nằm
    // trên, nhanh hơn là nó giành mất sự chú ý.
    _dua = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 11),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _dua.dispose();
    super.dispose();
  }

  /// Bảy lá của hôm nay.
  ///
  /// Chọn theo ngày chứ không theo [Random]: lá phải giữ nguyên suốt cả ngày.
  /// Rút ngẫu nhiên mỗi lần dựng lại thì cuộn lên cuộn xuống là bộ bài đổi,
  /// nhìn như lỗi. Bước nhảy 3 và 22 lá nguyên tố cùng nhau nên bảy lá lấy ra
  /// không trùng nhau.
  List<LaAnChinh> get _bo {
    final n = widget.homNay ?? DateTime.now();
    final moc = DateTime(n.year, n.month, n.day)
        .difference(DateTime(n.year))
        .inDays;
    return [
      for (var i = 0; i < _soLa; i++)
        anChinh[(moc + i * 3) % anChinh.length],
    ];
  }

  void _cham(int i, List<LaAnChinh> bo) {
    setState(() => _dangChon = _dangChon == i ? null : i);
    widget.onChon?.call(_dangChon == null ? null : bo[_dangChon!]);
  }

  @override
  Widget build(BuildContext context) {
    final bo = _bo;
    // Lá giữa nhô lên sẵn khi chưa ai chạm vào đâu: quạt cần một điểm nhìn,
    // không thì bảy lá ngang nhau và mắt không biết dừng ở đâu.
    final noiBat = _dangChon ?? _soLa ~/ 2;

    return LayoutBuilder(
      builder: (context, khung) {
        // Thu nhỏ cho vừa bề ngang máy hẹp. Lá ngoài cùng nghiêng _nuaGoc nên
        // hộp bao nó rộng hơn chính nó; phải tính cả phần nghiêng ấy, không
        // thì trên máy 360px hai lá rìa bị cắt cụt.
        final g = _nuaGoc * math.pi / 180;
        final nuaRongLaNghieng =
            (_rongLa * math.cos(g) + _caoLa * math.sin(g)) / 2;
        final canNua =
            (_banKinh + _caoLa / 2) * math.sin(g) + nuaRongLaNghieng;
        final ti = khung.maxWidth / 2 < canNua
            ? (khung.maxWidth / 2) / canNua
            : 1.0;

        final rong = _rongLa * ti;
        final cao = _caoLa * ti;
        final banKinh = _banKinh * ti;

        return SizedBox(
          height: widget.cao,
          width: double.infinity,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              // Hộp quạt cao hơn khung và thò xuống dưới, nên tâm xoay nằm
              // ngoài tầm nhìn.
              maxHeight: _dinh + banKinh + cao,
              minHeight: _dinh + banKinh + cao,
              child: AnimatedBuilder(
                animation: _dua,
                builder: (context, con) {
                  // Cả quạt nghiêng qua lại bốn độ quanh chính tâm ấy.
                  final nghieng =
                      (_dua.value * 2 - 1) * 4 * math.pi / 180;
                  return Transform.rotate(
                    angle: _dangChon == null ? nghieng : 0,
                    alignment: Alignment.bottomCenter,
                    child: con,
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(top: _dinh),
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      // Vẽ lá nổi bật SAU CÙNG để nó nằm trên. Trước đây vẽ
                      // thẳng từ trái sang phải nên mấy lá bên phải đè lên lá
                      // giữa: nó vừa nhô lên vừa sáng viền mà vẫn bị che, nhìn
                      // ra một lá bị kẹt dưới chồng bài chứ không ra lá được
                      // chọn.
                      for (final i in [
                        for (var j = 0; j < _soLa; j++)
                          if (j != noiBat) j,
                        noiBat,
                      ])
                        Transform.rotate(
                          // Lá đầu ở -30 độ, lá cuối ở +30.
                          angle:
                              (-_nuaGoc + 2 * _nuaGoc * i / (_soLa - 1)) *
                              math.pi /
                              180,
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: banKinh),
                            child: _La(
                              la: bo[i],
                              rong: rong,
                              cao: cao,
                              sang: i == noiBat,
                              mo: _dangChon != null && i != _dangChon,
                              onTap: () => _cham(i, bo),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _La extends StatelessWidget {
  const _La({
    required this.la,
    required this.rong,
    required this.cao,
    required this.sang,
    required this.mo,
    required this.onTap,
  });

  final LaAnChinh la;
  final double rong;
  final double cao;
  final bool sang;
  final bool mo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        // Lá nổi bật nhô lên khỏi hàng, tính theo chiều cao chính nó nên thu
        // nhỏ trên máy hẹp thì vẫn cân.
        offset: sang ? const Offset(0, -0.12) : Offset.zero,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 260),
          opacity: mo ? 0.45 : 1,
          child: Container(
            width: rong,
            height: cao,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Mau.vang.withValues(alpha: sang ? 0.95 : 0.35),
              ),
              boxShadow: [
                if (sang)
                  BoxShadow(
                    color: Mau.vang.withValues(alpha: 0.45),
                    blurRadius: 24,
                    spreadRadius: 1,
                  )
                else
                  const BoxShadow(
                    color: Color(0x99000000),
                    blurRadius: 12,
                    offset: Offset(0, 3),
                  ),
              ],
              // Nền sẫm phía sau để lúc ảnh chưa tải xong vẫn ra hình lá bài,
              // không phải một ô trống.
              color: Mau.the,
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              la.anh,
              fit: BoxFit.cover,
              // Giải mã đúng cỡ cần dùng. Ảnh nguyên cỡ nhân bảy lá là mấy
              // chục megabyte bộ nhớ cho một thứ trang trí.
              cacheWidth: (rong * 3).round(),
              // Hỏng ảnh thì để nguyên nền sẫm có viền vàng — vẫn ra dáng lá
              // bài úp, chứ đừng hiện biểu tượng ảnh vỡ.
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
