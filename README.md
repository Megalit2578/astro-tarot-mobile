# AstroTarot Mobile

App Flutter cho nền tảng AstroTarot, dùng chung backend với web:
`https://api.astrotarot.date`.

Đã dựng xong bề mặt chính cho cả ba vai trò. Không còn chỗ trống nào ở các
tab chính.

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
      endpoints.dart       mọi đường dẫn — backend có NĂM kiểu tiền tố
      trang.dart           trang Spring `Page<T>` + hàm đọc JSON lỏng
    auth/
      app_user.dart        người dùng + quyền
      auth_controller.dart Riverpod, một chỗ duy nhất quyết định "đã đăng nhập"
    realtime/
      realtime_client.dart STOMP + sổ đăng ký sống sót qua đứt nối
  widgets/                 dùng chung: danh sách phân trang, dải chọn ngang,
                           hộp thoại, biểu đồ thanh, khối lỗi / rỗng
  features/                mỗi khu một thư mục: *_repository.dart gọi API,
                           *_screen.dart / *_view.dart là giao diện
    admin/                 khu Quản lý / Quản trị (9 mục theo quyền)
    auth/  shell/  home/  readers/  bookings/  money/  staff/  support/
    tarot/  astrology/  shop/  blog/  profile/  account/  notifications/
    readerprofile/  readerapply/  feedback/
test/
  support/gia.dart         máy chủ giả ở tầng HTTP, phiên giả, realtime giả
  support/webrtc_gia.dart  giả lập kênh native của flutter_webrtc
tool/                      coverage, SonarQube
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

## Đã dựng

Ngang với web ở mọi luồng — kể cả khu Quản lý / Quản trị.

| Khu | Màn |
|---|---|
| Xác thực | Đăng nhập, đăng ký, quên mật khẩu, gửi lại thư xác minh, **dán liên kết trong email** để xác minh / đặt lại mật khẩu ngay trong app |
| Khách | Trang chủ (buổi sắp tới, rút thử một lá, lần trải bài gần đây, bản đồ sao, trạng thái đơn Reader), Tarot AI + hỏi tiếp, lịch sử trải bài, bản đồ sao (thêm / sửa / xoá, tra nơi sinh ra toạ độ) |
| Khách | Tìm Reader, hồ sơ Reader (đánh giá, ngày trống gần nhất), đặt lịch, thanh toán (PayOS **và** chuyển khoản tay), đánh giá, báo cáo vi phạm, trò chuyện realtime, gọi thoại / video |
| Khách | Hồ sơ cá nhân, ảnh đại diện, đổi mật khẩu, thông báo (ghim, xoá tin đã đọc, bấm mở đúng màn), hỗ trợ, gian hàng (tìm, lọc danh mục, chi tiết), bài viết, góp ý (NPS), đăng ký làm Reader |
| Nhân viên / Reader | Lịch hẹn nhận được (nhận, hoàn tất, huỷ, ghi chú), hàng chờ hỗ trợ (đổi trạng thái phiếu), hồ sơ Reader (giá, thế mạnh, khung giờ rảnh, **ngày nghỉ**), thu nhập (sổ ký quỹ, rút tiền) |
| Quản lý / Quản trị | Tổng quan, tài khoản (tìm, lọc, chi tiết, tạo, đổi vai trò kể cả hàng loạt, khoá, thu hồi phiên, gửi đặt lại mật khẩu / xác minh, xoá), hồ sơ Reader, thanh toán, rút tiền, báo cáo vi phạm, nhật ký, bảng phân quyền, sản phẩm liên kết |

Khách **chưa đăng nhập** xem được danh sách và hồ sơ Reader — giống web.

Web tách `/manager` và `/admin`; app gộp một "Khu quản trị", mục tự hiện
theo đúng quyền trong `@PreAuthorize` của backend. Bảng phân quyền đọc thẳng
từ máy chủ (chi tiết một tài khoản mỗi vai trò), không chép tay.

## Lỗi đã sửa khi đối chiếu với backend

Phần lớn là lỗi **âm thầm** — bị nuốt hoặc trông như đã chạy:

- Đăng xuất không gửi `refreshToken` → 400, phiên trên máy chủ sống thêm 7 ngày.
- Lượt bấm tiếp thị gửi id thay vì slug → 404, mất số liệu hoa hồng.
- Từ chối đơn Reader gửi `reason` thay vì `rejectionReason` → người nộp không thấy lý do.
- Thanh toán khi PayOS tắt: không có link nên app báo lỗi — khách không trả được tiền.
- Đánh dấu đã đọc / đọc hết thông báo gọi POST, backend map PATCH.
- Công tắc "Đang nhận lịch" gửi trường backend không có — bấm như đã lưu.
- Sổ ký quỹ đoán hướng tiền theo dấu (luôn dương) → tiền phạt hiện "+" xanh.
- Lịch sử rút tiền đọc sai tên trường → không có số tài khoản, ngày yêu cầu.
- Trang chủ sập (ô xám) khi lịch hẹn chưa tải xong hoặc lỗi.
- Hộp thoại nhập lý do huỷ controller trong lúc còn đang vẽ.

## Cố ý KHÔNG dựng

**Giỏ hàng và đơn hàng.** Backend có sẵn, nhưng web không dùng: gian hàng là
liên kết tiếp thị sang sàn, doanh thu đến từ hoa hồng.

**Liên kết sâu (App Links).** Thư xác minh / đặt lại mật khẩu trỏ về web; app
cho dán liên kết đó vào. Mở thẳng app từ thư cần xác minh tên miền — việc riêng.

**Mã QR chuyển khoản trong màn quản trị rút tiền.** Web vẽ VietQR để người
duyệt quét bằng điện thoại; trên chính điện thoại thì không quét được màn của
mình, nên app cho chép số tài khoản bằng một chạm.

Gọi WebRTC dùng `flutter_webrtc`, tín hiệu đi qua đúng hai đích STOMP mà web
đang dùng. Dự án chạy **chỉ STUN, không TURN** — hai máy cùng sau NAT đối
xứng (rất phổ biến với 4G ở Việt Nam) sẽ không nối được cuộc gọi.

## Kiểm tra

```bash
flutter analyze --fatal-infos
tool/coverage_helper.sh && flutter test --coverage && python3 tool/kiem_coverage.py 80
flutter build apk --debug
```

Test chặn ở tầng HTTP của Dio (`test/support/gia.dart`): đi qua đúng
`ApiClient`, interceptor, bóc bao thư thật, nên bắt được sai phương thức, sai
tên trường, sai đường dẫn. `flutter_webrtc`, `url_launcher`, `image_picker`
và clipboard đều có bản giả, nên chạy được cả luồng gọi video lẫn đổi ảnh.

`coverage_helper.sh` sinh một test import mọi tệp trong `lib/` — không có nó,
`flutter test --coverage` chỉ đo tệp được test chạm tới và số ra đẹp giả.
CI đỏ khi coverage dưới 80%.

## SonarQube

SonarQube Community **không có sẵn Dart**. Dùng plugin cộng đồng
[sonar-flutter](https://github.com/insideapp-oss/sonar-flutter) 0.5.2 (đã
chạy thử trên SonarQube 26.9):

```bash
# 1. SonarQube + plugin (thư mục data để tmpfs nếu ổ gần đầy: Elasticsearch
#    từ chối tạo chỉ mục khi ổ vượt 90%)
docker run -d --name sonar -p 9000:9000 sonarqube:community
docker cp sonar-flutter-plugin-0.5.2.jar sonar:/opt/sonarqube/extensions/plugins/
docker restart sonar

# 2. Quét
SONAR_HOST_URL=http://localhost:9000 SONAR_TOKEN=... tool/sonar.sh
```

Plugin 0.5.2 đổ `NoClassDefFoundError` khi tự ghi lỗi phân tích trên
SonarQube 10+, nên `sonar-project.properties` tắt phần đó và `tool/sonar.sh`
nạp kết quả `flutter analyze` qua định dạng issue chung của Sonar.

Lần quét gần nhất: coverage **95,6%**, 0 bug, 0 lỗ hổng, 0 code smell,
0% trùng lặp, quality gate **OK**.
