import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../theme.dart';
import '../../widgets/hop_thoai.dart';
import '../../widgets/trang_thai.dart';
import 'admin_repository.dart';
import 'tai_khoan_view.dart';

/// Quyền thật của từng vai trò, đọc từ máy chủ.
///
/// ## Vì sao không chép bảng vai-trò → quyền vào app
///
/// Web có một bản sao của bảng ấy, và bản sao đó **đã lệch** khỏi backend
/// (backend cấp thêm quyền duyệt hồ sơ Reader cho Nhân viên, web vẫn chưa).
/// Chép thêm lần nữa vào app là tạo bản thứ ba, còn lệch nhanh hơn.
///
/// Thay vào đó: với mỗi vai trò, lấy một tài khoản đang giữ vai trò ấy và đọc
/// chi tiết của nó — backend trả kèm danh sách quyền suy ra từ vai trò. Bảng
/// này vì thế luôn đúng với thứ API thật sự cho phép.
typedef QuyenTheoVaiTro = Map<String, List<String>?>;

final quyenTheoVaiTroProvider = FutureProvider<QuyenTheoVaiTro>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  final kq = <String, List<String>?>{};
  await Future.wait(vaiTroTaiKhoan.map((v) async {
    final trang = await repo.taiKhoan(vaiTro: v, co: 1);
    if (trang.muc.isEmpty) {
      kq[v] = null;
      return;
    }
    kq[v] = (await repo.chiTiet(trang.muc.first.id)).quyen;
  }));
  return kq;
});

class PhanQuyenView extends ConsumerWidget {
  const PhanQuyenView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(quyenTheoVaiTroProvider);
    return RefreshIndicator(
      color: Mau.vang,
      backgroundColor: Mau.the,
      onRefresh: () => ref.refresh(quyenTheoVaiTroProvider.future),
      child: q.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Mau.vang)),
        error: (e, _) => KhoiLoi(
          thongDiep:
              e is ApiException ? e.message : 'Không tải được bảng phân quyền.',
          thuLai: () => ref.invalidate(quyenTheoVaiTroProvider),
        ),
        data: (bang) {
          final tatCa = <String>{
            for (final ds in bang.values) ...?ds,
          }.toList()
            ..sort();
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              const Text(
                'Bảng này đọc thẳng từ máy chủ, không chép tay — nên luôn khớp '
                'với thứ API thật sự cho phép. Người đi cất nhắc cần thấy chính '
                'xác mình đang trao gì trước khi bấm.',
                style: TextStyle(fontSize: 12, color: Mau.chuMo, height: 1.55),
              ),
              const SizedBox(height: 12),
              for (final v in vaiTroTaiKhoan)
                _TheVaiTro(vaiTro: v, quyen: bang[v], tatCa: tatCa),
              const TieuDeKhoi('Ghi chú'),
              const Text(
                'Khách không phải một vai trò trong bảng tài khoản — đó là '
                'trạng thái chưa đăng nhập, nên không ai gán được vai trò đó '
                'cho người khác.',
                style: TextStyle(fontSize: 12, color: Mau.chuMo, height: 1.55),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TheVaiTro extends StatelessWidget {
  const _TheVaiTro({
    required this.vaiTro,
    required this.quyen,
    required this.tatCa,
  });

  final String vaiTro;
  final List<String>? quyen;
  final List<String> tatCa;

  @override
  Widget build(BuildContext context) {
    final co = quyen?.toSet() ?? const <String>{};
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        title: Row(
          children: [
            NhanVaiTro(vaiTro),
            const SizedBox(width: 8),
            Text(
              quyen == null ? 'chưa có ai' : '${co.length} quyền',
              style: const TextStyle(fontSize: 12, color: Mau.chuMo),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(moTaVaiTro[vaiTro]!,
              style: const TextStyle(fontSize: 11.5, color: Mau.chuMo)),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          if (quyen == null)
            const Text(
              'Chưa có tài khoản nào giữ vai trò này để đối chiếu với máy chủ.',
              style: TextStyle(fontSize: 12, color: Mau.chuMo),
            )
          else
            for (final p in tatCa)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(co.contains(p) ? Icons.check : Icons.remove,
                        size: 16,
                        color: co.contains(p) ? MauTrangThai.tot : Mau.vien),
                    const SizedBox(width: 8),
                    Text(p,
                        style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11.5,
                            color: co.contains(p) ? Mau.chu : Mau.chuMo)),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
