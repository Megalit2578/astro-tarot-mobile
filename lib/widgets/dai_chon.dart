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
class DaiChon extends StatelessWidget {
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

  Widget _o(int i) {
    final dangChon = chon == i;
    return InkWell(
      key: ValueKey('dai-chon-$i'),
      borderRadius: BorderRadius.circular(999),
      onTap: () => khiChon(i),
      child: Container(
        height: 36,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: cuon ? 16 : 6),
        decoration: BoxDecoration(
          color: dangChon ? Mau.vang.withValues(alpha: 0.16) : Mau.the,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: dangChon ? Mau.vang : Mau.vien),
        ),
        child: Text(
          nhan[i],
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
    if (cuon) {
      return SizedBox(
        height: 36 + padding.vertical,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: padding,
          itemCount: nhan.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) => _o(i),
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
