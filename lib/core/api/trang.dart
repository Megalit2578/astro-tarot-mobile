/// Một trang dữ liệu kiểu Spring `Page<T>`.
///
/// Backend trả khi thì trang `{content, totalPages, number, …}`, khi thì mảng
/// phẳng — tuỳ endpoint, và có endpoint từng đổi từ dạng này sang dạng kia.
/// [Trang.tu] nhận cả hai: đoán sai một dạng là màn hình rỗng mà không báo
/// lỗi gì, và "rỗng" trông y hệt "chưa có dữ liệu" — kiểu hỏng khó nhận ra
/// nhất.
class Trang<T> {
  const Trang({
    required this.muc,
    required this.so,
    required this.tongTrang,
    required this.tongSo,
  });

  const Trang.rong()
      : muc = const [],
        so = 0,
        tongTrang = 0,
        tongSo = 0;

  final List<T> muc;

  /// Số thứ tự trang, tính từ 0 như Spring.
  final int so;
  final int tongTrang;
  final int tongSo;

  bool get conNua => so + 1 < tongTrang;

  factory Trang.tu(dynamic data, T Function(Map<String, dynamic>) doc) {
    if (data is List) {
      final ds = data.whereType<Map<String, dynamic>>().map(doc).toList();
      return Trang(muc: ds, so: 0, tongTrang: 1, tongSo: ds.length);
    }
    if (data is! Map) return Trang<T>.rong();
    final raw = data['content'];
    final ds = raw is List
        ? raw.whereType<Map<String, dynamic>>().map(doc).toList()
        : <T>[];
    return Trang(
      muc: ds,
      so: (data['number'] as num?)?.toInt() ?? 0,
      tongTrang: (data['totalPages'] as num?)?.toInt() ?? 1,
      tongSo: (data['totalElements'] as num?)?.toInt() ?? ds.length,
    );
  }

  /// Nối trang kế tiếp vào sau — dùng cho nút "Tải thêm".
  Trang<T> noi(Trang<T> sau) => Trang(
        muc: [...muc, ...sau.muc],
        so: sau.so,
        tongTrang: sau.tongTrang,
        tongSo: sau.tongSo,
      );
}

/// Đọc chuỗi, bỏ qua giá trị rỗng. Dùng khi dựng model từ JSON lỏng.
String? chuoi(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

/// Đọc số nguyên từ JSON — backend trả Long, BigDecimal hay chuỗi tuỳ trường.
int? soNguyen(dynamic v) {
  if (v is num) return v.toInt();
  if (v is String) return num.tryParse(v)?.toInt();
  return null;
}

/// Đọc số thực từ JSON.
double? soThuc(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

/// Đọc thời điểm ISO-8601; hỏng thì trả null thay vì ném.
DateTime? thoiDiem(dynamic v) =>
    v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;
