import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/auth/auth_controller.dart';

/// Một gói AI đang bán.
class GoiAi {
  const GoiAi({
    required this.id,
    required this.loai,
    required this.ten,
    required this.hanMucNgay,
    required this.gia,
    required this.soNgay,
    this.moTa,
  });

  final String id;

  /// MONTHLY, DAY_PASS hoặc FREE.
  final String loai;
  final String ten;
  final int hanMucNgay;
  final int gia;
  final int soNgay;
  final String? moTa;

  factory GoiAi.fromJson(Map<String, dynamic> j) => GoiAi(
    id: (j['id'] ?? '').toString(),
    loai: (j['planType'] ?? 'FREE') as String,
    ten: (j['name'] ?? '') as String,
    hanMucNgay: (j['dailyQuota'] as num?)?.toInt() ?? 0,
    gia: (j['price'] as num?)?.toInt() ?? 0,
    soNgay: (j['durationDays'] as num?)?.toInt() ?? 0,
    moTa: j['description'] as String?,
  );
}

/// Một lượt mua gói của người dùng.
class LuotMuaGoi {
  const LuotMuaGoi({
    required this.id,
    required this.tenGoi,
    required this.hanMucNgay,
    required this.gia,
    required this.batDau,
    required this.ketThuc,
    required this.trangThai,
    required this.kieuMua,
  });

  final String id;
  final String tenGoi;
  final int hanMucNgay;
  final int gia;
  final DateTime? batDau;
  final DateTime? ketThuc;

  /// ACTIVE, EXPIRED, SUPERSEDED hoặc CANCELLED.
  final String trangThai;

  /// STRIPE, PAYOS, WALLET hoặc MANUAL.
  final String kieuMua;

  bool get dangChay => trangThai == 'ACTIVE';

  /// Số ngày còn lại, 0 nếu đã hết hạn.
  int get soNgayConLai {
    if (ketThuc == null) return 0;
    final con = ketThuc!.difference(DateTime.now()).inDays;
    return con < 0 ? 0 : con;
  }

  factory LuotMuaGoi.fromJson(Map<String, dynamic> j) => LuotMuaGoi(
    id: (j['id'] ?? '').toString(),
    tenGoi: (j['planNameSnapshot'] ?? j['planName'] ?? '') as String,
    hanMucNgay: (j['dailyQuotaSnapshot'] ?? j['dailyQuota'] as num?) is num
        ? ((j['dailyQuotaSnapshot'] ?? j['dailyQuota']) as num).toInt()
        : 0,
    gia: (j['priceSnapshot'] ?? j['price'] as num?) is num
        ? ((j['priceSnapshot'] ?? j['price']) as num).toInt()
        : 0,
    batDau: DateTime.tryParse((j['startAt'] ?? '').toString()),
    ketThuc: DateTime.tryParse((j['endAt'] ?? '').toString()),
    trangThai: (j['status'] ?? 'ACTIVE') as String,
    kieuMua: (j['purchaseType'] ?? 'WALLET') as String,
  );
}

/// Số lượt AI đã dùng trong một ngày.
class LuotDungNgay {
  const LuotDungNgay({required this.ngay, required this.soLuot});

  final DateTime ngay;
  final int soLuot;

  factory LuotDungNgay.fromJson(Map<String, dynamic> j) => LuotDungNgay(
    ngay:
        DateTime.tryParse((j['usageDate'] ?? '').toString()) ?? DateTime.now(),
    soLuot: (j['countUsed'] as num?)?.toInt() ?? 0,
  );
}

class GoiAiRepository {
  GoiAiRepository(this._api);
  final ApiClient _api;

  Future<List<GoiAi>> dangBan() async {
    final ds = await _api.get<List<dynamic>>(Endpoints.goiDangBan);
    return ds
        .map((e) => GoiAi.fromJson(e as Map<String, dynamic>))
        .where((g) => g.gia > 0)
        .toList();
  }

  Future<List<LuotMuaGoi>> cuaToi(String userId) async {
    final ds = await _api.get<List<dynamic>>(Endpoints.goiCuaToi(userId));
    return ds
        .map((e) => LuotMuaGoi.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<LuotDungNgay>> luotDung(String userId, DateTime ngay) async {
    final d =
        '${ngay.year.toString().padLeft(4, '0')}'
        '-${ngay.month.toString().padLeft(2, '0')}'
        '-${ngay.day.toString().padLeft(2, '0')}';
    final ds = await _api.get<List<dynamic>>(
      Endpoints.goiLuotDung(userId),
      query: {'date': d},
    );
    return ds
        .map((e) => LuotDungNgay.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Mua gói, trừ thẳng vào số dư ví.
  ///
  /// Chỉ có WALLET chứ không có PayOS: trên app, dẫn người dùng sang cổng
  /// thanh toán rồi quay lại là một đường vòng dễ đứt. Nạp ví một lần rồi mua
  /// nhiều lần bằng số dư thì mỗi lần mua chỉ còn một cú bấm.
  Future<void> mua(String planId) => _api.post(
    Endpoints.goiMua,
    body: {'planId': planId, 'purchaseType': 'WALLET'},
  );
}

final goiAiRepositoryProvider = Provider(
  (ref) => GoiAiRepository(ref.watch(apiClientProvider)),
);

final goiDangBanProvider = FutureProvider<List<GoiAi>>(
  (ref) => ref.watch(goiAiRepositoryProvider).dangBan(),
);

/// Lượt mua đang chạy của chính người đang đăng nhập.
///
/// Backend chỉ cho xem của chính mình (hoặc USERS_MANAGE), nên luôn lấy id từ
/// phiên hiện tại chứ không nhận id từ ngoài vào.
final goiCuaToiProvider = FutureProvider<List<LuotMuaGoi>>((ref) async {
  final u = ref.watch(authControllerProvider).user;
  if (u == null) return const [];
  return ref.watch(goiAiRepositoryProvider).cuaToi(u.id);
});

final luotDungHomNayProvider = FutureProvider<int>((ref) async {
  final u = ref.watch(authControllerProvider).user;
  if (u == null) return 0;
  final ds = await ref
      .watch(goiAiRepositoryProvider)
      .luotDung(u.id, DateTime.now());
  if (ds.isEmpty) return 0;
  return ds.first.soLuot;
});

/// Nhãn tiếng Việt cho loại gói.
String nhanLoaiGoi(String loai) => switch (loai) {
  'MONTHLY' => 'Theo tháng',
  'DAY_PASS' => 'Theo ngày',
  'FREE' => 'Miễn phí',
  _ => loai,
};
