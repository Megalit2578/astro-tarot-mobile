import '../../core/format.dart';

/// Một dòng trong hàng chờ quản trị.
///
/// ## Vì sao đọc lỏng thay vì ba lớp model chặt
///
/// Ba hàng chờ — thanh toán, rút tiền, duyệt Reader — có hình dạng gần giống
/// nhau nhưng tên trường thì mỗi nơi một kiểu, và chúng còn đổi theo thời
/// gian. Viết ba lớp chặt thì mỗi lần backend đổi tên một trường là màn hình
/// trắng, mà thông báo lỗi chỉ nói "type 'Null' is not a subtype of String" —
/// chẳng chỉ ra trường nào.
///
/// Ở đây nhận nhiều tên thay thế cho cùng một ý và luôn có đường lùi. Màn
/// quản trị cần **luôn hiển thị được**, kể cả khi vài trường lạ: người trực
/// vẫn nhìn ra dòng nào cần xử lý. Trường nào thiếu thì để trống, không làm
/// hỏng cả trang.
class MucDuyet {
  const MucDuyet({
    required this.id,
    required this.tieuDe,
    required this.phu,
    required this.trangThai,
    this.soTien,
    this.luc,
    this.tho = const {},
  });

  final String id;
  final String tieuDe;
  final String phu;
  final String trangThai;
  final int? soTien;
  final DateTime? luc;

  /// Bản gốc, để màn chi tiết đọc thêm mà không phải sửa lớp này.
  final Map<String, dynamic> tho;

  bool get dangCho {
    final t = trangThai.toUpperCase();
    return t == 'PENDING' || t == 'REQUESTED' || t == 'WAITING' || t.isEmpty;
  }

  String get dongTien => soTien == null ? '' : Dinh.tien(soTien);

  factory MucDuyet.fromJson(Map<String, dynamic> j) {
    String lay(List<String> ten) {
      for (final k in ten) {
        final v = j[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return '';
    }

    final id = lay(['id', 'paymentId', 'payoutId', 'applicationId']);
    final nguoi = lay([
      'payerName', 'userName', 'fullName', 'requesterName', 'customerName',
    ]);
    final email = lay(['payerEmail', 'email', 'userEmail']);
    final reader = lay(['readerName', 'targetName']);
    final maThamChieu = lay(['referenceCode', 'bankAccount', 'code']);

    final tien = j['amount'] ?? j['totalAmount'] ?? j['value'];
    final thoiDiem = lay(['createdAt', 'requestedAt', 'submittedAt']);

    // Dòng phụ ghép từ những gì có, bỏ qua phần rỗng — không thì ra chuỗi
    // kiểu "· · ·" trông như lỗi hiển thị.
    final phu = [
      if (email.isNotEmpty) email,
      if (reader.isNotEmpty) 'Reader: $reader',
      if (maThamChieu.isNotEmpty) maThamChieu,
    ].join(' · ');

    return MucDuyet(
      id: id,
      tieuDe: nguoi.isNotEmpty ? nguoi : (id.isNotEmpty ? id : 'Không rõ'),
      phu: phu,
      trangThai: lay(['status', 'state']),
      soTien: tien is num ? tien.toInt() : null,
      luc: thoiDiem.isEmpty ? null : DateTime.tryParse(thoiDiem),
      tho: j,
    );
  }
}

/// Một hành động trên dòng: nhãn, đường dẫn, và có phải việc nguy hiểm không.
class HanhDongDuyet {
  const HanhDongDuyet({
    required this.nhan,
    required this.duong,
    this.nguyHiem = false,
    this.hoiLyDo = false,
    this.body,
  });

  final String nhan;
  final String Function(String id) duong;
  final bool nguyHiem;

  /// Có hỏi lý do trước khi gửi không — dùng cho hành động từ chối.
  final bool hoiLyDo;

  /// Thân yêu cầu; nhận lý do người dùng vừa nhập.
  final Map<String, dynamic> Function(String? lyDo)? body;
}
