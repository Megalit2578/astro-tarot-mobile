import 'package:flutter_test/flutter_test.dart';

import 'package:astrotarot_mobile/core/ma_khach.dart';

/// Kho giả, không đụng tới Keystore thật.
class _KhoGia implements KhoChuoi {
  _KhoGia({this.nem = false, Map<String, String>? ban}) : _ban = ban ?? {};

  final Map<String, String> _ban;
  final bool nem;

  @override
  Future<String?> doc(String khoa) async {
    if (nem) throw Exception('Keystore không mở được');
    return _ban[khoa];
  }

  @override
  Future<void> ghi(String khoa, String giaTri) async {
    if (nem) throw Exception('Keystore không ghi được');
    _ban[khoa] = giaTri;
  }
}

/// Mã khách ẩn danh.
///
/// Kiểu hỏng mà những bài kiểm này canh: mã đổi mỗi lần mở app. Lúc ấy mọi
/// hành động của một người bị cắt thành từng mảnh rời, và màn "hành trình
/// từng khách" hiện ra hàng chục khách mỗi người đúng một bước — trông như
/// app có rất nhiều người dùng mà chẳng ai làm gì.
void main() {
  test('sinh mã mới khi chưa có, và giữ nguyên ở lần nạp sau', () async {
    final ban = <String, String>{};

    final lan1 = MaKhach(kho: _KhoGia(ban: ban));
    await lan1.nap();
    expect(lan1.ma, isNotEmpty);

    // Mở lại app: cùng kho, phải ra cùng mã.
    final lan2 = MaKhach(kho: _KhoGia(ban: ban));
    await lan2.nap();
    expect(lan2.ma, lan1.ma);
  });

  test('nạp hai lần không sinh mã mới', () async {
    final m = MaKhach(kho: _KhoGia());
    await m.nap();
    final dau = m.ma;
    await m.nap();
    expect(m.ma, dau);
  });

  test('hai máy khác nhau ra hai mã khác nhau', () async {
    final a = MaKhach(kho: _KhoGia());
    final b = MaKhach(kho: _KhoGia());
    await a.nap();
    await b.nap();
    expect(a.ma, isNot(b.ma));
  });

  test('mã đúng dạng UUID v4', () async {
    // Máy chủ cất vào cột varchar(64) và gộp theo chuỗi này. Dạng sai thì
    // không vỡ ngay, nhưng đối chiếu với mã bên web sẽ khó đọc.
    final m = MaKhach(kho: _KhoGia());
    await m.nap();
    expect(
      m.ma,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });

  test('kho hỏng thì KHÔNG ném, vẫn có mã cho phiên này', () async {
    // Keystore hỏng, máy không mở khoá được, bộ nhớ đầy — đều ném. Theo dõi
    // là việc phụ, không được phép chặn app khởi động.
    final m = MaKhach(kho: _KhoGia(nem: true));

    await expectLater(m.nap(), completes);
    expect(m.ma, isNotEmpty);
  });

  test('chưa nạp thì trả rỗng, không chờ và không ném', () async {
    // `ghi` chạy trong luồng người dùng đang thao tác. Một sự kiện thiếu mã
    // còn hơn một thao tác bị khựng lại vì đợi Keystore.
    final m = MaKhach(kho: _KhoGia());
    expect(m.ma, '');
  });
}
