import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/trang_thai.dart';
import '../support/support_repository.dart';
import '../support/support_screen.dart';

/// Hàng chờ hỗ trợ — phía nhân viên.
///
/// Khác màn Hỗ trợ của khách ở chỗ nó lấy TẤT CẢ phiếu đang chờ, không chỉ
/// phiếu của mình. Tái dùng chung màn chi tiết: nhân viên và khách nhìn cùng
/// một hội thoại, chỉ khác ai đứng bên nào.
final hangChoHoTroProvider = FutureProvider<List<Ticket>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final d = await api.get<dynamic>('${Endpoints.support}/queue',
      query: {'page': 0, 'size': 50});
  final l = d is Map ? d['content'] : d;
  if (l is! List) return const [];
  return l.whereType<Map<String, dynamic>>().map(Ticket.fromJson).toList();
});

class StaffSupportView extends ConsumerWidget {
  const StaffSupportView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = ref.watch(hangChoHoTroProvider);

    return RefreshIndicator(
      color: Mau.vang,
      backgroundColor: Mau.the,
      onRefresh: () => ref.refresh(hangChoHoTroProvider.future),
      child: ds.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Mau.vang)),
        error: (e, _) => KhoiLoi(
          thongDiep: e is ApiException
              ? e.message
              : 'Không tải được hàng chờ hỗ trợ.',
          thuLai: () => ref.invalidate(hangChoHoTroProvider),
        ),
        data: (list) => list.isEmpty
            ? const KhoiTrong(
                icon: Icons.inbox_outlined,
                tieuDe: 'Hàng chờ trống',
                moTa: 'Không có yêu cầu nào đang đợi trả lời.',
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: list.length,
                itemBuilder: (_, i) => _TheCho(t: list[i]),
              ),
      ),
    );
  }
}

class _TheCho extends ConsumerWidget {
  const _TheCho({required this.t});
  final Ticket t;

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
          ref.invalidate(hangChoHoTroProvider);
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
