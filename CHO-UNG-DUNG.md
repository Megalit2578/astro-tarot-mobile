# Điều kiện lên CH Play và App Store

Rà soát ngày 05/10/2026 trên chính mã nguồn, không phải chép danh sách chung.
Mỗi mục ghi rõ: đã sửa, hay còn phải làm, và làm thì ai làm được.

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

### A3. Người dùng không tự xoá được tài khoản — CÒN PHẢI LÀM

Cả hai chợ đều **bắt buộc**: Apple ở hướng dẫn 5.1.1(v), Google ở chính sách
Xoá dữ liệu tài khoản. App cho đăng ký thì phải cho xoá.

Trong mã hiện chỉ có `USER_DELETE` ở màn quản trị — tức admin xoá tài khoản
người khác. Không có đường nào cho chính chủ.

Cần ba phần:

| | |
|---|---|
| Backend | `DELETE /api/v1/users/me` — xoá hoặc ẩn danh dữ liệu cá nhân, giữ lại hoá đơn theo nghĩa vụ kế toán |
| App | Nút trong `lib/features/account/account_screen.dart`, cạnh "Đăng xuất", có bước xác nhận |
| Web | Một trang công khai để yêu cầu xoá **mà không cần cài app** — Google bắt buộc có đường dẫn này |

### A4. Không có chính sách riêng tư — CÒN PHẢI LÀM

Không có trang nào trong web (`src/routes/` không có `privacy` hay
`chinh-sach`), cũng không có đường dẫn nào trong app.

Bắt buộc ở cả hai chợ, và phải là **đường dẫn công khai mở được mà không cần
đăng nhập**. Nội dung phải khớp dữ liệu app thật sự thu thập:

- Tài khoản: email, họ tên, ảnh đại diện
- **Ngày, giờ và nơi sinh** — đây là dữ liệu nhạy cảm, phải nói riêng
- Nội dung trò chuyện với Reader, câu hỏi gửi cho AI
- Lịch sử giao dịch và số dư ví
- Camera và micro khi gọi video

### A5. Bán gói AI không qua cổng thanh toán của chợ — RỦI RO LỚN NHẤT

Đây là mục tôi lo nhất, và nó không sửa được bằng mã.

Gói AI là **nội dung số tiêu thụ ngay trong ứng dụng**. Apple (hướng dẫn 3.1.1)
và Google (chính sách Thanh toán) đều bắt loại này phải đi qua IAP của họ, và
đều ăn hoa hồng. App đang nạp ví bằng chuyển khoản rồi trừ ví để mua gói
(`goi_ai_repository.dart`, `purchaseType: 'WALLET'`) — đúng cái mẫu cả hai chợ
từ chối.

Buổi xem với Reader thì **không** dính: đó là dịch vụ do người thật thực hiện
theo thời gian thực, cả hai chợ đều cho phép thanh toán ngoài.

Ba đường đi, chọn một:

1. **Bỏ bán gói AI trong app.** App chỉ còn đặt lịch với Reader. Gói AI vẫn bán
   trên web. Nhưng cũng không được *dẫn* người dùng sang web mua — Apple cấm cả
   việc đặt đường dẫn ra ngoài để tránh IAP.
2. **Dựng IAP thật** cho riêng gói AI, ở cả hai chợ. Tốn công nhất, và mất
   15–30% doanh thu gói.
3. **Chỉ phát hành trên CH Play trước.** Google nới hơn Apple ở vài thị trường
   và có cơ chế thanh toán thay thế; Apple thì gần như không.

Với một đồ án một kỳ, hướng 1 là nhanh và chắc nhất.

### A6. Tài khoản thử cho người duyệt — CÒN PHẢI LÀM

Gần như mọi thứ nằm sau màn đăng nhập. Người duyệt của Apple không tự đăng ký
mà **trả hồ sơ về** nếu không vào được. Phải điền sẵn email và mật khẩu một tài
khoản thử vào ô "Sign-in information" của App Store Connect, và phần ghi chú
của CH Play.

Tài khoản ấy nên có sẵn: một lượt đặt lịch, một đoạn trò chuyện, một gói AI còn
hạn — để người duyệt thấy được app làm gì thay vì một màn hình trống.

---

## B. Dễ bị trả về, nên sửa trước khi nộp

### B1. Biểu tượng vẫn là icon Flutter mặc định

`android/app/src/main/res/mipmap-*/ic_launcher.png` nặng 442–1443 byte — đúng
hình chữ F xanh Flutter sinh ra lúc tạo dự án. Apple từ chối tài nguyên tạm ở
mục 2.3.8, và CH Play thì nhìn là biết chưa xong.

Cần bộ icon thật, kèm **icon thích ứng** cho Android 8 trở lên
(`mipmap-anydpi-v26`). Màn đăng nhập đã có hình bốn cánh sao màu vàng — lấy đó
làm gốc là hợp.

### B2. Tên gói `com.astrotarot.astrotarot_mobile`

Lặp chữ và có gạch dưới. Đổi được thì đổi thành `com.astrotarot.app`, **nhưng
phải đổi TRƯỚC lần phát hành đầu tiên** — sau đó tên gói là khoá định danh vĩnh
viễn, đổi là thành một ứng dụng khác hoàn toàn.

### B3. Chưa có lời miễn trừ về tính chất giải trí

App đoán vận mệnh. Hai chợ không cấm, nhưng nếu lời lẽ nghe như lời khuyên y
tế, tài chính hay pháp lý thì dính ngay. Nên có một câu rõ ràng ở màn Tarot và
trong phần mô tả: nội dung chỉ mang tính tham khảo và giải trí, không thay thế
tư vấn chuyên môn.

### B4. Chính sách nội dung do AI sinh ra

CH Play yêu cầu app có nội dung AI sinh ra phải cho người dùng **báo cáo nội
dung không phù hợp ngay trong app**. Lời giải Tarot do Gemini sinh ra thuộc
diện này. Hiện chưa có nút báo cáo nào ở màn trải bài.

### B5. Khai báo dữ liệu

- CH Play: biểu mẫu **Data safety**
- Apple: **Privacy nutrition labels**

Khai sai nguy hiểm hơn khai thiếu: hai chợ có đối chiếu với hành vi thật của
app, lệch là gỡ ứng dụng. Khai theo đúng danh sách ở mục A4.

### B6. Tài nguyên cho trang giới thiệu

Ảnh chụp màn hình theo từng cỡ máy, mô tả ngắn và dài, phân loại độ tuổi, và
với CH Play là ảnh nổi bật 1024×500.

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

## Thứ tự nên làm

1. A3 xoá tài khoản và A4 chính sách riêng tư — hai thứ này chắc chắn bị hỏi,
   và đều cần cả web lẫn app nên làm lâu nhất.
2. A5 quyết định hướng đi cho gói AI. Quyết sớm vì nó đổi cả luồng mua.
3. A1 tạo khoá ký, B1 bộ icon.
4. A6 tài khoản thử, B5 khai báo dữ liệu, B6 ảnh chụp màn hình.
5. B3, B4 những câu chữ và nút báo cáo.
