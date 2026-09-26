import 'package:flutter/material.dart';

import '../features/readers/slot.dart';
import '../theme.dart';

/// Ô tháng. Thứ hai đứng đầu, đúng cách lịch Việt Nam hay dùng.
class LuoiThang extends StatelessWidget {
  const LuoiThang({
    super.key,
    required this.thang,
    required this.chon,
    required this.doiNgay,
    required this.doiThang,
    this.loai = const {},
    this.soBuoi = const {},
    this.coTruoc = true,
    this.coSau = true,
    this.khoaQuaKhu = false,
  });

  /// Ngày bất kỳ trong tháng đang xem.
  final DateTime thang;
  final DateTime? chon;
  final ValueChanged<DateTime> doiNgay;
  final ValueChanged<int> doiThang;
  final Map<String, LoaiNgay> loai;
  final Map<String, int> soBuoi;
  final bool coTruoc;
  final bool coSau;

  /// Lịch đặt: ngày đã qua không bấm được. Lịch riêng vẫn xem buổi cũ.
  final bool khoaQuaKhu;

  static const _thu = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  static String khoa(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final dau = DateTime(thang.year, thang.month, 1);
    final soNgay = DateTime(thang.year, thang.month + 1, 0).day;
    final trong = (dau.weekday - 1) % 7;
    final hom = DateTime.now();
    final homNgay = DateTime(hom.year, hom.month, hom.day);

    return Column(
      children: [
        Row(
          children: [
            _Mui(
              tooltip: 'Tháng trước',
              icon: Icons.chevron_left,
              onTap: coTruoc ? () => doiThang(-1) : null,
            ),
            Expanded(
              child: Text(
                'Tháng ${thang.month} năm ${thang.year}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _Mui(
              tooltip: 'Tháng sau',
              icon: Icons.chevron_right,
              onTap: coSau ? () => doiThang(1) : null,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final t in _thu)
              Expanded(
                child: Text(
                  t,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, color: Mau.chuMo),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 1,
          children: [
            for (var i = 0; i < trong; i++) const SizedBox.shrink(),
            for (var d = 1; d <= soNgay; d++)
              _ONgay(
                ngay: DateTime(thang.year, thang.month, d),
                homNay: homNgay,
                chon: chon,
                loai: loai[khoa(DateTime(thang.year, thang.month, d))],
                so: soBuoi[khoa(DateTime(thang.year, thang.month, d))] ?? 0,
                onTap:
                    khoaQuaKhu &&
                        DateTime(thang.year, thang.month, d).isBefore(homNgay)
                    ? null
                    : () => doiNgay(DateTime(thang.year, thang.month, d)),
              ),
          ],
        ),
      ],
    );
  }
}

class _Mui extends StatelessWidget {
  const _Mui({required this.tooltip, required this.icon, required this.onTap});

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, color: onTap == null ? Mau.chuMo : Mau.vang),
    );
  }
}

class _ONgay extends StatelessWidget {
  const _ONgay({
    required this.ngay,
    required this.homNay,
    required this.chon,
    required this.loai,
    required this.so,
    required this.onTap,
  });

  final DateTime ngay;
  final DateTime homNay;
  final DateTime? chon;
  final LoaiNgay? loai;
  final int so;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dangChon =
        chon != null &&
        chon!.year == ngay.year &&
        chon!.month == ngay.month &&
        chon!.day == ngay.day;
    final laHomNay = ngay == homNay;
    final mauCham = switch (loai) {
      LoaiNgay.open => Mau.vang,
      LoaiNgay.full => Mau.chuMo,
      LoaiNgay.off => Colors.transparent,
      _ => Colors.transparent,
    };
    return Material(
      color: dangChon ? Mau.vang.withValues(alpha: 0.18) : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: dangChon
              ? Mau.vang
              : laHomNay
              ? Mau.vang.withValues(alpha: 0.7)
              : Colors.transparent,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        splashColor: Mau.vang.withValues(alpha: 0.2),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              laHomNay ? 'Nay' : '${ngay.day}',
              style: TextStyle(
                fontSize: laHomNay ? 11 : 13,
                fontWeight: dangChon || laHomNay ? FontWeight.w600 : null,
                color: dangChon
                    ? Mau.vang
                    : onTap == null || loai == LoaiNgay.past
                    ? Mau.chuMo.withValues(alpha: onTap == null ? 0.45 : 1)
                    : Mau.chu,
              ),
            ),
            if (so > 0)
              Text('$so', style: const TextStyle(fontSize: 9, color: Mau.vang))
            else if (loai == LoaiNgay.off)
              Container(
                margin: const EdgeInsets.only(top: 2),
                height: 4,
                width: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Mau.chuMo),
                ),
              )
            else
              Container(
                margin: const EdgeInsets.only(top: 2),
                height: 4,
                width: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: mauCham,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
