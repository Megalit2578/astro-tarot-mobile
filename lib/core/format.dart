import 'package:intl/intl.dart';

/// Định dạng dùng chung, khớp với cách web đang hiển thị.
class Dinh {
  const Dinh._();

  static final _vnd = NumberFormat.decimalPattern('vi_VN');

  /// `120000` → `120.000 đ`
  ///
  /// Không dùng NumberFormat.currency: nó đặt ký hiệu ₫ và khoảng trắng theo
  /// quy ước riêng, ra chuỗi lệch hẳn với web. Ghép tay thì hai nơi giống nhau.
  static String tien(num? v) => v == null ? '—' : '${_vnd.format(v)} đ';

  /// `2026-09-22T07:15:00Z` → `22/09, 14:15` theo giờ máy.
  ///
  /// dd/mm chứ không phải mm/dd — đã thống nhất cho toàn dự án.
  static String ngayGio(DateTime? t) {
    if (t == null) return '';
    final l = t.toLocal();
    return DateFormat('dd/MM, HH:mm').format(l);
  }

  /// `22/09/2026`
  static String ngay(DateTime? t) =>
      t == null ? '' : DateFormat('dd/MM/yyyy').format(t.toLocal());

  /// `14:15`
  static String gio(DateTime? t) =>
      t == null ? '' : DateFormat('HH:mm').format(t.toLocal());

  /// Điểm đánh giá — chưa ai đánh giá thì đừng hiện "0.0".
  ///
  /// "0.0 sao" trông như bị chê tệ, trong khi sự thật là chưa có ai đánh giá.
  /// Reader mới vào sàn bị con số ấy dìm oan.
  static String diem(double diemSo, int soDanhGia) =>
      soDanhGia == 0 ? 'Chưa có' : diemSo.toStringAsFixed(1);
}
