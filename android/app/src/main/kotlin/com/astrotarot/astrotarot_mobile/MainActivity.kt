package com.astrotarot.astrotarot_mobile

import android.content.pm.ApplicationInfo
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Cổng đọc `extras` của intent mở app, để thử bốn vai trò cùng lúc.
 *
 * ## Vì sao cần
 *
 * Token nằm trong Keystore, khoá theo tên gói, nên MỘT bản cài chỉ giữ được
 * MỘT phiên. Muốn xem khách đặt lịch rồi Reader nhận ở màn bên cạnh thì phải
 * có bốn máy ảo, mỗi máy đăng nhập một vai trò.
 *
 * Trước đây script gõ hộ bằng `adb shell input tap` theo toạ độ cố định. Cách
 * ấy hỏng bất cứ khi nào bố cục xê dịch, độ phân giải khác đi, hay bàn phím
 * mở chậm hơn nửa giây — và khi hỏng thì nó gõ email vào chỗ trống chứ không
 * báo gì cả.
 *
 * `--dart-define` thì không dùng được: nó nướng thẳng vào apk, mà bốn vai trò
 * cần bốn giá trị khác nhau trên cùng một bản dựng.
 *
 * Intent extras là đúng chỗ: dựng apk MỘT lần, rồi mỗi máy mở bằng một lệnh
 * `am start` mang bộ đăng nhập riêng.
 *
 * ## Vì sao chặn ở bản phát hành
 *
 * Một đường cho phép đăng nhập bằng tham số dòng lệnh là một đường vòng qua
 * màn đăng nhập. Bản gỡ lỗi thì chấp nhận được — máy ảo của người làm. Bản
 * phát hành thì không, nên cờ `FLAG_DEBUGGABLE` chặn ngay tại đây, trước cả
 * khi Dart kịp hỏi. Phía Dart còn một lớp chặn nữa bằng `kDebugMode`.
 *
 * Dùng `FLAG_DEBUGGABLE` chứ không phải `BuildConfig.DEBUG`: từ AGP 8,
 * `BuildConfig` chỉ được sinh ra khi bật `buildFeatures { buildConfig = true }`,
 * mà bật nó lên chỉ để đọc một cờ thì không đáng — cờ này nằm sẵn trong
 * manifest đã cài, và chính là thứ quyết định bản ấy có gỡ lỗi được hay không.
 */
class MainActivity : FlutterActivity() {

    private val laBanGoLoi: Boolean
        get() = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "astrotarot/tu_dong_dang_nhap",
        ).setMethodCallHandler { call, ket ->
            if (call.method != "layThongTin") {
                ket.notImplemented()
                return@setMethodCallHandler
            }
            if (!laBanGoLoi) {
                ket.success(null)
                return@setMethodCallHandler
            }
            val email = intent?.getStringExtra("email")
            val matKhau = intent?.getStringExtra("matKhau")
            if (email.isNullOrBlank() || matKhau.isNullOrBlank()) {
                ket.success(null)
            } else {
                ket.success(mapOf("email" to email, "matKhau" to matKhau))
            }
        }
    }
}
