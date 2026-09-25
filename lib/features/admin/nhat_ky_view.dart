import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/danh_sach_phan_trang.dart';
import '../../widgets/trang_thai.dart';
import 'admin_repository.dart';
import 'hang_cho_views.dart';

/// Nhật ký hệ thống: ai làm gì, lúc nào, đổi từ gì sang gì.
class NhatKyView extends ConsumerStatefulWidget {
  const NhatKyView({super.key});

  @override
  ConsumerState<NhatKyView> createState() => _NhatKyViewState();
}

class _NhatKyViewState extends ConsumerState<NhatKyView> {
  String _hanhDong = '';

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(adminRepositoryProvider);
    return DanhSachPhanTrang<NhatKy>(
      key: ValueKey('nk-$_hanhDong'),
      tai: (t) => repo.nhatKy(hanhDong: _hanhDong, trang: t),
      loiDuPhong: 'Không tải được nhật ký hệ thống.',
      dau: [
        LocTrangThai(
          giaTri: _hanhDong,
          nhan: tenHanhDong,
          doi: (v) => setState(() => _hanhDong = v),
        ),
      ],
      trong: const KhoiTrong(
        icon: Icons.history,
        tieuDe: 'Chưa có dòng nhật ký nào',
        moTa: 'Không có hành động nào khớp bộ lọc.',
      ),
      dong: (_, n) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(n.tenHanhDongVi,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w600)),
                  ),
                  Text(Dinh.ngayGio(n.luc),
                      style: const TextStyle(fontSize: 11, color: Mau.chuMo)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                n.vaiTroNguoiLam == null
                    ? n.nguoiLam
                    : '${n.nguoiLam} (${tenVaiTro[n.vaiTroNguoiLam] ?? n.vaiTroNguoiLam})',
                style: const TextStyle(fontSize: 12, color: Mau.chuMo),
              ),
              if (n.loaiDoiTuong != null)
                Text(
                  '${n.loaiDoiTuong}${n.maDoiTuong != null ? ' · ${n.maDoiTuong}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 10.5,
                      fontFamily: 'monospace',
                      color: Mau.chuMo),
                ),
              if (n.thayDoi != null) ...[
                const SizedBox(height: 6),
                Text(n.moTaThayDoi,
                    style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: Mau.vangNhat,
                        height: 1.5)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
