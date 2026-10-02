import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/trang_thai.dart';
import 'goi_ai_repository.dart';
import 'vi_repository.dart';

/// Gói AI và ví — phần web đã có mà app chưa có.
///
/// ## Vì sao gộp ví vào cùng màn
///
/// Trên web, ví và gói AI nằm ở hai chỗ. Trên điện thoại thì tách ra lại thành
/// phiền: muốn mua gói phải nhớ sang màn khác nạp tiền trước, rồi quay lại tìm
/// đúng gói. Đặt số dư ngay trên đầu danh sách gói thì người dùng thấy ngay
/// mình đủ tiền hay chưa, trước khi bấm vào gói nào.
///
/// ## Vì sao mua bằng ví chứ không qua cổng thanh toán
///
/// Dẫn người dùng rời app sang cổng rồi quay lại là một đường vòng dễ đứt —
/// nhất là khi app chưa có liên kết sâu để bắt lại lượt quay về. Nạp ví một
/// lần rồi mua nhiều lần bằng số dư thì mỗi lần mua chỉ còn một cú bấm.
class GoiAiScreen extends ConsumerWidget {
  const GoiAiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = ref.watch(goiDangBanProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gói AI')),
      body: RefreshIndicator(
        color: Mau.vang,
        backgroundColor: Mau.the,
        onRefresh: () async {
          ref.invalidate(goiDangBanProvider);
          ref.invalidate(viCuaToiProvider);
          ref.invalidate(goiCuaToiProvider);
          ref.invalidate(luotDungHomNayProvider);
          await ref.read(goiDangBanProvider.future);
        },
        child: ds.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: Mau.vang)),
          error: (e, _) => KhoiLoi(
            thongDiep: e is ApiException
                ? e.message
                : 'Không tải được danh sách gói. Thử lại sau.',
            thuLai: () => ref.invalidate(goiDangBanProvider),
          ),
          data: (goi) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              const _TheVi(),
              const SizedBox(height: 12),
              const _HanMucHomNay(),
              const SizedBox(height: 20),
              const Text(
                'Chọn gói',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (goi.isEmpty)
                const KhoiTrong(
                  icon: Icons.auto_awesome,
                  tieuDe: 'Chưa có gói nào đang bán',
                )
              else
                for (final g in goi) _TheGoi(goi: g),
              const SizedBox(height: 20),
              const _LuotMuaCuaToi(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Số dư ví, kèm lối nạp thêm.
class _TheVi extends ConsumerWidget {
  const _TheVi();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vi = ref.watch(viCuaToiProvider);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Mau.vang.withValues(alpha: 0.35)),
        color: Mau.the,
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet_outlined, color: Mau.vang),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Số dư ví',
                  style: TextStyle(fontSize: 12, color: Mau.chuMo),
                ),
                const SizedBox(height: 2),
                Text(
                  vi.when(
                    loading: () => '…',
                    error: (_, _) => '—',
                    data: (v) => Dinh.tien(v.soDu),
                  ),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Mau.vangNhat,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => _moNap(context, ref),
            child: const Text('Nạp tiền'),
          ),
        ],
      ),
    );
  }
}

/// Hạn mức hôm nay: đã dùng bao nhiêu trên tổng bao nhiêu.
class _HanMucHomNay extends ConsumerWidget {
  const _HanMucHomNay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daDung = ref.watch(luotDungHomNayProvider).asData?.value ?? 0;
    final goi = ref.watch(goiCuaToiProvider).asData?.value ?? const [];
    final dangChay = goi.where((g) => g.dangChay).toList();

    // Không có gói nào đang chạy thì vẫn còn hạn mức miễn phí của hệ thống.
    // Không bịa con số ấy ra ở đây: chỉ nói đang dùng gói miễn phí, để mình
    // không nói một đằng mà máy chủ chặn một nẻo.
    final ten = dangChay.isEmpty ? 'Gói miễn phí' : dangChay.first.tenGoi;
    final tong = dangChay.isEmpty ? null : dangChay.first.hanMucNgay;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Mau.vien),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ten,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                tong == null ? '$daDung lượt hôm nay' : '$daDung / $tong',
                style: const TextStyle(color: Mau.chuMo, fontSize: 13),
              ),
            ],
          ),
          if (tong != null && tong > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (daDung / tong).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: Mau.vien,
                valueColor: const AlwaysStoppedAnimation(Mau.vang),
              ),
            ),
          ],
          if (dangChay.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Còn ${dangChay.first.soNgayConLai} ngày',
              style: const TextStyle(color: Mau.chuMo, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _TheGoi extends ConsumerStatefulWidget {
  const _TheGoi({required this.goi});
  final GoiAi goi;

  @override
  ConsumerState<_TheGoi> createState() => _TheGoiState();
}

class _TheGoiState extends ConsumerState<_TheGoi> {
  bool _dangMua = false;

  Future<void> _mua() async {
    final g = widget.goi;
    final soDu = ref.read(viCuaToiProvider).asData?.value.soDu ?? 0;

    // Chặn ở đây thay vì để máy chủ trả lỗi: câu "số dư không đủ" nói rõ còn
    // thiếu bao nhiêu thì người dùng biết phải nạp bao nhiêu, còn lỗi từ máy
    // chủ chỉ nói là thất bại.
    if (soDu < g.gia) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Số dư còn ${Dinh.tien(soDu)}, thiếu '
            '${Dinh.tien(g.gia - soDu)} để mua ${g.ten}.',
          ),
        ),
      );
      return;
    }

    final dong = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Mau.the,
        title: const Text('Xác nhận mua'),
        content: Text(
          'Mua ${g.ten} với giá ${Dinh.tien(g.gia)}?\n\n'
          'Tiền trừ thẳng từ số dư ví. Sau khi mua, số dư còn '
          '${Dinh.tien(soDu - g.gia)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Thôi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Mua'),
          ),
        ],
      ),
    );
    if (dong != true) return;

    setState(() => _dangMua = true);
    try {
      await ref.read(goiAiRepositoryProvider).mua(g.id);
      ref.invalidate(viCuaToiProvider);
      ref.invalidate(goiCuaToiProvider);
      ref.invalidate(giaoDichViProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Đã mua ${g.ten}.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'Mua không thành công.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _dangMua = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.goi;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Mau.vien),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  g.ten,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                Dinh.tien(g.gia),
                style: const TextStyle(
                  color: Mau.vangNhat,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${g.hanMucNgay} lượt AI mỗi ngày · ${nhanLoaiGoi(g.loai)} · '
            '${g.soNgay} ngày',
            style: const TextStyle(color: Mau.chuMo, fontSize: 12.5),
          ),
          if (g.moTa != null && g.moTa!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              g.moTa!,
              style: const TextStyle(color: Mau.chuMo, fontSize: 12.5),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _dangMua ? null : _mua,
              child: Text(_dangMua ? 'Đang mua…' : 'Mua bằng ví'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LuotMuaCuaToi extends ConsumerWidget {
  const _LuotMuaCuaToi();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = ref.watch(goiCuaToiProvider).asData?.value ?? const [];
    if (ds.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gói đã mua',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        for (final m in ds)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              m.dangChay ? Icons.check_circle_outline : Icons.history,
              color: m.dangChay ? Mau.vang : Mau.chuMo,
            ),
            title: Text(m.tenGoi, style: const TextStyle(fontSize: 14)),
            subtitle: Text(
              m.dangChay
                  ? 'Đang dùng · còn ${m.soNgayConLai} ngày'
                  : 'Đã hết hạn ${Dinh.ngayGio(m.ketThuc)}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Text(
              Dinh.tien(m.gia),
              style: const TextStyle(fontSize: 13, color: Mau.chuMo),
            ),
          ),
      ],
    );
  }
}

/// Mở ô nhập số tiền nạp.
Future<void> _moNap(BuildContext context, WidgetRef ref) async {
  final o = TextEditingController();
  final soTien = await showDialog<int>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: Mau.the,
      title: const Text('Nạp tiền vào ví'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: o,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Số tiền',
              suffixText: 'đ',
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final m in [50000, 100000, 200000, 500000])
                ActionChip(
                  label: Text(Dinh.tien(m)),
                  onPressed: () => o.text = '$m',
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Thôi'),
        ),
        FilledButton(
          onPressed: () {
            final v = int.tryParse(o.text.trim());
            if (v != null && v > 0) Navigator.pop(c, v);
          },
          child: const Text('Tạo mã nạp'),
        ),
      ],
    ),
  );
  if (soTien == null) return;

  try {
    final h = await ref.read(viRepositoryProvider).nap(soTien);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Mau.the,
        title: const Text('Chuyển khoản để nạp'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Số tiền: ${Dinh.tien(h.soTien)}'),
            if (h.tenNganHang != null) Text('Ngân hàng: ${h.tenNganHang}'),
            if (h.soTaiKhoan != null) Text('Số tài khoản: ${h.soTaiKhoan}'),
            if (h.chuTaiKhoan != null) Text('Chủ tài khoản: ${h.chuTaiKhoan}'),
            if (h.noiDung != null) ...[
              const SizedBox(height: 8),
              const Text(
                'Nội dung chuyển khoản — ghi ĐÚNG:',
                style: TextStyle(fontSize: 12, color: Mau.chuMo),
              ),
              SelectableText(
                h.noiDung!,
                style: const TextStyle(
                  color: Mau.vangNhat,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Sai nội dung thì hệ thống không khớp được lượt chuyển với ví '
                'của bạn, và tiền phải đối soát tay.',
                style: TextStyle(fontSize: 11.5, color: Mau.chuMo),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              ref.invalidate(viCuaToiProvider);
              ref.invalidate(giaoDichViProvider);
            },
            child: const Text('Xong'),
          ),
        ],
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          e is ApiException ? e.message : 'Không tạo được lệnh nạp.',
        ),
      ),
    );
  }
}
