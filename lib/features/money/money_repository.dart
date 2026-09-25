import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_controller.dart';

/// Số dư ký quỹ của Reader.
///
/// Ba con số tách bạch có lý do: [choVe] là tiền của buổi đã xong nhưng còn
/// trong thời gian giữ, [soDu] là tiền đã rút được. Gộp lại thành một con số
/// là hứa với Reader nhiều hơn thứ họ thật sự rút được ngay.
class SoDu {
  const SoDu({
    required this.soDu,
    required this.choVe,
    required this.tongKiemDuoc,
    required this.daRut,
    required this.mucRutToiThieu,
    required this.tienPhat,
  });

  final int soDu;
  final int choVe;
  final int tongKiemDuoc;
  final int daRut;
  final int mucRutToiThieu;
  final int tienPhat;

  bool get duDieuKienRut => soDu >= mucRutToiThieu && soDu > 0;

  factory SoDu.fromJson(Map<String, dynamic> j) {
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;
    return SoDu(
      soDu: n('balance'),
      choVe: n('pendingBalance'),
      tongKiemDuoc: n('totalEarned'),
      daRut: n('totalWithdrawn'),
      mucRutToiThieu: n('minimumPayout'),
      tienPhat: n('penaltyOwed'),
    );
  }
}

class GiaoDichKyQuy {
  const GiaoDichKyQuy({
    required this.id,
    required this.loai,
    required this.soTien,
    this.ghiChu,
    this.luc,
  });

  final String id;
  final String loai;
  final int soTien;
  final String? ghiChu;
  final DateTime? luc;

  factory GiaoDichKyQuy.fromJson(Map<String, dynamic> j) => GiaoDichKyQuy(
        id: (j['id'] ?? '').toString(),
        loai: (j['kind'] ?? '') as String,
        soTien: (j['amount'] as num?)?.toInt() ?? 0,
        ghiChu: j['note'] as String?,
        luc: DateTime.tryParse((j['createdAt'] ?? '').toString()),
      );
}

class YeuCauRut {
  const YeuCauRut({
    required this.id,
    required this.soTien,
    required this.trangThai,
    this.nganHang,
    this.soTaiKhoan,
    this.luc,
  });

  final String id;
  final int soTien;
  final String trangThai;
  final String? nganHang;
  final String? soTaiKhoan;
  final DateTime? luc;

  factory YeuCauRut.fromJson(Map<String, dynamic> j) => YeuCauRut(
        id: (j['id'] ?? '').toString(),
        soTien: (j['amount'] as num?)?.toInt() ?? 0,
        trangThai: (j['status'] ?? '') as String,
        nganHang: j['bankName'] as String?,
        soTaiKhoan: j['bankAccount'] as String?,
        luc: DateTime.tryParse((j['createdAt'] ?? '').toString()),
      );
}

class MoneyRepository {
  MoneyRepository(this._api);
  final ApiClient _api;

  static const _escrow = '/api/v1/me/escrow';
  static const _payouts = '/api/v1/me/payouts';

  Future<SoDu> soDu() async =>
      SoDu.fromJson(await _api.get<Map<String, dynamic>>(_escrow));

  Future<List<GiaoDichKyQuy>> giaoDich() async {
    final d = await _api.get<dynamic>('$_escrow/transactions',
        query: {'page': 0, 'size': 30});
    final l = d is Map ? d['content'] : d;
    if (l is! List) return const [];
    return l
        .whereType<Map<String, dynamic>>()
        .map(GiaoDichKyQuy.fromJson)
        .toList();
  }

  Future<List<YeuCauRut>> yeuCauRut() async {
    final d = await _api.get<dynamic>(_payouts, query: {'page': 0, 'size': 30});
    final l = d is Map ? d['content'] : d;
    if (l is! List) return const [];
    return l.whereType<Map<String, dynamic>>().map(YeuCauRut.fromJson).toList();
  }

  Future<void> xinRut({
    required int soTien,
    required String nganHang,
    required String soTaiKhoan,
    required String chuTaiKhoan,
    String? maNganHang,
  }) =>
      _api.post(_payouts, body: {
        'amount': soTien,
        'bankName': nganHang.trim(),
        'bankAccount': soTaiKhoan.trim(),
        'accountHolder': chuTaiKhoan.trim(),
        if (maNganHang != null && maNganHang.trim().isNotEmpty)
          'bankBin': maNganHang.trim(),
      });
}

final moneyRepositoryProvider =
    Provider((ref) => MoneyRepository(ref.watch(apiClientProvider)));

final soDuProvider =
    FutureProvider<SoDu>((ref) => ref.watch(moneyRepositoryProvider).soDu());

final giaoDichProvider = FutureProvider<List<GiaoDichKyQuy>>(
    (ref) => ref.watch(moneyRepositoryProvider).giaoDich());

final yeuCauRutProvider = FutureProvider<List<YeuCauRut>>(
    (ref) => ref.watch(moneyRepositoryProvider).yeuCauRut());

/// Nhãn tiếng Việt cho loại giao dịch ký quỹ.
String nhanLoaiGiaoDich(String k) => switch (k.toUpperCase()) {
      'HOLD' => 'Giữ tiền buổi xem',
      'RELEASE' => 'Trả về số dư',
      'REFUND' => 'Hoàn cho khách',
      'PAYOUT' => 'Chi ra',
      'PENALTY' => 'Trừ phạt',
      'COMMISSION' => 'Hoa hồng sàn',
      _ => k,
    };

String nhanTrangThaiRut(String s) => switch (s.toUpperCase()) {
      'PENDING' || 'REQUESTED' => 'Đang chờ duyệt',
      'APPROVED' => 'Đã duyệt, chờ chi',
      'PAID' => 'Đã chi',
      'REJECTED' => 'Bị từ chối',
      _ => s,
    };
