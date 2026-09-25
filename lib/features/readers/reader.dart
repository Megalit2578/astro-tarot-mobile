import 'package:characters/characters.dart';

/// Một Reader trong danh sách công khai.
///
/// Backend đã lọc sẵn: chỉ trả về hồ sơ đã duyệt, đang nhận lịch, và **có ít
/// nhất một mức giá**. Nên phía này không cần lọc lại — thấy gì thì hiện nấy.
class Reader {
  const Reader({
    required this.id,
    required this.userId,
    required this.username,
    required this.fullName,
    required this.rating,
    required this.totalReviews,
    required this.isAvailable,
    required this.specialties,
    this.avatar,
    this.bio,
    this.yearsExperience,
    this.pricePer15m,
    this.pricePer30m,
    this.pricePer60m,
  });

  final String id;
  final String userId;
  final String username;
  final String fullName;
  final String? avatar;
  final String? bio;
  final List<String> specialties;
  final int? yearsExperience;
  final int? pricePer15m;
  final int? pricePer30m;
  final int? pricePer60m;
  final double rating;
  final int totalReviews;
  final bool isAvailable;

  /// Mức rẻ nhất để hiện "chỉ từ".
  ///
  /// Lấy giá NHỎ NHẤT trong ba mức chứ không lấy mức 15 phút đầu tiên khác
  /// null: không có gì bắt buộc mức ngắn phải rẻ hơn mức dài, và một Reader
  /// chỉ khai giá 30 và 60 phút vẫn phải hiện được con số.
  int? get giaReNhat {
    final ds = [pricePer15m, pricePer30m, pricePer60m].whereType<int>();
    if (ds.isEmpty) return null;
    return ds.reduce((a, b) => a < b ? a : b);
  }

  /// Tên hiển thị — hồ sơ thiếu họ tên thì lùi về username.
  String get ten => fullName.trim().isEmpty ? '@$username' : fullName;

  /// Chữ cái cho ảnh đại diện chữ.
  String get chuDau {
    final t = ten.replaceFirst('@', '').trim();
    return t.isEmpty ? '?' : t.characters.first.toUpperCase();
  }

  factory Reader.fromJson(Map<String, dynamic> j) {
    final sp = j['specialties'];
    return Reader(
      id: j['id'] as String,
      userId: (j['userId'] ?? '') as String,
      username: (j['username'] ?? '') as String,
      fullName: (j['fullName'] ?? '') as String,
      avatar: j['avatar'] as String?,
      bio: j['bio'] as String?,
      specialties: sp is List ? sp.whereType<String>().toList() : const [],
      yearsExperience: (j['yearsExperience'] as num?)?.toInt(),
      pricePer15m: (j['pricePer15m'] as num?)?.toInt(),
      pricePer30m: (j['pricePer30m'] as num?)?.toInt(),
      pricePer60m: (j['pricePer60m'] as num?)?.toInt(),
      rating: (j['rating'] as num?)?.toDouble() ?? 0,
      totalReviews: (j['totalReviews'] as num?)?.toInt() ?? 0,
      isAvailable: j['isAvailable'] as bool? ?? true,
    );
  }
}
