import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/auth/auth_controller.dart';

class Ticket {
  const Ticket({
    required this.id,
    required this.tieuDe,
    required this.trangThai,
    required this.soTin,
    this.nguoiNhan,
    this.luc,
  });

  final String id;
  final String tieuDe;
  final String trangThai;
  final int soTin;
  final String? nguoiNhan;
  final DateTime? luc;

  factory Ticket.fromJson(Map<String, dynamic> j) => Ticket(
        id: (j['id'] ?? '').toString(),
        tieuDe: (j['subject'] ?? '') as String,
        trangThai: (j['status'] ?? '') as String,
        soTin: (j['messageCount'] as num?)?.toInt() ?? 0,
        nguoiNhan: j['assignedToName'] as String?,
        luc: DateTime.tryParse((j['createdAt'] ?? '').toString()),
      );
}

class TinHoTro {
  const TinHoTro({
    required this.id,
    required this.noiDung,
    required this.nguoiGui,
    required this.cuaNhanVien,
    this.luc,
  });

  final String id;
  final String noiDung;
  final String nguoiGui;
  final bool cuaNhanVien;
  final DateTime? luc;

  factory TinHoTro.fromJson(Map<String, dynamic> j) => TinHoTro(
        id: (j['id'] ?? '').toString(),
        noiDung: (j['body'] ?? j['content'] ?? '') as String,
        nguoiGui: (j['senderName'] ?? j['authorName'] ?? '') as String,
        // Backend đặt tên cờ này mỗi bản một khác; nhận cả ba để khỏi vỡ khi
        // đổi. Đoán sai thì tin của nhân viên hiện nhầm bên và hội thoại
        // trông như người dùng tự nói chuyện một mình.
        cuaNhanVien: j['fromStaff'] == true ||
            j['isStaff'] == true ||
            j['staff'] == true,
        luc: DateTime.tryParse((j['createdAt'] ?? '').toString()),
      );
}

class SupportRepository {
  SupportRepository(this._api);
  final ApiClient _api;

  Future<List<Ticket>> cuaToi() async {
    final d = await _api.get<dynamic>('${Endpoints.support}/tickets/mine');
    final l = d is Map ? d['content'] : d;
    if (l is! List) return const [];
    return l.whereType<Map<String, dynamic>>().map(Ticket.fromJson).toList();
  }

  Future<Map<String, dynamic>> chiTiet(String id) =>
      _api.get<Map<String, dynamic>>('${Endpoints.support}/tickets/$id');

  Future<void> tao(String tieuDe, String noiDung) => _api.post(
        '${Endpoints.support}/tickets',
        body: {'subject': tieuDe.trim(), 'body': noiDung.trim()},
      );

  Future<void> traLoi(String id, String noiDung) => _api.post(
        '${Endpoints.support}/tickets/$id/messages',
        body: {'body': noiDung.trim()},
      );
}

final supportRepositoryProvider =
    Provider((ref) => SupportRepository(ref.watch(apiClientProvider)));

final ticketsCuaToiProvider = FutureProvider<List<Ticket>>(
  (ref) => ref.watch(supportRepositoryProvider).cuaToi(),
);

final ticketChiTietProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
  (ref, id) => ref.watch(supportRepositoryProvider).chiTiet(id),
);

/// Nhãn tiếng Việt cho trạng thái phiếu.
String nhanTrangThaiTicket(String s) => switch (s.toUpperCase()) {
      'OPEN' || 'PENDING' => 'Đang chờ',
      'WAITING_CUSTOMER' || 'WAITING' => 'Chờ bạn phản hồi',
      'RESOLVED' || 'DONE' => 'Đã giải quyết',
      'CLOSED' => 'Đã đóng',
      _ => s,
    };
