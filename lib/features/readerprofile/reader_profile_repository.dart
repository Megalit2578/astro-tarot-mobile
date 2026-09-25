import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_controller.dart';

/// Hồ sơ Reader của chính mình.
class HoSoReader {
  const HoSoReader({
    required this.id,
    required this.nhanLich,
    required this.chuyenMon,
    this.gioiThieu,
    this.soNam,
    this.gia15,
    this.gia30,
    this.gia60,
  });

  final String id;
  final bool nhanLich;
  final List<String> chuyenMon;
  final String? gioiThieu;
  final int? soNam;
  final int? gia15;
  final int? gia30;
  final int? gia60;

  /// Hồ sơ này có xuất hiện trong danh sách công khai không.
  ///
  /// Backend chỉ trả về Reader **đã duyệt, đang nhận lịch, và có ít nhất một
  /// mức giá**. Reader không biết luật đó nên rất dễ ngồi chờ khách mà không
  /// hiểu vì sao mình không hiện — màn hồ sơ phải nói thẳng ra.
  bool get hienCongKhai =>
      nhanLich && (gia15 != null || gia30 != null || gia60 != null);

  factory HoSoReader.fromJson(Map<String, dynamic> j) {
    final sp = j['specialties'];
    return HoSoReader(
      id: (j['id'] ?? '').toString(),
      nhanLich: j['isAvailable'] as bool? ?? j['available'] as bool? ?? true,
      chuyenMon: sp is List ? sp.whereType<String>().toList() : const [],
      gioiThieu: j['bio'] as String?,
      soNam: (j['yearsExperience'] as num?)?.toInt(),
      gia15: (j['pricePer15m'] as num?)?.toInt(),
      gia30: (j['pricePer30m'] as num?)?.toInt(),
      gia60: (j['pricePer60m'] as num?)?.toInt(),
    );
  }
}

/// Một khung giờ rảnh hằng tuần.
class KhungRanh {
  const KhungRanh({
    required this.id,
    required this.thu,
    required this.batDau,
    required this.ketThuc,
  });

  final String id;

  /// 1 = Thứ Hai … 7 = Chủ nhật, theo quy ước backend đang dùng.
  final int thu;
  final String batDau;
  final String ketThuc;

  /// `09:00:00` → `09:00`. Giây luôn bằng không nên hiện ra chỉ gây rối.
  static String gonGio(String t) =>
      t.length >= 5 ? t.substring(0, 5) : t;

  factory KhungRanh.fromJson(Map<String, dynamic> j) => KhungRanh(
        id: (j['id'] ?? '').toString(),
        thu: (j['dayOfWeek'] as num?)?.toInt() ?? 1,
        batDau: (j['startTime'] ?? '') as String,
        ketThuc: (j['endTime'] ?? '') as String,
      );
}

class ReaderProfileRepository {
  ReaderProfileRepository(this._api);
  final ApiClient _api;

  static const _hoSo = '/api/v1/readers/profile';
  static const _ranh = '/api/v1/availability';

  Future<HoSoReader?> cuaToi() async {
    try {
      return HoSoReader.fromJson(
          await _api.get<Map<String, dynamic>>('$_hoSo/me'));
    } on ApiException catch (e) {
      // 404 nghĩa là chưa có hồ sơ Reader — đó là trạng thái bình thường của
      // người chưa nộp đơn, không phải lỗi.
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> luu({
    String? gioiThieu,
    List<String>? chuyenMon,
    int? soNam,
    int? gia15,
    int? gia30,
    int? gia60,
    bool? nhanLich,
  }) {
    final body = <String, dynamic>{
      'bio': ?gioiThieu,
      'specialties': ?chuyenMon,
      'yearsExperience': ?soNam,
      'pricePer15m': ?gia15,
      'pricePer30m': ?gia30,
      'pricePer60m': ?gia60,
      'available': ?nhanLich,
    };
    return _api.patch(_hoSo, body: body);
  }

  Future<List<KhungRanh>> khungRanh() async {
    final d = await _api.get<dynamic>(_ranh);
    if (d is! List) return const [];
    final ds =
        d.whereType<Map<String, dynamic>>().map(KhungRanh.fromJson).toList();
    ds.sort((a, b) {
      final t = a.thu.compareTo(b.thu);
      return t != 0 ? t : a.batDau.compareTo(b.batDau);
    });
    return ds;
  }

  /// Thêm khung rảnh.
  ///
  /// Giờ gửi dạng `HH:mm:ss` — backend parse `LocalTime`, và `HH:mm` trần
  /// cũng nhận nhưng gửi đủ giây thì khỏi phụ thuộc vào chuyện đó.
  Future<void> themKhung({
    required int thu,
    required String batDau,
    required String ketThuc,
  }) =>
      _api.post(_ranh, body: {
        'dayOfWeek': thu,
        'startTime': batDau,
        'endTime': ketThuc,
      });

  Future<void> xoaKhung(String id) => _api.delete('$_ranh/$id');
}

final readerProfileRepositoryProvider =
    Provider((ref) => ReaderProfileRepository(ref.watch(apiClientProvider)));

final hoSoReaderProvider = FutureProvider<HoSoReader?>(
    (ref) => ref.watch(readerProfileRepositoryProvider).cuaToi());

final khungRanhProvider = FutureProvider<List<KhungRanh>>(
    (ref) => ref.watch(readerProfileRepositoryProvider).khungRanh());

const tenThu = ['', 'Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu',
                'Thứ Bảy', 'Chủ nhật'];
