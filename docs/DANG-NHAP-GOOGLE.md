# Đăng nhập Google trên app

Mã đã xong cả hai đầu. Phần cấu hình bên Google cũng đã dựng sẵn. Việc còn
lại chỉ là **upload một bản dựng mới** — bản đang nằm trên Play chưa có nút
này.

## Đã dựng sẵn bên Google (21/10/2026)

Project `astrotarot-play`, dùng chung với Play Billing và GA4.

| Client | Kiểu | Dùng cho |
| --- | --- | --- |
| `AstroTarot Web` | Web | máy chủ xác minh ID token |
| `AstroTarot Android (Play)` | Android | bản tải từ CH Play |
| `AstroTarot Android (upload key)` | Android | bản thử nội bộ, bản `flutter build` ký bằng upload key |

Package name cả hai client Android: `com.astrotarot.astrotarot_mobile`.

| Vân tay SHA-1 | Lấy ở đâu |
| --- | --- |
| `2D:8B:B4:D3:0D:4F:FE:70:75:BB:26:E3:5C:BC:9E:C2:EA:60:F4:BC` | Play Console → App signing → **App signing key** |
| `97:A2:14:A8:49:37:48:45:62:A2:00:76:AD:9E:4B:59:8C:95:25:51` | Play Console → App signing → **Upload key** |

Vân tay không phải bí mật — nó là băm của chứng chỉ công khai.

## Vì sao phải có HAI client Android

Google Play **ký lại** app bằng khoá của họ trước khi phát cho người dùng.
Nên bản tải từ CH Play mang vân tay *app signing key*, còn bản bạn tự dựng và
cài bằng `adb` mang vân tay *upload key*. Google đối chiếu đúng vân tay của
bản đang chạy trên máy.

Khai thiếu một cái thì nút Google chạy ở nơi này và im ở nơi kia — đúng kiểu
lỗi làm người ta nghi ngờ cả tính năng.

## Vì sao `serverClientId` là client WEB

Chỗ này sai là lỗi khó tìm nhất của cả tính năng.

`lib/core/auth/dang_nhap_google.dart` truyền client ID **web** vào
`serverClientId`, không phải client Android. Lý do: ID token mà app gửi về
phải mang `aud` là client của **bên xác minh nó** — tức máy chủ web.

Đưa nhầm client Android vào đó thì luồng trên máy chạy trơn tru, người dùng
chọn tài khoản xong xuôi, rồi máy chủ từ chối ở bước cuối với câu *"Token
Google không dành cho ứng dụng này"*.

## Việc còn lại

**Upload một bản dựng mới lên Play.** Bản đang ở đó là bản 13/10, trước khi
có nút này. Nhớ tăng `version` trong `pubspec.yaml` — trùng `versionCode` là
Play từ chối.

Chưa upload thì người dùng hiện tại không thấy nút, nhưng **không có gì
hỏng**: bản cũ vẫn đăng nhập bằng email và mật khẩu như trước.

## Thử trước khi phát hành

```bash
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

1. Mở app → màn đăng nhập → **Tiếp tục với Google**.
2. Chọn một trong bốn tài khoản test (app đang ở chế độ *Testing* bên Google,
   người ngoài danh sách sẽ bị từ chối ngay trên trang của Google).
3. Phải vào thẳng app.
4. Thử bằng tài khoản **đã từng đăng ký bằng mật khẩu** → phải vào đúng tài
   khoản cũ, không sinh tài khoản trùng.

Bước 4 là bước đáng làm nhất. Sinh tài khoản trùng thì người dùng mất lịch sử
và số dư ví, mà lỗi ấy chỉ lộ ra sau khi đã xảy ra với người thật.

Quy tắc nối tài khoản nằm ở **một chỗ duy nhất** bên máy chủ
(`TaiKhoanGoogleServiceImpl`), dùng chung cho cả web và app — chính để tránh
hai bản cài đặt sai lệch nhau.

## Khi không thấy ID token

Thông báo trong app đã nói sẵn: kiểm `serverClientId` và vân tay SHA-1. Hai
nguyên nhân ấy chiếm gần hết các trường hợp. Lấy vân tay của bản đang chạy:

```bash
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk
```

So với bảng trên. Lệch thì khai thêm một client Android nữa cho đúng vân tay
đó.
