# Đưa AstroTarot lên CH Play

Viết ngày 13/10/2026. Mỗi bước ghi rõ **ai làm được**: có bước chỉ bạn làm
được vì nó cần tiền, giấy tờ, hoặc một khoá bí mật không ai được giữ hộ.

---

## Đọc cái này trước: lịch trình thật là ~3 tuần, không phải một buổi

**Tài khoản đã mở ngày 13/10/2026 là loại cá nhân** (Personal), id nhà phát
triển `5909859073290519896`. Nên luật dưới đây áp dụng, không phải "có thể":

Tài khoản **cá nhân** mở sau 13/11/2023 phải chạy **closed testing với ít
nhất 12 người thử, giữ liên tục 14 ngày**, rồi mới được xin quyền phát hành
công khai. Mức này từng là 20 người, Google hạ xuống 12 từ 11/12/2024; còn mốc
14 ngày thì không đổi.

Cộng thêm thời gian Google xét đơn (trang trợ giúp nói thường dưới 7 ngày),
lần phát hành đầu tiên mất **khoảng ba tuần** kể từ lúc có đủ 12 người cài
thật.

Ba chỗ dễ vỡ kế hoạch:

- **Chỉ tính người đã CÀI, không tính người đã mời.** Mời 20 người mà 8 người
  không bấm cài thì bạn có 12, không phải 20.
- **14 ngày phải liên tục.** Có người gỡ ứng dụng giữa chừng và tụt xuống 11
  là đồng hồ chạy lại. Nên mời dư vài người.
- **Đủ điều kiện không có nghĩa là được duyệt.** Ngưỡng ấy chỉ mở ra cái nút
  nộp đơn; Google còn hỏi người thử dùng ra sao, bạn nhận phản hồi gì, đã sửa
  gì.

Tài khoản **tổ chức** không thuộc diện này, nhưng nó đòi giấy tờ doanh nghiệp
và mã D-U-N-S — với một đồ án sinh viên thì thường không có.

> **Nếu hạn nộp EXE201 gần hơn ba tuần**: đừng đặt cược vào CH Play. Dùng tệp
> `.apk` ở phần Releases của repo để cài tay lúc demo — nó chạy y hệt. Vẫn mở
> hồ sơ CH Play song song, nhưng đừng để tiến độ đồ án phụ thuộc vào nó.

---

## Bước 1 — Tạo kho khoá ký (chỉ bạn làm được)

Đây là việc duy nhất còn lại nằm trong mã nguồn, và tôi không làm hộ được: nó
sinh ra một khoá bí mật kèm mật khẩu. **Mất khoá là mất vĩnh viễn khả năng
cập nhật ứng dụng đã phát hành** — không ai khôi phục được, kể cả Google.

Làm theo [`android/KHOA-KY.md`](android/KHOA-KY.md). Xong thì có
`android/key.properties`, và tệp ấy đã nằm trong `.gitignore`.

**Sao lưu ngay** kho khoá ra một chỗ thứ hai (ổ ngoài, hoặc trình quản lý mật
khẩu). Đừng để nó chỉ nằm trên một máy.

Kiểm nhanh là xong:

```bash
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.astrotarot.date
```

Không in cảnh báo `Chua co android/key.properties` nghĩa là đã ký bằng khoá
thật.

---

## Bước 2 — Quyết hướng đi cho gói AI (A5)

Quyết **trước** khi chụp ảnh màn hình, vì nếu chọn Play Billing thì cả luồng
mua phải viết lại và ảnh chụp cũ bỏ hết.

### Việt Nam KHÔNG có cửa thanh toán thay thế (kiểm lại 14/10/2026)

Bản trước của tài liệu này ghi một hướng không tồn tại, nên xoá hẳn: cơ chế
*user choice billing* và *alternative billing* của Google **không mở cho Việt
Nam**. Danh sách thị trường của Google gồm 30 nước EEA, Anh, Mỹ, Nhật, Úc,
Brazil, Indonesia, Nam Phi, cộng Hàn Quốc và Ấn Độ theo diện riêng. Không có
Việt Nam. Đừng mất thời gian đi đăng ký.

### Cái gì buộc dùng Play Billing, cái gì không

Theo chính sách Thanh toán của Google:

| Luồng tiền trong app | Bắt buộc Play Billing? | Vì sao |
|---|---|---|
| **Gói cước AI** | **CÓ** | "subscription services" cho nội dung số, dùng ngay trong app |
| **Nạp ví ASTROTAROT** | **CÓ** | ví là tiền ảo bán trong app, mà tiền ảo bán trong app bị nêu đích danh |
| **Buổi xem với Reader** | KHÔNG | miễn trừ "one-to-one online services": hai cá nhân, không xem lại được |

Chỗ chết người là **cái ví**. Nó là một túi chung trả cho cả thứ được miễn
trừ (buổi xem) lẫn thứ không được miễn trừ (gói AI). Nạp ví bằng PayOS rồi
trừ ví mua gói AI chính là mẫu Google xem là bán tiền ảo trong ứng dụng.

### Hai đường đi thật

1. **Tách dòng tiền.** Gói AI bán qua Play Billing như một sản phẩm trong ứng
   dụng thật; ví + PayOS chỉ còn để đặt lịch Reader. Phí Play 15% cho một
   triệu đô doanh thu đầu (chương trình nhà phát triển nhỏ). Đây là đường
   chắc chắn qua.
2. **Bỏ hẳn việc mua trong app Android.** Gói AI chỉ bán trên web, app không
   có nút mua và không dẫn ra ngoài để mua. App vẫn nhận tiền đặt lịch bình
   thường vì khoản đó được miễn trừ. Rẻ công hơn, nhưng mất doanh thu gói từ
   người dùng di động, và phải cẩn thận không để sót chỗ nào mời mua.

Hiện app đang bán gói AI bằng ví (`goi_ai_screen.dart`), tức là đang ở trạng
thái **chưa hợp lệ** nếu Google soi kỹ. Mốc này không chặn closed testing,
nhưng sẽ chặn lúc xin phát hành công khai.

---

## Bước 3 — Mở tài khoản Play Console

Phí đăng ký **25 USD, trả một lần**, không phải hằng năm.

Cần căn cước và một thẻ thanh toán quốc tế. Tên trên tài khoản sẽ hiện công
khai ở trang ứng dụng, nên điền đúng tên bạn muốn người ta thấy.

---

## Bước 4 — Đổi tên gói, nếu còn muốn đổi (B2)

Tên hiện tại `com.astrotarot.astrotarot_mobile` lặp chữ và có gạch dưới.
Muốn thành `com.astrotarot.app` thì **phải đổi trước lần nộp đầu tiên** — sau
đó nó là khoá định danh vĩnh viễn, đổi là thành một ứng dụng khác hoàn toàn,
mất hết người dùng và đánh giá.

Nói tôi biết thì tôi đổi, khoảng mười phút. Không đổi cũng không sao, chỉ là
hơi xấu.

---

## Bước 5 — Dựng tệp nộp

CH Play **chỉ nhận App Bundle (`.aab`)**, không nhận `.apk`.

Cách dễ nhất: vào tab **Actions** của repo, chạy workflow **Phát hành**. Nó
dựng cả `.aab` lẫn `.apk`, rồi đính vào mục Releases. Tải
`astrotarot-release.aab` về.

Workflow sẽ **dừng với lỗi** nếu chưa có `android/key.properties` — cố ý, để
bạn không mang một tệp ký bằng khoá gỡ lỗi lên trang tải lên rồi mới biết.

Muốn dựng ở máy thì:

```bash
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.astrotarot.date
```

Tệp ra ở `build/app/outputs/bundle/release/`. Đo thật ngày 13/10/2026: **72,3
MB**, lọt giới hạn 150 MB. Nặng vì thư viện gọi video gói mã máy cho mọi loại
chip; Google cắt ra nên máy người dùng tải về nhẹ hơn nhiều.

---

## Bước 6 — Điền hồ sơ ứng dụng

Thứ tự này đi từ thứ đã có sẵn tới thứ phải tự viết.

| Mục | Điền gì |
|---|---|
| Chính sách riêng tư | `https://astrotarot.date/chinh-sach-rieng-tu` |
| Xoá tài khoản | `https://astrotarot.date/xoa-tai-khoan` — Google bắt buộc có đường dẫn xoá **mở được mà không cần cài app** |
| Danh mục | Phong cách sống |
| Đối tượng | Chọn **18+**. App có nội dung bói toán và thanh toán; khai thấp hơn là mở thêm một loạt yêu cầu về trẻ em |
| Phân loại nội dung | Bộ câu hỏi của Google. Khai thật, nhất là mục nội dung do AI sinh |
| Data safety | Khai theo đúng danh sách ở [`CHO-UNG-DUNG.md`](CHO-UNG-DUNG.md) mục A4 |
| Tài khoản thử cho người duyệt | **Lập tài khoản mới**, đừng lấy lại tài khoản demo cũ — mật khẩu của chúng đã bị migration `V2_32` khoá vì từng nằm công khai trên GitHub |

**Khai sai nguy hiểm hơn khai thiếu**: Google đối chiếu với hành vi thật của
app, lệch là gỡ ứng dụng.

Phần Data safety phải nhắc riêng **ngày giờ và nơi sinh** — đó là dữ liệu nhạy
cảm, không gộp chung vào "thông tin cá nhân".

---

## Bước 7 — Ảnh chụp màn hình và ảnh nổi bật (B6)

Cần: ảnh chụp theo từng cỡ máy, mô tả ngắn, mô tả dài, và ảnh nổi bật
1024×500.

Chụp từ máy ảo là được. Ba máy ảo đang dựng sẵn ở máy bạn, và
[`tool/chay.ps1 -MoiMay`](tool/chay.ps1) cài app lên tất cả cùng lúc.

Màn đáng chụp: trang chủ với quạt bài, màn trải bài Tarot có kết quả, danh
sách Reader, màn trò chuyện trong buổi xem, bản đồ sao.

**Trong mô tả phải có câu miễn trừ** — app đoán vận mệnh, và lời lẽ nghe như
lời khuyên y tế, tài chính hay pháp lý là dính ngay. Trong app đã có câu ấy
rồi, chép sang là được.

---

## Bước 8 — Closed testing 14 ngày

Tạo track **Closed testing**, tải `.aab` lên, thêm 12+ địa chỉ Gmail.

Mỗi người phải **bấm vào liên kết opt-in và cài thật** bằng đúng tài khoản
Google ấy. Gửi họ kèm một câu nhờ mở app vài lần trong hai tuần — Google có
hỏi về mức độ tương tác khi xét đơn.

Mời **dư 3–4 người** phòng khi có người gỡ app giữa chừng.

---

## Bước 9 — Xin quyền phát hành công khai

Đủ 12 người × 14 ngày liên tục thì nút nộp đơn hiện ra ở Dashboard. Đơn hỏi
người thử phản hồi gì và bạn đã sửa gì — trả lời cụ thể, đừng viết chung
chung.

Duyệt xong mới tạo được bản phát hành trên track Production.

---

## Những gì đã xong, không phải lo

- Khoá ký đọc từ `key.properties`, không còn ký bằng khoá gỡ lỗi
- Người dùng tự xoá tài khoản được, ngay trong app và cả trên web
- Chính sách riêng tư, mở được không cần đăng nhập
- Biểu tượng ứng dụng thật, có cả icon thích ứng
- Câu miễn trừ về tính chất giải trí
- Nút báo cáo nội dung do AI sinh — chính sách AI tạo sinh của CH Play bắt buộc
- `usesCleartextTraffic` chỉ bật ở bản gỡ lỗi
- Quyền xin đúng mức, không có quyền thừa
- Dựng được `.aab`, có chốt chặn khoá ký

Chi tiết từng mục ở [`CHO-UNG-DUNG.md`](CHO-UNG-DUNG.md).

---

## Nguồn

Yêu cầu 12 người thử × 14 ngày: [Play Console Help — App testing requirements
for new personal developer
accounts](https://support.google.com/googleplay/android-developer/answer/14151465).
Mốc hạ từ 20 xuống 12 ngày 11/12/2024 và các lưu ý về cách đếm người thử lấy
từ các bài hướng dẫn bên thứ ba, nên kiểm lại trên chính Play Console trước
khi dựa vào.
