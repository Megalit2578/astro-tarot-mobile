// Màn Gói AI: hai lối mua (Google Play trên Android, ví ở nơi khác) và luật
// chặn mua trùng gói.
//
// Luật chặn phải test cho chắc: đường Google không chặn được ở máy chủ nữa —
// lúc máy chủ biết chuyện thì Google đã trừ tiền khách rồi — nên app cho bấm
// sai một lần là khách mất tiền thật.
//
// Hai điều phải biết trước khi đọc:
//
// 1. Trong widget test, `defaultTargetPlatform` là ANDROID. Màn này đi đường
//    Google Play theo đúng cờ ấy, nên test đường ví phải tự đổi nền tảng.
// 2. Lời gọi sang plugin in_app_purchase không bao giờ trả lời trong widget
//    test (không có máy thật đầu bên kia), nên `sanPhamGoogleProvider` được
//    thay bằng giá giả thay vì để nó treo ở trạng thái đang tải.

import 'package:astrotarot_mobile/features/goiai/goi_ai_screen.dart';
import 'package:astrotarot_mobile/features/goiai/google_billing.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'support/gia.dart';

/// Một gói đang bán, dạng JSON như máy chủ trả.
Map<String, dynamic> goi({
  required String id,
  required String ten,
  String loai = 'DAY_PASS',
  int gia = 15000,
  int hanMuc = 10,
  int soNgay = 1,
  String? maGoogle,
}) => {
  'id': id,
  'name': ten,
  'planType': loai,
  'price': gia,
  'dailyQuota': hanMuc,
  'durationDays': soNgay,
  'googlePlayProductId': maGoogle,
};

/// Một lượt mua, mặc định là còn hiệu lực.
Map<String, dynamic> daMua({
  required String maGoi,
  required String ten,
  int gia = 15000,
  int hanMuc = 10,
  int conNgay = 5,
}) => {
  'id': 'mua-$maGoi',
  'planId': maGoi,
  'planNameSnapshot': ten,
  'dailyQuotaSnapshot': hanMuc,
  'priceSnapshot': gia,
  'startAt': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
  'endAt': DateTime.now().add(Duration(days: conNgay)).toIso8601String(),
  'status': 'ACTIVE',
  'purchaseType': 'WALLET',
};

/// Giá giả từ Google, tra theo mã sản phẩm.
List<dynamic> giaGoogle(Map<String, String> bang) => [
  sanPhamGoogleProvider.overrideWith(
    (_) async => {
      for (final e in bang.entries)
        e.key: ProductDetails(
          id: e.key,
          title: e.key,
          description: '',
          price: e.value,
          rawPrice: 0,
          currencyCode: 'VND',
        ),
    },
  ),
];

/// Chạy [than] như thể đang ở máy tính, để màn đi đường mua bằng ví.
///
/// Trả cờ về chỗ cũ trong `finally` chứ không dùng `addTearDown`: dọn sau
/// thì muộn — flutter_test kiểm "có biến debug nào bị đổi mà chưa trả lại
/// không" ngay khi thân test vừa xong, trước lúc tearDown chạy.
Future<void> nhuMayTinh(Future<void> Function() than) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  try {
    await than();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  group('Màn Gói AI', () {
    late MoiTruong mt;

    setUp(() {
      mt = MoiTruong(user: nguoiDung());
      mt.mayChu.tra('GET /api/v1/wallet/me', {'id': 'vi-1', 'balance': 500000});
      mt.mayChu.tra('GET /api/v1/wallet/transactions', []);
      mt.mayChu.tra('GET /api/admin/subscriptions/users/*/ai-usage', []);
      mt.mayChu.tra('POST /api/admin/subscriptions/purchase', {'id': 'mua-1'});
    });

    void banMotGoi({String? maGoogle = 'ai_basic_1d'}) {
      mt.mayChu.tra('GET /api/admin/subscriptions/plans/active', [
        goi(id: 'g1', ten: 'Basic 1 ngày', maGoogle: maGoogle),
      ]);
    }

    void daMuaNhung(List<Map<String, dynamic>> ds) {
      mt.mayChu.tra(
        'GET /api/admin/subscriptions/users/*/purchases/active',
        ds,
      );
    }

    testWidgets('trên Android: hiện giá của Google, không hiện giá máy chủ', (
      tester,
    ) async {
      // Google bắt hiện đúng con số thư viện trả về. Giá trên app cao hơn giá
      // web vì Google thu hoa hồng mỗi lượt mua, nên lấy nhầm giá máy chủ là
      // hứa với khách một con số rồi Google tính con số khác.
      banMotGoi();
      daMuaNhung([]);

      await mt.dung(
        tester,
        const GoiAiScreen(),
        them: giaGoogle({'ai_basic_1d': '19.000₫'}),
      );

      expect(find.text('19.000₫'), findsOneWidget);
      expect(find.text('15.000 đ'), findsNothing);
      expect(find.text('Mua qua Google Play'), findsOneWidget);
      expect(find.text('Mua bằng ví'), findsNothing);
    });

    testWidgets(
      'trên Android: chưa khai sản phẩm thì khoá nút, KHÔNG quay về ví',
      (tester) async {
        // Chính sách của Google: nội dung số bán trong ứng dụng phải qua Play.
        // Lặng lẽ quay về ví là đường ngắn nhất tới việc bị gỡ app, nên ở đây
        // test đúng cái việc KHÔNG được xảy ra.
        banMotGoi();
        daMuaNhung([]);

        await mt.dung(tester, const GoiAiScreen(), them: giaGoogle({}));

        expect(find.text('Mua bằng ví'), findsNothing);
        expect(find.text('Chưa mở bán trong ứng dụng'), findsOneWidget);
        final nut = tester.widget<FilledButton>(
          find.ancestor(
            of: find.text('Chưa mở bán trong ứng dụng'),
            matching: find.byType(FilledButton),
          ),
        );
        expect(nut.onPressed, isNull);
        expect(
          mt.mayChu.goi.any((g) => g.duong.endsWith('/subscriptions/purchase')),
          isFalse,
        );
      },
    );

    testWidgets('ngoài Android: hiện giá máy chủ và mua bằng ví', (
      tester,
    ) async {
      await nhuMayTinh(() async {
        banMotGoi();
        daMuaNhung([]);

        await mt.dung(tester, const GoiAiScreen());

        expect(find.text('Mua bằng ví'), findsOneWidget);
        expect(find.text('15.000 đ'), findsOneWidget);

        await bam(tester, find.text('Mua bằng ví'));
        await bam(tester, find.text('Mua'));

        expect(
          mt.mayChu.goi.any(
            (g) =>
                g.phuongThuc == 'POST' &&
                g.duong.endsWith('/subscriptions/purchase'),
          ),
          isTrue,
        );
      });
    });

    testWidgets('đang dùng gói nào thì không mua lại gói ấy', (tester) async {
      banMotGoi();
      daMuaNhung([daMua(maGoi: 'g1', ten: 'Basic 1 ngày')]);

      await mt.dung(
        tester,
        const GoiAiScreen(),
        them: giaGoogle({'ai_basic_1d': '19.000₫'}),
      );

      expect(find.text('Bạn đang dùng gói này rồi.'), findsOneWidget);
      expect(find.text('Không mua được'), findsOneWidget);
      expect(find.text('Mua qua Google Play'), findsNothing);
    });

    testWidgets('gói tháng đang chạy: chặn gói đang dùng, mở gói cao hơn', (
      tester,
    ) async {
      mt.mayChu.tra('GET /api/admin/subscriptions/plans/active', [
        goi(
          id: 'thap',
          ten: 'Cơ bản tháng',
          loai: 'MONTHLY',
          gia: 99000,
          hanMuc: 20,
          soNgay: 30,
          maGoogle: 'ai_month_basic',
        ),
        goi(
          id: 'cao',
          ten: 'Pro tháng',
          loai: 'MONTHLY',
          gia: 199000,
          hanMuc: 50,
          soNgay: 30,
          maGoogle: 'ai_month_pro',
        ),
      ]);
      daMuaNhung([
        daMua(maGoi: 'thap', ten: 'Cơ bản tháng', gia: 99000, hanMuc: 20),
      ]);

      await mt.dung(
        tester,
        const GoiAiScreen(),
        them: giaGoogle({
          'ai_month_basic': '119.000₫',
          'ai_month_pro': '239.000₫',
        }),
      );

      expect(find.text('Bạn đang dùng gói này rồi.'), findsOneWidget);
      expect(find.text('Không mua được'), findsOneWidget);
      expect(find.text('Mua qua Google Play'), findsOneWidget);
    });

    testWidgets('gói tháng đang chạy: chặn gói tháng rẻ hơn', (tester) async {
      mt.mayChu.tra('GET /api/admin/subscriptions/plans/active', [
        goi(
          id: 're',
          ten: 'Tháng rẻ hơn',
          loai: 'MONTHLY',
          gia: 49000,
          hanMuc: 10,
          soNgay: 30,
          maGoogle: 'ai_month_basic',
        ),
        goi(
          id: 'dangchay',
          ten: 'Pro tháng',
          loai: 'MONTHLY',
          gia: 199000,
          hanMuc: 50,
          soNgay: 30,
          maGoogle: 'ai_month_pro',
        ),
      ]);
      daMuaNhung([
        daMua(maGoi: 'dangchay', ten: 'Pro tháng', gia: 199000, hanMuc: 50),
      ]);

      await mt.dung(
        tester,
        const GoiAiScreen(),
        them: giaGoogle({
          'ai_month_basic': '119.000₫',
          'ai_month_pro': '239.000₫',
        }),
      );

      expect(
        find.textContaining('Chỉ đổi lên được gói có hạn mức'),
        findsOneWidget,
      );
      expect(find.text('Mua qua Google Play'), findsNothing);
    });

    testWidgets('lượt mua đã hết hạn nhưng còn nhãn ACTIVE thì cho mua lại', (
      tester,
    ) async {
      // Máy chủ chỉ đổi nhãn sang EXPIRED khi có việc chạy qua, nên một lượt
      // đã qua mốc hết hạn vẫn về với status ACTIVE. Xem nhãn thôi là khoá
      // luôn lối mua của khách đã hết gói.
      banMotGoi();
      daMuaNhung([daMua(maGoi: 'g1', ten: 'Basic 1 ngày', conNgay: -3)]);

      await mt.dung(
        tester,
        const GoiAiScreen(),
        them: giaGoogle({'ai_basic_1d': '19.000₫'}),
      );

      expect(find.text('Bạn đang dùng gói này rồi.'), findsNothing);
      expect(find.text('Mua qua Google Play'), findsOneWidget);
    });

    testWidgets('gói chưa khai mã Google thì không lấy giá của gói khác', (
      tester,
    ) async {
      banMotGoi(maGoogle: null);
      daMuaNhung([]);

      await mt.dung(
        tester,
        const GoiAiScreen(),
        them: giaGoogle({'ai_basic_1d': '19.000₫'}),
      );

      expect(find.text('Chưa mở bán trong ứng dụng'), findsOneWidget);
      expect(find.text('19.000₫'), findsNothing);
      // Rơi về giá máy chủ để khách vẫn thấy gói đáng bao nhiêu.
      expect(find.text('15.000 đ'), findsOneWidget);
    });
  });
}
