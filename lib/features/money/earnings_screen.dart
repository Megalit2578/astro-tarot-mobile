import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/trang_thai.dart';
import 'money_repository.dart';
import 'payout_sheet.dart';

/// Thu nhập của Reader: số dư, lịch sử ký quỹ, và yêu cầu rút tiền.
///
/// KHÔNG có Scaffold hay AppBar riêng: màn này luôn nằm trong Bàn làm việc,
/// vốn đã có thanh tiêu đề của nó. Bọc thêm một Scaffold nữa là hai thanh
/// tiêu đề chồng lên nhau.
class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sd = ref.watch(soDuProvider);
    final gd = ref.watch(giaoDichProvider);
    final yc = ref.watch(yeuCauRutProvider);

    return RefreshIndicator(
        color: Mau.vang,
        backgroundColor: Mau.the,
        onRefresh: () async {
          ref.invalidate(soDuProvider);
          ref.invalidate(giaoDichProvider);
          ref.invalidate(yeuCauRutProvider);
          await ref.read(soDuProvider.future);
        },
        child: sd.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: Mau.vang)),
          error: (e, _) => KhoiLoi(
            thongDiep:
                e is ApiException ? e.message : 'Không tải được thu nhập.',
            thuLai: () => ref.invalidate(soDuProvider),
          ),
          data: (s) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _KhoiSoDu(s: s),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: s.duDieuKienRut
                    ? () async {
                        final ok = await moXinRut(context, s);
                        if (ok) {
                          ref.invalidate(soDuProvider);
                          ref.invalidate(yeuCauRutProvider);
                        }
                      }
                    : null,
                icon: const Icon(Icons.account_balance_outlined, size: 18),
                label: const Text('Yêu cầu rút tiền'),
              ),
              if (!s.duDieuKienRut) ...[
                const SizedBox(height: 8),
                // Nói RÕ vì sao nút bị khoá. Nút xám không lời giải thích là
                // kiểu giao diện khiến người dùng bấm đi bấm lại rồi bỏ cuộc.
                Text(
                  s.soDu <= 0
                      ? 'Chưa có tiền trong số dư để rút.'
                      : 'Số dư phải đạt tối thiểu '
                          '${Dinh.tien(s.mucRutToiThieu)} mới rút được. '
                          'Bạn đang có ${Dinh.tien(s.soDu)}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11.5, color: Mau.chuMo, height: 1.6),
                ),
              ],

              ...switch (yc.asData?.value) {
                final l? when l.isNotEmpty => [
                    const SizedBox(height: 26),
                    const _Nhan('Yêu cầu rút tiền'),
                    const SizedBox(height: 10),
                    for (final y in l) _TheRut(y: y),
                  ],
                _ => const <Widget>[],
              },

              const SizedBox(height: 26),
              const _Nhan('Lịch sử ký quỹ'),
              const SizedBox(height: 10),
              ...switch (gd.asData?.value) {
                final l? when l.isNotEmpty => [
                    for (final g in l) _TheGiaoDich(g: g),
                  ],
                final l? when l.isEmpty => const [
                    Text('Chưa có giao dịch nào.',
                        style: TextStyle(fontSize: 12.5, color: Mau.chuMo)),
                  ],
                _ => const [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Mau.vang),
                        ),
                      ),
                    ),
                  ],
              },
            ],
          ),
        ),
    );
  }
}

class _Nhan extends StatelessWidget {
  const _Nhan(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 12, color: Mau.chuMo, letterSpacing: 0.4));
}

class _KhoiSoDu extends StatelessWidget {
  const _KhoiSoDu({required this.s});
  final SoDu s;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Mau.the,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Mau.vien),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rút được ngay',
              style: TextStyle(fontSize: 12, color: Mau.chuMo)),
          const SizedBox(height: 4),
          Text(Dinh.tien(s.soDu),
              style: const TextStyle(
                  fontSize: 27,
                  color: Mau.vang,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _O(nhan: 'Đang chờ về', v: s.choVe)),
              Expanded(child: _O(nhan: 'Tổng đã kiếm', v: s.tongKiemDuoc)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _O(nhan: 'Đã rút', v: s.daRut)),
              Expanded(
                child: _O(
                  nhan: 'Đang bị trừ phạt',
                  v: s.tienPhat,
                  canhBao: s.tienPhat > 0,
                ),
              ),
            ],
          ),
          if (s.choVe > 0) ...[
            const SizedBox(height: 14),
            // Giải thích "đang chờ về", nếu không Reader thấy tiền ở đó mà
            // rút không được và tưởng hệ thống giữ tiền vô cớ.
            const Text(
              '"Đang chờ về" là tiền của buổi đã xong nhưng còn trong thời '
              'gian giữ để phòng khiếu nại. Hết hạn giữ thì nó tự chuyển sang '
              'số dư rút được.',
              style:
                  TextStyle(fontSize: 11, color: Mau.chuMo, height: 1.6),
            ),
          ],
        ],
      ),
    );
  }
}

class _O extends StatelessWidget {
  const _O({required this.nhan, required this.v, this.canhBao = false});
  final String nhan;
  final int v;
  final bool canhBao;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(nhan, style: const TextStyle(fontSize: 11, color: Mau.chuMo)),
        const SizedBox(height: 3),
        Text(
          Dinh.tien(v),
          style: TextStyle(
            fontSize: 14,
            color: canhBao ? const Color(0xFFE5645E) : Mau.chu,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _TheGiaoDich extends StatelessWidget {
  const _TheGiaoDich({required this.g});
  final GiaoDichKyQuy g;

  @override
  Widget build(BuildContext context) {
    // Tiền vào màu xanh, tiền ra màu đỏ. Dấu cộng/trừ thôi thì trên màn nhỏ
    // rất dễ đọc lướt qua.
    final ra = g.soTien < 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nhanLoaiGiaoDich(g.loai),
                    style: const TextStyle(fontSize: 13)),
                if (g.ghiChu != null && g.ghiChu!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(g.ghiChu!,
                      style: const TextStyle(
                          fontSize: 11, color: Mau.chuMo)),
                ],
                if (g.luc != null) ...[
                  const SizedBox(height: 2),
                  Text(Dinh.ngayGio(g.luc),
                      style: const TextStyle(
                          fontSize: 10.5, color: Mau.chuMo)),
                ],
              ],
            ),
          ),
          Text(
            '${ra ? '' : '+'}${Dinh.tien(g.soTien)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color:
                  ra ? const Color(0xFFE5645E) : const Color(0xFF6BBF7B),
            ),
          ),
        ],
      ),
    );
  }
}

class _TheRut extends StatelessWidget {
  const _TheRut({required this.y});
  final YeuCauRut y;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(Dinh.tien(y.soTien),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (y.nganHang != null) y.nganHang!,
                      if (y.soTaiKhoan != null) y.soTaiKhoan!,
                      if (y.luc != null) Dinh.ngay(y.luc),
                    ].join(' · '),
                    style:
                        const TextStyle(fontSize: 11, color: Mau.chuMo),
                  ),
                ],
              ),
            ),
            Text(nhanTrangThaiRut(y.trangThai),
                style: const TextStyle(fontSize: 11, color: Mau.vang)),
          ],
        ),
      ),
    );
  }
}
