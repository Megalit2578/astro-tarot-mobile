import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/trang_thai.dart';
import 'admin_models.dart';

/// Nạp một hàng chờ quản trị.
///
/// Backend trả khi thì mảng phẳng, khi thì trang `{content: [...]}`. Nhận cả
/// hai: đoán sai một cái là màn hình rỗng mà không báo lỗi gì, và đó là kiểu
/// hỏng khó nhận ra nhất vì "rỗng" trông y hệt "chưa có việc nào".
final hangChoProvider =
    FutureProvider.family<List<MucDuyet>, String>((ref, duong) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get<dynamic>(duong, query: {'page': 0, 'size': 50});
  final list = data is Map ? data['content'] : data;
  if (list is! List) return const [];
  return list
      .whereType<Map<String, dynamic>>()
      .map(MucDuyet.fromJson)
      .toList();
});

/// Màn hàng chờ dùng chung cho thanh toán, rút tiền và duyệt Reader.
///
/// Ba hàng chờ ấy khác nhau ở nhãn và đường dẫn, còn thao tác thì y hệt:
/// nhìn danh sách, bấm duyệt hoặc từ chối. Viết ba bản sao thì sửa một lỗi
/// phải sửa ba chỗ, và chắc chắn sẽ có chỗ bị quên.
class HangChoScreen extends ConsumerWidget {
  const HangChoScreen({
    super.key,
    required this.tieuDe,
    required this.duong,
    required this.hanhDong,
    this.moTaTrong,
  });

  final String tieuDe;
  final String duong;
  final List<HanhDongDuyet> hanhDong;
  final String? moTaTrong;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = ref.watch(hangChoProvider(duong));

    return Scaffold(
      appBar: AppBar(title: Text(tieuDe)),
      body: RefreshIndicator(
        color: Mau.vang,
        backgroundColor: Mau.the,
        onRefresh: () => ref.refresh(hangChoProvider(duong).future),
        child: ds.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: Mau.vang)),
          error: (e, _) => KhoiLoi(
            thongDiep: e is ApiException
                ? e.message
                : 'Không tải được $tieuDe.',
            thuLai: () => ref.invalidate(hangChoProvider(duong)),
          ),
          data: (list) => list.isEmpty
              ? KhoiTrong(
                  icon: Icons.inbox_outlined,
                  tieuDe: 'Không có việc nào',
                  moTa: moTaTrong,
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _Dong(
                    muc: list[i],
                    hanhDong: hanhDong,
                    duong: duong,
                  ),
                ),
        ),
      ),
    );
  }
}

class _Dong extends ConsumerStatefulWidget {
  const _Dong({
    required this.muc,
    required this.hanhDong,
    required this.duong,
  });

  final MucDuyet muc;
  final List<HanhDongDuyet> hanhDong;
  final String duong;

  @override
  ConsumerState<_Dong> createState() => _DongState();
}

class _DongState extends ConsumerState<_Dong> {
  bool _dangChay = false;

  MucDuyet get m => widget.muc;

  Future<void> _chay(HanhDongDuyet hd) async {
    if (_dangChay) return;

    String? lyDo;
    if (hd.hoiLyDo) {
      lyDo = await _hoiLyDo(hd.nhan);
      if (lyDo == null) return; // bấm Thoát
    }

    // Việc nguy hiểm thì hỏi lại. Trên điện thoại các nút nằm sát nhau và
    // ngón cái chạm nhầm là chuyện thường — mà đây là thao tác đụng tới tiền
    // của người khác.
    if (hd.nguyHiem && !hd.hoiLyDo) {
      final ok = await _xacNhan(hd.nhan);
      if (ok != true) return;
    }

    setState(() => _dangChay = true);
    try {
      await ref.read(apiClientProvider).patch(
            hd.duong(m.id),
            body: hd.body?.call(lyDo),
          );
      ref.invalidate(hangChoProvider(widget.duong));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${hd.nhan} — xong'), backgroundColor: Mau.the),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Mau.the),
      );
    } finally {
      if (mounted) setState(() => _dangChay = false);
    }
  }

  Future<String?> _hoiLyDo(String nhan) {
    final o = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Mau.the,
        title: Text(nhan, style: const TextStyle(fontSize: 16)),
        content: TextField(
          controller: o,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Lý do (người nhận sẽ đọc được)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Thoát'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(o.text.trim()),
            child: const Text('Gửi'),
          ),
        ],
      ),
    ).whenComplete(o.dispose);
  }

  Future<bool?> _xacNhan(String nhan) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Mau.the,
          title: Text(nhan, style: const TextStyle(fontSize: 16)),
          content: Text(
            'Xác nhận "$nhan" cho ${m.tieuDe}'
            '${m.dongTien.isEmpty ? '' : ' · ${m.dongTien}'}?',
            style: const TextStyle(fontSize: 13.5, height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Thoát'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Đồng ý'),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.tieuDe,
                          style: const TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w600)),
                      if (m.phu.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(m.phu,
                            style: const TextStyle(
                                fontSize: 11.5, color: Mau.chuMo)),
                      ],
                      if (m.luc != null) ...[
                        const SizedBox(height: 3),
                        Text(Dinh.ngayGio(m.luc),
                            style: const TextStyle(
                                fontSize: 11, color: Mau.chuMo)),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (m.dongTien.isNotEmpty)
                      Text(m.dongTien,
                          style: const TextStyle(
                              color: Mau.vang,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    if (m.trangThai.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(m.trangThai,
                          style: const TextStyle(
                              fontSize: 10.5, color: Mau.chuMo)),
                    ],
                  ],
                ),
              ],
            ),
            if (m.dangCho && widget.hanhDong.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final hd in widget.hanhDong)
                    hd.nguyHiem
                        ? OutlinedButton(
                            onPressed: _dangChay ? null : () => _chay(hd),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 40),
                              foregroundColor: const Color(0xFFE5645E),
                              side: const BorderSide(color: Color(0x55E5645E)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            child: Text(hd.nhan),
                          )
                        : FilledButton(
                            onPressed: _dangChay ? null : () => _chay(hd),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 40),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 18),
                            ),
                            child: Text(hd.nhan),
                          ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
