import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/auth/auth_controller.dart';

/// Mua gói AI qua Google Play.
///
/// VÌ SAO KHÔNG DÙNG VÍ NỮA TRÊN ANDROID: chính sách Thanh toán của Google
/// xếp gói cước nội dung số dùng trong ứng dụng vào diện BẮT BUỘC dùng hệ
/// thống thanh toán của Play, và Việt Nam không nằm trong chương trình
/// thanh toán thay thế nào. Buổi xem với Reader thì khác — dịch vụ một-kèm-
/// một giữa hai cá nhân, Google miễn trừ — nên phần ấy vẫn đi PayOS.
///
/// Giá hiển thị LẤY TỪ GOOGLE, không lấy từ máy chủ mình: Google bắt hiện
/// đúng giá thư viện trả về (đúng tiền tệ và thuế của từng nước), và giá ấy
/// chỉnh ở Play Console.
class GoogleBilling {
  GoogleBilling(this._api);

  final ApiClient _api;

  /// Lấy muộn, không giữ trong trường khởi tạo: máy nào không đăng ký
  /// Play Billing thì chỉ chỗ nào thật sự dùng mới hỏng, chứ không hỏng ngay
  /// lúc dựng provider và đổ cả màn gói.
  InAppPurchase get _iap => InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _theo;

  /// Mã sản phẩm đã khai trong Play Console, khớp cột
  /// `subscription_plan.google_play_product_id` ở máy chủ.
  static const maSanPham = <String>{
    'ai_basic_1d',
    'ai_combo_3d',
    'ai_vip_7d',
    'ai_month_basic',
    'ai_month_pro',
  };

  /// Báo cho giao diện biết một lượt mua vừa xong (hoặc hỏng).
  final _ketQua = StreamController<KetQuaMua>.broadcast();
  Stream<KetQuaMua> get ketQua => _ketQua.stream;

  bool _daMo = false;

  /// Bật lắng nghe. Gọi một lần, sớm — ngay khi mở màn gói.
  ///
  /// Phải lắng nghe TRƯỚC khi mua: luồng mua của Google có thể trả kết quả
  /// sau khi app đã bị hệ điều hành thu hồi và mở lại, lúc ấy kết quả về qua
  /// stream này chứ không về chỗ gọi `mua()`.
  /// Đồng bộ có chủ đích: gọi là lắng nghe xong ngay.
  ///
  /// Để `async` thì lỗi lúc đăng ký lọt ra future mà không ai bắt, và chỗ gọi
  /// có `try` cũng không đỡ được.
  void mo() {
    if (_daMo) return;
    _daMo = true;
    _theo = _iap.purchaseStream.listen(
      _xuLy,
      onError: (Object e) => _ketQua.add(KetQuaMua.loi('$e')),
    );
  }

  Future<void> dong() async {
    await _theo?.cancel();
    _theo = null;
    _daMo = false;
  }

  /// Máy này có dùng được thanh toán trong ứng dụng không.
  ///
  /// Máy không có Google Play (một số máy Trung Quốc, bản dựng không có
  /// dịch vụ Google) thì trả về false, và giao diện phải nói rõ thay vì để
  /// nút mua bấm vào không ăn.
  Future<bool> dungDuoc() async {
    try {
      return await _iap.isAvailable();
    } catch (_) {
      // Bản dựng không có plugin (chạy test, chạy trên nền tảng khác): coi
      // như không mua được, đừng để lỗi nổ lên giao diện.
      return false;
    }
  }

  /// Hỏi Google giá và mô tả của từng gói.
  ///
  /// Mã nào Play Console chưa khai sẽ nằm trong `notFoundIDs` và bị bỏ qua —
  /// đó là chuyện thường gặp lúc mới dựng, nên không ném lỗi.
  Future<List<ProductDetails>> taiSanPham() async {
    final r = await _iap.queryProductDetails(maSanPham);
    return r.productDetails;
  }

  /// Mở luồng thanh toán của Google.
  ///
  /// Trả về ngay sau khi mở, KHÔNG đợi mua xong: kết quả về qua [ketQua].
  Future<void> mua(ProductDetails sp) async {
    // buyConsumable chứ không phải buyNonConsumable: gói có thời hạn, hết
    // hạn thì khách mua lại được. Hàng không tiêu thụ thì Google coi là mua
    // một lần vĩnh viễn và chặn lần mua thứ hai.
    await _iap.buyConsumable(
      purchaseParam: PurchaseParam(productDetails: sp),
      // Tự tiêu thụ sau khi hoàn tất. Để false thì phải tự gọi, quên là
      // khách không mua lại được gói ấy nữa.
      autoConsume: true,
    );
  }

  Future<void> _xuLy(List<PurchaseDetails> ds) async {
    for (final p in ds) {
      switch (p.status) {
        case PurchaseStatus.pending:
          _ketQua.add(KetQuaMua.dangCho());

        case PurchaseStatus.error:
          _ketQua.add(
            KetQuaMua.loi(p.error?.message ?? 'Thanh toán không xong.'),
          );
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);

        case PurchaseStatus.canceled:
          _ketQua.add(KetQuaMua.huy());
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _doiLayGoi(p);
      }
    }
  }

  /// Gửi token lên máy chủ để đổi lấy gói.
  ///
  /// Máy chủ mới là chỗ hỏi Google xem lượt mua có thật không — app chỉ
  /// chuyển token. Tin app tự khai "tôi mua rồi" thì ai cũng tự cấp gói cho
  /// mình được.
  Future<void> _doiLayGoi(PurchaseDetails p) async {
    try {
      await _api.post(
        Endpoints.googlePlayDoiGoi,
        body: {
          'productId': p.productID,
          'purchaseToken': p.verificationData.serverVerificationData,
        },
      );
      _ketQua.add(KetQuaMua.xong());

      // completePurchase SAU KHI máy chủ cấp gói xong.
      //
      // Gọi trước thì gặp lúc mạng rớt giữa chừng là mất luôn: Google coi
      // như đã giao hàng và không phát lại, còn máy chủ thì chưa cấp gì.
      if (p.pendingCompletePurchase) await _iap.completePurchase(p);
    } catch (e) {
      // KHÔNG completePurchase ở đây. Để nguyên thì lần mở app sau Google
      // phát lại lượt mua này và thử đổi lại — đó chính là cách khách lấy
      // được gói khi mạng hỏng đúng lúc.
      _ketQua.add(
        KetQuaMua.loi(
          e is ApiException
              ? e.message
              : 'Chưa cấp được gói. Mở lại app để thử lại.',
        ),
      );
    }
  }
}

/// Kết quả một lượt mua, để giao diện hiển thị.
class KetQuaMua {
  const KetQuaMua._(this.loai, [this.thongBao]);

  factory KetQuaMua.dangCho() => const KetQuaMua._(LoaiKetQua.dangCho);
  factory KetQuaMua.xong() => const KetQuaMua._(LoaiKetQua.xong);
  factory KetQuaMua.huy() => const KetQuaMua._(LoaiKetQua.huy);
  factory KetQuaMua.loi(String m) => KetQuaMua._(LoaiKetQua.loi, m);

  final LoaiKetQua loai;
  final String? thongBao;
}

enum LoaiKetQua { dangCho, xong, huy, loi }

final googleBillingProvider = Provider<GoogleBilling>((ref) {
  final b = GoogleBilling(ref.watch(apiClientProvider));
  ref.onDispose(b.dong);
  return b;
});

/// Nền tảng này có phải đi qua Google Play không.
///
/// Chỉ Android: bản chạy trên máy tính lúc phát triển và máy ảo web không có
/// Play Billing, kiểm bằng cờ này thì chúng vẫn mua được bằng ví như cũ thay
/// vì gặp một nút bấm không ăn.
bool get nenDungGooglePlay =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Giá và tên gói do Google trả về, tra theo mã sản phẩm.
///
/// Rỗng nghĩa là không mua được trong ứng dụng: máy không có Google Play, hoặc
/// Play Console chưa khai sản phẩm nào. Giao diện phải nói rõ lý do đó chứ
/// không được lặng lẽ quay về mua bằng ví — chính sách của Google không cho
/// bán nội dung số trong ứng dụng bằng cổng khác.
final sanPhamGoogleProvider = FutureProvider<Map<String, ProductDetails>>((
  ref,
) async {
  if (!nenDungGooglePlay) return const {};
  final b = ref.watch(googleBillingProvider);
  if (!await b.dungDuoc()) return const {};
  b.mo();
  final ds = await b.taiSanPham();
  return {for (final p in ds) p.id: p};
});

/// Mã gói đang chờ Google trả kết quả.
///
/// Để ở ngoài widget vì kết quả KHÔNG về chỗ gọi `mua()`: nó về qua stream, và
/// có thể về sau khi hệ điều hành đã thu hồi app rồi mở lại — lúc ấy thẻ gói
/// cũ không còn tồn tại để tự tắt trạng thái của mình.
/// Dùng Notifier chứ không phải StateProvider: Riverpod 3 đã bỏ hẳn
/// StateProvider.
class DangMuaGoogle extends Notifier<String?> {
  @override
  String? build() => null;

  void dat(String? maGoi) => state = maGoi;
}

final dangMuaGoogleProvider = NotifierProvider<DangMuaGoogle, String?>(
  DangMuaGoogle.new,
);
