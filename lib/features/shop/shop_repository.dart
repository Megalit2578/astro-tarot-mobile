import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/config.dart';

/// Một sản phẩm trong gian hàng.
///
/// **Gian hàng là liên kết tiếp thị, không phải bán hàng trong app.** Backend
/// có sẵn giỏ và đơn, nhưng web không dùng — mô hình thật là dẫn khách sang
/// Shopee và ăn hoa hồng. Dựng giỏ hàng ở đây là dựng một luồng không ai đi.
class SanPham {
  const SanPham({
    required this.id,
    required this.ten,
    required this.slug,
    required this.gia,
    required this.anhMinhHoa,
    this.moTa,
    this.anh,
    this.giaGoc,
    this.kho,
    this.lienKet,
    this.san,
    this.danhMuc,
  });

  final String id;
  final String ten;
  final String slug;
  final int gia;
  final String? moTa;
  final String? anh;
  final int? giaGoc;
  final int? kho;
  final String? lienKet;
  final String? san;
  final String? danhMuc;

  /// Ảnh chỉ mang tính minh hoạ, không phải ảnh chụp đúng món hàng.
  ///
  /// Backend có cờ riêng cho việc này và nó đáng hiển thị: ảnh minh hoạ mà
  /// không nói rõ là đặt người mua vào thế kỳ vọng sai.
  final bool anhMinhHoa;

  String? get anhDayDu => AppConfig.anh(anh);

  bool get coGiamGia => giaGoc != null && giaGoc! > gia;

  factory SanPham.fromJson(Map<String, dynamic> j) => SanPham(
        id: (j['id'] ?? '').toString(),
        ten: (j['name'] ?? '') as String,
        slug: (j['slug'] ?? '') as String,
        gia: (j['price'] as num?)?.toInt() ?? 0,
        giaGoc: (j['compareAtPrice'] as num?)?.toInt(),
        moTa: j['description'] as String?,
        anh: j['imageUrl'] as String?,
        anhMinhHoa: j['imageIsIllustrative'] == true,
        kho: (j['stock'] as num?)?.toInt(),
        lienKet: j['affiliateUrl'] as String?,
        san: j['affiliatePlatform'] as String?,
        danhMuc: j['categoryName'] as String?,
      );
}

class ShopRepository {
  ShopRepository(this._api);
  final ApiClient _api;

  Future<List<SanPham>> sanPham() async {
    final d = await _api.get<dynamic>(Endpoints.shopProducts,
        query: {'page': 0, 'size': 50});
    final l = d is Map ? d['content'] : d;
    if (l is! List) return const [];
    return l.whereType<Map<String, dynamic>>().map(SanPham.fromJson).toList();
  }

  /// Ghi nhận lượt bấm sang sàn liên kết.
  ///
  /// Đây là số liệu doanh thu của dự án, nhưng KHÔNG được để nó chặn việc mở
  /// liên kết: người dùng bấm mua thì phải sang được Shopee, kể cả khi máy
  /// chủ đang hỏng. Nuốt lỗi có chủ đích.
  Future<void> ghiNhanBam(String id) async {
    try {
      await _api.post(Endpoints.shopClick(id));
    } catch (_) {}
  }
}

final shopRepositoryProvider =
    Provider((ref) => ShopRepository(ref.watch(apiClientProvider)));

final sanPhamProvider =
    FutureProvider<List<SanPham>>((ref) => ref.watch(shopRepositoryProvider).sanPham());
