import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/auth/auth_controller.dart';

/// Hồ sơ đầy đủ của người đang đăng nhập.
///
/// Khác [AppUser] ở chỗ nó mang cả những trường chỉ màn hồ sơ cần (số điện
/// thoại, địa chỉ, giới tính…). Không nhét hết vào AppUser: AppUser nằm trong
/// trí nhớ suốt phiên và được đọc ở mọi màn, còn mấy trường này chỉ dùng ở
/// đúng một chỗ.
class HoSo {
  const HoSo({
    required this.id,
    required this.username,
    required this.fullName,
    this.email,
    this.emailVerified = false,
    this.phone,
    this.avatar,
    this.gender,
    this.dateOfBirth,
    this.bio,
    this.address,
    this.city,
    this.country,
  });

  final String id;
  final String username;
  final String fullName;
  final String? email;
  final bool emailVerified;
  final String? phone;
  final String? avatar;
  final String? gender;
  final String? dateOfBirth;
  final String? bio;
  final String? address;
  final String? city;
  final String? country;

  factory HoSo.fromJson(Map<String, dynamic> j) => HoSo(
        id: (j['id'] ?? '').toString(),
        username: (j['username'] ?? '') as String,
        fullName: (j['fullName'] ?? '') as String,
        email: j['email'] as String?,
        emailVerified: j['emailVerified'] == true,
        phone: j['phone'] as String?,
        avatar: j['avatar'] as String?,
        gender: j['gender'] as String?,
        dateOfBirth: j['dateOfBirth']?.toString(),
        bio: j['bio'] as String?,
        address: j['address'] as String?,
        city: j['city'] as String?,
        country: j['country'] as String?,
      );
}

class ProfileRepository {
  ProfileRepository(this._api);

  final ApiClient _api;

  Future<HoSo> doc() async =>
      HoSo.fromJson(await _api.get<Map<String, dynamic>>(Endpoints.me));

  /// Lưu hồ sơ.
  ///
  /// Chỉ gửi trường KHÁC null. Backend ghi đè theo từng trường gửi lên, nên
  /// gửi kèm null là xoá trắng những ô màn hình này không đụng tới.
  Future<HoSo> luu(Map<String, dynamic> thayDoi) async {
    thayDoi.removeWhere((_, v) => v == null);
    final d = await _api.patch<Map<String, dynamic>>(
      Endpoints.me,
      body: thayDoi,
    );
    return HoSo.fromJson(d);
  }

  Future<void> doiMatKhau(String hienTai, String moi) => _api.post(
        Endpoints.meChangePassword,
        body: {'currentPassword': hienTai, 'newPassword': moi},
      );

  /// Tải ảnh đại diện. Trường form phải tên đúng `file`.
  Future<HoSo> taiAnh(String duongDan) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(duongDan),
    });
    final d = await _api.post<Map<String, dynamic>>(
      Endpoints.meAvatar,
      body: form,
    );
    return HoSo.fromJson(d);
  }

  Future<HoSo> goAnh() async =>
      HoSo.fromJson(await _api.delete<Map<String, dynamic>>(Endpoints.meAvatar));
}

final profileRepositoryProvider =
    Provider((ref) => ProfileRepository(ref.watch(apiClientProvider)));

final hoSoProvider =
    FutureProvider<HoSo>((ref) => ref.watch(profileRepositoryProvider).doc());
