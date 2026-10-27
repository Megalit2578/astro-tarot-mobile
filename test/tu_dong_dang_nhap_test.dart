import 'dart:async';

import 'package:astrotarot_mobile/core/auth/tu_dong_dang_nhap.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bộ đăng nhập mà máy ảo được mở kèm theo.
///
/// Đáng kiểm vì đây là một đường VÒNG QUA màn đăng nhập. Nó chỉ được phép
/// tồn tại ở bản gỡ lỗi, và chỉ khi intent mang đủ cả hai giá trị — thiếu một
/// nửa mà vẫn trả về thì tầng trên sẽ gọi `dangNhap` với chuỗi rỗng.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Dựng một cổng giả trả về đúng thứ mình đặt, không cần máy Android nào.
  DocBoDangNhapThu doc(Object? tra, {List<String>? goi}) {
    const kenh = MethodChannel('astrotarot/tu_dong_dang_nhap');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(kenh, (call) async {
      goi?.add(call.method);
      if (tra is Exception) throw tra;
      return tra;
    });
    return const DocBoDangNhapThu(kenh);
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('astrotarot/tu_dong_dang_nhap'),
      null,
    );
  });

  test('đủ email và mật khẩu thì đọc được', () async {
    final goi = <String>[];
    final ra = await doc(
      {'email': 'a@b.com', 'matKhau': '12345678'},
      goi: goi,
    ).doc();

    expect(ra, const BoDangNhapThu(email: 'a@b.com', matKhau: '12345678'));
    expect(goi, ['layThongTin']);
  });

  test('intent không mang gì thì trả null', () async {
    expect(await doc(null).doc(), isNull);
  });

  test('thiếu một nửa thì coi như không có', () async {
    expect(await doc({'email': 'a@b.com'}).doc(), isNull);
    expect(await doc({'matKhau': '12345678'}).doc(), isNull);
  });

  test('giá trị rỗng cũng coi như không có', () async {
    expect(await doc({'email': '', 'matKhau': '12345678'}).doc(), isNull);
    expect(await doc({'email': 'a@b.com', 'matKhau': ''}).doc(), isNull);
  });

  /// iOS, máy thật chưa cài bản gỡ lỗi, hay chính bộ test — không có cổng nào
  /// trả lời. Đó là trạng thái bình thường chứ không phải lỗi, nên không được
  /// ném ngược lên màn khởi động.
  test('không có cổng nào trả lời thì trả null chứ không ném', () async {
    expect(
      await doc(MissingPluginException('khong co cong')).doc(),
      isNull,
    );
  });

  test('cổng ném lỗi nền tảng thì cũng trả null', () async {
    expect(await doc(PlatformException(code: 'hong')).doc(), isNull);
  });

  /// Chỗ dễ sai nhất, và đã sai thật một lần.
  ///
  /// Ở nơi KHÔNG có đầu nhận bên kia — `flutter test`, iOS, bản chưa cài
  /// native — lời gọi kênh không ném lỗi mà im lặng không bao giờ hồi đáp.
  /// Thiếu hạn chờ thì `khoiDong()` kẹt lại, `state` không bao giờ chuyển
  /// sang `chuaDangNhap`, và app đứng ở vòng quay khởi động. Dấu hiệu lúc ấy
  /// là "không tìm thấy màn đăng nhập" — không hề giống một lời gọi bị treo.
  test('cổng không bao giờ trả lời thì bỏ qua, không treo', () async {
    const kenh = MethodChannel('astrotarot/tu_dong_dang_nhap');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(kenh, (call) => Completer<Object?>().future);

    final ra = await const DocBoDangNhapThu(kenh)
        .doc()
        .timeout(const Duration(seconds: 5));

    expect(ra, isNull);
  });
}
