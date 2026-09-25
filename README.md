# AstroTarot Mobile

App Flutter cho nền tảng AstroTarot, dùng chung backend với web:
`https://api.astrotarot.date`.

Đây là **khung dự án**, chưa phải sản phẩm hoàn chỉnh. Phần đã chạy thật:
đăng nhập, giữ phiên qua Keystore, tự làm mới token, kênh realtime STOMP, và
thanh điều hướng tự đổi theo quyền. Mọi màn hình nghiệp vụ còn là chỗ trống có
ghi rõ sẽ gọi endpoint nào.

## Vì sao đặt ở `C:\src\`

`flutter analyze` chết khi dự án nằm trong `OneDrive\Máy tính` — analysis
server không chịu được dấu tiếng Việt trong đường dẫn. Cả `C:\src\rcr` cũng là
junction dựng vì lý do này. Đừng chuyển dự án vào thư mục có dấu.

## Chạy

```bash
cd C:\src\astrotarot_mobile
flutter run
```

Mặc định trỏ tới production. Muốn trỏ về backend chạy ở máy:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

`10.0.2.2` chứ **không phải** `localhost`: trong máy ảo Android, `localhost`
là chính máy ảo, không phải máy tính của bạn. Máy ảo iOS thì `localhost` lại
đúng.

## Hai cái bẫy đã gặp trên máy này

**1. `Failed to find target with hash string 'android-37'`**

SDK Manager cài API 37 vào thư mục `android-37.0`, vì `source.properties` của
gói ghi sai `AndroidVersion.ApiLevel=37.0` thay vì `37`. Gradle tìm
`android-37` nên không thấy.

Đã xử bằng junction (cộng thêm, hoàn tác được):

```powershell
New-Item -ItemType Junction `
  -Path "C:\Users\LENOVO\Android\Sdk\platforms\android-37" `
  -Target "C:\Users\LENOVO\Android\Sdk\platforms\android-37.0"
```

Build sẽ in cảnh báo `Observed package id ... in inconsistent location` — vô
hại. Muốn bỏ junction: `rmdir` đúng đường dẫn `android-37` (xoá liên kết,
không xoá dữ liệu trong `android-37.0`).

**2. `compileSdk` của app phải ≥ của mọi thư viện**

`permission_handler_android` 14.1.0 ghim cứng `compileSdk = 37`, trong khi
`flutter.compileSdkVersion` đang là 36. Đã ghim thẳng `compileSdk = 37` trong
`android/app/build.gradle.kts`.

## Kiến trúc

```
lib/
  core/
    config.dart            URL theo môi trường, suy ra luôn URL WebSocket
    api/
      token_store.dart     token nằm trong Keystore/Keychain, không phải prefs
      api_client.dart      Dio + tự làm mới token + bóc bao thư
    auth/
      app_user.dart        người dùng + quyền
      auth_controller.dart Riverpod, một chỗ duy nhất quyết định "đã đăng nhập"
    realtime/
      realtime_client.dart STOMP + sổ đăng ký sống sót qua đứt nối
  features/
    auth/                  màn đăng nhập (chạy thật)
    shell/                 thanh tab theo quyền
    account/               hồ sơ + cửa vào khu quản trị (chạy thật)
    placeholder/           chỗ trống có ghi endpoint sẽ dùng
```

### Ba quyết định đáng nêu

**Không chép bảng vai-trò → quyền sang đây.** Backend đã trả thẳng
`permissions` trong phản hồi đăng nhập và `/api/v1/me`. Web giữ một bản sao
kèm chú thích "sửa một bên phải sửa bên kia"; chép thêm lần nữa là tạo bản sao
thứ ba, và bản thứ ba chắc chắn lệch trước vì ít được đụng tới nhất. App chỉ
tiêu thụ thứ máy chủ gửi. Thiếu trường đó thì lùi về đúng `USER_BASIC` — hẹp
còn hơn sai.

**Làm mới token một-luồng.** Mở một màn hình là bắn vài lời gọi song song;
token hết hạn thì tất cả cùng nhận 401. Mỗi cái tự đi làm mới là backend cấp N
refresh token, các lượt sau cầm token đã bị thay, và người dùng bị đăng xuất
ngẫu nhiên. Xem `ApiClient._lamMoiMotLuong`.

**Sổ đăng ký realtime.** WebSocket đứt liên tục (máy chủ gói free khởi động
lại, 4G chuyển trạm, khoá màn hình). Màn hình chỉ `subscribe` một lần sẽ câm
sau lần đứt đầu tiên trong khi vẫn hiện "đang kết nối". Xem
`RealtimeClient.nghe`.

## Còn phải làm

Phạm vi đã chọn là **toàn bộ vai trò, kể cả quản trị**. Backend có 138
endpoint trên 27 controller; không màn hình nào dưới đây cần viết thêm API.

| Nhóm | Màn hình | Ưu tiên |
|---|---|---|
| Khách | Trang chủ, tìm Reader, hồ sơ Reader, đặt lịch, thanh toán | 1 |
| Khách | Lịch hẹn, trò chuyện, gọi WebRTC | 2 |
| Khách | Tarot AI, lịch sử trải bài, bản đồ sao | 3 |
| Khách | Gian hàng, giỏ, đơn hàng | 4 |
| Nhân sự | Hàng chờ hỗ trợ, lịch hẹn nhận được, thu nhập, hồ sơ Reader | 2 |
| Quản trị | Tài khoản, duyệt đơn Reader, đối soát thanh toán, rút tiền | 5 |

Gọi WebRTC dùng `flutter_webrtc`, tín hiệu đi qua đúng hai đích STOMP mà web
đang dùng: `/app/bookings/{id}/chat` và `/app/bookings/{id}/call`. Lưu ý dự án
đang chạy **chỉ STUN, không TURN** — hai máy cùng sau NAT đối xứng (rất phổ
biến với 4G ở Việt Nam) sẽ không nối được cuộc gọi.

## Kiểm tra

```bash
flutter analyze
flutter test
flutter build apk --debug
```
