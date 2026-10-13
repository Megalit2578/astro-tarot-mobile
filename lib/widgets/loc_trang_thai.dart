import 'package:flutter/material.dart';

import '../theme.dart';

/// Ô chọn lọc trạng thái, gọn trong một dòng.
///
/// Dùng ô chọn thay cho một hàng pill nữa: màn nào cũng đã có một hàng pill
/// để chuyển mục, và hai hàng pill xếp chồng thì vừa ăn hết phần trên màn
/// hình, vừa khó nhìn ra hàng nào đang điều khiển cái gì — cả hai trông y hệt
/// nhau. Trên Bàn làm việc, hai hàng ấy cộng với lịch tháng đẩy buổi hẹn đầu
/// tiên xuống dưới mép màn.
///
/// Đổi lại là mất một cú chạm để xem các lựa chọn. Chấp nhận được: người ta
/// đổi bộ lọc vài lần một phiên, còn chiều cao thì trả giá ở mọi khung hình.
class LocTrangThai extends StatelessWidget {
  const LocTrangThai({
    super.key,
    required this.giaTri,
    required this.nhan,
    required this.doi,
    this.nhanTatCa = 'Tất cả',
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 4),
  });

  /// Lề quanh ô. Màn nào nhúng ô này vào `dau` của danh sách phân trang thì
  /// danh sách đã chừa lề ngang sẵn, truyền lề chỉ-dưới để khỏi thụt hai lần.
  final EdgeInsets padding;

  /// Khoá đang chọn. Chuỗi rỗng nghĩa là không lọc.
  final String giaTri;

  /// Khoá → chữ hiện ra, theo đúng thứ tự muốn hiện.
  final Map<String, String> nhan;

  final ValueChanged<String> doi;

  final String nhanTatCa;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: DropdownButtonFormField<String>(
        key: const ValueKey('loc-trang-thai'),
        initialValue: giaTri,
        isExpanded: true,
        dropdownColor: Mau.the,
        decoration: const InputDecoration(
          isDense: true,
          prefixIcon: Icon(Icons.filter_list, size: 18),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        items: [
          DropdownMenuItem(value: '', child: Text(nhanTatCa)),
          for (final e in nhan.entries)
            DropdownMenuItem(value: e.key, child: Text(e.value)),
        ],
        onChanged: (v) => doi(v ?? ''),
      ),
    );
  }
}
