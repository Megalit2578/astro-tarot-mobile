import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../core/api/trang.dart';
import '../../widgets/danh_sach_phan_trang.dart';
import '../../widgets/trang_thai.dart';
import '../support/support_repository.dart';
import '../support/support_screen.dart';

/// Hàng chờ hỗ trợ — phía nhân viên.
///
/// Khác màn Hỗ trợ của khách ở chỗ nó lấy TẤT CẢ phiếu đang chờ, không chỉ
/// phiếu của mình. Tái dùng chung màn chi tiết: nhân viên và khách nhìn cùng
/// một hội thoại, chỉ khác ai đứng bên nào.
/// Tải MỘT trang hàng chờ hỗ trợ.
///
/// Trước đây lấy đúng năm mươi phiếu đầu rồi dừng. Hàng chờ hỗ trợ là nơi
/// để dồn lại nhiều nhất — ai cũng xử những phiếu trên cùng — nên chính những
/// phiếu cũ bị bỏ quên lại là những phiếu không hiện ra.
Future<Trang<Ticket>> _taiHangCho(WidgetRef ref, int trang) async {
  final api = ref.read(apiClientProvider);
  final d = await api.get<dynamic>('${Endpoints.support}/queue',
      query: {'page': trang, 'size': 30});
  return Trang.tu(d, Ticket.fromJson);
}

class StaffSupportView extends ConsumerStatefulWidget {
  const StaffSupportView({super.key});

  @override
  ConsumerState<StaffSupportView> createState() => _StaffSupportViewState();
}

class _StaffSupportViewState extends ConsumerState<StaffSupportView> {
  final _dieuKhien = DieuKhienDanhSach();

  @override
  Widget build(BuildContext context) {
    return DanhSachPhanTrang<Ticket>(
      dieuKhien: _dieuKhien,
      tai: (t) => _taiHangCho(ref, t),
      loiDuPhong: 'Không tải được hàng chờ hỗ trợ.',
      trong: const KhoiTrong(
        icon: Icons.inbox_outlined,
        tieuDe: 'Hàng chờ trống',
        moTa: 'Không có yêu cầu nào đang đợi trả lời.',
      ),
      dong: (_, t) => _TheCho(t: t, taiLai: _dieuKhien.taiLai),
    );
  }
}

class _TheCho extends ConsumerWidget {
  const _TheCho({required this.t, required this.taiLai});
  final Ticket t;

  /// Tải lại hàng chờ sau khi mở một phiếu — trả lời xong thì trạng thái
  /// phiếu đã khác, và nó có thể không còn thuộc hàng chờ nữa.
  final Future<void> Function() taiLai;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Phiếu chưa ai nhận thì đánh dấu rõ: đó là thứ cần xử trước, và nếu
    // không phân biệt thì cả hàng chờ trông giống nhau.
    final chuaNhan = t.nguoiNhan == null || t.nguoiNhan!.isEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => TicketDetailScreen(ticket: t, nhanVien: true)),
          );
          await taiLai();
        },
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          height: 8,
          width: 8,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: chuaNhan ? Mau.vang : Colors.transparent,
            border: chuaNhan ? null : Border.all(color: Mau.chuMo),
          ),
        ),
        title: Text(t.tieuDe,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, height: 1.4)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            [
              nhanTrangThaiTicket(t.trangThai, nhanVien: true),
              chuaNhan ? 'chưa ai nhận' : 'đang xử: ${t.nguoiNhan}',
              if (t.luc != null) Dinh.ngayGio(t.luc),
            ].join(' · '),
            style: const TextStyle(fontSize: 11.5, color: Mau.chuMo),
          ),
        ),
        trailing:
            const Icon(Icons.chevron_right, size: 20, color: Mau.chuMo),
      ),
    );
  }
}
