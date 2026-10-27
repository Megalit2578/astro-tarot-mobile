import 'package:astrotarot_mobile/features/bookings/lich_va_danh_sach.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/gia.dart';

/// Lịch tháng thu lại khi cuộn danh sách.
///
/// Đáng kiểm vì nó là một quy tắc về THỜI ĐIỂM, không phải về hình thức:
/// thu quá sớm thì lịch chớp tắt theo mỗi lần nhích ngón tay, mở lại quá sớm
/// thì danh sách nhảy xuống dưới tay người đang đọc. Nhìn ảnh chụp không
/// phát hiện được cả hai.
void main() {
  /// Dựng lịch + một danh sách đủ dài để cuộn.
  Future<void> dung(WidgetTester t) async {
    final m = MoiTruong();
    m.mayChu.tra('GET /api/v1/bookings/me/calendar', []);
    m.mayChu.tra('GET /api/v1/bookings/reader/calendar', []);
    await m.dung(
      t,
      LichVaDanhSach(
        cuaReader: false,
        danhSach: ListView(
          children: [for (var i = 0; i < 40; i++) SizedBox(height: 60, child: Text('dong $i'))],
        ),
      ),
    );
  }

  bool coLuoi(WidgetTester t) => find.text('Thu gọn lịch').evaluate().isNotEmpty;

  testWidgets('mặc định bày cả lưới tháng', (t) async {
    await dung(t);
    expect(coLuoi(t), isTrue);
  });

  /// Nhích một chút KHÔNG được thu: chạm rồi xê dịch vài pixel là chuyện
  /// thường, và lịch chớp tắt theo mỗi lần nhích thì khó chịu hơn hẳn so với
  /// việc nó đứng yên.
  testWidgets('nhích nhẹ thì lịch vẫn mở', (t) async {
    await dung(t);
    await t.drag(find.text('dong 1'), const Offset(0, -10));
    await t.pump(const Duration(milliseconds: 300));
    expect(coLuoi(t), isTrue);
  });

  testWidgets('cuộn xuống hẳn thì lịch thu thành một dòng', (t) async {
    await dung(t);
    await t.drag(find.text('dong 1'), const Offset(0, -220));
    await t.pumpAndSettle();
    expect(coLuoi(t), isFalse);
    // Thu chứ KHÔNG biến mất: tháng đang xem vẫn phải đọc được.
    expect(find.textContaining('Tháng '), findsOneWidget);
  });

  testWidgets('bấm dòng tóm tắt thì lịch mở lại', (t) async {
    await dung(t);
    await t.drag(find.text('dong 1'), const Offset(0, -220));
    await t.pumpAndSettle();
    expect(coLuoi(t), isFalse);

    await t.tap(find.textContaining('Tháng '));
    await t.pumpAndSettle();
    expect(coLuoi(t), isTrue);
  });
}
