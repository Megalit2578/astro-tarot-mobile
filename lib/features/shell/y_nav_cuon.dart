import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/widgets.dart' show Axis;

/// Thanh điều hướng nên làm gì sau một thông báo cuộn.
enum YNav {
  /// Trả thanh về chỗ cũ.
  hien,

  /// Cho thanh trượt khuất xuống dưới.
  giau,

  /// Thông báo này không nói gì về thanh.
  giuNguyen,
}

/// Dài hơn chừng này thì mới được phép giấu thanh.
///
/// Một trang chỉ dài hơn màn hình vài chục pixel vẫn cuộn được, và cú cuộn
/// ấy đủ để sinh một thông báo. Không có ngưỡng thì thanh chớp tắt một cái
/// rồi hiện lại ngay — trông như lỗi vẽ chứ không như một hành vi.
const double duDaiDeGiau = 240;

/// Đọc một thông báo cuộn ra quyết định cho thanh điều hướng.
///
/// ## Vì sao tách rời khỏi widget
///
/// Phần hoạt ảnh thì nhìn một cái là biết đúng sai. Phần dễ sai lại là mấy
/// BỘ LỌC bên dưới, mà muốn thấy chúng sai thì phải vuốt đúng kiểu trên đúng
/// màn — ví dụ vuốt ngang băng chuyền Reader ở trang chủ. Tách ra thì từng
/// luật kiểm được bằng một dòng, và luật mới thêm vào sau cũng vậy.
///
/// ## Từng bộ lọc để làm gì
///
/// - **Chỉ nghe cuộn do người dùng kéo.** Cuộn do mã gọi (`animateTo` lúc
///   mở màn, hoặc bàn phím đẩy ô nhập lên) không phải ý định của ai cả.
/// - **Chỉ nghe tầng ngoài cùng.** Danh sách lồng trong danh sách gửi thông
///   báo riêng; đếm cả hai là một cú vuốt ra hai quyết định ngược nhau.
/// - **Chỉ nghe trục dọc.** Trang chủ có băng chuyền ngang — không lọc thì
///   vuốt xem Reader cũng làm thanh dưới biến mất, mà người dùng có cuộn
///   trang đâu.
/// - **Trang ngắn thì luôn hiện.** Xem {@link duDaiDeGiau}.
YNav yNavTuCuon({
  required bool laCuaNguoiDung,
  required int doSau,
  required Axis truc,
  required double daiCuonDuoc,
  required ScrollDirection huong,
}) {
  if (!laCuaNguoiDung) return YNav.giuNguyen;
  if (doSau != 0) return YNav.giuNguyen;
  if (truc != Axis.vertical) return YNav.giuNguyen;
  if (daiCuonDuoc < duDaiDeGiau) return YNav.hien;
  return switch (huong) {
    ScrollDirection.reverse => YNav.giau,
    ScrollDirection.forward => YNav.hien,
    ScrollDirection.idle => YNav.giuNguyen,
  };
}
