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
    this.lyDoTuChoi,
  });

  final String id;
  final int soTien;
  final String trangThai;
  final String? nganHang;
  final String? soTaiKhoan;
  final DateTime? luc;
  final String? lyDoTuChoi;

  factory YeuCauRut.fromJson(Map<String, dynamic> j) => YeuCauRut(
        id: (j['id'] ?? '').toString(),
        soTien: (j['amount'] as num?)?.toInt() ?? 0,
        trangThai: (j['status'] ?? '') as String,
        nganHang: j['bankName'] as String?,
        // PayoutResponse trả `bankAccountMasked` (bốn số cuối) và
        // `requestedAt`. Bản đầu đọc `bankAccount` / `createdAt` — hai trường
        // không tồn tại — nên lịch sử rút không bao giờ có số tài khoản hay
        // ngày yêu cầu.
        soTaiKhoan: (j['bankAccountMasked'] ?? j['bankAccount']) as String?,
        luc: DateTime.tryParse(
            (j['requestedAt'] ?? j['createdAt'] ?? '').toString()),
        lyDoTuChoi: j['rejectReason'] as String?,
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
/// Nhãn loại dòng sổ ký quỹ, khớp ESCROW_KIND_LABEL của web.
///
/// Bản đầu chỉ biết năm loại, trong đó hai loại backend không hề có
/// (PAYOUT, COMMISSION); các loại thật như PAYOUT_RESERVE hiện nguyên mã.
String nhanLoaiGiaoDich(String k) => switch (k.toUpperCase()) {
      'HOLD' => 'Khách đã trả, đang giữ',
      'RELEASE' => 'Nhận từ buổi xem',
      'REFUND' => 'Hoàn lại cho khách',
      'PENALTY' => 'Trừ do vi phạm',
      'PENALTY_DEBT' => 'Ghi nợ tiền phạt',
      'DEBT_COLLECTED' => 'Thu tiền phạt còn nợ',
      'PAYOUT_RESERVE' => 'Giữ chỗ để rút',
      'PAYOUT_RETURN' => 'Hoàn lại do từ chối rút',
      'PAYOUT_SETTLE' => 'Đã chuyển khoản',
      _ => k,
    };

/// Dòng này làm số dư RÚT ĐƯỢC tăng (1), giảm (-1) hay không đổi (0)?
///
/// Số tiền backend trả **luôn dương** — hướng tiền nằm ở loại dòng. Bản đầu
/// đoán theo dấu số tiền nên mọi dòng, kể cả tiền phạt và tiền rút, đều hiện
/// "+" xanh. HOLD/REFUND chỉ đụng phần đang giữ; PAYOUT_SETTLE và PENALTY_DEBT
/// chỉ ghi nhận — tiền đã trừ từ bước trước. Gộp chúng vào "giảm" là sổ nói
/// sai.
int huongTien(String k) => switch (k.toUpperCase()) {
      'RELEASE' || 'PAYOUT_RETURN' => 1,
      'PENALTY' || 'DEBT_COLLECTED' || 'PAYOUT_RESERVE' => -1,
      _ => 0,
    };

String nhanTrangThaiRut(String s) => switch (s.toUpperCase()) {
      'PENDING' || 'REQUESTED' => 'Đang chờ duyệt',
      'APPROVED' => 'Đã duyệt, chờ chi',
      'PAID' => 'Đã chi',
      'REJECTED' => 'Bị từ chối',
      _ => s,
    };
