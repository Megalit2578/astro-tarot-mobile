import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/auth/auth_controller.dart';

/// Một khung giờ còn trống.
class Slot {
  const Slot({required this.batDau, required this.ketThuc, required this.gia});

  final DateTime batDau;
  final DateTime ketThuc;
  final int gia;

  factory Slot.fromJson(Map<String, dynamic> j) => Slot(
        // Máy chủ trả giờ UTC có hậu tố Z. DateTime.parse giữ nguyên là UTC;
        // mọi chỗ hiển thị phải .toLocal(), nếu không giờ hẹn lệch bảy tiếng
        // và không ai để ý cho tới khi khách đến muộn.
        batDau: DateTime.parse(j['startTime'] as String),
        ketThuc: DateTime.parse(j['endTime'] as String),
        gia: (j['price'] as num?)?.toInt() ?? 0,
      );
}

/// Khoá tra khung giờ: một Reader, một ngày, một độ dài.
class SlotQuery {
  const SlotQuery({
    required this.readerId,
    required this.ngay,
    required this.phut,
  });

  final String readerId;
  final DateTime ngay;
  final int phut;

  String get ngayISO =>
      '${ngay.year.toString().padLeft(4, '0')}-'
      '${ngay.month.toString().padLeft(2, '0')}-'
      '${ngay.day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is SlotQuery &&
      other.readerId == readerId &&
      other.ngayISO == ngayISO &&
      other.phut == phut;

  @override
  int get hashCode => Object.hash(readerId, ngayISO, phut);
}

final slotsProvider =
    FutureProvider.family<List<Slot>, SlotQuery>((ref, q) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get<List<dynamic>>(
    Endpoints.readerSlots(q.readerId),
    query: {'date': q.ngayISO, 'duration': q.phut},
  );
  final ds = data
      .whereType<Map<String, dynamic>>()
      .map(Slot.fromJson)
      .toList();

  // Bỏ khung giờ đã trôi qua.
  //
  // Máy chủ trả theo NGÀY nên buổi sáng vẫn nằm trong danh sách dù bây giờ đã
  // chiều. Để nguyên thì người dùng bấm vào rồi mới bị từ chối, và câu từ chối
  // không nói rõ vì sao.
  final bayGio = DateTime.now();
  return ds.where((s) => s.batDau.toLocal().isAfter(bayGio)).toList();
});

/// Ngoại lệ mạng cho tầng giao diện đọc lại — tiện cho `when(error:)`.
typedef LoiApi = ApiException;
