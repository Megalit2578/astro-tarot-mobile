import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/auth/auth_controller.dart';

/// Ví của người dùng.
class Vi {
  const Vi({required this.id, required this.soDu});

  final String id;
  final int soDu;

  factory Vi.fromJson(Map<String, dynamic> j) => Vi(
    id: (j['id'] ?? '').toString(),
    soDu: (j['balance'] as num?)?.toInt() ?? 0,
  );
}

/// Một dòng trong sổ cái ví.
class GiaoDichVi {
  const GiaoDichVi({
    required this.id,
    required this.loai,
    required this.soTien,
    required this.soDuTruoc,
    required this.soDuSau,
    required this.trangThai,
    this.moTa,
    this.luc,
  });

  final String id;

  /// TOPUP, AI_SUBSCRIPTION, BOOKING_PAYMENT, BOOKING_REFUND,
  /// ADMIN_ADJUSTMENT.
  final String loai;

  /// Số tiền, LUÔN DƯƠNG kể cả giao dịch trừ ví.
  ///
  /// Máy chủ lưu độ lớn chứ không lưu dấu — xem `WalletServiceImpl.debit`, nó
  /// đặt `.amount(amount)` với amount đã bắt buộc > 0.
  final int soTien;

  final int soDuTruoc;
  final int soDuSau;
  final String trangThai;
  final String? moTa;
  final DateTime? luc;

  /// Tiền vào hay tiền ra, đọc ở chênh lệch số dư.
  ///
  /// Bản trước viết `soTien >= 0`, mà `soTien` không bao giờ âm — nên MỌI giao
  /// dịch đều hiện là tiền vào, kể cả "Mua gói AI" và "Thanh toán buổi xem".
  /// Sổ ví cộng lên trông như chỉ có tiền chảy vào.
  ///
  /// Chênh lệch số dư là nguồn đáng tin duy nhất: nó đúng cho cả những loại
  /// giao dịch chưa tồn tại hôm nay, và đúng cả với điều chỉnh của quản trị
  /// vốn có thể cộng hoặc trừ.
  bool get tienVao => soDuSau >= soDuTruoc;

  factory GiaoDichVi.fromJson(Map<String, dynamic> j) => GiaoDichVi(
    id: (j['id'] ?? '').toString(),
    loai: (j['type'] ?? '') as String,
    soTien: (j['amount'] as num?)?.toInt() ?? 0,
    soDuTruoc: (j['balanceBefore'] as num?)?.toInt() ?? 0,
    soDuSau: (j['balanceAfter'] as num?)?.toInt() ?? 0,
    trangThai: (j['status'] ?? 'SUCCESS') as String,
    moTa: j['description'] as String?,
    luc: DateTime.tryParse((j['createdAt'] ?? '').toString()),
  );
}

/// Hướng dẫn chuyển khoản mà máy chủ trả về sau khi tạo lệnh nạp.
class HuongDanNap {
  const HuongDanNap({
    required this.soTien,
    this.maThamChieu,
    this.tenNganHang,
    this.soTaiKhoan,
    this.chuTaiKhoan,
    this.noiDung,
    this.duongDanThanhToan,
    this.anhQr,
  });

  final int soTien;
  final String? maThamChieu;
  final String? tenNganHang;
  final String? soTaiKhoan;
  final String? chuTaiKhoan;
  final String? noiDung;
  final String? duongDanThanhToan;
  final String? anhQr;

  factory HuongDanNap.fromJson(Map<String, dynamic> j) => HuongDanNap(
    soTien: (j['amount'] as num?)?.toInt() ?? 0,
    maThamChieu: j['referenceCode'] as String?,
    tenNganHang: j['bankName'] as String?,
    soTaiKhoan: j['bankAccountNumber'] as String?,
    chuTaiKhoan: j['bankAccountHolder'] as String?,
    noiDung: j['transferContent'] as String?,
    duongDanThanhToan: j['checkoutUrl'] as String?,
    anhQr: j['qrCode'] as String?,
  );
}

class ViRepository {
  ViRepository(this._api);
  final ApiClient _api;

  Future<Vi> cuaToi() async =>
      Vi.fromJson(await _api.get<Map<String, dynamic>>(Endpoints.vi));

  Future<List<GiaoDichVi>> giaoDich({int trang = 0, int co = 20}) async {
    final j = await _api.get<Map<String, dynamic>>(
      Endpoints.viGiaoDich,
      query: {'page': trang, 'size': co},
    );
    final ds = (j['content'] as List<dynamic>?) ?? const [];
    return ds
        .map((e) => GiaoDichVi.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<HuongDanNap> nap(int soTien) async => HuongDanNap.fromJson(
    await _api.post<Map<String, dynamic>>(
      Endpoints.viNap,
      body: {'amount': soTien},
    ),
  );
}

final viRepositoryProvider = Provider(
  (ref) => ViRepository(ref.watch(apiClientProvider)),
);

final viCuaToiProvider = FutureProvider<Vi>(
  (ref) => ref.watch(viRepositoryProvider).cuaToi(),
);

final giaoDichViProvider = FutureProvider<List<GiaoDichVi>>(
  (ref) => ref.watch(viRepositoryProvider).giaoDich(),
);

/// Nhãn tiếng Việt cho loại giao dịch.
///
/// Nói theo việc đã xảy ra chứ không dịch sát mã: người xem sổ cái muốn biết
/// "mua gói AI" chứ không phải "AI_SUBSCRIPTION".
String nhanLoaiGiaoDich(String loai) => switch (loai) {
  'TOPUP' => 'Nạp ví',
  'AI_SUBSCRIPTION' => 'Mua gói AI',
  'BOOKING_PAYMENT' => 'Thanh toán buổi xem',
  'BOOKING_REFUND' => 'Hoàn tiền buổi xem',
  'ADMIN_ADJUSTMENT' => 'Quản trị điều chỉnh',
  _ => loai,
};
