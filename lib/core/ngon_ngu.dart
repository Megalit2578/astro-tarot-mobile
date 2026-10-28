import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'tu_dien_en.dart';

/// Chuyển đổi tiếng Việt ↔ tiếng Anh.
///
/// KHOÁ TRA LÀ CHÍNH CÂU TIẾNG VIỆT, không phải mã kiểu `booking.title`.
///
/// Lý do: app có gần một nghìn năm trăm chuỗi tiếng Việt viết thẳng trong mã.
/// Dùng mã khoá thì mỗi chuỗi chưa khai báo sẽ hiện ra đúng cái mã ấy — giao
/// diện vỡ ngay từ lần đầu bật, và phải dịch xong sạch mới dám bật. Tra theo
/// câu tiếng Việt thì chuỗi nào chưa dịch tự rơi về tiếng Việt: màn hình vẫn
/// đọc được, chỉ lẫn hai thứ tiếng, nên dịch dần mà không bao giờ gãy.
///
/// Dùng `ValueNotifier` toàn cục chứ không phải provider của Riverpod: hàm
/// dịch cần gọi được từ MỌI widget, kể cả `StatelessWidget` không có `ref`,
/// và từ cả những chỗ không phải widget (thông báo lỗi trong repository).
/// Đổi `Ngu.hien` thì `NguNghe` ở gốc dựng lại cả cây.
class Ngu {
  Ngu._();

  static const _khoa = 'ngon_ngu';
  static const _kho = FlutterSecureStorage();

  /// 'vi' hoặc 'en'. Mặc định tiếng Việt.
  static final hien = ValueNotifier<String>('vi');

  /// Đọc lựa chọn đã lưu. Gọi một lần lúc khởi động.
  static Future<void> nap() async {
    try {
      final d = await _kho.read(key: _khoa);
      if (d == 'en') hien.value = 'en';
    } catch (_) {
      // Kho khoá hỏng hoặc chưa cấp quyền: cứ chạy tiếng Việt.
    }
  }

  static Future<void> doi(String ma) async {
    hien.value = ma == 'en' ? 'en' : 'vi';
    try {
      await _kho.write(key: _khoa, value: hien.value);
    } catch (_) {
      // Không lưu được thì vẫn đổi cho phiên này.
    }
  }

  /// Dịch một câu. Chưa có bản dịch thì trả lại nguyên câu tiếng Việt.
  static String d(String cau) =>
      hien.value == 'en' ? (tuDienEn[cau] ?? cau) : cau;
}

/// Bọc quanh app để đổi ngôn ngữ là dựng lại toàn bộ.
class NguNghe extends StatelessWidget {
  const NguNghe({super.key, required this.con});

  final Widget Function(BuildContext) con;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: Ngu.hien,
    builder: (c, _, _) => con(c),
  );
}

/// "đánh giá" / "review" / "reviews" — chọn số ít hay số nhiều.
///
/// Tiếng Việt không chia số nhiều nên một khoá từ điển là đủ cho nó, nhưng
/// tiếng Anh thì "(1 reviews)" đọc lên là sai. Hàm này sống ở đây chứ không
/// nằm trong từ điển vì từ điển chỉ tra chuỗi sang chuỗi, không biết đếm.
String danhGiaSoNhieu(int so) {
  if (Ngu.hien.value != 'en') return 'đánh giá';
  return so == 1 ? 'review' : 'reviews';
}

/// Tên tháng để hiện trên đầu một khối lịch.
///
/// ## Vì sao không nhét vào từ điển
///
/// Từ điển tra chuỗi sang chuỗi. Nhét vào thì phải có đủ mười hai khoá
/// "Tháng 1 năm 2026", "Tháng 1 năm 2027"... — tức là vô hạn khoá, vì năm
/// thì không có giới hạn.
///
/// Và hai thứ tiếng xếp khác nhau chứ không chỉ khác chữ: tiếng Việt viết
/// "Tháng 10 năm 2026" còn tiếng Anh viết "October 2026", không có từ nào
/// tương ứng với "năm". Ghép chuỗi theo kiểu "${Ngu.d('Tháng')} $thang" sẽ
/// ra "October 10 2026".
String tenThang(DateTime d) {
  if (Ngu.hien.value != 'en') return 'Tháng ${d.month} năm ${d.year}';
  const ten = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${ten[d.month - 1]} ${d.year}';
}

/// Tên tháng dạng ngắn: "Tháng 10/2026" / "Oct 2026".
String tenThangNgan(DateTime d) {
  if (Ngu.hien.value != 'en') return 'Tháng ${d.month}/${d.year}';
  const ten = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${ten[d.month - 1]} ${d.year}';
}

/// Bảy chữ viết tắt của thứ, bắt đầu từ thứ Hai.
///
/// Tiếng Việt đánh số ngày trong tuần (T2 là thứ Hai), tiếng Anh viết tắt
/// tên riêng. Không đổi được bằng cách tra từ điển từng chữ vì "T2" một mình
/// chẳng mang nghĩa gì để dịch.
List<String> get thuVietTat => Ngu.hien.value == 'en'
    ? const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
    : const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
