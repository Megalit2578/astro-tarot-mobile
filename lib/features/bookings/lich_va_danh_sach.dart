import 'package:flutter/material.dart';

import 'lich_hen_thang.dart';

/// Lịch tháng ở trên, danh sách buổi hẹn ở dưới — lịch tự thu lại khi cuộn.
///
/// ## Vì sao gom thành một widget
///
/// Hai màn dùng đúng cặp này: lịch hẹn của khách và Bàn làm việc của Reader.
/// Để mỗi màn tự nối lịch với danh sách thì phần nghe tiếng cuộn bị chép làm
/// hai bản, và hai bản ấy sẽ lệch nhau ngay lần đầu có người chỉnh một bên.
///
/// ## Vì sao nghe tiếng cuộn ở đây
///
/// Danh sách là ANH EM của lịch, không nằm trong cây con của nó, nên
/// `NotificationListener` đặt trong lịch sẽ không nghe thấy gì. Phải đặt ở
/// widget bọc cả hai.
class LichVaDanhSach extends StatefulWidget {
  const LichVaDanhSach({
    super.key,
    required this.cuaReader,
    required this.danhSach,
  });

  /// `true` là lịch của Reader (buổi khách đặt), `false` là của khách.
  final bool cuaReader;

  /// Danh sách buổi hẹn, tự cuộn.
  final Widget danhSach;

  @override
  State<LichVaDanhSach> createState() => _LichVaDanhSachState();
}

class _LichVaDanhSachState extends State<LichVaDanhSach> {
  bool _moRong = true;

  /// Cuộn xuống quá chừng này mới thu lịch.
  ///
  /// Không thu ngay từ pixel đầu tiên: ngón tay chạm rồi nhích một chút là
  /// chuyện thường, và lịch chớp tắt theo mỗi lần nhích thì khó chịu hơn hẳn
  /// so với việc nó đứng yên.
  static const _nguong = 24.0;

  bool _nghe(ScrollNotification n) {
    // Chỉ quan tâm trục dọc của danh sách, không phải mấy thanh cuộn ngang
    // của bộ lọc ở trên.
    if (n.metrics.axis != Axis.vertical) return false;

    if (n is ScrollUpdateNotification) {
      final d = n.scrollDelta ?? 0;
      if (d > 0 && n.metrics.pixels > _nguong && _moRong) {
        setState(() => _moRong = false);
      } else if (d < 0 && n.metrics.pixels <= 0 && !_moRong) {
        // Chỉ mở lại khi đã kéo về sát đỉnh. Mở ngay lúc vừa kéo ngược một
        // chút thì danh sách nhảy xuống dưới tay người đang đọc.
        setState(() => _moRong = true);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _nghe,
      child: Column(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: LichHenThang(
              cuaReader: widget.cuaReader,
              moRong: _moRong,
              doiMoRong: () => setState(() => _moRong = !_moRong),
            ),
          ),
          Expanded(child: widget.danhSach),
        ],
      ),
    );
  }
}
