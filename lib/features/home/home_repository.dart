import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/endpoints.dart';
import '../../core/auth/auth_controller.dart';

/// Một lần trải bài đã lưu.
///
/// Đọc lỏng có chủ đích: backend trả nhiều trường và tên có thể đổi, nhưng
/// màn hình chỉ cần câu hỏi + thời điểm. Ép kiểu chặt ở đây thì một trường
/// đổi tên là cả khối biến mất, mà lỗi lại không nói gì về nguyên nhân.
class LanTraiBai {
  const LanTraiBai({required this.id, required this.cauHoi, this.luc});

  final String id;
  final String cauHoi;
  final DateTime? luc;

  factory LanTraiBai.fromJson(Map<String, dynamic> j) {
    // `mainQuestion` là tên thật trong ReadingHistoryItem bên backend. Ba tên
    // còn lại giữ làm đường lùi. Trước đây thiếu mainQuestion nên khối này
    // luôn hiện chữ "Lần trải bài" thay vì câu hỏi người dùng đã đặt.
    final q = (j['mainQuestion'] ??
        j['question'] ??
        j['prompt'] ??
        j['title'] ??
        '') as Object?;
    final t = (j['createdAt'] ?? j['created_at']) as Object?;
    return LanTraiBai(
      id: (j['id'] ?? '').toString(),
      cauHoi: q is String && q.trim().isNotEmpty ? q.trim() : 'Lần trải bài',
      luc: t is String ? DateTime.tryParse(t) : null,
    );
  }
}

/// Lịch sử trải bài. Trả rỗng khi hỏng thay vì ném.
///
/// Đây là một KHỐI trên trang chủ, không phải cả màn hình. Một khối hỏng mà
/// làm trắng cả trang chủ là đánh đổi tồi — khối tự ẩn đi thì phần còn lại
/// vẫn dùng được.
final lichSuTraiBaiProvider = FutureProvider<List<LanTraiBai>>((ref) async {
  try {
    final api = ref.watch(apiClientProvider);
    final data = await api.get<dynamic>(
      Endpoints.aiReadings,
      query: {'page': 0, 'size': 3},
    );
    final list = data is Map ? data['content'] : data;
    if (list is! List) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(LanTraiBai.fromJson)
        .toList();
  } catch (_) {
    return const [];
  }
});

/// Bản đồ sao chính. `null` = chưa tạo, và đó là trạng thái bình thường.
final banDoSaoProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  try {
    final api = ref.watch(apiClientProvider);
    return await api.get<Map<String, dynamic>>(Endpoints.astrologyPrimary);
  } catch (_) {
    return null;
  }
});
