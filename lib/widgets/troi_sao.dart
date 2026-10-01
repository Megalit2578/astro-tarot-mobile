import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Bầu trời sao làm nền cho cả app.
///
/// Chép ý của `StarrySky.tsx` bên web. App trước đây là nền đen trơn tuyệt
/// đối ở mọi màn hình — chạy đủ chức năng nhưng nhìn phẳng, không ra cùng một
/// sản phẩm với trang web.
///
/// ## Vì sao vẽ bằng CustomPainter chứ không phải 198 widget
///
/// Bản web dựng mỗi ngôi sao là một thẻ `<span>` và để CSS lo phần nháy. Dịch
/// thẳng sang Flutter thành 198 widget nằm sau MỌI màn hình thì mỗi khung hình
/// phải dựng lại từng ấy phần tử, trên máy yếu là thấy giật ngay. Một
/// CustomPainter vẽ 198 hình tròn rẻ hơn nhiều bậc.
///
/// ## Ba tầng độ sâu
///
/// Tầng xa: nhiều sao nhỏ mờ, nháy chậm. Tầng giữa: vừa. Tầng gần: ít sao to,
/// có quầng sáng, nháy nhanh hơn. Mắt đọc ra chiều sâu từ chênh lệch đó — một
/// tầng duy nhất thì trông như giấy dán tường chấm bi.
///
/// Chỉ tầng gần mới có quầng. Rải quầng khắp nơi thì bầu trời bị đục, mất cảm
/// giác đen sâu.
class TroiSao extends StatefulWidget {
  const TroiSao({super.key});

  @override
  State<TroiSao> createState() => _TroiSaoState();
}

class _TroiSaoState extends State<TroiSao> with SingleTickerProviderStateMixin {
  late final AnimationController _nhip;
  late final List<_Sao> _sao;

  @override
  void initState() {
    super.initState();
    // Một chu kỳ dài làm đồng hồ chung; mỗi ngôi sao tự lấy pha và chu kỳ
    // riêng từ đó, nên cả bầu trời không nháy đồng loạt.
    _nhip = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();

    // Hạt cố định: vị trí sao phải giữ nguyên qua mỗi lần dựng lại, không thì
    // cứ đổi màn hình là cả bầu trời nhảy sang chỗ khác.
    _sao = [
      ..._tang(
        seed: 1337,
        soLuong: 120,
        coTu: 1.0,
        coDen: 1.6,
        moTu: 0.30,
        moDen: 0.60,
        chuKyTu: 5.0,
        chuKyDen: 9.0,
        quang: false,
      ),
      ..._tang(
        seed: 7331,
        soLuong: 60,
        coTu: 1.6,
        coDen: 2.3,
        moTu: 0.55,
        moDen: 0.85,
        chuKyTu: 3.5,
        chuKyDen: 6.0,
        quang: false,
      ),
      ..._tang(
        seed: 9137,
        soLuong: 18,
        coTu: 2.4,
        coDen: 3.4,
        moTu: 0.85,
        moDen: 1.0,
        chuKyTu: 2.5,
        chuKyDen: 4.5,
        quang: true,
      ),
    ];
  }

  @override
  void dispose() {
    _nhip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary để phần nháy của bầu trời không kéo theo cả cây widget
    // của màn hình đang nằm trên nó phải vẽ lại.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _nhip,
        builder: (_, _) => CustomPaint(
          painter: _VeTroiSao(sao: _sao, t: _nhip.value * 60),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Sao {
  const _Sao(
    this.x,
    this.y,
    this.co,
    this.mo,
    this.chuKy,
    this.pha,
    this.quang,
  );

  /// Toạ độ theo tỉ lệ 0..1 của khung, để đổi cỡ màn hình không phải tính lại.
  final double x;
  final double y;
  final double co;
  final double mo;
  final double chuKy;
  final double pha;
  final bool quang;
}

List<_Sao> _tang({
  required int seed,
  required int soLuong,
  required double coTu,
  required double coDen,
  required double moTu,
  required double moDen,
  required double chuKyTu,
  required double chuKyDen,
  required bool quang,
}) {
  final r = math.Random(seed);
  return List.generate(soLuong, (_) {
    return _Sao(
      r.nextDouble(),
      r.nextDouble(),
      coTu + r.nextDouble() * (coDen - coTu),
      moTu + r.nextDouble() * (moDen - moTu),
      chuKyTu + r.nextDouble() * (chuKyDen - chuKyTu),
      r.nextDouble() * 8,
      quang,
    );
  });
}

class _VeTroiSao extends CustomPainter {
  _VeTroiSao({required this.sao, required this.t});

  final List<_Sao> sao;

  /// Thời gian tính bằng giây trong chu kỳ chung.
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    _veTinhVan(canvas, size);

    final but = Paint()..color = Colors.white;
    final butQuang = Paint()
      ..color = Colors.white
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    for (final s in sao) {
      // Nháy: dao động quanh độ sáng riêng, không bao giờ tắt hẳn. Tắt hẳn
      // rồi sáng lại trông như lỗi vẽ chứ không như sao.
      final pha = (t / s.chuKy + s.pha) * 2 * math.pi;
      final heSo = 0.65 + 0.35 * math.sin(pha);
      final mo = (s.mo * heSo).clamp(0.0, 1.0);
      final tam = Offset(s.x * size.width, s.y * size.height);

      if (s.quang) {
        canvas.drawCircle(
          tam,
          s.co * 2.2,
          butQuang..color = Colors.white.withValues(alpha: mo * 0.35),
        );
      }
      canvas.drawCircle(
        tam,
        s.co / 2,
        but..color = Colors.white.withValues(alpha: mo),
      );
    }
  }

  /// Hai vệt sáng rất mờ cho bầu trời khỏi chết cứng. Độ mờ phải thật thấp —
  /// nền vẫn phải giữ được cảm giác đen.
  void _veTinhVan(Canvas canvas, Size size) {
    void vet(Offset tamTiLe, double banKinhTiLe, Color mau) {
      final tam = Offset(tamTiLe.dx * size.width, tamTiLe.dy * size.height);
      final r = banKinhTiLe * size.width;
      canvas.drawCircle(
        tam,
        r,
        Paint()
          ..shader = RadialGradient(colors: [mau, mau.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: tam, radius: r)),
      );
    }

    vet(const Offset(0.18, 0.22), 0.55, const Color(0x1A6D4BA8));
    vet(const Offset(0.82, 0.72), 0.5, const Color(0x174A5BA8));
  }

  @override
  bool shouldRepaint(_VeTroiSao cu) => cu.t != t;
}

/// Bọc một màn hình lên trên nền sao.
///
/// Dùng ở `MaterialApp.builder` để mọi màn đều có nền, thay vì từng màn tự
/// thêm — cách sau thì sớm muộn có màn bị quên, và nền sẽ nhảy mất khi chuyển
/// trang.
class NenSao extends StatelessWidget {
  const NenSao({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Mau.nen,
      child: Stack(
        children: [
          const Positioned.fill(child: TroiSao()),
          child,
        ],
      ),
    );
  }
}
