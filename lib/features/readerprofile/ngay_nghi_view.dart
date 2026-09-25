import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme.dart';
import '../../widgets/hop_thoai.dart';
import '../astrology/astrology_repository.dart';
import 'reader_profile_repository.dart';

/// Ngày nghỉ của Reader: danh sách + thêm + bỏ, khớp khối "Ngày nghỉ" của web.
class NgayNghiView extends ConsumerStatefulWidget {
  const NgayNghiView({super.key});

  @override
  ConsumerState<NgayNghiView> createState() => _NgayNghiViewState();
}

class _NgayNghiViewState extends ConsumerState<NgayNghiView> {
  bool _ban = false;

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _them() async {
    final homNay = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: homNay,
      firstDate: DateTime(homNay.year, homNay.month, homNay.day),
      lastDate: homNay.add(const Duration(days: 365)),
      helpText: 'Chọn ngày nghỉ',
    );
    if (d == null || !mounted) return;
    final lyDo = await hoiNoiDung(
      context,
      tieuDe: 'Lý do (không bắt buộc)',
      goiY: 'Việc riêng, đi xa…',
      gui: 'Thêm',
      dongToiDa: 1,
    );
    if (lyDo == null) return;
    await _chay(
      () => ref
          .read(readerProfileRepositoryProvider)
          .themNgayNghi(_iso(d), lyDo: lyDo),
      'Đã thêm ngày nghỉ.',
    );
  }

  Future<void> _chay(Future<void> Function() viec, String xong) async {
    setState(() => _ban = true);
    try {
      await viec();
      ref.invalidate(ngayNghiProvider);
      if (mounted) baoTin(context, xong);
    } catch (e) {
      if (mounted) baoLoi(context, e, 'Thao tác không thành công.');
    } finally {
      if (mounted) setState(() => _ban = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ds = ref.watch(ngayNghiProvider);
    final list = ds.asData?.value ?? const <NgayNghi>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ds.hasError)
          const Text('Không tải được ngày nghỉ.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFFE5645E))),
        if (ds.isLoading && list.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Center(
                child: SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))),
          ),
        if (!ds.isLoading && !ds.hasError && list.isEmpty)
          const Text('Chưa có ngày nghỉ nào.',
              style: TextStyle(fontSize: 12.5, color: Mau.chuMo)),
        for (final n in list)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.event_busy, color: Mau.vang, size: 20),
              title: Text(ngayViTuIso(n.ngay),
                  style: const TextStyle(fontSize: 13.5)),
              subtitle: n.lyDo == null
                  ? null
                  : Text(n.lyDo!,
                      style:
                          const TextStyle(fontSize: 11.5, color: Mau.chuMo)),
              trailing: IconButton(
                tooltip: 'Bỏ ngày nghỉ ${n.ngay}',
                onPressed: _ban
                    ? null
                    : () => _chay(
                        () => ref
                            .read(readerProfileRepositoryProvider)
                            .xoaNgayNghi(n.id),
                        'Đã bỏ ngày nghỉ.'),
                icon: const Icon(Icons.close, size: 18),
              ),
            ),
          ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: _ban ? null : _them,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Thêm ngày nghỉ'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Mau.vang,
            side: const BorderSide(color: Mau.vien),
          ),
        ),
      ],
    );
  }
}
