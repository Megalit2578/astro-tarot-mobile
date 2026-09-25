import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/api/trang.dart';
import '../../core/auth/auth_controller.dart';
import '../shop/shop_repository.dart';

// ============================================================
// Vai trò và trạng thái tài khoản
// ============================================================

/// Bốn vai trò lưu trong CSDL. "Khách" không phải một vai trò gán được.
const vaiTroTaiKhoan = ['USER', 'STAFF', 'MANAGER', 'ADMIN'];

const tenVaiTro = {
  'USER': 'Thành viên',
  'STAFF': 'Nhân viên',
  'MANAGER': 'Quản lý',
  'ADMIN': 'Quản trị viên',
};

const moTaVaiTro = {
  'USER': 'Đặt lịch, xem bài, nộp hồ sơ Reader.',
  'STAFF': 'Hỗ trợ khách và nhận lịch với tư cách Reader.',
  'MANAGER': 'Nhân sự, duyệt hồ sơ Reader, báo cáo vi phạm, gian hàng.',
  'ADMIN': 'Toàn quyền tài khoản, tiền và sản phẩm.',
};

const trangThaiTaiKhoan = ['PENDING', 'ACTIVE', 'INACTIVE', 'BANNED'];

const tenTrangThaiTaiKhoan = {
  'PENDING': 'Chờ xác minh',
  'ACTIVE': 'Đang hoạt động',
  'INACTIVE': 'Ngưng hoạt động',
  'BANNED': 'Đã khoá',
};

/// Một dòng trong danh sách tài khoản.
class TaiKhoan {
  const TaiKhoan({
    required this.id,
    required this.tenDangNhap,
    required this.hoTen,
    required this.vaiTro,
    required this.trangThai,
    required this.daXacMinh,
    required this.suaDuoc,
    this.email,
    this.anh,
    this.dangNhapCuoi,
    this.taoLuc,
  });

  final String id;
  final String tenDangNhap;
  final String hoTen;
  final String? email;
  final String? anh;
  final String vaiTro;
  final String trangThai;
  final bool daXacMinh;
  final DateTime? dangNhapCuoi;
  final DateTime? taoLuc;

  /// Người đang đăng nhập có được sửa hàng này không. **Máy chủ tính**, app
  /// không đoán lại: đoán lại là sớm muộn lệch với luật thật ở backend (quản
  /// lý chỉ được đụng USER/STAFF, không ai tự đổi vai trò của mình…).
  final bool suaDuoc;

  bool get biKhoa => trangThai == 'BANNED';

  String get tenHienThi => hoTen.isNotEmpty ? hoTen : tenDangNhap;

  factory TaiKhoan.fromJson(Map<String, dynamic> j) => TaiKhoan(
        id: (j['id'] ?? '').toString(),
        tenDangNhap: (j['username'] ?? '') as String,
        hoTen: (j['fullName'] ?? '') as String,
        email: chuoi(j['email']),
        anh: chuoi(j['avatar']),
        vaiTro: (j['role'] ?? 'USER') as String,
        trangThai: (j['status'] ?? 'ACTIVE') as String,
        daXacMinh: j['emailVerified'] == true,
        dangNhapCuoi: thoiDiem(j['lastLoginAt']),
        taoLuc: thoiDiem(j['createdAt']),
        suaDuoc: j['editable'] == true,
      );
}

/// Chi tiết một tài khoản — thêm liên hệ, quyền và vài số đếm.
class ChiTietTaiKhoan {
  const ChiTietTaiKhoan({
    required this.co,
    required this.quyen,
    required this.phienMo,
    required this.soDon,
    required this.daChi,
    required this.coHoSoReader,
    required this.coDonReaderCho,
    this.dienThoai,
    this.thanhPho,
    this.diaChi,
    this.dangNhapBang,
  });

  final TaiKhoan co;
  final String? dienThoai;
  final String? thanhPho;
  final String? diaChi;
  final String? dangNhapBang;

  /// Quyền suy ra từ vai trò hiện tại — để người sắp đổi vai trò thấy mình
  /// đang trao cái gì.
  final List<String> quyen;
  final int phienMo;
  final int soDon;
  final int daChi;
  final bool coHoSoReader;
  final bool coDonReaderCho;

  factory ChiTietTaiKhoan.fromJson(Map<String, dynamic> j) => ChiTietTaiKhoan(
        co: TaiKhoan.fromJson(j),
        dienThoai: chuoi(j['phone']),
        thanhPho: chuoi(j['city']),
        diaChi: chuoi(j['address']),
        dangNhapBang: chuoi(j['authProvider']),
        quyen: (j['permissions'] is List)
            ? (j['permissions'] as List).whereType<String>().toList()
            : const [],
        phienMo: soNguyen(j['activeSessions']) ?? 0,
        soDon: soNguyen(j['orderCount']) ?? 0,
        daChi: soNguyen(j['totalSpent']) ?? 0,
        coHoSoReader: j['hasReaderProfile'] == true,
        coDonReaderCho: j['hasPendingReaderApplication'] == true,
      );
}

// ============================================================
// Nhật ký hệ thống
// ============================================================

/// Nhãn tiếng Việt cho từng hành động, khớp AdminActions bên backend.
const tenHanhDong = {
  'USER_CREATE': 'Tạo tài khoản',
  'USER_UPDATE': 'Sửa thông tin',
  'USER_ROLE_CHANGE': 'Đổi vai trò',
  'USER_STATUS_CHANGE': 'Đổi trạng thái',
  'USER_DELETE': 'Xoá tài khoản',
  'USER_SESSIONS_REVOKE': 'Buộc đăng xuất',
  'USER_PASSWORD_RESET_SENT': 'Gửi link đặt lại mật khẩu',
  'USER_VERIFICATION_RESENT': 'Gửi lại mail xác minh',
  'PAYMENT_CONFIRM': 'Xác nhận thanh toán',
  'PAYMENT_REJECT': 'Từ chối thanh toán',
  'PAYOUT_APPROVE': 'Duyệt lệnh rút',
  'PAYOUT_REJECT': 'Từ chối lệnh rút',
  'PAYOUT_PAID': 'Đánh dấu đã chi',
  'REPORT_HANDLE': 'Xử lý báo cáo',
  'PRODUCT_CREATE': 'Thêm sản phẩm',
  'PRODUCT_UPDATE': 'Sửa sản phẩm',
  'PRODUCT_SET_ACTIVE': 'Bật/tắt sản phẩm',
};

class NhatKy {
  const NhatKy({
    required this.id,
    required this.nguoiLam,
    required this.hanhDong,
    this.vaiTroNguoiLam,
    this.loaiDoiTuong,
    this.maDoiTuong,
    this.thayDoi,
    this.luc,
  });

  final String id;
  final String nguoiLam;
  final String? vaiTroNguoiLam;
  final String hanhDong;
  final String? loaiDoiTuong;
  final String? maDoiTuong;

  /// JSON thô mô tả thay đổi.
  final String? thayDoi;
  final DateTime? luc;

  String get tenHanhDongVi => tenHanhDong[hanhDong] ?? hanhDong;

  /// Diễn giải [thayDoi] thành một dòng đọc được.
  ///
  /// Hai dạng hay gặp: `{from, to}` và `{truong: {from, to}, …}`. Không phải
  /// JSON thì trả nguyên văn — thà hiện chuỗi thô còn hơn giấu mất.
  String get moTaThayDoi {
    final raw = thayDoi;
    if (raw == null || raw.isEmpty) return '—';
    Object? v;
    try {
      v = jsonDecode(raw);
    } catch (_) {
      return raw;
    }
    String tuDen(Object? x) {
      if (x is Map && x.containsKey('from') && x.containsKey('to')) {
        return '${x['from']} → ${x['to']}';
      }
      return '$x';
    }

    if (v is Map) {
      if (v.length == 2 && v.containsKey('from') && v.containsKey('to')) {
        return tuDen(v);
      }
      return v.entries.map((e) => '${e.key}: ${tuDen(e.value)}').join(' · ');
    }
    return '$v';
  }

  factory NhatKy.fromJson(Map<String, dynamic> j) => NhatKy(
        id: (j['id'] ?? '').toString(),
        nguoiLam: (j['actorName'] ?? 'Hệ thống') as String,
        vaiTroNguoiLam: chuoi(j['actorRole']),
        hanhDong: (j['action'] ?? '') as String,
        loaiDoiTuong: chuoi(j['entityType']),
        maDoiTuong: chuoi(j['entityId']),
        thayDoi: chuoi(j['changes']),
        luc: thoiDiem(j['createdAt']),
      );
}

// ============================================================
// Báo cáo vi phạm
// ============================================================

const tenTrangThaiBaoCao = {
  'PENDING': 'Chờ xử lý',
  'REVIEWED': 'Đang xem xét',
  'RESOLVED': 'Đã xử lý',
  'REJECTED': 'Không vi phạm',
};

/// Loại vi phạm khách chọn được — giữ ngắn, danh sách dài thì không ai đọc.
const loaiViPham = [
  ('NO_SHOW', 'Không có mặt đúng giờ hẹn'),
  ('RUDE', 'Thái độ không đúng mực'),
  ('MISLEADING', 'Nội dung sai lệch, gây hoang mang'),
  ('SCAM', 'Đòi tiền ngoài hệ thống'),
  ('OTHER', 'Lý do khác'),
];

String tenLoaiViPham(String ma) =>
    loaiViPham.firstWhere((e) => e.$1 == ma, orElse: () => (ma, ma)).$2;

class BaoCao {
  const BaoCao({
    required this.id,
    required this.nguoiBao,
    required this.nguoiBiBao,
    required this.loai,
    required this.trangThai,
    this.vaiTroBiBao,
    this.bookingId,
    this.moTa,
    this.tienPhat = 0,
    this.nguoiXuLy,
    this.xuLyLuc,
    this.ketLuan,
    this.luc,
  });

  final String id;

  /// Chỉ người xử lý thấy. Không bao giờ hiện cho người bị báo cáo.
  final String nguoiBao;
  final String nguoiBiBao;
  final String? vaiTroBiBao;
  final String? bookingId;
  final String loai;
  final String? moTa;
  final String trangThai;
  final int tienPhat;
  final String? nguoiXuLy;
  final DateTime? xuLyLuc;
  final String? ketLuan;
  final DateTime? luc;

  bool get conMo => trangThai == 'PENDING' || trangThai == 'REVIEWED';

  factory BaoCao.fromJson(Map<String, dynamic> j) => BaoCao(
        id: (j['id'] ?? '').toString(),
        nguoiBao: (j['reporterName'] ?? '') as String,
        nguoiBiBao: (j['reportedName'] ?? '') as String,
        vaiTroBiBao: chuoi(j['reportedRole']),
        bookingId: chuoi(j['bookingId']),
        loai: (j['reportType'] ?? 'OTHER') as String,
        moTa: chuoi(j['description']),
        trangThai: (j['status'] ?? 'PENDING') as String,
        tienPhat: soNguyen(j['penaltyAmount']) ?? 0,
        nguoiXuLy: chuoi(j['handledByName']),
        xuLyLuc: thoiDiem(j['handledAt']),
        ketLuan: chuoi(j['resolutionNote']),
        luc: thoiDiem(j['createdAt']),
      );
}

// ============================================================
// Thanh toán và rút tiền
// ============================================================

const tenTrangThaiGiaoDich = {
  'PENDING': 'Chờ đối soát',
  'SUCCESS': 'Đã nhận tiền',
  'FAILED': 'Không đối soát được',
  'CANCELLED': 'Đã huỷ / hoàn',
};

class GiaoDich {
  const GiaoDich({
    required this.id,
    required this.nguoiTra,
    required this.soTien,
    required this.trangThai,
    this.emailNguoiTra,
    this.reader,
    this.phuongThuc,
    this.maThamChieu,
    this.bookingId,
    this.buoiLuc,
    this.luc,
  });

  final String id;
  final String nguoiTra;
  final String? emailNguoiTra;
  final String? reader;
  final int soTien;
  final String? phuongThuc;

  /// Chuỗi khách gõ vào nội dung chuyển khoản — thứ để dò trong sao kê.
  final String? maThamChieu;
  final String trangThai;
  final String? bookingId;
  final DateTime? buoiLuc;
  final DateTime? luc;

  factory GiaoDich.fromJson(Map<String, dynamic> j) => GiaoDich(
        id: (j['id'] ?? '').toString(),
        nguoiTra: (j['payerName'] ?? '') as String,
        emailNguoiTra: chuoi(j['payerEmail']),
        reader: chuoi(j['readerName']),
        soTien: soNguyen(j['amount']) ?? 0,
        phuongThuc: chuoi(j['paymentMethod']),
        maThamChieu: chuoi(j['referenceCode']),
        trangThai: (j['status'] ?? 'PENDING') as String,
        bookingId: chuoi(j['bookingId']),
        buoiLuc: thoiDiem(j['bookingStartTime']),
        luc: thoiDiem(j['createdAt']),
      );
}

const tenTrangThaiLenhRut = {
  'PENDING': 'Chờ duyệt',
  'APPROVED': 'Đã duyệt, chờ chuyển',
  'REJECTED': 'Bị từ chối',
  'PAID': 'Đã chuyển tiền',
};

class LenhRut {
  const LenhRut({
    required this.id,
    required this.reader,
    required this.soTien,
    required this.trangThai,
    this.emailReader,
    this.nganHang,
    this.soTaiKhoanChe,
    this.chuTaiKhoan,
    this.lyDoTuChoi,
    this.yeuCauLuc,
    this.xuLyLuc,
  });

  final String id;
  final String reader;
  final String? emailReader;
  final int soTien;
  final String? nganHang;

  /// Chỉ bốn số cuối — màn quản trị hay mở trên máy dùng chung.
  final String? soTaiKhoanChe;
  final String? chuTaiKhoan;
  final String trangThai;
  final String? lyDoTuChoi;
  final DateTime? yeuCauLuc;
  final DateTime? xuLyLuc;

  factory LenhRut.fromJson(Map<String, dynamic> j) => LenhRut(
        id: (j['id'] ?? '').toString(),
        reader: (j['readerName'] ?? '') as String,
        emailReader: chuoi(j['readerEmail']),
        soTien: soNguyen(j['amount']) ?? 0,
        nganHang: chuoi(j['bankName']),
        soTaiKhoanChe: chuoi(j['bankAccountMasked']),
        chuTaiKhoan: chuoi(j['accountHolder']),
        trangThai: (j['status'] ?? 'PENDING') as String,
        lyDoTuChoi: chuoi(j['rejectReason']),
        yeuCauLuc: thoiDiem(j['requestedAt']),
        xuLyLuc: thoiDiem(j['processedAt']),
      );
}

// ============================================================
// Đơn xin làm Reader
// ============================================================

/// Một đơn xin làm Reader đang chờ duyệt.
///
/// Backend trả `List<Map>` nên hình dạng không được ràng buộc ở đó — đọc lỏng
/// và luôn có đường lùi khi thiếu trường.
class DonReader {
  const DonReader({
    required this.id,
    required this.hoTen,
    required this.chuyenMon,
    this.email,
    this.gioiThieu,
    this.soNam,
    this.trangThai,
    this.luc,
  });

  final String id;
  final String hoTen;
  final String? email;
  final String? gioiThieu;
  final int? soNam;
  final List<String> chuyenMon;
  final String? trangThai;
  final DateTime? luc;

  factory DonReader.fromJson(Map<String, dynamic> j) {
    final cm = j['specialties'];
    return DonReader(
      id: (j['id'] ?? j['applicationId'] ?? '').toString(),
      hoTen: (chuoi(j['fullName']) ?? chuoi(j['username']) ?? 'Không rõ tên'),
      email: chuoi(j['email']),
      gioiThieu: chuoi(j['bio']),
      soNam: soNguyen(j['experience']),
      chuyenMon: cm is List ? cm.map((e) => '$e').toList() : const [],
      trangThai: chuoi(j['status']),
      luc: thoiDiem(j['createdAt']),
    );
  }
}

// ============================================================
// Thống kê tổng quan
// ============================================================

/// Số liệu `/api/v1/admin/stats`. Toàn phép đếm ở tầng CSDL.
///
/// Các khối `ai`, `revenue`, `traction` có thể thiếu nếu backend cũ — đọc
/// lỏng, thiếu thì coi như 0, đừng để cả trang vỡ vì lệch phiên bản.
class ThongKe {
  const ThongKe(this.tho);
  final Map<String, dynamic> tho;

  Map<String, dynamic> _khoi(String k) =>
      tho[k] is Map<String, dynamic> ? tho[k] as Map<String, dynamic> : const {};

  int so(String khoi, String truong) => soNguyen(_khoi(khoi)[truong]) ?? 0;
  double thuc(String khoi, String truong) =>
      soThuc(_khoi(khoi)[truong]) ?? 0;

  Map<String, int> bang(String khoi, String truong) {
    final m = _khoi(khoi)[truong];
    if (m is! Map) return const {};
    return {
      for (final e in m.entries) '${e.key}': soNguyen(e.value) ?? 0,
    };
  }

  bool coKhoi(String k) => tho[k] is Map;
}

/// Thống kê liên kết tiếp thị cho màn Sản phẩm.
class ThongKeTiepThi {
  const ThongKeTiepThi({
    required this.tongBam,
    required this.bamTrongKy,
    required this.soNgay,
    required this.coLink,
    required this.chuaCoLink,
    required this.uocTinhHoaHong,
    required this.dauBang,
  });

  final int tongBam;
  final int bamTrongKy;
  final int soNgay;
  final int coLink;
  final int chuaCoLink;

  /// ƯỚC LƯỢNG (giá × tỉ lệ × lượt bấm), KHÔNG phải doanh thu thật.
  final int uocTinhHoaHong;
  final List<SanPham> dauBang;

  factory ThongKeTiepThi.fromJson(Map<String, dynamic> j) => ThongKeTiepThi(
        tongBam: soNguyen(j['totalClicks']) ?? 0,
        bamTrongKy: soNguyen(j['clicksInPeriod']) ?? 0,
        soNgay: soNguyen(j['periodDays']) ?? 30,
        coLink: soNguyen(j['productsWithLink']) ?? 0,
        chuaCoLink: soNguyen(j['productsWithoutLink']) ?? 0,
        uocTinhHoaHong: soNguyen(j['estimatedCommission']) ?? 0,
        dauBang: j['topProducts'] is List
            ? (j['topProducts'] as List)
                .whereType<Map<String, dynamic>>()
                .map(SanPham.fromJson)
                .toList()
            : const [],
      );
}

/// Các sàn liên kết backend chấp nhận.
const sanLienKet = ['SHOPEE', 'LAZADA', 'TIKI', 'TIKTOK', 'OTHER'];

// ============================================================
// Kho gọi API
// ============================================================

class AdminRepository {
  AdminRepository(this._api);
  final ApiClient _api;

  static const coTrang = 20;

  Map<String, dynamic> _loc(Map<String, String?> m) => {
        for (final e in m.entries)
          if (e.value != null && e.value!.isNotEmpty) e.key: e.value,
      };

  // ---- Thống kê ----

  Future<ThongKe> thongKe() async =>
      ThongKe(await _api.get<Map<String, dynamic>>(Endpoints.adminStats));

  // ---- Tài khoản ----

  Future<Trang<TaiKhoan>> taiKhoan({
    String? vaiTro,
    String? trangThai,
    String? tuKhoa,
    int trang = 0,
    int co = coTrang,
  }) async {
    final d = await _api.get<dynamic>(Endpoints.adminUsers, query: {
      ..._loc({'role': vaiTro, 'status': trangThai, 'keyword': tuKhoa}),
      'page': trang,
      'size': co,
    });
    return Trang.tu(d, TaiKhoan.fromJson);
  }

  Future<ChiTietTaiKhoan> chiTiet(String id) async => ChiTietTaiKhoan.fromJson(
      await _api.get<Map<String, dynamic>>(Endpoints.adminUser(id)));

  Future<void> taoTaiKhoan({
    required String email,
    required String hoTen,
    required String vaiTro,
    String? dienThoai,
    bool daXacMinh = false,
  }) =>
      _api.post(Endpoints.adminUsers, body: {
        'email': email.trim(),
        'fullName': hoTen.trim(),
        'role': vaiTro,
        if (dienThoai != null && dienThoai.trim().isNotEmpty)
          'phone': dienThoai.trim(),
        'markEmailVerified': daXacMinh,
      });

  Future<void> suaThongTin(String id, Map<String, String> thayDoi) =>
      _api.patch(Endpoints.adminUser(id), body: thayDoi);

  Future<void> doiVaiTro(String id, String vaiTro) =>
      _api.patch(Endpoints.adminUserRole(id), body: {'role': vaiTro});

  Future<void> doiVaiTroHangLoat(List<String> ids, String vaiTro) =>
      _api.patch(Endpoints.adminUsersRoleBulk,
          body: {'userIds': ids, 'role': vaiTro});

  Future<void> doiTrangThai(String id, String trangThai) =>
      _api.patch(Endpoints.adminUserStatus(id), body: {'status': trangThai});

  Future<void> thuHoiPhien(String id) =>
      _api.post(Endpoints.adminUserRevokeSessions(id));

  Future<void> guiDatLaiMatKhau(String id) =>
      _api.post(Endpoints.adminUserPasswordReset(id));

  Future<void> guiLaiXacMinh(String id) =>
      _api.post(Endpoints.adminUserResendVerification(id));

  Future<void> xoaTaiKhoan(String id) =>
      _api.delete(Endpoints.adminUser(id));

  // ---- Nhật ký ----

  Future<Trang<NhatKy>> nhatKy({String? hanhDong, int trang = 0}) async {
    final d = await _api.get<dynamic>(Endpoints.adminActivityLogs, query: {
      ..._loc({'action': hanhDong}),
      'page': trang,
      'size': coTrang,
    });
    return Trang.tu(d, NhatKy.fromJson);
  }

  // ---- Đơn Reader ----

  Future<List<DonReader>> donReader() async {
    final d = await _api.get<dynamic>(Endpoints.adminReaderApplications);
    return Trang.tu(d, DonReader.fromJson).muc;
  }

  /// Duyệt hoặc từ chối một đơn.
  ///
  /// Trường lý do tên là `rejectionReason` — bản đầu gửi `reason`, backend
  /// bỏ qua trường lạ, nên người bị từ chối không bao giờ đọc được lý do.
  Future<void> xetDonReader(String id, {required bool duyet, String? lyDo}) =>
      _api.patch(Endpoints.adminReaderReview(id), body: {
        'action': duyet ? 'APPROVED' : 'REJECTED',
        'rejectionReason': duyet ? null : lyDo,
      });

  // ---- Thanh toán ----

  Future<Trang<GiaoDich>> giaoDich({String? trangThai, int trang = 0}) async {
    final d = await _api.get<dynamic>(Endpoints.adminPayments, query: {
      ..._loc({'status': trangThai}),
      'page': trang,
      'size': coTrang,
    });
    return Trang.tu(d, GiaoDich.fromJson);
  }

  Future<void> xacNhanGiaoDich(String id) =>
      _api.patch(Endpoints.adminPaymentConfirm(id));

  Future<void> tuChoiGiaoDich(String id, String? lyDo) =>
      _api.patch(Endpoints.adminPaymentReject(id), body: {'reason': lyDo});

  // ---- Rút tiền ----

  Future<Trang<LenhRut>> lenhRut({String? trangThai, int trang = 0}) async {
    final d = await _api.get<dynamic>(Endpoints.adminPayouts, query: {
      ..._loc({'status': trangThai}),
      'page': trang,
      'size': coTrang,
    });
    return Trang.tu(d, LenhRut.fromJson);
  }

  Future<void> duyetLenhRut(String id) =>
      _api.patch(Endpoints.adminPayoutApprove(id));

  Future<void> tuChoiLenhRut(String id, String? lyDo) =>
      _api.patch(Endpoints.adminPayoutReject(id), body: {'reason': lyDo});

  Future<void> daChiLenhRut(String id) =>
      _api.patch(Endpoints.adminPayoutPaid(id));

  // ---- Báo cáo vi phạm ----

  Future<Trang<BaoCao>> baoCao({String? trangThai, int trang = 0}) async {
    final d = await _api.get<dynamic>(Endpoints.adminReports, query: {
      ..._loc({'status': trangThai}),
      'page': trang,
      'size': coTrang,
    });
    return Trang.tu(d, BaoCao.fromJson);
  }

  /// Kết luận một báo cáo. Tiền phạt chỉ có tác dụng khi kết luận RESOLVED;
  /// 0 là nhắc nhở suông — vẫn là một kết luận hợp lệ.
  Future<void> xuLyBaoCao(
    String id, {
    required String ketLuan,
    String? ghiChu,
    int tienPhat = 0,
  }) =>
      _api.patch(Endpoints.adminReportHandle(id), body: {
        'status': ketLuan,
        'resolutionNote': ghiChu,
        'penaltyAmount': ketLuan == 'RESOLVED' ? tienPhat : 0,
      });

  // ---- Sản phẩm liên kết ----

  Future<Trang<SanPham>> sanPham({String? tuKhoa, int trang = 0}) async {
    final d = await _api.get<dynamic>(Endpoints.adminProducts, query: {
      ..._loc({'keyword': tuKhoa}),
      'page': trang,
      'size': coTrang,
    });
    return Trang.tu(d, SanPham.fromJson);
  }

  Future<void> luuSanPham(String? id, Map<String, dynamic> body) => id == null
      ? _api.post(Endpoints.adminProducts, body: body)
      : _api.put(Endpoints.adminProduct(id), body: body);

  Future<void> batTatSanPham(String id, bool hien) =>
      _api.patch('${Endpoints.adminProductActive(id)}?value=$hien');

  Future<ThongKeTiepThi> thongKeTiepThi({int soNgay = 30}) async =>
      ThongKeTiepThi.fromJson(await _api.get<Map<String, dynamic>>(
          Endpoints.adminAffiliateStats,
          query: {'days': soNgay}));
}

final adminRepositoryProvider =
    Provider((ref) => AdminRepository(ref.watch(apiClientProvider)));

final thongKeProvider =
    FutureProvider<ThongKe>((ref) => ref.watch(adminRepositoryProvider).thongKe());

final donReaderProvider = FutureProvider<List<DonReader>>(
    (ref) => ref.watch(adminRepositoryProvider).donReader());

final chiTietTaiKhoanProvider = FutureProvider.family<ChiTietTaiKhoan, String>(
    (ref, id) => ref.watch(adminRepositoryProvider).chiTiet(id));

final thongKeTiepThiProvider = FutureProvider<ThongKeTiepThi>(
    (ref) => ref.watch(adminRepositoryProvider).thongKeTiepThi());
