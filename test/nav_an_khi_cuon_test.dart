import 'package:astrotarot_mobile/features/shell/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/gia.dart';

/// Gửi một thông báo cuộn y như một danh sách thật gửi lên.
///
/// Đây là cách kiểm ĐÚNG thứ đang chạy: thông báo đi qua chính
/// `NotificationListener` của [HomeShell], chính hàm quyết định, rồi tới
/// chính `SizeTransition` bọc thanh. Dựng lại một bản sao của cấu trúc ấy
/// trong test thì chỉ kiểm được bản sao — đổi cách nối trong khung thật mà
/// test vẫn xanh.
void baoCuon(
  WidgetTester tester, {
  required double dich,
  bool dangKeoTay = true,
  double daiCuonDuoc = 4000,
  double viTri = 800,
  double caoKhungNhin = 2000,
  Axis truc = Axis.vertical,
  int doSau = 0,
}) {
  final ctx = tester.element(find.byType(IndexedStack));
  ScrollUpdateNotification(
    metrics: FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: daiCuonDuoc,
      pixels: viTri,
      viewportDimension: caoKhungNhin,
      axisDirection: truc == Axis.vertical
          ? AxisDirection.down
          : AxisDirection.right,
      devicePixelRatio: 1,
    ),
    context: ctx,
    scrollDelta: dich,
    dragDetails: dangKeoTay
        ? DragUpdateDetails(
            globalPosition: Offset.zero,
            delta: Offset(0, -dich),
          )
        : null,
    depth: doSau,
  ).dispatch(ctx);
}

/// Đẩy khung cho tới khi hoạt ảnh của thanh chạy xong.
///
/// KHÔNG dùng `pumpAndSettle`: các màn trong khung có vòng quay tải chạy
/// không ngừng (máy chủ giả không khai route cho chúng), nên `pumpAndSettle`
/// chờ mãi rồi hết giờ. Hoạt ảnh của thanh dài nhất 220ms, đẩy quá lên một
/// chút là chắc chắn xong.
Future<void> xongHoatAnh(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Bề cao thanh điều hướng đang CHIẾM trên màn, kể cả phần đã bị cắt đi.
double caoThanh(WidgetTester tester) =>
    tester.getSize(find.byType(SizeTransition)).height;

void main() {
  group('thanh điều hướng ẩn khi cuộn', () {
    testWidgets('cuộn xuống thì thanh đi khuất, cuộn lên thì trở lại', (
      tester,
    ) async {
      final m = MoiTruong(user: nguoiDung());
      await m.dung(tester, const HomeShell());

      final banDau = caoThanh(tester);
      expect(banDau, greaterThan(0), reason: 'lúc mở app thanh phải hiện');

      baoCuon(tester, dich: 40);
      await xongHoatAnh(tester);
      expect(
        caoThanh(tester),
        lessThan(1),
        reason: 'cuộn xuống thì thanh phải khuất hẳn',
      );

      baoCuon(tester, dich: -40);
      await xongHoatAnh(tester);
      expect(
        caoThanh(tester),
        banDau,
        reason: 'cuộn lên thì thanh phải về đúng chỗ cũ',
      );
    });

    testWidgets('thanh đi khuất dần chứ không biến mất một nhát', (
      tester,
    ) async {
      final m = MoiTruong(user: nguoiDung());
      await m.dung(tester, const HomeShell());
      final banDau = caoThanh(tester);

      baoCuon(tester, dich: 40);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final giua = caoThanh(tester);

      // Biến mất một nhát thì người dùng không thấy nó đi đâu, và lúc nó
      // quay lại thì giật lên như một lỗi vẽ.
      expect(giua, lessThan(banDau));
      expect(giua, greaterThan(0));

      await xongHoatAnh(tester);
    });

    testWidgets('vuốt ngang băng chuyền không đụng tới thanh', (tester) async {
      final m = MoiTruong(user: nguoiDung());
      await m.dung(tester, const HomeShell());
      final banDau = caoThanh(tester);

      baoCuon(tester, dich: 40, truc: Axis.horizontal);
      await xongHoatAnh(tester);
      expect(caoThanh(tester), banDau);
    });

    testWidgets('trang ngắn thì thanh không bao giờ đi đâu', (tester) async {
      final m = MoiTruong(user: nguoiDung());
      await m.dung(tester, const HomeShell());
      final banDau = caoThanh(tester);

      baoCuon(tester, dich: 40, daiCuonDuoc: 40);
      await xongHoatAnh(tester);
      expect(caoThanh(tester), banDau);
    });

    testWidgets('DỰNG LẠI NGÕ CỤT: giấu rồi về đầu danh sách thì hiện lại', (
      tester,
    ) async {
      // Trên máy thật, đây là lúc app mất hẳn đường chuyển tab: thanh đang
      // giấu, danh sách đã về đầu, kéo xuống thì ClampingScrollPhysics không
      // cho nội dung nhúc nhích nên KHÔNG thông báo nào được phát nữa.
      final m = MoiTruong(user: nguoiDung());
      await m.dung(tester, const HomeShell());
      final banDau = caoThanh(tester);

      baoCuon(tester, dich: 40);
      await xongHoatAnh(tester);
      expect(caoThanh(tester), lessThan(1), reason: 'phải giấu trước đã');

      // Cú cuộn đưa danh sách về đầu. Ngón tay đã nhấc, không còn dịch
      // chuyển — chỉ còn mỗi vị trí nói lên điều gì.
      baoCuon(tester, dich: 0, viTri: 0, dangKeoTay: false);
      await xongHoatAnh(tester);
      expect(caoThanh(tester), banDau);
    });

    testWidgets('đổi tab thì thanh hiện lại', (tester) async {
      final m = MoiTruong(user: nguoiDung());
      await m.dung(tester, const HomeShell());
      final banDau = caoThanh(tester);

      baoCuon(tester, dich: 40);
      await xongHoatAnh(tester);
      expect(caoThanh(tester), lessThan(1));

      // Giấu rồi mà không trả lại khi đổi tab thì người dùng sang màn mới
      // không còn đường nào đi tiếp — phải cuộn lên mới lấy lại được thanh,
      // mà màn mới có khi chẳng có gì để cuộn.
      //
      // Thanh đang khuất nên không bấm vào được; gọi thẳng như lúc người
      // dùng vừa bấm xong, tức là đúng nhánh mã mà cú bấm chạy vào.
      final nav = tester.widget<NavigationBar>(find.byType(NavigationBar));
      nav.onDestinationSelected!(1);
      await xongHoatAnh(tester);

      expect(caoThanh(tester), banDau);
    });
  });
}
