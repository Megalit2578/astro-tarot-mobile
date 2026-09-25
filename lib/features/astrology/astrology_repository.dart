import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/api/trang.dart';
import '../../core/auth/auth_controller.dart';

const tenKieuHoSo = {
  'SELF': 'Của tôi',
  'OTHER': 'Người khác',
  'COUPLE': 'Cặp đôi',
};

/// `2001-09-25` → `25/09/2001`. Chuỗi lạ thì trả nguyên văn.
String ngayViTuIso(String iso) {
  final p = iso.split('-');
  return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : iso;
}

/// Một hồ sơ chiêm tinh (bản đồ sao).
class HoSoSao {
  const HoSoSao({
    required this.id,
    required this.tieuDe,
    required this.ngaySinh,
    required this.noiSinh,
    required this.kieu,
    required this.chinh,
    this.tenNguoi,
    this.gioSinh,
    this.viDo,
    this.kinhDo,
    this.muiGio,
  });

  final String id;
  final String tieuDe;
  final String? tenNguoi;

  /// `YYYY-MM-DD`, giữ nguyên chuỗi backend trả — ngày sinh không có múi
  /// giờ, đổi sang DateTime rồi đổi lại là nguy cơ lệch một ngày.
  final String ngaySinh;

  /// `HH:mm:ss` hoặc null khi không biết giờ sinh.
  final String? gioSinh;
  final String noiSinh;
  final double? viDo;
  final double? kinhDo;
  final String? muiGio;
  final String kieu;

  /// Hồ sơ AI dùng khi đọc bài.
  final bool chinh;

  String get ngaySinhVi => ngayViTuIso(ngaySinh);

  /// `07:30:00` → `07:30`.
  String? get gioSinhNgan =>
      gioSinh == null || gioSinh!.length < 5 ? gioSinh : gioSinh!.substring(0, 5);

  factory HoSoSao.fromJson(Map<String, dynamic> j) => HoSoSao(
        id: (j['id'] ?? '').toString(),
        tieuDe: (j['title'] ?? '') as String,
        tenNguoi: chuoi(j['targetName']),
        ngaySinh: (j['birthDate'] ?? '') as String,
        gioSinh: chuoi(j['birthTime']),
        noiSinh: (j['birthPlace'] ?? '') as String,
        viDo: soThuc(j['latitude']),
        kinhDo: soThuc(j['longitude']),
        muiGio: chuoi(j['timezone']),
        kieu: (j['profileType'] ?? 'SELF') as String,
        chinh: j['isPrimary'] == true || j['primary'] == true,
      );
}

/// Một gợi ý địa danh kèm toạ độ.
class DiaDanh {
  const DiaDanh(this.ten, this.viDo, this.kinhDo);
  final String ten;
  final double viDo;
  final double kinhDo;
}

/// Tra nơi sinh ra toạ độ.
///
/// Backend bắt buộc có vĩ độ / kinh độ để tính bản đồ sao, mà người dùng thì
/// chỉ biết tên nơi mình sinh ra. Dùng đúng nguồn web dùng (OpenStreetMap
/// Nominatim, giới hạn ở Việt Nam) để cùng một địa danh ra cùng một toạ độ ở
/// hai nơi.
///
/// Trả rỗng thay vì ném lỗi: đây là tính năng phụ trợ, mạng hỏng thì người
/// dùng vẫn phải gõ tiếp được chứ không nên thấy màn hình lỗi.
typedef TimDiaDanh = Future<List<DiaDanh>> Function(String q);

Future<List<DiaDanh>> timDiaDanhNominatim(String q, {Dio? dio}) async {
  if (q.trim().length < 2) return const [];
  try {
    final r = await (dio ?? Dio()).get<dynamic>(
      'https://nominatim.openstreetmap.org/search',
      queryParameters: {
        'q': q.trim(),
        'format': 'json',
        'limit': 5,
        'countrycodes': 'vn',
        'accept-language': 'vi',
      },
      // Nominatim bắt buộc định danh ứng dụng; thiếu là bị chặn.
      options: Options(headers: {
        'User-Agent': 'ASTROTAROT-mobile/1.0 (https://astrotarot.date)',
      }),
    );
    final d = r.data;
    if (d is! List) return const [];
    return [
      for (final m in d.whereType<Map>())
        if (double.tryParse('${m['lat']}') != null &&
            double.tryParse('${m['lon']}') != null)
          DiaDanh('${m['display_name']}', double.parse('${m['lat']}'),
              double.parse('${m['lon']}')),
    ];
  } catch (_) {
    return const [];
  }
}

final timDiaDanhProvider = Provider<TimDiaDanh>((_) => timDiaDanhNominatim);

class AstrologyRepository {
  AstrologyRepository(this._api);
  final ApiClient _api;

  Future<List<HoSoSao>> danhSach() async {
    final d = await _api.get<dynamic>(Endpoints.astrologyProfiles);
    return Trang.tu(d, HoSoSao.fromJson).muc;
  }

  Future<void> luu(String? id, Map<String, dynamic> body) => id == null
      ? _api.post(Endpoints.astrologyProfiles, body: body)
      : _api.put(Endpoints.astrologyProfile(id), body: body);

  Future<void> xoa(String id) => _api.delete(Endpoints.astrologyProfile(id));
}

final astrologyRepositoryProvider =
    Provider((ref) => AstrologyRepository(ref.watch(apiClientProvider)));

final hoSoSaoProvider = FutureProvider<List<HoSoSao>>(
    (ref) => ref.watch(astrologyRepositoryProvider).danhSach());
