import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../theme.dart';
import '../tarot/tarot_screen.dart';

/// Một lá Ẩn Chính dùng cho khối rút bài trên trang chủ.
class LaAnChinh {
  const LaAnChinh({
    required this.tep,
    required this.ten,
    required this.tenVi,
    required this.tuKhoa,
    required this.yNghia,
  });

  /// Trùng tên tệp ảnh trong `public/tarot/` của web.
  final String tep;
  final String ten;
  final String tenVi;
  final List<String> tuKhoa;

  /// Một câu gợi mở, viết ở ngôi thứ hai.
  final String yNghia;

  /// Ảnh lấy thẳng từ trang web — cùng bộ Rider-Waite-Smith 1909 web đang
  /// dùng, nên không phải đóng gói thêm hai mươi hai tấm ảnh vào app.
  String get anh => '${AppConfig.webBaseUrl}/tarot/$tep.jpg';
}

/// 22 lá Ẩn Chính — chép từ `src/lib/tarot-cards.ts` của web.
///
/// Nghĩa ở đây là bản rút gọn, chỉ đủ cho một lá gợi mở trong ngày. Trải bài
/// đầy đủ có bối cảnh và AI diễn giải nằm ở màn Tarot.
const anChinh = <LaAnChinh>[
  LaAnChinh(
    tep: '00-fool',
    ten: 'The Fool',
    tenVi: 'Gã Khờ',
    tuKhoa: ['Khởi đầu', 'Tự do', 'Liều lĩnh'],
    yNghia: 'Một chương mới đang mở ra và bạn chưa cần biết hết đường đi. Bước thứ nhất quan trọng hơn bản đồ hoàn hảo.',
  ),
  LaAnChinh(
    tep: '01-magician',
    ten: 'The Magician',
    tenVi: 'Nhà Ảo Thuật',
    tuKhoa: ['Năng lực', 'Ý chí', 'Sáng tạo'],
    yNghia: 'Mọi thứ bạn cần đã nằm trong tay rồi. Việc còn lại là dám dùng nó thay vì chờ thêm một điều kiện nữa.',
  ),
  LaAnChinh(
    tep: '02-high-priestess',
    ten: 'The High Priestess',
    tenVi: 'Nữ Tư Tế',
    tuKhoa: ['Trực giác', 'Tĩnh lặng', 'Bí ẩn'],
    yNghia: 'Câu trả lời không nằm ở việc hỏi thêm ai. Hãy im lặng đủ lâu để nghe thấy điều bạn vốn đã biết.',
  ),
  LaAnChinh(
    tep: '03-empress',
    ten: 'The Empress',
    tenVi: 'Nữ Hoàng',
    tuKhoa: ['Nuôi dưỡng', 'Sung túc', 'Dịu dàng'],
    yNghia: 'Thời điểm để chăm sóc thứ mình đã gieo, cả một dự án lẫn chính bản thân. Điều tốt đẹp cần thời gian chín.',
  ),
  LaAnChinh(
    tep: '04-emperor',
    ten: 'The Emperor',
    tenVi: 'Hoàng Đế',
    tuKhoa: ['Kỷ luật', 'Cấu trúc', 'Bảo vệ'],
    yNghia: 'Bạn đang cần ranh giới rõ hơn là thêm cảm hứng. Dựng khung trước, tự do sẽ tới sau.',
  ),
  LaAnChinh(
    tep: '05-hierophant',
    ten: 'The Hierophant',
    tenVi: 'Giáo Hoàng',
    tuKhoa: ['Truyền thống', 'Học hỏi', 'Cố vấn'],
    yNghia: 'Có người đã đi qua con đường này rồi. Hỏi một lời khuyên đúng chỗ sẽ tiết kiệm cho bạn nhiều tháng.',
  ),
  LaAnChinh(
    tep: '06-lovers',
    ten: 'The Lovers',
    tenVi: 'Tình Nhân',
    tuKhoa: ['Lựa chọn', 'Kết nối', 'Giá trị'],
    yNghia: 'Một quyết định đang chờ, và nó không chỉ là chọn cái nào — mà là chọn con người nào bạn muốn trở thành.',
  ),
  LaAnChinh(
    tep: '07-chariot',
    ten: 'The Chariot',
    tenVi: 'Cỗ Xe',
    tuKhoa: ['Quyết tâm', 'Tiến tới', 'Kiểm soát'],
    yNghia: 'Hai lực đang kéo bạn về hai phía. Nắm cương cả hai, đừng bỏ bên nào, rồi nhắm thẳng một hướng.',
  ),
  LaAnChinh(
    tep: '08-strength',
    ten: 'Strength',
    tenVi: 'Sức Mạnh',
    tuKhoa: ['Kiên nhẫn', 'Ôn hoà', 'Can đảm'],
    yNghia: 'Sức mạnh thật nằm ở chỗ dịu dàng với thứ đang làm bạn sợ, chứ không phải ở chỗ áp đảo nó.',
  ),
  LaAnChinh(
    tep: '09-hermit',
    ten: 'The Hermit',
    tenVi: 'Ẩn Sĩ',
    tuKhoa: ['Nội tâm', 'Tách biệt', 'Soi sáng'],
    yNghia: 'Rút lui một chút không phải là bỏ cuộc. Bạn cần khoảng trống để thấy rõ mình đang đi đâu.',
  ),
  LaAnChinh(
    tep: '10-wheel-of-fortune',
    ten: 'Wheel of Fortune',
    tenVi: 'Bánh Xe Vận Mệnh',
    tuKhoa: ['Chuyển biến', 'Chu kỳ', 'Thời cơ'],
    yNghia: 'Guồng quay vừa đổi chiều. Thứ tưởng đã đóng lại có thể mở ra theo cách bạn không tính trước.',
  ),
  LaAnChinh(
    tep: '11-justice',
    ten: 'Justice',
    tenVi: 'Công Lý',
    tuKhoa: ['Cân bằng', 'Sự thật', 'Trách nhiệm'],
    yNghia: 'Mọi lựa chọn đều có cái giá của nó. Nhìn thẳng vào phần mình đã góp vào tình huống này.',
  ),
  LaAnChinh(
    tep: '12-hanged-man',
    ten: 'The Hanged Man',
    tenVi: 'Người Treo Ngược',
    tuKhoa: ['Buông bỏ', 'Đổi góc nhìn', 'Chờ đợi'],
    yNghia: 'Càng cố thì càng kẹt. Thử lật ngược vấn đề, hoặc đơn giản là để nó yên thêm một thời gian.',
  ),
  LaAnChinh(
    tep: '13-death',
    ten: 'Death',
    tenVi: 'Cái Chết',
    tuKhoa: ['Kết thúc', 'Lột xác', 'Tái sinh'],
    yNghia: 'Không phải điềm xấu. Có một thứ đã hết vai trò trong đời bạn, và giữ nó lại mới là điều đáng lo.',
  ),
  LaAnChinh(
    tep: '14-temperance',
    ten: 'Temperance',
    tenVi: 'Tiết Độ',
    tuKhoa: ['Điều hoà', 'Kiên trì', 'Trung dung'],
    yNghia: 'Pha đúng liều lượng quan trọng hơn làm thật nhiều. Chậm và đều sẽ đưa bạn tới xa hơn.',
  ),
  LaAnChinh(
    tep: '15-devil',
    ten: 'The Devil',
    tenVi: 'Ác Quỷ',
    tuKhoa: ['Ràng buộc', 'Cám dỗ', 'Thói quen'],
    yNghia: 'Sợi xích lỏng hơn bạn tưởng. Gọi tên đúng thứ đang giữ chân mình là đã đi được nửa đường.',
  ),
  LaAnChinh(
    tep: '16-tower',
    ten: 'The Tower',
    tenVi: 'Toà Tháp',
    tuKhoa: ['Đổ vỡ', 'Bừng tỉnh', 'Giải phóng'],
    yNghia: 'Một điều đang sụp, và nó sụp vì móng vốn đã yếu. Dọn dẹp xong, chỗ đó sẽ xây được thứ vững hơn.',
  ),
  LaAnChinh(
    tep: '17-star',
    ten: 'The Star',
    tenVi: 'Ngôi Sao',
    tuKhoa: ['Hy vọng', 'Chữa lành', 'Thanh thản'],
    yNghia: 'Sau một quãng mệt, bầu trời đang quang trở lại. Cho phép mình tin lần nữa, nhẹ nhàng thôi.',
  ),
  LaAnChinh(
    tep: '18-moon',
    ten: 'The Moon',
    tenVi: 'Mặt Trăng',
    tuKhoa: ['Mơ hồ', 'Lo âu', 'Tiềm thức'],
    yNghia: 'Chưa nhìn rõ thì đừng vội kết luận. Phần lớn nỗi sợ lúc này đến từ tưởng tượng chứ không từ sự thật.',
  ),
  LaAnChinh(
    tep: '19-sun',
    ten: 'The Sun',
    tenVi: 'Mặt Trời',
    tuKhoa: ['Niềm vui', 'Thành công', 'Rõ ràng'],
    yNghia: 'Mọi thứ sáng rõ và bạn xứng đáng tận hưởng. Đừng vội tìm xem có gì sai — đôi khi tốt là tốt thật.',
  ),
  LaAnChinh(
    tep: '20-judgement',
    ten: 'Judgement',
    tenVi: 'Phán Xét',
    tuKhoa: ['Thức tỉnh', 'Tổng kết', 'Gọi mời'],
    yNghia: 'Một lời gọi từ bên trong đang vang lên. Nhìn lại chặng đã qua rồi quyết định điều thật sự quan trọng.',
  ),
  LaAnChinh(
    tep: '21-world',
    ten: 'The World',
    tenVi: 'Thế Giới',
    tuKhoa: ['Hoàn tất', 'Trọn vẹn', 'Chương mới'],
    yNghia: 'Một vòng đã khép trọn vẹn. Ăn mừng trước đã, rồi hãy nghĩ tới điều tiếp theo.',
  ),
];

/// Rút thử một lá ngay trên trang chủ, khớp khối "Rút thử một lá" của web.
///
/// Người mới muốn THỬ ngay chứ không muốn đọc giới thiệu. Cho họ lật một lá
/// thật, đọc một câu gợi mở, rồi mới mời sang trải bài đầy đủ.
class RutBaiHangNgay extends StatefulWidget {
  const RutBaiHangNgay({super.key, this.ngauNhien});

  /// Cho test cố định lá rút ra.
  final Random? ngauNhien;

  @override
  State<RutBaiHangNgay> createState() => _RutBaiHangNgayState();
}

class _RutBaiHangNgayState extends State<RutBaiHangNgay> {
  LaAnChinh? _la;
  late final Random _r = widget.ngauNhien ?? Random();

  void _rut() => setState(() => _la = anChinh[_r.nextInt(anChinh.length)]);

  @override
  Widget build(BuildContext context) {
    final la = _la;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '✦ RÚT THỬ MỘT LÁ',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 2,
                    color: Mau.vang.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Mau.vien),
                  ),
                  child: const Text(
                    'Miễn phí',
                    style: TextStyle(fontSize: 10, color: Mau.vang),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (la == null) ..._up() else ..._ngua(la),
          ],
        ),
      ),
    );
  }

  List<Widget> _up() => [
    const Text(
      'Hôm nay vũ trụ muốn nói gì với bạn?',
      style: TextStyle(fontSize: 17, height: 1.35),
    ),
    const SizedBox(height: 6),
    const Text(
      'Hít một hơi, nghĩ về điều đang khiến bạn băn khoăn, rồi chọn một lá.',
      style: TextStyle(fontSize: 12.5, color: Mau.chuMo, height: 1.5),
    ),
    const SizedBox(height: 14),
    Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: InkWell(
              key: ValueKey('la-up-$i'),
              onTap: _rut,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 64,
                height: 104,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1426),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Mau.vang.withValues(alpha: 0.5)),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Mau.vang,
                  size: 22,
                ),
              ),
            ),
          ),
      ],
    ),
  ];

  List<Widget> _ngua(LaAnChinh la) => [
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            la.anh,
            width: 78,
            height: 130,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 78,
              height: 130,
              color: const Color(0xFF1A1426),
              child: const Icon(Icons.style, color: Mau.vang),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                la.tenVi,
                style: const TextStyle(fontSize: 18, color: Mau.vangNhat),
              ),
              Text(
                la.ten,
                style: const TextStyle(fontSize: 11.5, color: Mau.chuMo),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  for (final k in la.tuKhoa)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Mau.vien),
                      ),
                      child: Text(
                        k,
                        style: const TextStyle(fontSize: 10.5, color: Mau.vang),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                la.yNghia,
                style: const TextStyle(fontSize: 13, height: 1.55),
              ),
            ],
          ),
        ),
      ],
    ),
    const SizedBox(height: 12),
    // Wrap: cỡ chữ lớn thì hai nút không còn vừa một hàng.
    Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        TextButton(
          onPressed: () => setState(() => _la = null),
          child: const Text('Rút lại'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const TarotScreen())),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
          child: const Text('Trải bài đầy đủ'),
        ),
      ],
    ),
  ];
}
