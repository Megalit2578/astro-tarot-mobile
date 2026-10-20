import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/auth/auth_controller.dart';

/// Một đợt khuyến mãi dịp lễ.
class KhuyenMai {
  const KhuyenMai({
    required this.id,
    required this.ten,
    required this.loaiGiam,
    required this.giaTri,
    this.loiChuc,
    this.giamToiDa,
  });

  final String id;
  final String ten;

  /// `PHAN_TRAM` hoặc `SO_TIEN`.
  final String loaiGiam;
  final int giaTri;
  final String? loiChuc;
  final int? giamToiDa;

  factory KhuyenMai.fromJson(Map<String, dynamic> j) => KhuyenMai(
    id: (j['id'] ?? '').toString(),
    ten: (j['ten'] ?? '') as String,
    loaiGiam: (j['loaiGiam'] ?? 'PHAN_TRAM') as String,
    giaTri: (j['giaTri'] as num?)?.toInt() ?? 0,
    loiChuc: j['loiChuc'] as String?,
    giamToiDa: (j['giamToiDa'] as num?)?.toInt(),
  );
}

/// Giá một gói sau khi áp đợt đang chạy.
///
/// Máy chủ tính, app chỉ hiện. Tự nhân phần trăm ở đây là bản cài đặt thứ ba
/// của cùng một phép tính (máy chủ, web, app) — và chỉ cần một bản quên cái
/// trần giảm là màn hình hiện một giá còn ví trừ một giá khác.
class GiaSauGiam {
  const GiaSauGiam({
    required this.giaGoc,
    required this.tienGiam,
    required this.giaCuoi,
    this.tenDot,
  });

  final int giaGoc;
  final int tienGiam;
  final int giaCuoi;
  final String? tenDot;

  bool get coGiam => tienGiam > 0;

  factory GiaSauGiam.fromJson(Map<String, dynamic> j) => GiaSauGiam(
    giaGoc: (j['giaGoc'] as num?)?.toInt() ?? 0,
    tienGiam: (j['tienGiam'] as num?)?.toInt() ?? 0,
    giaCuoi: (j['giaCuoi'] as num?)?.toInt() ?? 0,
    tenDot: j['tenDot'] as String?,
  );
}

class KhuyenMaiRepository {
  const KhuyenMaiRepository(this._api);

  final ApiClient _api;

  Future<List<KhuyenMai>> dangChay() async {
    final d = await _api.get<dynamic>(Endpoints.khuyenMaiDangChay);
    final ds = (d as List?) ?? const [];
    return ds
        .map((e) => KhuyenMai.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Khoá là id gói.
  Future<Map<String, GiaSauGiam>> giaGoi() async {
    final d = await _api.get<dynamic>(Endpoints.khuyenMaiGiaGoi);
    final m = (d as Map?) ?? const {};
    return {
      for (final e in m.entries)
        e.key.toString(): GiaSauGiam.fromJson(e.value as Map<String, dynamic>),
    };
  }

  /// Lời chúc chưa xem — và đánh dấu đã xem ngay trong lượt gọi này.
  ///
  /// Trả `null` khi không có gì để chúc. Gọi lần hai luôn `null`, kể cả khi
  /// mở song song trên web: sổ "đã chúc" nằm ở máy chủ theo `user_id`, không
  /// phải ở máy này.
  Future<KhuyenMai?> loiChuc() async {
    final d = await _api.post<dynamic>(Endpoints.khuyenMaiLoiChuc);
    if (d is! Map<String, dynamic>) return null;
    final k = KhuyenMai.fromJson(d);
    return (k.loiChuc == null || k.loiChuc!.trim().isEmpty) ? null : k;
  }
}

final khuyenMaiRepositoryProvider = Provider(
  (ref) => KhuyenMaiRepository(ref.read(apiClientProvider)),
);

/// Giá sau giảm của mọi gói. Lỗi mạng thì trả rỗng — màn gói vẫn hiện giá
/// niêm yết chứ không trắng xoá.
final giaGoiProvider = FutureProvider<Map<String, GiaSauGiam>>((ref) async {
  try {
    return await ref.read(khuyenMaiRepositoryProvider).giaGoi();
  } catch (_) {
    return const {};
  }
});

final khuyenMaiDangChayProvider = FutureProvider<List<KhuyenMai>>((ref) async {
  try {
    return await ref.read(khuyenMaiRepositoryProvider).dangChay();
  } catch (_) {
    return const [];
  }
});
