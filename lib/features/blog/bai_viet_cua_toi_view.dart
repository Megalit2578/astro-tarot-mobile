import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/danh_sach_phan_trang.dart';
import '../../widgets/hop_thoai.dart';
import '../../widgets/trang_thai.dart';
import 'blog_repository.dart';
import 'soan_bai_screen.dart';

/// Bài viết của chính người đang đăng nhập — ở mọi trạng thái.
///
/// Khác tab "Bài viết" công khai: ở đó chỉ có bài đã xuất bản, nên tác giả
/// không có đường nào nhìn thấy bản nháp hay bài bị từ chối của mình. Trước
/// màn này, viết bài trên điện thoại là chuyện không làm được.
class BaiVietCuaToiView extends ConsumerStatefulWidget {
  const BaiVietCuaToiView({super.key});

  @override
  ConsumerState<BaiVietCuaToiView> createState() => _BaiVietCuaToiViewState();
}

class _BaiVietCuaToiViewState extends ConsumerState<BaiVietCuaToiView> {
  String _loc = '';
  final _dk = DieuKhienDanhSach();

  Future<void> _moSoan([BaiVietQuanTri? bai]) async {
    final doi = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SoanBaiScreen(bai: bai)),
    );
    if (doi == true) await _dk.taiLai();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(blogRepositoryProvider);
    return Scaffold(
      body: DanhSachPhanTrang<BaiVietQuanTri>(
        key: ValueKey('bai-toi-$_loc'),
        dieuKhien: _dk,
        tai: (t) => repo.cuaToi(trangThai: _loc, trang: t),
        loiDuPhong: 'Không tải được bài viết của bạn.',
        dau: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DropdownButtonFormField<String>(
              key: const ValueKey('loc-bai-cua-toi'),
              initialValue: _loc,
              isExpanded: true,
              dropdownColor: Mau.the,
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.filter_list, size: 18),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: [
                const DropdownMenuItem(value: '', child: Text('Tất cả')),
                for (final e in tenTrangThaiBai.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _loc = v ?? ''),
            ),
          ),
        ],
        trong: KhoiTrong(
          icon: Icons.edit_note_outlined,
          tieuDe: _loc.isEmpty
              ? 'Bạn chưa viết bài nào'
              : 'Không có bài nào ở trạng thái này',
          moTa: _loc.isEmpty
              ? 'Bấm nút bên dưới để viết bài đầu tiên.'
              : 'Đổi bộ lọc để xem các bài khác của bạn.',
        ),
        dong: (_, b) => _TheBaiCuaToi(b: b, dk: _dk, sua: () => _moSoan(b)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _moSoan(),
        icon: const Icon(Icons.add),
        label: const Text('Viết bài'),
      ),
    );
  }
}

class _TheBaiCuaToi extends ConsumerStatefulWidget {
  const _TheBaiCuaToi({required this.b, required this.dk, required this.sua});

  final BaiVietQuanTri b;
  final DieuKhienDanhSach dk;
  final VoidCallback sua;

  @override
  ConsumerState<_TheBaiCuaToi> createState() => _TheBaiCuaToiState();
}

class _TheBaiCuaToiState extends ConsumerState<_TheBaiCuaToi> {
  bool _ban = false;

  Future<void> _lam(Future<void> Function() viec, String xong) async {
    setState(() => _ban = true);
    try {
      await viec();
      if (!mounted) return;
      baoTin(context, xong);
      await widget.dk.taiLai();
    } catch (e) {
      if (mounted) baoLoi(context, e, 'Thao tác không thành công.');
    }
    if (mounted) setState(() => _ban = false);
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.b;
    final repo = ref.read(blogRepositoryProvider);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    b.tieuDe,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600, height: 1.4),
                  ),
                ),
                const SizedBox(width: 10),
                NhanTrangThai(b.tenTrangThai, mau: mauTrangThaiBai(b.trangThai)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              giaiThichTrangThaiBai(b.trangThai),
              style: const TextStyle(fontSize: 12, color: Mau.chuMo, height: 1.5),
            ),
            if (b.trangThai == 'REJECTED' &&
                (b.lyDoTuChoi?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: MauTrangThai.xau.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(b.lyDoTuChoi!,
                    style: const TextStyle(fontSize: 12.5, height: 1.5)),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              [
                if (b.suaLuc != null) 'Sửa ${Dinh.ngay(b.suaLuc)}',
                if (b.nguoiDuyet != null) 'Người duyệt: ${b.nguoiDuyet}',
              ].join(' · '),
              style: const TextStyle(fontSize: 11, color: Mau.chuMo),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (suaDuocBai(b.trangThai))
                    OutlinedButton(
                      onPressed: _ban ? null : widget.sua,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        foregroundColor: Mau.vang,
                        side: const BorderSide(color: Mau.vien),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999)),
                      ),
                      child: const Text('Sửa'),
                    ),
                  if (guiDuyetDuoc(b.trangThai))
                    FilledButton(
                      onPressed: _ban
                          ? null
                          : () => _lam(() => repo.guiDuyet(b.id),
                              'Đã gửi bài đi duyệt.'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                      ),
                      child: Text(
                          b.trangThai == 'REJECTED' ? 'Gửi lại' : 'Gửi duyệt'),
                    ),
                  if (tacGiaXoaDuoc(b.trangThai))
                    OutlinedButton(
                      onPressed: _ban
                          ? null
                          : () async {
                              final chac = await hoiXacNhan(
                                context,
                                tieuDe: 'Xoá bản nháp',
                                noiDung:
                                    'Xoá "${b.tieuDe}"? Bản nháp này không lấy lại được.',
                                dongY: 'Xoá',
                                nguyHiem: true,
                              );
                              if (!chac) return;
                              await _lam(() => repo.xoaBaiCuaToi(b.id),
                                  'Đã xoá bản nháp.');
                            },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        foregroundColor: MauTrangThai.xau,
                        side: const BorderSide(color: Color(0x55E5645E)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999)),
                      ),
                      child: const Text('Xoá'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
