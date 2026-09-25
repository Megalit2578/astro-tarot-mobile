import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/auth/auth_controller.dart';
import 'reader.dart';

class ReadersRepository {
  ReadersRepository(this._api);

  final ApiClient _api;

  /// `/api/v1/readers` trả về một MẢNG phẳng, không phải trang.
  ///
  /// Khác với phần lớn endpoint khác của dự án. Nên không bọc Page ở đây —
  /// bọc vào rồi lại phải bóc ra, và chỗ bóc sai là màn hình trắng.
  Future<List<Reader>> danhSach() async {
    final data = await _api.get<List<dynamic>>(Endpoints.readers);
    return data
        .whereType<Map<String, dynamic>>()
        .map(Reader.fromJson)
        .toList();
  }

  Future<Reader> chiTiet(String id) async {
    final data = await _api.get<Map<String, dynamic>>(Endpoints.reader(id));
    return Reader.fromJson(data);
  }
}

final readersRepositoryProvider = Provider(
  (ref) => ReadersRepository(ref.watch(apiClientProvider)),
);

/// Danh sách Reader. Tự tải lại khi bị làm mới.
final readersProvider = FutureProvider<List<Reader>>(
  (ref) => ref.watch(readersRepositoryProvider).danhSach(),
);

/// Từ khoá tìm kiếm — lọc tại máy.
///
/// Lọc phía client vì backend chưa có tham số tìm kiếm cho endpoint này, và
/// số Reader hiện còn nhỏ. Khi danh sách lớn lên thì chuyển sang lọc phía máy
/// chủ, đừng tải cả sàn về rồi mới lọc.
///
/// Dùng Notifier chứ không phải StateProvider: Riverpod 3 đã bỏ hẳn
/// StateProvider.
class TuKhoa extends Notifier<String> {
  @override
  String build() => '';

  void dat(String v) => state = v;
}

final tuKhoaProvider = NotifierProvider<TuKhoa, String>(TuKhoa.new);

final readersDaLocProvider = Provider<AsyncValue<List<Reader>>>((ref) {
  final ds = ref.watch(readersProvider);
  final tu = ref.watch(tuKhoaProvider).trim().toLowerCase();
  if (tu.isEmpty) return ds;
  return ds.whenData(
    (l) => l.where((r) {
      final trong = [
        r.fullName,
        r.username,
        r.bio ?? '',
        ...r.specialties,
      ].join(' ').toLowerCase();
      return trong.contains(tu);
    }).toList(),
  );
});
