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

/// Phần nội dung thừa ra ngoài màn phải bằng ít nhất chừng này lần chiều cao
/// màn thì mới được phép giấu thanh.
///
/// ## Vì sao đo theo màn chứ không theo một số pixel cố định
///
/// Bản đầu đặt ngưỡng cứng 240px. Trên máy 1080×2400 thì đó là một phần mười
/// màn hình — gần như không chặn gì. Đo theo màn thì ngưỡng tự lớn lên trên
/// máy màn to và nhỏ lại trên máy màn bé, đúng như cảm giác "còn phải cuộn
/// một lúc nữa" của người dùng.
///
/// ## Vì sao 0,15 chứ không phải nhiều hơn
///
/// Đã thử 0,5 (nửa màn) và nó hỏng theo hướng ngược lại: **không màn nào
/// trong app vượt nổi**. Đo trên máy thật ngày 29/10/2026 — tab Tài khoản,
/// màn dài nhất, chỉ thừa chừng 720px trên khung nhìn 2000px; danh sách
/// Reader thừa 400px. Ngưỡng nửa màn biến cả tính năng thành vô dụng: thanh
/// không bao giờ giấu ở đâu cả.
///
/// 0,15 của 2000px là 300px — nhỉnh hơn hai lần chiều cao thanh (168px). Đó
/// là ranh giới hợp lý: giấu thanh chỉ đáng khi phần cuộn được còn nhiều hơn
/// phần màn hình mình vừa giành lại được.
///
/// Danh sách ngắn hơn thế mà vẫn giấu thì sau khi giấu, nội dung lại vừa đủ
/// một màn và không còn gì để cuộn — thanh chớp một cái rồi hiện lại.
const double tiLeDuDaiDeGiau = 0.15;

/// Quãng kéo tối thiểu (điểm logic) trước khi thanh được phép đổi trạng thái.
///
/// ## Vì sao phải có
///
/// Đây là lỗi chỉ máy thật mới chỉ ra. Đo bằng log trên máy ảo, cuối MỖI cú
/// kéo xuống đều có đúng một nhiễu nửa pixel ngược chiều:
///
/// ```
/// vt=113  dich=-3.9  -> hien
/// vt=114  dich=+0.5  -> giau   <- lệnh cuối cùng
/// ```
///
/// Không có vùng chết thì cái nhiễu ấy là lệnh cuối cùng tới tay thanh, và
/// thanh luôn luôn làm ngược điều người dùng vừa làm. Nhìn từ ngoài thì y hệt
/// triệu chứng của lỗi nảy-ở-biên, nên dễ tưởng đã sửa xong rồi.
///
/// 6 điểm logic: nhiễu dưới một pixel không bao giờ chạm tới, còn một cú kéo
/// thật (3–10 điểm mỗi khung hình) chạm tới trong một hai khung.
const double nguongDich = 6;

/// Đọc một thông báo cuộn ra quyết định cho thanh điều hướng.
///
/// ## Vì sao tách rời khỏi widget
///
/// Phần hoạt ảnh thì nhìn một cái là biết đúng sai. Phần dễ sai lại là mấy
/// BỘ LỌC bên dưới, mà muốn thấy chúng sai thì phải vuốt đúng kiểu trên đúng
/// màn với đúng dữ liệu. Tách ra thì từng luật kiểm được bằng một dòng.
///
/// ## Từng bộ lọc để làm gì
///
/// - **Chỉ nghe tầng ngoài cùng.** Danh sách lồng trong danh sách gửi thông
///   báo riêng; đếm cả hai là một cú vuốt ra hai quyết định ngược nhau.
/// - **Chỉ nghe trục dọc.** Trang chủ có băng chuyền ngang — không lọc thì
///   vuốt xem Reader cũng làm thanh dưới biến mất, mà người dùng có cuộn
///   trang đâu.
/// - **Danh sách ngắn thì luôn hiện.** Xem [tiLeDuDaiDeGiau].
/// - **Về tới đầu danh sách thì luôn hiện.** Xem bên dưới.
/// - **Chỉ nghe lúc ngón tay còn đặt trên màn.** Xem bên dưới.
/// - **Phải kéo đủ xa mới đổi.** Xem [nguongDich].
///
/// ## Vì sao phải có luật "về đầu danh sách thì hiện"
///
/// Đây là chỗ app từng rơi vào ngõ cụt thật. Thanh đang giấu, danh sách đã ở
/// đầu, người dùng kéo xuống để gọi thanh về — và **không có gì xảy ra**.
/// Android dùng `ClampingScrollPhysics`: ở đầu danh sách, kéo thêm không làm
/// nội dung nhúc nhích, nên không một thông báo cuộn nào được phát. Không có
/// thông báo thì không có lệnh hiện, và thanh nằm khuất vĩnh viễn — app mất
/// hẳn đường chuyển tab.
///
/// Luật này đọc **vị trí**, không đọc chuyển động, nên nó cứu được: cú cuộn
/// đưa danh sách về đầu tự nó đã phát thông báo, và thông báo ấy mang
/// `viTri == 0`.
///
/// ## Vì sao chỉ nghe lúc ngón tay còn đặt trên màn
///
/// Một cú vuốt sinh ra ba đợt thông báo: lúc kéo, lúc trôi theo quán tính sau
/// khi nhấc tay, và lúc đập vào biên rồi nảy ngược. Hai đợt sau KHÔNG phải ý
/// định của người dùng — nhất là cú nảy, vì nó chuyển động theo chiều ngược
/// với chiều người ta vừa vuốt. Nghe cả ba thì lệnh cuối cùng tới tay thanh
/// là lệnh của cú nảy, tức là luôn luôn ngược.
///
/// Đó chính là triệu chứng "vuốt xuống thì thanh ẩn, vuốt lên thì thanh cũng
/// ẩn" đo được trên máy thật.
YNav yNavTuCuon({
  required bool dangKeoTay,
  required int doSau,
  required Axis truc,
  required double daiCuonDuoc,
  required double caoKhungNhin,
  required double viTri,
  required double dich,
}) {
  if (doSau != 0) return YNav.giuNguyen;
  if (truc != Axis.vertical) return YNav.giuNguyen;
  if (daiCuonDuoc < caoKhungNhin * tiLeDuDaiDeGiau) return YNav.hien;
  // Kể cả khi đang kéo quá đầu (viTri âm) — lúc ấy người dùng đang cố kéo
  // nội dung xuống, và điều họ muốn thấy là thanh quay về.
  if (viTri <= 0) return YNav.hien;
  if (!dangKeoTay) return YNav.giuNguyen;
  // [dich] là quãng đã kéo CỘNG DỒN từ lần quyết gần nhất, không phải quãng
  // của riêng khung hình này. Cộng dồn thì một cú kéo chậm vẫn tới ngưỡng,
  // còn nhiễu nửa pixel đổi chiều liên tục thì tự triệt tiêu nhau.
  if (dich >= nguongDich) return YNav.giau;
  if (dich <= -nguongDich) return YNav.hien;
  return YNav.giuNguyen;
}
