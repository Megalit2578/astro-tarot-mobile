# Khoá ký bản phát hành Android

CH Play từ chối mọi bản ký bằng **khoá gỡ lỗi**. Khoá ấy do Android SDK phát,
máy nào cũng có y hệt, nên nó không chứng minh được bản cài đặt này do ai làm
ra. Trước 05/10/2026 `build.gradle.kts` để nguyên mẫu Flutter sinh ra:

```kotlin
// TODO: Add your own signing config for the release build.
signingConfig = signingConfigs.getByName("debug")
```

Giờ nó đọc khoá thật từ `android/key.properties`. Chưa có tệp đó thì bản
release vẫn dựng được bằng khoá gỡ lỗi để chạy thử ở máy, nhưng log build in
một dòng cảnh báo và **bản ấy không nộp lên CH Play được**.

## Đọc phần này trước khi tạo khoá

**Mất khoá là mất luôn ứng dụng.** CH Play nhận bản cập nhật chỉ khi nó được ký
bằng đúng khoá của bản trước. Mất khoá thì không cập nhật được nữa, phải đăng
một ứng dụng MỚI với tên gói khác, và toàn bộ người đã cài ở lại bản cũ vĩnh
viễn. Không có cách khôi phục, kể cả nhờ Google.

Nên ngay sau khi tạo: chép `astrotarot.jks` và mật khẩu ra **ít nhất hai nơi**
ngoài máy này, và cho người khác trong nhóm giữ một bản. Đừng để mỗi mình một
máy giữ.

> Bật **Play App Signing** lúc đăng ký ứng dụng thì Google giữ khoá phát hành
> hộ, còn khoá này chỉ còn là khoá *tải lên*. Mất khoá tải lên thì xin cấp lại
> được. Nên bật, và vẫn giữ bản sao.

## Tạo khoá

Chạy ở thư mục `android/`. `keytool` nằm trong JDK của Android Studio:

```bash
"C:\Users\LENOVO\Android\android-studio\jbr\bin\keytool.exe" -genkeypair -v -keystore astrotarot.jks -keyalg RSA -keysize 2048 -validity 10000 -alias astrotarot
```

Nó sẽ hỏi mật khẩu rồi hỏi tên, đơn vị, thành phố. Hạn 10000 ngày là theo
khuyến nghị của Google: khoá hết hạn trước ứng dụng thì cũng kẹt như mất khoá.

## Khai báo

Tạo `android/key.properties` — tệp này **đã nằm trong .gitignore**, đừng commit:

```properties
storePassword=<mật khẩu kho khoá vừa đặt>
keyPassword=<mật khẩu khoá vừa đặt>
keyAlias=astrotarot
storeFile=astrotarot.jks
```

`storeFile` tính từ thư mục `android/`.

## Dựng bản nộp lên

```bash
flutter build appbundle --release
```

Kết quả ở `build/app/outputs/bundle/release/app-release.aab`. CH Play nhận
`.aab` chứ không nhận `.apk` cho ứng dụng mới.

Kiểm đã ký đúng khoá chưa:

```bash
"C:\Users\LENOVO\Android\android-studio\jbr\bin\keytool.exe" -printcert -jarfile build\app\outputs\bundle\release\app-release.aab
```

Dòng `Owner:` phải ra tên bạn đã khai, không phải `CN=Android Debug`.
