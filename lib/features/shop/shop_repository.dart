import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/api/trang.dart';
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
    this.danhMucSlug,
    this.danhMucId,
    this.luotBam,
    this.hoaHong,
    this.noiBat = false,
    this.dangBan = true,
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
  final String? danhMucSlug;
  final String? danhMucId;
  final int? luotBam;

  /// Phần trăm hoa hồng — chỉ màn quản trị đọc.
  final double? hoaHong;
  final bool noiBat;

  /// Đang hiện trong gian hàng. Màn quản trị thấy cả sản phẩm đã ẩn.
  final bool dangBan;

  /// Ảnh chỉ mang tính minh hoạ, không phải ảnh chụp đúng món hàng.
  ///
  /// Backend có cờ riêng cho việc này và nó đáng hiển thị: ảnh minh hoạ mà
  /// không nói rõ là đặt người mua vào thế kỳ vọng sai.
  final bool anhMinhHoa;

  String? get anhDayDu => AppConfig.anh(anh);

  bool get coGiamGia => giaGoc != null && giaGoc! > gia;

  bool get coLienKet => lienKet != null && lienKet!.isNotEmpty;

  /// Phần trăm giảm so với giá gốc, làm tròn như web.
  int? get phanTramGiam =>
      coGiamGia ? (((giaGoc! - gia) / giaGoc!) * 100).round() : null;

  factory SanPham.fromJson(Map<String, dynamic> j) => SanPham(
        id: (j['id'] ?? '').toString(),
        ten: (j['name'] ?? '') as String,
        slug: (j['slug'] ?? '') as String,
        gia: soNguyen(j['price']) ?? 0,
        giaGoc: soNguyen(j['compareAtPrice']),
        moTa: j['description'] as String?,
        anh: j['imageUrl'] as String?,
        anhMinhHoa: j['imageIsIllustrative'] == true,
        kho: soNguyen(j['stock']),
        lienKet: j['affiliateUrl'] as String?,
        san: j['affiliatePlatform'] as String?,
        danhMuc: j['categoryName'] as String?,
        danhMucSlug: j['categorySlug'] as String?,
        danhMucId: chuoi(j['categoryId']),
        luotBam: soNguyen(j['clickCount']),
        hoaHong: soThuc(j['commissionPercent']),
        noiBat: j['featured'] == true,
        dangBan: j['active'] != false,
      );
}

/// Một danh mục trong gian hàng.
class DanhMuc {
  const DanhMuc({required this.id, required this.ten, required this.slug});
  final String id;
  final String ten;
  final String slug;

  factory DanhMuc.fromJson(Map<String, dynamic> j) => DanhMuc(
        id: (j['id'] ?? '').toString(),
        ten: (j['name'] ?? '') as String,
        slug: (j['slug'] ?? '') as String,
      );
}

/// Tên hiển thị của sàn liên kết.
String tenSan(String? s) => switch ((s ?? '').toUpperCase()) {
      'SHOPEE' => 'Shopee',
      'LAZADA' => 'Lazada',
      'TIKI' => 'Tiki',
      'TIKTOK' => 'TikTok Shop',
      '' => 'sàn liên kết',
      _ => s!,
    };

class ShopRepository {
  ShopRepository(this._api);
  final ApiClient _api;

  static const coTrang = 20;

  Future<List<DanhMuc>> danhMuc() async {
    final d = await _api.get<dynamic>(Endpoints.shopCategories);
    if (d is! List) return const [];
    return d.whereType<Map<String, dynamic>>().map(DanhMuc.fromJson).toList();
  }

  Future<Trang<SanPham>> sanPham({
    String? danhMuc,
    String? tuKhoa,
    int trang = 0,
  }) async {
    final d = await _api.get<dynamic>(Endpoints.shopProducts, query: {
      'page': trang,
      'size': coTrang,
      if (danhMuc != null && danhMuc.isNotEmpty) 'category': danhMuc,
      if (tuKhoa != null && tuKhoa.trim().isNotEmpty) 'keyword': tuKhoa.trim(),
    });
    return Trang.tu(d, SanPham.fromJson);
  }

  Future<SanPham> chiTiet(String slug) async => SanPham.fromJson(
      await _api.get<Map<String, dynamic>>(Endpoints.shopProduct(slug)));

  /// Ghi nhận lượt bấm sang sàn và lấy liên kết để mở.
  ///
  /// Endpoint nhận **slug**, không phải id — bản đầu gửi id, máy chủ trả 404,
  /// và vì lỗi bị nuốt nên mọi lượt bấm (tức số liệu hoa hồng của dự án) mất
  /// sạch mà không ai hay. Máy chủ còn trả lại chính liên kết cần mở; dùng nó
  /// thay vì liên kết cũ trong danh sách, để quản trị đổi liên kết là có hiệu
  /// lực ngay.
  ///
  /// KHÔNG được để việc ghi nhận chặn việc mở liên kết: người dùng bấm mua
  /// thì phải sang được sàn, kể cả khi máy chủ đang hỏng. Hỏng thì trả
  /// [duPhong].
  Future<String?> ghiNhanBam(String slug, {String? duPhong}) async {
    try {
      final d = await _api.post<dynamic>(Endpoints.shopClick(slug));
      final url = d is Map ? chuoi(d['url']) : null;
      return url ?? duPhong;
    } catch (_) {
      return duPhong;
    }
  }
}

final shopRepositoryProvider =
    Provider((ref) => ShopRepository(ref.watch(apiClientProvider)));

final danhMucProvider = FutureProvider<List<DanhMuc>>(
    (ref) => ref.watch(shopRepositoryProvider).danhMuc());

/// Sản phẩm nổi bật cho trang chủ — lấy trang đầu của danh sách.
final sanPhamProvider = FutureProvider<List<SanPham>>((ref) async =>
    (await ref.watch(shopRepositoryProvider).sanPham()).muc);

final chiTietSanPhamProvider = FutureProvider.family<SanPham, String>(
    (ref, slug) => ref.watch(shopRepositoryProvider).chiTiet(slug));
