/// Phần dữ liệu mà một sự kiện làm cũ đi.
enum PhanDuLieu {
  /// Danh sách lịch hẹn của khách và của Reader.
  lichHen,

  /// Số dư ví, giao dịch ký quỹ, yêu cầu rút.
  tien,

  /// Phiếu hỗ trợ.
  hoTro,
}

/// Một gói từ `/user/queue/events` nói rằng phần dữ liệu nào đã cũ.
///
/// ## Vì sao cần
///
/// Trước đây khung chính có nghe kênh này, nhưng **vứt bỏ nội dung gói tin**:
///
/// ```dart
/// realtime.nghe(Endpoints.queueEvents, (_) {   // <- gói tin bị bỏ
///   ref.invalidate(soChuaDocProvider);
///   ref.read(thucThongBaoProvider.notifier).thuc();
/// });
/// ```
///
/// Nên chỉ mỗi chấm đỏ trên chuông là đúng. Tiền về ví mà số dư vẫn là số cũ;
/// Reader xác nhận lịch mà danh sách lịch hẹn không đổi; nhân viên trả lời
/// phiếu hỗ trợ mà màn phiếu vẫn im. Người dùng phải kéo để tải lại mới thấy
/// — và vì thông báo ĐÃ hiện, họ tưởng app hỏng chứ không nghĩ là phải tải
/// lại.
///
/// Bản web đã định tuyến theo `type` từ lâu (`RealtimeProvider`); phần này
/// đưa app về ngang bằng.
///
/// ## Vì sao trả về enum thay vì tự gọi `invalidate`
///
/// Trong Riverpod 3, `Ref` (của provider) và `WidgetRef` (của widget) không
/// thay thế nhau được, nên một hàm nhận "ref" chỉ dùng được ở đúng một phía.
/// Tách phần QUYẾT ĐỊNH ra thành hàm thuần, không dính gì tới Riverpod, thì
/// nó chạy được ở cả hai — và kiểm được bằng test thường, không cần dựng
/// widget rồi giả lập cả một kết nối WebSocket.
///
/// ## Vì sao so sánh bằng tiền tố
///
/// Máy chủ đặt tên theo họ: `BOOKING_CONFIRMED`, `BOOKING_CANCELLED`,
/// `PAYMENT_SUCCESS`, `PAYOUT_PAID`… Liệt kê từng tên một thì mỗi lần backend
/// thêm một loại là app lặng lẽ bỏ sót, không có gì báo. So theo tiền tố thì
/// loại mới thuộc họ cũ tự được xử lý đúng.
Set<PhanDuLieu> phanDaCu(Map<String, dynamic> goi) {
  final loai = loaiSuKien(goi);
  if (loai.isEmpty) return const {};

  final ds = <PhanDuLieu>{};

  if (loai.startsWith('BOOKING_') || loai == 'REVIEW_RECEIVED') {
    ds.add(PhanDuLieu.lichHen);
  }

  // Tiền đụng tới cả hai phía: ví đổi số dư, mà buổi hẹn cũng đổi trạng thái
  // thanh toán — trả tiền xong mà thẻ lịch hẹn vẫn ghi "chờ thanh toán" thì
  // người dùng trả lần nữa.
  if (loai.startsWith('PAYMENT_') || loai.startsWith('PAYOUT_')) {
    ds.add(PhanDuLieu.tien);
    ds.add(PhanDuLieu.lichHen);
  }

  if (loai.startsWith('SUPPORT_')) {
    ds.add(PhanDuLieu.hoTro);
  }

  return ds;
}

/// Lấy loại sự kiện, chịu được cả hai cách máy chủ gói tin.
///
/// `RealtimeEventPayload` có trường `type` ở ngoài, nhưng một số đường đi chỉ
/// điền `notification.type`. Đọc thiếu một chỗ là cả họ sự kiện im lặng không
/// được xử lý — đúng kiểu hỏng không ai nhìn thấy.
String loaiSuKien(Map<String, dynamic> goi) {
  final ngoai = goi['type'];
  if (ngoai is String && ngoai.isNotEmpty) return ngoai;

  final thongBao = goi['notification'];
  if (thongBao is Map && thongBao['type'] is String) {
    return thongBao['type'] as String;
  }
  return '';
}
