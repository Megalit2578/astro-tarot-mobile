import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/danh_sach_phan_trang.dart';
import '../../widgets/hop_thoai.dart';
import '../../widgets/trang_thai.dart';
import 'blog_repository.dart';

/// Hàng chờ duyệt bài, cho Quản lý và Quản trị viên.
///
/// Mặc định lọc PENDING như các hàng chờ khác trong khu quản trị: người mở
/// màn này là để xử lý việc tồn đọng, không phải để cuộn qua mọi bài đã xong.
class DuyetBaiView extends ConsumerStatefulWidget {
  const DuyetBaiView({super.key});

  @override
  ConsumerState<DuyetBaiView> createState() => _DuyetBaiViewState();
}

class _DuyetBaiViewState extends ConsumerState<DuyetBaiView> {
  String _loc = 'PENDING';
  final _dk = DieuKhienDanhSach();

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(blogRepositoryProvider);
    return DanhSachPhanTrang<BaiVietQuanTri>(
      key: ValueKey('duyet-bai-$_loc'),
      dieuKhien: _dk,
      tai: (t) => repo.tatCa(trangThai: _loc, trang: t),
      loiDuPhong: 'Không tải được danh sách bài viết.',
      dau: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: DropdownButtonFormField<String>(
            key: const ValueKey('loc-duyet-bai'),
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
        icon: Icons.inbox_outlined,
        tieuDe: _loc == 'PENDING'
            ? 'Không có bài nào chờ duyệt'
            : 'Không có bài nào',
        moTa: 'Không có bài viết nào khớp bộ lọc.',
      ),
      dong: (_, b) => _TheDuyetBai(b: b, dk: _dk),
    );
  }
}

class _TheDuyetBai extends ConsumerStatefulWidget {
  const _TheDuyetBai({required this.b, required this.dk});
  final BaiVietQuanTri b;
  final DieuKhienDanhSach dk;

  @override
  ConsumerState<_TheDuyetBai> createState() => _TheDuyetBaiState();
}

class _TheDuyetBaiState extends ConsumerState<_TheDuyetBai> {
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
    // Backend chỉ nhận APPROVED/REJECTED khi bài đang PENDING, và chỉ nhận
    // PUBLISH khi bài đã APPROVED. Bày nút ngoài hai khung đó là hứa một việc
    // máy chủ sẽ từ chối.
    final xetDuoc = b.trangThai == 'PENDING';
    final xuatBanDuoc = b.trangThai == 'APPROVED';

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
                  child: Text(b.tieuDe,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.4)),
                ),
                const SizedBox(width: 10),
                NhanTrangThai(b.tenTrangThai, mau: mauTrangThaiBai(b.trangThai)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              [
                if (b.tacGia != null) b.tacGia!,
                if (b.taoLuc != null) Dinh.ngay(b.taoLuc),
              ].join(' · '),
              style: const TextStyle(fontSize: 11.5, color: Mau.chuMo),
            ),
            if (b.tomTat?.isNotEmpty ?? false) ...[
              const SizedBox(height: 10),
              Text(b.tomTat!,
                  style: const TextStyle(
                      fontSize: 12.5, color: Mau.chuMo, height: 1.55)),
            ],
            const SizedBox(height: 10),
            // Đọc nội dung ngay tại thẻ. Duyệt bài mà chỉ nhìn tiêu đề với
            // tóm tắt thì cái nút "Duyệt" không có nghĩa gì.
            if ((b.noiDung ?? '').trim().isNotEmpty)
              Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  title: const Text('Đọc toàn bài',
                      style: TextStyle(fontSize: 13, color: Mau.vang)),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SelectableText(
                        b.noiDung!.trim(),
                        style: const TextStyle(fontSize: 13.5, height: 1.75),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (xetDuoc)
                    FilledButton(
                      onPressed: _ban
                          ? null
                          : () => _lam(
                              () => repo.duyet(b.id), 'Đã duyệt bài viết.'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                      ),
                      child: const Text('Duyệt'),
                    ),
                  if (xetDuoc)
                    OutlinedButton(
                      onPressed: _ban
                          ? null
                          : () async {
                              final lyDo = await hoiNoiDung(
                                context,
                                tieuDe: 'Từ chối bài viết',
                                moTa:
                                    'Tác giả đọc đúng câu này để sửa, nên viết '
                                    'cụ thể chỗ cần đổi.',
                                goiY: 'Ví dụ: phần mở còn lan man…',
                                gui: 'Từ chối',
                                batBuoc: true,
                              );
                              if (lyDo == null || lyDo.isEmpty) return;
                              await _lam(() => repo.tuChoi(b.id, lyDo),
                                  'Đã từ chối và gửi lý do cho tác giả.');
                            },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        foregroundColor: MauTrangThai.xau,
                        side: const BorderSide(color: Color(0x55E5645E)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999)),
                      ),
                      child: const Text('Từ chối'),
                    ),
                  if (xuatBanDuoc)
                    FilledButton(
                      onPressed: _ban
                          ? null
                          : () async {
                              final chac = await hoiXacNhan(
                                context,
                                tieuDe: 'Xuất bản bài viết',
                                noiDung:
                                    '"${b.tieuDe}" sẽ lên trang Bài viết và ai '
                                    'cũng đọc được.',
                                dongY: 'Xuất bản',
                              );
                              if (!chac) return;
                              await _lam(() => repo.xuatBan(b.id),
                                  'Đã xuất bản bài viết.');
                            },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                      ),
                      child: const Text('Xuất bản'),
                    ),
                  OutlinedButton(
                    onPressed: _ban
                        ? null
                        : () async {
                            final chac = await hoiXacNhan(
                              context,
                              tieuDe: 'Xoá bài viết',
                              noiDung: b.trangThai == 'PUBLISHED'
                                  ? '"${b.tieuDe}" đang hiển thị công khai. '
                                      'Xoá là gỡ khỏi trang Bài viết và mọi '
                                      'liên kết đã dán đi đều hỏng.'
                                  : 'Xoá "${b.tieuDe}"? Tác giả sẽ mất bài này.',
                              dongY: 'Xoá',
                              nguyHiem: true,
                            );
                            if (!chac) return;
                            await _lam(() => repo.xoaBaiBatKy(b.id),
                                'Đã xoá bài viết.');
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
