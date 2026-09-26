import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../core/api/trang.dart';
import '../../widgets/hop_thoai.dart';
import '../../widgets/trang_thai.dart';
import 'money_repository.dart';
import 'payout_sheet.dart';

/// Thu nhập của Reader: số dư, lịch sử ký quỹ, và yêu cầu rút tiền.
///
/// KHÔNG có Scaffold hay AppBar riêng: màn này luôn nằm trong Bàn làm việc,
/// vốn đã có thanh tiêu đề của nó. Bọc thêm một Scaffold nữa là hai thanh
/// tiêu đề chồng lên nhau.
class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen> {
  /// Các trang đã dồn thêm sau trang đầu. Trang đầu vẫn do provider giữ, để
  /// mở màn là có ngay cái gì đó thay vì một vòng xoay.
  Trang<GiaoDichKyQuy>? _gdDon;
  Trang<YeuCauRut>? _ycDon;
  bool _dangTaiGd = false;
  bool _dangTaiYc = false;

  /// Kéo làm mới thì bỏ hết phần đã dồn — giữ lại là trộn dữ liệu cũ với mới.
  void _datLai() {
    setState(() {
      _gdDon = null;
      _ycDon = null;
    });
  }

  Future<void> _taiThemGd(Trang<GiaoDichKyQuy> hien) async {
    if (_dangTaiGd || !hien.conNua) return;
    setState(() => _dangTaiGd = true);
    try {
      final sau =
          await ref.read(moneyRepositoryProvider).giaoDich(trang: hien.so + 1);
      if (mounted) setState(() => _gdDon = hien.noi(sau));
    } catch (e) {
      if (mounted) baoLoi(context, e, 'Khong tai them duoc so ky quy.');
    } finally {
      if (mounted) setState(() => _dangTaiGd = false);
    }
  }

  Future<void> _taiThemYc(Trang<YeuCauRut> hien) async {
    if (_dangTaiYc || !hien.conNua) return;
    setState(() => _dangTaiYc = true);
    try {
      final sau =
          await ref.read(moneyRepositoryProvider).yeuCauRut(trang: hien.so + 1);
      if (mounted) setState(() => _ycDon = hien.noi(sau));
    } catch (e) {
      if (mounted) baoLoi(context, e, 'Khong tai them duoc lenh rut.');
    } finally {
      if (mounted) setState(() => _dangTaiYc = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sd = ref.watch(soDuProvider);
    // Trang dau tu provider, cong voi nhung trang da bam "Tai them".
    final gd = _gdDon ?? ref.watch(giaoDichProvider).asData?.value;
    final yc = _ycDon ?? ref.watch(yeuCauRutProvider).asData?.value;
    final gdDangTai = _gdDon == null && ref.watch(giaoDichProvider).isLoading;

    return RefreshIndicator(
        color: Mau.vang,
        backgroundColor: Mau.the,
        onRefresh: () async {
          _datLai();
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
                          _datLai();
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

              ...switch (yc) {
                final t? when t.muc.isNotEmpty => [
                    const SizedBox(height: 26),
                    _Nhan('Yêu cầu rút tiền',
                        phu: '${t.muc.length}/${t.tongSo}'),
                    const SizedBox(height: 10),
                    for (final y in t.muc) _TheRut(y: y),
                    if (t.conNua)
                      NutTaiThem(
                          dangTai: _dangTaiYc, bam: () => _taiThemYc(t)),
                  ],
                _ => const <Widget>[],
              },

              const SizedBox(height: 26),
              _Nhan('Lịch sử ký quỹ',
                  phu: gd == null ? null : '${gd.muc.length}/${gd.tongSo}'),
              const SizedBox(height: 10),
              ...switch (gd) {
                final t? when t.muc.isNotEmpty => [
                    for (final g in t.muc) _TheGiaoDich(g: g),
                    if (t.conNua)
                      NutTaiThem(
                          dangTai: _dangTaiGd, bam: () => _taiThemGd(t)),
                  ],
                final t? when t.muc.isEmpty => const [
                    Text('Chưa có giao dịch nào.',
                        style: TextStyle(fontSize: 12.5, color: Mau.chuMo)),
                  ],
                _ when gdDangTai => const [
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
                _ => const <Widget>[],
              },
            ],
          ),
        ),
    );
  }
}

class _Nhan extends StatelessWidget {
  const _Nhan(this.text, {this.phu});
  final String text;

  /// Dem "da hien / tong so", vi du 20/143.
  ///
  /// Khong co con so nay thi nut "Tai them" la dau hieu duy nhat cho biet con
  /// nua, va khi het trang thi nut bien mat — nguoi dung khong biet minh dang
  /// nhin toan bo hay mot phan.
  final String? phu;

  @override
  Widget build(BuildContext context) {
    const kieu =
        TextStyle(fontSize: 12, color: Mau.chuMo, letterSpacing: 0.4);
    final p = phu;
    if (p == null) return Text(text, style: kieu);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(text, style: kieu),
        Text(p, style: const TextStyle(fontSize: 11, color: Mau.chuMo)),
      ],
    );
  }
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
    final huong = huongTien(g.loai);
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
            '${huong > 0 ? '+' : (huong < 0 ? '−' : '')}${Dinh.tien(g.soTien.abs())}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: huong < 0
                  ? const Color(0xFFE5645E)
                  : (huong > 0 ? const Color(0xFF6BBF7B) : Mau.chuMo),
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
                  if (y.lyDoTuChoi != null) ...[
                    const SizedBox(height: 3),
                    Text('Lý do: ${y.lyDoTuChoi}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFFE5645E))),
                  ],
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
