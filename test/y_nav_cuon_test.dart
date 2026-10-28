import 'package:astrotarot_mobile/features/shell/y_nav_cuon.dart';
import 'package:flutter/widgets.dart' show Axis;
import 'package:flutter_test/flutter_test.dart';

/// Màn điện thoại thật: cao 2400, khung nhìn còn chừng này sau thanh trên dưới.
const double man = 2000;

/// Một danh sách dài bình thường, ngón tay đang kéo, đang ở giữa danh sách.
YNav goi({
  bool dangKeoTay = true,
  int doSau = 0,
  Axis truc = Axis.vertical,
  double daiCuonDuoc = 4000,
  double caoKhungNhin = man,
  double viTri = 800,
  double dich = 30,
}) => yNavTuCuon(
  dangKeoTay: dangKeoTay,
  doSau: doSau,
  truc: truc,
  daiCuonDuoc: daiCuonDuoc,
  caoKhungNhin: caoKhungNhin,
  viTri: viTri,
  dich: dich,
);

void main() {
  group('yNavTuCuon', () {
    test('kéo nội dung lên thì giấu, kéo xuống thì hiện', () {
      expect(goi(dich: 30), YNav.giau);
      expect(goi(dich: -30), YNav.hien);
    });

    test('đứng yên thì không đụng tới thanh', () {
      expect(goi(dich: 0), YNav.giuNguyen);
    });

    group('vùng chết', () {
      test('DỰNG LẠI LỖI THẬT: nhiễu nửa pixel cuối cú kéo', () {
        // Đo bằng log trên máy thật 29/10/2026: cuối MỖI cú kéo xuống đều có
        // đúng một nhiễu +0,5 ngược chiều. Không có vùng chết thì nó là lệnh
        // cuối cùng tới tay thanh, và thanh luôn làm ngược điều người dùng
        // vừa làm — nhìn từ ngoài y hệt lỗi nảy-ở-biên, nên dễ tưởng đã sửa.
        expect(goi(dich: 0.5), YNav.giuNguyen);
        expect(goi(dich: -0.5), YNav.giuNguyen);
      });

      test('kéo chưa đủ xa thì chưa đổi', () {
        expect(goi(dich: nguongDich - 0.1), YNav.giuNguyen);
        expect(goi(dich: -(nguongDich - 0.1)), YNav.giuNguyen);
      });

      test('vừa đủ ngưỡng thì đổi', () {
        expect(goi(dich: nguongDich), YNav.giau);
        expect(goi(dich: -nguongDich), YNav.hien);
      });

      test('ngưỡng phải đủ nhỏ để một cú kéo thật chạm tới ngay', () {
        // Kéo thật cho 3–10 điểm mỗi khung hình. Ngưỡng cao hơn thế thì
        // người dùng kéo mà thanh không nhúc nhích.
        expect(nguongDich, lessThanOrEqualTo(10));
        // Và đủ lớn để nhiễu dưới một pixel không bao giờ chạm tới.
        expect(nguongDich, greaterThan(1));
      });
    });

    test('băng chuyền ngang không làm thanh biến mất', () {
      // Trang chủ có băng chuyền Reader vuốt ngang.
      expect(goi(truc: Axis.horizontal), YNav.giuNguyen);
    });

    test('danh sách lồng bên trong không được quyết', () {
      expect(goi(doSau: 1), YNav.giuNguyen);
      expect(goi(doSau: 2), YNav.giuNguyen);
    });

    group('danh sách ngắn thì luôn hiện', () {
      test('thừa ít hơn ngưỡng thì không bao giờ giấu', () {
        expect(goi(daiCuonDuoc: 0), YNav.hien);
        expect(goi(daiCuonDuoc: man * tiLeDuDaiDeGiau - 1), YNav.hien);
      });

      test('vừa đủ ngưỡng thì đã được giấu', () {
        expect(goi(daiCuonDuoc: man * tiLeDuDaiDeGiau), YNav.giau);
      });

      test('ngưỡng phải lớn hơn chính chiều cao thanh', () {
        // Giấu thanh để giành 168px mà phần cuộn được còn ít hơn thế thì sau
        // khi giấu, nội dung vừa đủ một màn và hết chỗ cuộn — thanh chớp một
        // cái rồi hiện lại.
        const caoThanh = 168.0;
        expect(man * tiLeDuDaiDeGiau, greaterThan(caoThanh));
      });

      test('nhưng vẫn phải đủ thấp để các màn THẬT của app dùng được', () {
        // Đo trên máy thật 29/10/2026. Ngưỡng nửa màn từng làm cả tính năng
        // thành vô dụng vì không màn nào vượt nổi.
        expect(goi(daiCuonDuoc: 720, caoKhungNhin: man), YNav.giau,
            reason: 'tab Tài khoản — màn dài nhất của app');
        expect(goi(daiCuonDuoc: 400, caoKhungNhin: man), YNav.giau,
            reason: 'danh sách 5 Reader trên production');
      });
    });

    group('về đầu danh sách thì luôn hiện', () {
      test('ở đúng đầu', () {
        expect(goi(viTri: 0, dich: 30), YNav.hien);
      });

      test('đang kéo quá đầu (vị trí âm)', () {
        expect(goi(viTri: -50, dich: 30), YNav.hien);
      });

      test('DỰNG LẠI NGÕ CỤT: về đầu mà ngón tay đã nhấc', () {
        // Đây là chỗ app từng kẹt vĩnh viễn. Thanh đang giấu, danh sách đã về
        // đầu, người dùng kéo xuống để gọi thanh về — Android dùng
        // ClampingScrollPhysics nên kéo thêm KHÔNG phát thông báo nào, và
        // thanh nằm khuất mãi.
        //
        // Luật này đọc vị trí chứ không đọc chuyển động, nên chính cú cuộn
        // đưa danh sách về đầu đã cứu được.
        expect(goi(viTri: 0, dangKeoTay: false, dich: 0), YNav.hien);
      });
    });

    group('bỏ qua phần không phải ngón tay kéo', () {
      test('DỰNG LẠI LỖI THẬT: cú nảy ở biên không được lật thanh', () {
        // Một cú vuốt sinh ba đợt thông báo: lúc kéo, lúc trôi theo quán
        // tính, và lúc đập biên rồi nảy ngược. Cú nảy chuyển động NGƯỢC
        // chiều người dùng vừa vuốt, nên nghe nó là lệnh cuối cùng tới tay
        // thanh luôn luôn ngược.
        //
        // Đo được trên máy: "vuốt xuống thì thanh ẩn, vuốt lên thì cũng ẩn".
        expect(
          goi(dangKeoTay: false, dich: -30, viTri: 3900),
          YNav.giuNguyen,
        );
        expect(
          goi(dangKeoTay: false, dich: 30, viTri: 800),
          YNav.giuNguyen,
        );
      });

      test('cuộn do mã gọi thì bỏ qua', () {
        // Bàn phím đẩy ô nhập lên cũng cuộn. Đếm nó là người dùng gõ một chữ
        // thì thanh dưới biến mất.
        expect(goi(dangKeoTay: false, dich: 200), YNav.giuNguyen);
      });
    });

    test('thứ tự các bộ lọc là một quyết định, không phải ngẫu nhiên', () {
      // Vuốt ngang trên một danh sách ngắn KHÔNG được trả về `hien`: nó
      // không nói gì về trang cả. Đảo hai dòng ấy trong hàm là test này đỏ.
      expect(goi(truc: Axis.horizontal, daiCuonDuoc: 0), YNav.giuNguyen);
      // Danh sách lồng cũng vậy, kể cả khi nó đang ở đầu.
      expect(goi(doSau: 1, viTri: 0), YNav.giuNguyen);
    });

    test('không có tổ hợp nào ném lỗi', () {
      for (final keo in [true, false]) {
        for (final sau in [0, 1]) {
          for (final truc in Axis.values) {
            for (final dai in [0.0, 400.0, 5000.0]) {
              for (final vt in [-50.0, 0.0, 800.0]) {
                for (final d in [-30.0, 0.0, 30.0]) {
                  expect(
                    () => yNavTuCuon(
                      dangKeoTay: keo,
                      doSau: sau,
                      truc: truc,
                      daiCuonDuoc: dai,
                      caoKhungNhin: man,
                      viTri: vt,
                      dich: d,
                    ),
                    returnsNormally,
                  );
                }
              }
            }
          }
        }
      }
    });
  });
}
