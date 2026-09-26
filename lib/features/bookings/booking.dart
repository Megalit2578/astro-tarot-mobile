/// Trạng thái buổi hẹn, khớp enum bên backend.
enum TrangThaiBuoi { pending, confirmed, completed, cancelled, khac }

/// Mã trạng thái gửi LÊN máy chủ. null = không lọc.
///
/// Không dùng `name.toUpperCase()`: `khac` sẽ thành "KHAC", một giá trị backend
/// không biết, và nó trả 400 cho một thao tác đáng lẽ là "xem tất cả".
String? tenTrangThai(TrangThaiBuoi? t) => switch (t) {
  TrangThaiBuoi.pending => 'PENDING',
  TrangThaiBuoi.confirmed => 'CONFIRMED',
  TrangThaiBuoi.completed => 'COMPLETED',
  TrangThaiBuoi.cancelled => 'CANCELLED',
  TrangThaiBuoi.khac || null => null,
};

TrangThaiBuoi trangThaiTu(String? s) => switch (s) {
  'PENDING' => TrangThaiBuoi.pending,
  'CONFIRMED' => TrangThaiBuoi.confirmed,
  'COMPLETED' => TrangThaiBuoi.completed,
  'CANCELLED' => TrangThaiBuoi.cancelled,
  _ => TrangThaiBuoi.khac,
};

enum TrangThaiTra { unpaid, depositPaid, paid, refunded, failed, khac }

TrangThaiTra trangThaiTraTu(String? s) => switch (s) {
  'UNPAID' => TrangThaiTra.unpaid,
  'DEPOSIT_PAID' => TrangThaiTra.depositPaid,
  'PAID' => TrangThaiTra.paid,
  'REFUNDED' => TrangThaiTra.refunded,
  'FAILED' => TrangThaiTra.failed,
  _ => TrangThaiTra.khac,
};

class Booking {
  const Booking({
    required this.id,
    required this.readerProfileId,
    required this.readerUserId,
    required this.readerName,
    required this.customerId,
    required this.customerName,
    required this.batDau,
    required this.ketThuc,
    required this.phut,
    required this.tongTien,
    required this.trangThai,
    required this.trangThaiTra,
    required this.daDanhGia,
    required this.chatMo,
    this.readerAvatar,
    this.customerAvatar,
    this.lyDoHuy,
    this.ghiChuReader,
    this.tienCoc,
    this.tienConLai,
    this.hanTraNot,
  });

  final String id;
  final String readerProfileId;
  final String readerUserId;
  final String readerName;
  final String? readerAvatar;
  final String customerId;
  final String customerName;
  final String? customerAvatar;
  final DateTime batDau;
  final DateTime ketThuc;
  final int phut;
  final int tongTien;
  final TrangThaiBuoi trangThai;
  final TrangThaiTra trangThaiTra;
  final bool daDanhGia;
  final String? lyDoHuy;
  final String? ghiChuReader;

  /// Cọc 50% và phần còn lại. Hạn trả nốt là 12 tiếng trước giờ hẹn.
  final int? tienCoc;
  final int? tienConLai;
  final DateTime? hanTraNot;

  /// Hộp trao đổi có đang mở không.
  ///
  /// **Máy chủ tính, giao diện chỉ đọc.** Đừng tự suy từ trạng thái + thanh
  /// toán ở đây: luật gồm cả hạn ân hạn bảy ngày sau khi buổi kết thúc, và
  /// đoán lại ở client thì hai nơi sớm muộn lệch nhau — nút hiện ra nhưng gửi
  /// tin lại bị từ chối.
  final bool chatMo;

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
    id: j['id'] as String,
    readerProfileId: (j['readerProfileId'] ?? '') as String,
    readerUserId: (j['readerUserId'] ?? '') as String,
    readerName: (j['readerName'] ?? '') as String,
    readerAvatar: j['readerAvatar'] as String?,
    customerId: (j['customerId'] ?? '') as String,
    customerName: (j['customerName'] ?? '') as String,
    customerAvatar: j['customerAvatar'] as String?,
    batDau: DateTime.parse(j['startTime'] as String),
    ketThuc: DateTime.parse(j['endTime'] as String),
    phut: (j['durationMinutes'] as num?)?.toInt() ?? 0,
    tongTien: (j['totalAmount'] as num?)?.toInt() ?? 0,
    trangThai: trangThaiTu(j['status'] as String?),
    trangThaiTra: trangThaiTraTu(j['paymentStatus'] as String?),
    daDanhGia: j['reviewed'] as bool? ?? false,
    // Bản backend cũ chưa có trường này. Mặc định false: giấu nhầm nút
    // còn hơn bày ra rồi bấm vào nhận lỗi.
    chatMo: j['chatOpen'] as bool? ?? false,
    lyDoHuy: j['cancelReason'] as String?,
    ghiChuReader: j['readerNote'] as String?,
    tienCoc: (j['depositAmount'] as num?)?.toInt(),
    tienConLai: (j['remainingAmount'] as num?)?.toInt(),
    hanTraNot: j['paymentDeadline'] == null
        ? null
        : DateTime.tryParse(j['paymentDeadline'] as String),
  );

  bool get chuaTra => trangThaiTra == TrangThaiTra.unpaid;
  bool get daCoc => trangThaiTra == TrangThaiTra.depositPaid;

  /// Còn phải trả: chưa trả gì, hoặc đã cọc nhưng chưa trả nốt.
  bool get conPhaiTra => chuaTra || daCoc;
  bool get dangCho => trangThai == TrangThaiBuoi.pending;
}

/// Nhãn tiếng Việt cho trạng thái, dùng chung cả phía khách lẫn phía Reader.
String nhanTrangThai(TrangThaiBuoi t) => switch (t) {
  TrangThaiBuoi.pending => 'Chờ Reader nhận',
  TrangThaiBuoi.confirmed => 'Đã nhận lịch',
  TrangThaiBuoi.completed => 'Đã hoàn tất',
  TrangThaiBuoi.cancelled => 'Đã huỷ',
  TrangThaiBuoi.khac => '—',
};
