# Điều kiện lên CH Play

Rà soát ngày 05/10/2026 trên chính mã nguồn, không phải chép danh sách chung.
Mỗi mục ghi rõ: đã sửa, hay còn phải làm, và làm thì ai làm được.
Cập nhật 12/10/2026 sau khi chốt **chỉ phát hành Android**.

## Chốt ngày 12/10/2026: chỉ CH Play, không nộp App Store

Quyết định này **xoá hoặc làm nhẹ bốn mục** bên dưới, nên đọc nó trước khi đọc
danh sách:

| Mục | Đổi thành |
|---|---|
| A2 iOS thiếu mô tả quyền | Không còn liên quan. Giữ nguyên `Info.plist` đã sửa, không mất gì, và nếu sau này đổi ý thì khỏi làm lại. |
| A5 bán gói AI ngoài IAP | **Nhẹ hẳn.** Phần khắt khe nhất là của Apple. Google cho phép thanh toán thay thế ở Việt Nam, và điều cấm *dẫn người dùng ra web* cũng là của Apple. |
| A6 tài khoản thử | Vẫn cần, nhưng CH Play chỉ hỏi trong phần ghi chú cho người duyệt, không trả hồ sơ về ngay như Apple. |
| B5 khai báo dữ liệu | Chỉ còn biểu mẫu **Data safety** của Google. |

Những mục còn lại — A1 khoá ký, A3 xoá tài khoản, A4 chính sách riêng tư, B1
icon, B3 miễn trừ, B4 báo cáo nội dung AI — **Google cũng bắt buộc y hệt**, nên
không mục nào biến mất vì bỏ iOS.

---

## A. Chặn cứng — không qua được vòng duyệt

### A1. Bản phát hành ký bằng khoá gỡ lỗi — ĐÃ SỬA một nửa

`android/app/build.gradle.kts` để nguyên mẫu Flutter sinh ra:

```kotlin
// TODO: Add your own signing config for the release build.
signingConfig = signingConfigs.getByName("debug")
```

Khoá gỡ lỗi do Android SDK phát, máy nào cũng giống nhau, nên CH Play từ chối
thẳng. Nay đã đọc khoá thật từ `android/key.properties`.

**Còn phải làm:** tự tạo kho khoá. Xem [`android/KHOA-KY.md`](android/KHOA-KY.md).
Tôi không tạo hộ vì đó là khoá bí mật kèm mật khẩu — và mất nó là **mất vĩnh
viễn** khả năng cập nhật ứng dụng đã phát hành.

### A2. iOS thiếu mô tả quyền — ĐÃ SỬA

`ios/Runner/Info.plist` không có `NSCameraUsageDescription` lẫn
`NSMicrophoneUsageDescription`, trong khi app gọi video với Reader.

iOS không hỏi người dùng mà **kết thúc tiến trình ngay** khi app chạm vào
camera thiếu khoá ấy, và App Store Connect chặn ngay từ lúc nộp. Đã thêm cả ba
(camera, micro, thư viện ảnh) với câu nói rõ dùng vào việc gì — Apple từ chối
những câu chung chung kiểu "ứng dụng cần quyền camera".

### A3. Người dùng không tự xoá được tài khoản — ĐÃ LÀM

Google bắt buộc ở chính sách Xoá dữ liệu tài khoản: app cho đăng ký thì phải
cho xoá. Trước đây trong mã chỉ có `USER_DELETE` ở màn quản trị — tức admin xoá
tài khoản *người khác*, không có đường nào cho chính chủ.

Nay đủ ba phần:

| | |
|---|---|
| Backend | `DELETE /api/v1/users/me`. Xoá mềm hồ sơ và ẩn danh dữ liệu cá nhân, **giữ lại hoá đơn** theo nghĩa vụ kế toán — xoá cứng cả bảng giao dịch là tự xoá sổ sách của chính mình. |
| App | `_HopXoaTaiKhoan` trong `lib/features/account/account_screen.dart`, cạnh "Đăng xuất", có bước xác nhận. |
| Web | `src/routes/xoa-tai-khoan.tsx` — trang công khai, yêu cầu xoá được **mà không cần cài app**, đúng như Google đòi. |

### A4. Chính sách riêng tư — ĐÃ LÀM

`src/routes/chinh-sach-rieng-tu.tsx`, mở được **không cần đăng nhập** như
Google đòi. Nội dung khớp đúng dữ liệu app thật sự thu thập:

- Tài khoản: email, họ tên, ảnh đại diện
- **Ngày, giờ và nơi sinh** — đây là dữ liệu nhạy cảm, phải nói riêng
- Nội dung trò chuyện với Reader, câu hỏi gửi cho AI
- Lịch sử giao dịch và số dư ví
- Camera và micro khi gọi video

### A5. Bán gói AI không qua cổng thanh toán của chợ — NHẸ ĐI, nhưng phải quyết

Đây từng là mục đáng lo nhất, và nó không sửa được bằng mã. Bỏ iOS làm nó nhẹ
hẳn, chứ **không xoá hẳn**.

Gói AI là **nội dung số tiêu thụ ngay trong ứng dụng**. Apple (hướng dẫn 3.1.1)
và Google (chính sách Thanh toán) đều bắt loại này đi qua IAP của họ. App đang
nạp ví bằng chuyển khoản rồi trừ ví để mua gói (`goi_ai_repository.dart`,
`purchaseType: 'WALLET'`).

Buổi xem với Reader thì **không** dính: đó là dịch vụ do người thật thực hiện
theo thời gian thực, Google cho phép thanh toán ngoài.

Chỉ còn Google thì hai đường, chọn một:

1. **Dùng cơ chế thanh toán thay thế** Google mở cho nhà phát triển ở Việt Nam.
   Giữ nguyên luồng ví hiện tại, chỉ phải đăng ký và khai báo. Điều cấm *dẫn
   người dùng ra web mua* là của Apple, Google không cấm — nên đường này không
   còn vướng như lúc còn tính nộp App Store.
2. **Dựng Play Billing** cho riêng gói AI. Chắc chắn qua, nhưng tốn công và mất
   15–30% doanh thu gói.

**Chưa quyết.** Quyết sớm vì nó đổi cả luồng mua.

### A6. Tài khoản thử cho người duyệt — CÒN PHẢI LÀM

Gần như mọi thứ nằm sau màn đăng nhập. Điền sẵn email và mật khẩu một tài khoản
thử vào phần ghi chú cho người duyệt của CH Play.

Lưu ý: mật khẩu các tài khoản demo đã bị khoá ở migration
`V2_32__khoa_mat_khau_tai_khoan_demo.sql` (chúng từng nằm công khai trên
GitHub), nên tài khoản thử phải **lập mới** và đặt mật khẩu riêng, đừng lấy lại
tài khoản cũ trong tài liệu.

Tài khoản ấy nên có sẵn: một lượt đặt lịch, một đoạn trò chuyện, một gói AI còn
hạn — để người duyệt thấy được app làm gì thay vì một màn hình trống.

---

## B. Dễ bị trả về, nên sửa trước khi nộp

### B1. Biểu tượng ứng dụng — ĐÃ LÀM 05/10/2026

`mipmap-*/ic_launcher.png` từng nặng 442–1443 byte: đúng hình chữ F xanh
Flutter sinh ra lúc tạo dự án. Apple từ chối tài nguyên tạm ở mục 2.3.8, và CH
Play thì nhìn là biết chưa xong.

Nay có bộ icon thật cho mọi độ phân giải Android và iOS, kèm **icon thích ứng**
cho Android 8 trở lên (`mipmap-anydpi-v26`). Sinh bằng `flutter_launcher_icons`
từ một tệp nguồn duy nhất, `assets/icon/app_icon.png` 1024×1024.

Nguồn lấy từ chính logo sẵn có của web (`src/assets/logo-astrotarot.png`) —
**phần tròn ở tâm**, không phải cả logo. Logo là ảnh ngang 579×334 hình con
mắt; cắt vuông cả con mắt thì thu xuống 48px không còn nhìn ra gì. Ngôi sao năm
cánh với vầng mandala quanh nó mới là phần đọc được ở cỡ nhỏ.

Nền icon thích ứng để `#0D0B14` — màu nền của app, không để trắng: hệ thống bo
tròn hoặc cắt góc theo kiểu máy, và một viền trắng lòi ra quanh hình tối trông
như lỗi.

Đổi ảnh nguồn thì sinh lại bằng `dart run flutter_launcher_icons`.

### B2. Tên gói `com.astrotarot.astrotarot_mobile`

Lặp chữ và có gạch dưới. Đổi được thì đổi thành `com.astrotarot.app`, **nhưng
phải đổi TRƯỚC lần phát hành đầu tiên** — sau đó tên gói là khoá định danh vĩnh
viễn, đổi là thành một ứng dụng khác hoàn toàn.

### B3. Lời miễn trừ về tính chất giải trí — ĐÃ LÀM 05/10/2026

App đoán vận mệnh. Hai chợ không cấm, nhưng nếu lời lẽ nghe như lời khuyên y
tế, tài chính hay pháp lý thì dính ngay.

App đã có câu này từ trước, web thì chưa — nay đã thêm, ở cùng chỗ với nút báo
cáo bên dưới. **Còn phải viết câu tương tự vào phần mô tả ứng dụng** trên hai
chợ; việc đó làm lúc điền hồ sơ, không nằm trong mã.

### B4. Báo cáo nội dung do AI sinh ra — ĐÃ LÀM 05/10/2026

Chính sách AI tạo sinh của CH Play buộc ứng dụng có nội dung do AI sinh phải
cho người dùng **báo cáo nội dung không phù hợp ngay trong ứng dụng**. Lời giải
Tarot do Gemini sinh thuộc diện này, và trước đây không có đường nào.

Nay có nút *Báo cáo nội dung này* ngay dưới lời miễn trừ ở màn trải bài, **cả
web lẫn app**. Bốn lý do — sai lệch, xúc phạm, nguy hiểm, khác — kèm ô mô tả.

Backend: `POST /api/ai-readings/reports`, bảng riêng `ai_content_reports`.
Không dùng lại bảng `reports` vì bảng ấy để tố cáo **người**: cột
`reported_user_id` khai NOT NULL, mà nội dung AI thì không có người nào để tố;
nhét một tài khoản bất kỳ vào cho hợp lệ sẽ sinh ra những bản ghi tố cáo oan.

Số báo cáo chờ xử lý hiện trên màn Tổng quan của quản trị, **tách khỏi** ô báo
cáo vi phạm — kỷ luật một tài khoản và sửa một lời nhắc của mô hình là hai việc
rất khác nhau, gộp chung một con số là trộn hai hàng chờ.

### B5. Khai báo dữ liệu

Biểu mẫu **Data safety** của CH Play.

Khai sai nguy hiểm hơn khai thiếu: Google có đối chiếu với hành vi thật của
app, lệch là gỡ ứng dụng. Khai theo đúng danh sách ở mục A4.

### B6. Tài nguyên cho trang giới thiệu

Ảnh chụp màn hình theo từng cỡ máy, mô tả ngắn và dài, phân loại độ tuổi, và
ảnh nổi bật 1024×500.

---

## C. Đã ổn, không phải làm gì

- **`usesCleartextTraffic` chỉ bật ở bản gỡ lỗi**
  (`android/app/src/debug/AndroidManifest.xml`). Bật ở bản phát hành là một lý
  do bị từ chối; chỗ này làm đúng rồi.
- **Không có đăng nhập Google trong app**, nên Apple không bắt phải thêm "Sign
  in with Apple" — quy định ấy chỉ áp khi đã có đăng nhập của bên thứ ba khác.
- **Quyền xin đúng mức**: `INTERNET`, `CAMERA`, `RECORD_AUDIO`,
  `MODIFY_AUDIO_SETTINGS`, `BLUETOOTH_CONNECT`. Đều dùng thật cho gọi video,
  không có quyền thừa nào.
- **Phiên bản** `1.0.0+1` hợp lệ cho lần nộp đầu.

---

### A7. Không có tệp nào nộp lên CH Play được — ĐÃ SỬA 13/10/2026

Mục này trước đây không có trong danh sách, và đó là thiếu sót: nó chặn cứng
hơn mọi mục khác.

`release.yml` chỉ dựng **APK**. Google bắt ứng dụng mới phát hành bằng **App
Bundle (`.aab`)** từ tháng 8/2021; trang tải lên từ chối thẳng tệp `.apk`.
Nghĩa là trước hôm nay, repo không sinh ra tệp nào nộp được — và chuyện đó chỉ
lộ ra ở đúng phút ngồi điền hồ sơ.

Nay workflow dựng thêm `flutter build appbundle --release` và đính
`astrotarot-release.aab` vào bản phát hành. APK vẫn giữ: nó để cài tay lúc
thử và gửi cho người khác xem mà không cần Play.

Không dùng `--split-per-abi` cho bundle: Google tự cắt `.aab` thành bản riêng
cho từng loại máy, cờ ấy chỉ có nghĩa với APK.

**Kèm một chốt chặn**: `build.gradle.kts` cố ý KHÔNG làm hỏng bản dựng khi
thiếu `key.properties` — nó in cảnh báo rồi ký bằng khoá gỡ lỗi, để người mới
clone về vẫn chạy được. Nhưng một `.aab` ký bằng khoá gỡ lỗi là tệp vô dụng,
nên trong workflow phát hành thì ngược lại: thiếu `key.properties` là dừng
ngay với thông báo rõ, thay vì để phát hiện lúc đã đứng trước trang tải lên.

Đo thật ở máy: bundle **72,3MB**. Lọt giới hạn 150MB của CH Play. Nặng vì thư
viện gọi video gói mã máy cho mọi loại chip; Google cắt ra nên máy người dùng
tải về nhẹ hơn nhiều. Assets chỉ 1,6MB.

---

## Còn lại gì — tính đến 13/10/2026

Đã xong: A2 (không còn liên quan), A3, A4, **A7**, B1, B3, B4, và cả C.

Từ đây trở đi **không còn việc nào nằm trong mã nguồn**. Bốn mục dưới đây đều
cần bạn quyết hoặc tự làm.

Còn bốn việc, xếp theo thứ tự nên làm:

1. **A5 — quyết hướng đi cho gói AI.** Quyết đầu tiên vì nếu chọn Play Billing
   thì cả luồng mua phải viết lại, và mọi ảnh chụp màn hình chụp trước đó đều
   phải chụp lại.
2. **A1 — tạo kho khoá ký.** Chỉ bạn làm được: đó là khoá bí mật kèm mật khẩu,
   và mất nó là mất vĩnh viễn khả năng cập nhật ứng dụng đã phát hành. Xem
   [`android/KHOA-KY.md`](android/KHOA-KY.md).
3. **B2 — đổi tên gói** thành `com.astrotarot.app`, nếu còn muốn đổi. Phải đổi
   **trước lần nộp đầu tiên**; sau đó tên gói là khoá định danh vĩnh viễn.
4. **A6 tài khoản thử, B5 Data safety, B6 ảnh chụp màn hình** — việc điền hồ
   sơ, làm cuối cùng khi mọi thứ trong app đã chốt.

## Rà app so với web — 13/10/2026

Lần này đối chiếu **từng endpoint web gọi** với từng endpoint app gọi, chứ
không đọc lướt màn hình. Cách ấy có bẫy riêng: bốn đường dẫn trông như thiếu
(`/availability`, `/me/escrow`, `/me/payouts`) hoá ra app vẫn gọi, chỉ là khai
làm hằng riêng trong repository thay vì ở `endpoints.dart`.

Thiếu thật và đã bổ sung:

| | |
|---|---|
| Tìm bài viết | web có ô tìm, app thì không — danh sách bài chỉ dài thêm, nên bài cũ coi như mất |
| Bài liên quan | đọc xong một bài là hết đường đi tiếp, phải bấm quay lại rồi tự dò |
| Thời gian đọc | trả lời đúng câu người ta hỏi trước khi bấm vào |
| Chép liên kết bài | bài nằm trên web nên thứ muốn gửi đi là cái địa chỉ |
| Đường dẫn trang ghi công ảnh | app hiện đúng những ảnh CC BY ấy, nên phần nghĩa vụ của app trước đó vẫn còn nợ |

`/cart` và `/orders` bên web là mã chết — giỏ hàng đã bỏ từ lúc chuyển sang
mô hình liên kết tiếp thị. Không phải khoảng trống.

Còn **sản phẩm nổi bật** ở trang chủ: web có, app chưa. Chưa làm vì gian hàng
đang là 12 món chưa có liên kết tiếp thị thật — thêm một chỗ đẩy chúng ra
trước mặt người dùng lúc này là khuếch đại một thứ chưa sẵn sàng.
