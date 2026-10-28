import 'package:astrotarot_mobile/features/shell/y_nav_cuon.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/widgets.dart' show Axis;
import 'package:flutter_test/flutter_test.dart';

/// Một trang dài bình thường, đủ điều kiện cho thanh được giấu.
YNav goi({
  bool laCuaNguoiDung = true,
  int doSau = 0,
  Axis truc = Axis.vertical,
  double daiCuonDuoc = 2000,
  ScrollDirection huong = ScrollDirection.reverse,
}) => yNavTuCuon(
  laCuaNguoiDung: laCuaNguoiDung,
  doSau: doSau,
  truc: truc,
  daiCuonDuoc: daiCuonDuoc,
  huong: huong,
);

void main() {
  group('yNavTuCuon', () {
    test('cuộn xuống thì giấu, cuộn lên thì hiện', () {
      expect(goi(huong: ScrollDirection.reverse), YNav.giau);
      expect(goi(huong: ScrollDirection.forward), YNav.hien);
    });

    test('đứng yên thì không đụng tới thanh', () {
      // Mỗi lần cuộn kết thúc đều sinh một thông báo `idle`. Coi nó là lệnh
      // hiện thì thanh bật lại ngay khi người dùng nhấc tay — tức là không
      // bao giờ giấu được quá nửa giây.
      expect(goi(huong: ScrollDirection.idle), YNav.giuNguyen);
    });

    test('cuộn do mã gọi thì bỏ qua', () {
      // Bàn phím đẩy ô nhập lên cũng cuộn. Đếm nó là người dùng gõ một chữ
      // thì thanh dưới biến mất.
      expect(goi(laCuaNguoiDung: false), YNav.giuNguyen);
    });

    test('băng chuyền ngang không làm thanh biến mất', () {
      // Trang chủ có băng chuyền Reader vuốt ngang.
      expect(goi(truc: Axis.horizontal), YNav.giuNguyen);
    });

    test('danh sách lồng bên trong không được quyết', () {
      expect(goi(doSau: 1), YNav.giuNguyen);
      expect(goi(doSau: 2), YNav.giuNguyen);
    });

    test('trang ngắn thì luôn hiện, kể cả đang cuộn xuống', () {
      expect(goi(daiCuonDuoc: 0), YNav.hien);
      expect(goi(daiCuonDuoc: duDaiDeGiau - 1), YNav.hien);
      // Ngay tại ngưỡng thì đã được giấu.
      expect(goi(daiCuonDuoc: duDaiDeGiau), YNav.giau);
    });

    test('trang ngắn thắng cả hướng cuộn, nhưng thua các bộ lọc trước nó', () {
      // Thứ tự các bộ lọc là một quyết định, không phải ngẫu nhiên: một cú
      // vuốt ngang trên trang ngắn KHÔNG được trả về `hien`, vì nó không nói
      // gì về trang cả. Đảo thứ tự hai dòng ấy trong hàm là test này đỏ.
      expect(
        goi(truc: Axis.horizontal, daiCuonDuoc: 0),
        YNav.giuNguyen,
      );
      expect(
        goi(laCuaNguoiDung: false, daiCuonDuoc: 0),
        YNav.giuNguyen,
      );
    });

    test('không có tổ hợp nào ném lỗi', () {
      for (final nd in [true, false]) {
        for (final sau in [0, 1]) {
          for (final truc in Axis.values) {
            for (final dai in [0.0, 100.0, 5000.0]) {
              for (final h in ScrollDirection.values) {
                expect(
                  () => yNavTuCuon(
                    laCuaNguoiDung: nd,
                    doSau: sau,
                    truc: truc,
                    daiCuonDuoc: dai,
                    huong: h,
                  ),
                  returnsNormally,
                );
              }
            }
          }
        }
      }
    });
  });
}
