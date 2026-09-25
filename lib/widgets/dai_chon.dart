import 'package:flutter/material.dart';

import '../theme.dart';

/// Dải chọn ngang dạng viên thuốc — dùng thay TabBar.
///
/// TabBar kéo theo cơ chế vuốt ngang, và vuốt nhầm giữa lúc đang cuộn danh
/// sách là chuyện xảy ra suốt. Dải này chỉ đổi khi bấm.
///
/// Có hai chế độ:
/// - Ít mục ([cuon] = false): chia đều bề ngang, mỗi mục một ô.
/// - Nhiều mục ([cuon] = true): cuộn ngang. Khu Quản trị có tới chín mục;
///   chia đều trên máy 360dp thì mỗi nhãn còn chưa tới bốn mươi pixel.
class DaiChon extends StatefulWidget {
  const DaiChon({
    super.key,
    required this.nhan,
    required this.chon,
    required this.khiChon,
    this.cuon = false,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 10),
  });

  final List<String> nhan;
  final int chon;
  final ValueChanged<int> khiChon;
  final bool cuon;
  final EdgeInsets padding;

  @override
  State<DaiChon> createState() => _DaiChonState();
}

class _DaiChonState extends State<DaiChon> {
  final _khoa = <int, GlobalKey>{};

  GlobalKey _khoaCua(int i) => _khoa.putIfAbsent(i, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    _hienMucChon();
  }

  @override
  void didUpdateWidget(DaiChon cu) {
    super.didUpdateWidget(cu);
    if (cu.chon != widget.chon) _hienMucChon();
  }

  /// Ở chế độ cuộn, mục đang chọn có thể nằm ngoài mép phải (khu Quản trị
  /// có chín mục). Kéo nó vào giữa, không thì người dùng không biết mình
  /// đang ở mục nào.
  void _hienMucChon() {
    if (!widget.cuon) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _khoa[widget.chon]?.currentContext;
      if (c == null || !c.mounted) return;
      Scrollable.ensureVisible(
        c,
        alignment: 0.5,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Widget _o(int i) {
    final dangChon = widget.chon == i;
    return InkWell(
      key: ValueKey('dai-chon-$i'),
      borderRadius: BorderRadius.circular(999),
      onTap: () => widget.khiChon(i),
      child: Container(
        key: widget.cuon ? _khoaCua(i) : null,
        height: 36,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: widget.cuon ? 16 : 6),
        decoration: BoxDecoration(
          color: dangChon ? Mau.vang.withValues(alpha: 0.16) : Mau.the,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: dangChon ? Mau.vang : Mau.vien),
        ),
        child: Text(
          widget.nhan[i],
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            color: dangChon ? Mau.vang : Mau.chuMo,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = widget.padding;
    final nhan = widget.nhan;
    if (widget.cuon) {
      // SingleChildScrollView chứ không ListView: ListView chỉ dựng mục đang
      // thấy, mục ngoài màn không có context để kéo vào.
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        child: Row(
          children: [
            for (var i = 0; i < nhan.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _o(i),
            ],
          ],
        ),
      );
    }
    return Padding(
      padding: padding,
      child: Row(
        children: [
          for (var i = 0; i < nhan.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: _o(i)),
          ],
        ],
      ),
    );
  }
}
