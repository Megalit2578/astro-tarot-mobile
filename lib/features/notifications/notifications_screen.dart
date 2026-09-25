import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/trang_thai.dart';

class ThongBao {
  const ThongBao({
    required this.id,
    required this.tieuDe,
    required this.noiDung,
    required this.daDoc,
    required this.ghim,
    this.luc,
  });

  final String id;
  final String tieuDe;
  final String noiDung;
  final bool daDoc;
  final bool ghim;
  final DateTime? luc;

  factory ThongBao.fromJson(Map<String, dynamic> j) => ThongBao(
        id: (j['id'] ?? '').toString(),
        tieuDe: (j['title'] ?? '') as String,
        noiDung: (j['message'] ?? '') as String,
        daDoc: j['read'] == true,
        ghim: j['pinned'] == true,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = ref.watch(thongBaoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await ref
                    .read(apiClientProvider)
                    .post('${Endpoints.notifications}/read-all');
                ref.invalidate(thongBaoProvider);
                ref.invalidate(soChuaDocProvider);
              } on ApiException catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(e.message), backgroundColor: Mau.the),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Mau.chuMo),
            child: const Text('Đọc hết', style: TextStyle(fontSize: 12.5)),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: tb.daDoc
            ? null
            : () async {
                try {
                  await ref
                      .read(apiClientProvider)
                      .post('${Endpoints.notifications}/${tb.id}/read');
                  ref.invalidate(thongBaoProvider);
                  ref.invalidate(soChuaDocProvider);
                } catch (_) {}
              },
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
