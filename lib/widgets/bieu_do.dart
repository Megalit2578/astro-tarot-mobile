import 'package:flutter/material.dart';

import '../theme.dart';

/// Một thanh trong biểu đồ.
class ThanhSo {
  const ThanhSo(this.nhan, this.giaTri, {this.mau = Mau.vang, this.chuSo});
  final String nhan;
  final num giaTri;
  final Color mau;

  /// Cách hiện con số; mặc định là số nguyên có dấu chấm ngăn cách.
  final String? chuSo;
}

/// Biểu đồ thanh nằm ngang.
///
/// Web dùng Recharts với cột đứng và biểu đồ bánh. Trên màn dọc 360dp, cột
/// đứng chỉ còn vài pixel mỗi cột và nhãn trục X chồng lên nhau; bánh thì
/// không đọc được số. Thanh ngang giữ đủ chỗ cho nhãn đầy đủ và con số, và
/// vẫn so được lớn nhỏ bằng mắt — thứ biểu đồ ở đây cần làm.
class BieuDoThanh extends StatelessWidget {
  const BieuDoThanh({
    super.key,
    required this.tieuDe,
    required this.thanh,
    this.ghiChu,
  });

  final String tieuDe;
  final List<ThanhSo> thanh;
  final String? ghiChu;

  @override
  Widget build(BuildContext context) {
    final lonNhat = thanh.fold<num>(0, (m, t) => t.giaTri > m ? t.giaTri : m);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tieuDe,
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w600)),
            if (ghiChu != null) ...[
              const SizedBox(height: 3),
              Text(ghiChu!,
                  style: const TextStyle(fontSize: 11.5, color: Mau.chuMo)),
            ],
            const SizedBox(height: 12),
            if (thanh.isEmpty || lonNhat == 0)
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text('Chưa có số liệu.',
                    style: TextStyle(fontSize: 12, color: Mau.chuMo)),
              )
            else
              for (final t in thanh) _Dong(t: t, lonNhat: lonNhat),
          ],
        ),
      ),
    );
  }
}

class _Dong extends StatelessWidget {
  const _Dong({required this.t, required this.lonNhat});
  final ThanhSo t;
  final num lonNhat;

  @override
  Widget build(BuildContext context) {
    final ti = lonNhat == 0 ? 0.0 : (t.giaTri / lonNhat).clamp(0, 1).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(t.nhan,
                    style: const TextStyle(fontSize: 12, color: Mau.chuMo)),
              ),
              Text(t.chuSo ?? dinhSo(t.giaTri),
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                Container(height: 8, color: const Color(0xFF0F0F16)),
                FractionallySizedBox(
                  widthFactor: ti,
                  child: Container(height: 8, color: t.mau),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ô số liệu lớn: nhãn, con số, dòng gợi ý nhỏ.
class OSoLieu extends StatelessWidget {
  const OSoLieu({
    super.key,
    required this.nhan,
    required this.so,
    this.goiY,
    this.icon,
    this.canChuY = false,
  });

  final String nhan;
  final String so;
  final String? goiY;
  final IconData? icon;

  /// Có việc tồn đọng cần người trực nhìn tới — tô vàng để nổi lên.
  final bool canChuY;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Mau.the,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: canChuY ? Mau.vang.withValues(alpha: 0.6) : Mau.vien),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) Icon(icon, size: 18, color: Mau.vang),
          if (icon != null) const SizedBox(height: 6),
          Text(so,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w600, color: Mau.chu)),
          const SizedBox(height: 2),
          Text(nhan,
              maxLines: 2,
              style: const TextStyle(fontSize: 12, color: Mau.chu)),
          if (goiY != null) ...[
            const SizedBox(height: 3),
            Text(goiY!,
                maxLines: 2,
                style: const TextStyle(fontSize: 10.5, color: Mau.chuMo)),
          ],
        ],
      ),
    );
  }
}

/// Lưới hai cột cho các [OSoLieu] — vừa màn dọc mà không phải cuộn ngang.
class LuoiSoLieu extends StatelessWidget {
  const LuoiSoLieu({super.key, required this.o});
  final List<Widget> o;

  @override
  Widget build(BuildContext context) {
    final hang = <Widget>[];
    for (var i = 0; i < o.length; i += 2) {
      hang.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: o[i]),
              const SizedBox(width: 10),
              Expanded(child: i + 1 < o.length ? o[i + 1] : const SizedBox()),
            ],
          ),
        ),
      ));
    }
    return Column(children: hang);
  }
}

/// `1234567` → `1.234.567` (không kèm đơn vị).
String dinhSo(num n) {
  final s = n.round().abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return n < 0 ? '-$b' : b.toString();
}
