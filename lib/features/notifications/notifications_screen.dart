import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/hop_thoai.dart';
import '../../widgets/trang_thai.dart';
import '../bookings/bookings_screen.dart';
import '../readerapply/reader_apply_screen.dart';
import '../staff/staff_screen.dart';
import '../support/support_screen.dart';

/// Màn cần mở khi bấm một thông báo — cùng luật với `notificationLink` của
/// web. Trả null khi không có đích rõ ràng: bấm vào chỉ đánh dấu đã đọc, tốt
/// hơn là đẩy người dùng tới một màn chẳng liên quan.
Widget? manChoThongBao(String? loai) {
  if (loai == null) return null;
  if (loai == 'REVIEW_RECEIVED' || loai == 'SUPPORT_MESSAGE') {
    return const StaffScreen();
  }
  if (loai.startsWith('PAYOUT_')) return const StaffScreen();
  if (loai.startsWith('BOOKING_') || loai.startsWith('PAYMENT_')) {
    return const BookingsScreen();
  }
  if (loai.startsWith('READER_APPLICATION_')) return const ReaderApplyScreen();
  if (loai == 'SUPPORT_REPLY') return const SupportScreen();
  return null;
}

/// Các thao tác trên hộp thông báo.
///
/// Đánh dấu đã đọc và ghim là **PATCH**, không phải POST. Bản đầu dùng POST:
/// máy chủ từ chối, lỗi bị nuốt, nên chấm đỏ không bao giờ tắt và nút "Đọc
/// hết" chỉ hiện một câu lỗi khó hiểu.
class NotificationsRepository {
  NotificationsRepository(this._api);
  final ApiClient _api;

  Future<void> daDoc(String id) =>
      _api.patch('${Endpoints.notifications}/$id/read');

  Future<void> docHet() => _api.patch('${Endpoints.notifications}/read-all');

  Future<void> ghim(String id, bool ghim) => _api.patch(
      '${Endpoints.notifications}/$id/pin',
      body: {'pinned': ghim});

  /// Xoá mọi thông báo đã đọc, trừ tin đã ghim. Trả số tin đã xoá.
  Future<int> xoaDaDoc() async {
    final d = await _api.delete<dynamic>('${Endpoints.notifications}/read');
    return d is Map ? (d['deleted'] as num?)?.toInt() ?? 0 : 0;
  }

  /// Xoá một thông báo. Tin ghim bị máy chủ bỏ qua.
  Future<void> xoa(String id) => _api.dio
      .delete<dynamic>(Endpoints.notifications, data: {'ids': [id]});
}

final notificationsRepositoryProvider =
    Provider((ref) => NotificationsRepository(ref.watch(apiClientProvider)));

class ThongBao {
  const ThongBao({
    required this.id,
    required this.tieuDe,
    required this.noiDung,
    required this.daDoc,
    required this.ghim,
    this.loai,
    this.luc,
  });

  final String id;
  final String tieuDe;
  final String noiDung;
  final bool daDoc;
  final bool ghim;

  /// Xem NotificationTypes bên backend. Quyết định màn mở ra khi bấm.
  final String? loai;
  final DateTime? luc;

  factory ThongBao.fromJson(Map<String, dynamic> j) => ThongBao(
        id: (j['id'] ?? '').toString(),
        tieuDe: (j['title'] ?? '') as String,
        noiDung: (j['message'] ?? '') as String,
        daDoc: j['read'] == true,
        ghim: j['pinned'] == true,
        loai: j['type'] as String?,
        luc: DateTime.tryParse((j['createdAt'] ?? '').toString()),
      );
}

final thongBaoProvider = FutureProvider<List<ThongBao>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final d = await api.get<dynamic>(
    Endpoints.notifications,
    query: {'page': 0, 'size': 50},
  );
  final l = d is Map ? d['content'] : d;
  if (l is! List) return const [];
  final ds =
      l.whereType<Map<String, dynamic>>().map(ThongBao.fromJson).toList();
  // Ghim lên đầu, rồi mới tới thứ tự thời gian. Backend đã có cờ pinned nhưng
  // không bảo đảm thứ tự, mà ghim mà nằm lẫn giữa danh sách thì vô nghĩa.
  ds.sort((a, b) {
    if (a.ghim != b.ghim) return a.ghim ? -1 : 1;
    final x = a.luc, y = b.luc;
    if (x == null || y == null) return 0;
    return y.compareTo(x);
  });
  return ds;
});

final soChuaDocProvider = FutureProvider<int>((ref) async {
  try {
    final api = ref.watch(apiClientProvider);
    final d = await api.get<dynamic>('${Endpoints.notifications}/unread-count');
    if (d is Map) {
      final v = d['count'] ?? d['unread'] ?? d['value'];
      if (v is num) return v.toInt();
    }
    if (d is num) return d.toInt();
    return 0;
  } catch (_) {
    // Con số này chỉ là chấm đỏ trên biểu tượng. Hỏng thì coi như không có,
    // đừng để nó làm hỏng màn hình chứa nó.
    return 0;
  }
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  static Future<void> _chay(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() viec,
  ) async {
    try {
      await viec();
    } catch (e) {
      if (context.mounted) baoLoi(context, e, 'Thao tác không thành công.');
    }
    ref.invalidate(thongBaoProvider);
    ref.invalidate(soChuaDocProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = ref.watch(thongBaoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          TextButton(
            onPressed: () => _chay(
              context,
              ref,
              () => ref.read(notificationsRepositoryProvider).docHet(),
            ),
            style: TextButton.styleFrom(foregroundColor: Mau.chuMo),
            child: const Text('Đọc hết', style: TextStyle(fontSize: 12.5)),
          ),
          PopupMenuButton<String>(
            tooltip: 'Thêm',
            color: Mau.the,
            onSelected: (_) => _chay(context, ref, () async {
              final n =
                  await ref.read(notificationsRepositoryProvider).xoaDaDoc();
              if (context.mounted) baoTin(context, 'Đã xoá $n thông báo.');
            }),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'xoa-da-doc',
                child: Text('Xoá thông báo đã đọc (trừ tin ghim)'),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        color: Mau.vang,
        backgroundColor: Mau.the,
        onRefresh: () => ref.refresh(thongBaoProvider.future),
        child: ds.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: Mau.vang)),
          error: (e, _) => KhoiLoi(
            thongDiep:
                e is ApiException ? e.message : 'Không tải được thông báo.',
            thuLai: () => ref.invalidate(thongBaoProvider),
          ),
          data: (list) => list.isEmpty
              ? const KhoiTrong(
                  icon: Icons.notifications_none,
                  tieuDe: 'Chưa có thông báo nào',
                  moTa: 'Khi có người nhận lịch, nhắn tin hay thanh toán, '
                      'bạn sẽ thấy ở đây.',
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _The(tb: list[i]),
                ),
        ),
      ),
    );
  }
}

class _The extends ConsumerWidget {
  const _The({required this.tb});
  final ThongBao tb;

  /// Giữ ngón tay trên một thông báo: ghim / bỏ ghim / xoá.
  Future<void> _menu(BuildContext context, WidgetRef ref) async {
    final chon = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Mau.the,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(tb.ghim ? Icons.push_pin_outlined : Icons.push_pin),
              title: Text(tb.ghim ? 'Bỏ ghim' : 'Ghim lên đầu'),
              onTap: () => Navigator.of(ctx).pop('ghim'),
            ),
            if (!tb.ghim)
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: Color(0xFFE5645E)),
                title: const Text('Xoá thông báo'),
                onTap: () => Navigator.of(ctx).pop('xoa'),
              ),
          ],
        ),
      ),
    );
    if (chon == null || !context.mounted) return;
    final repo = ref.read(notificationsRepositoryProvider);
    await NotificationsScreen._chay(
      context,
      ref,
      () => chon == 'ghim' ? repo.ghim(tb.id, !tb.ghim) : repo.xoa(tb.id),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final repo = ref.read(notificationsRepositoryProvider);
          if (!tb.daDoc) {
            try {
              await repo.daDoc(tb.id);
            } catch (_) {
              // Đánh dấu đã đọc hỏng không được chặn việc mở màn đích.
            }
            ref.invalidate(thongBaoProvider);
            ref.invalidate(soChuaDocProvider);
          }
          final man = manChoThongBao(tb.loai);
          if (man != null && context.mounted) {
            await Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => man));
          }
        },
        onLongPress: () => _menu(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Chấm chưa đọc. Dùng chấm thay vì in đậm cả khối: danh sách
              // toàn chữ đậm thì mắt không còn phân biệt được gì nữa.
              Container(
                margin: const EdgeInsets.only(top: 5, right: 11),
                height: 7,
                width: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tb.daDoc ? Colors.transparent : Mau.vang,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (tb.ghim)
                          const Padding(
                            padding: EdgeInsets.only(right: 5),
                            child: Icon(Icons.push_pin,
                                size: 12, color: Mau.vang),
                          ),
                        Expanded(
                          child: Text(
                            tb.tieuDe,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: tb.daDoc
                                  ? FontWeight.w400
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (tb.noiDung.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(tb.noiDung,
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: Mau.chuMo,
                              height: 1.5)),
                    ],
                    if (tb.luc != null) ...[
                      const SizedBox(height: 5),
                      Text(Dinh.ngayGio(tb.luc),
                          style: const TextStyle(
                              fontSize: 10.5, color: Mau.chuMo)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
