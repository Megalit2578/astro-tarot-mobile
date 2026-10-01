import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../theme.dart';
import 'booking.dart';
import 'bookings_repository.dart';
import 'chat_screen.dart';

/// Nút chat nổi, có mặt ở mọi tab.
///
/// ## Vì sao cần
///
/// Khung chat vốn đã có, nhưng muốn tới được thì phải vào tab Lịch hẹn, tìm
/// đúng buổi, rồi bấm "Nhắn tin / Gọi". Ba bước cho việc mà người ta làm nhiều
/// nhất sau khi đặt cọc xong — và nếu đang ở tab khác thì chẳng có dấu hiệu
/// nào cho biết có người vừa nhắn.
///
/// Bản web đã có nút nổi như vậy từ lâu; đây là phần app còn thiếu.
///
/// ## Vì sao tự ẩn khi không có gì để chat
///
/// Một nút luôn hiện mà bấm vào chỉ để báo "chưa có cuộc trò chuyện nào" thì
/// tệ hơn là không có nút: nó che mất nội dung ở mọi màn hình, suốt thời gian
/// người dùng chưa đặt buổi nào. Chỉ những buổi đã mở chat (`chatMo`) mới tính.
///
/// ## Vì sao gộp cả hai phía
///
/// Một người vừa có thể là khách vừa có thể là Reader. Chỉ xem lịch của một
/// phía thì Reader đang trực sẽ không thấy tin của khách, mà đó mới đúng là
/// người cần thấy nhất.
class NutChatNoi extends ConsumerWidget {
  const NutChatNoi({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = ref.watch(authControllerProvider).user;
    if (u == null) return const SizedBox.shrink();

    final cuaToi =
        ref.watch(myBookingsProvider).asData?.value ?? const <Booking>[];
    // Chỉ hỏi lịch phía Reader khi người này thật sự là nhân sự. Hỏi vô điều
    // kiện thì mọi khách thường cũng tốn thêm một lượt gọi trả về 403.
    final cuaReader = u.laNhanSu
        ? (ref.watch(readerBookingsProvider).asData?.value ?? const <Booking>[])
        : const <Booking>[];

    // Gộp theo id: một buổi có thể xuất hiện ở cả hai danh sách khi người dùng
    // tự đặt lịch với chính mình lúc thử nghiệm, và hai thẻ trùng nhau trong
    // danh sách chọn thì rất khó hiểu.
    final theoId = <String, Booking>{};
    for (final b in [...cuaToi, ...cuaReader]) {
      if (b.chatMo) theoId[b.id] = b;
    }
    final mo = theoId.values.toList()
      ..sort((a, b) => b.batDau.compareTo(a.batDau));

    if (mo.isEmpty) return const SizedBox.shrink();

    return FloatingActionButton(
      heroTag: 'nut-chat-noi',
      backgroundColor: Mau.vang,
      foregroundColor: Colors.black,
      tooltip: mo.length == 1
          ? 'Nhắn tin với ${_doiPhuong(mo.first, u.id)}'
          : '${mo.length} cuộc trò chuyện',
      onPressed: () {
        // Một cuộc thì vào thẳng. Bắt người ta chọn trong danh sách chỉ có một
        // dòng là thêm một bước vô nghĩa.
        if (mo.length == 1) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ChatScreen(booking: mo.first)),
          );
        } else {
          _chonCuocTroChuyen(context, mo, u.id);
        }
      },
      child: Badge(
        isLabelVisible: mo.length > 1,
        label: Text('${mo.length}'),
        child: const Icon(Icons.chat_bubble_outline),
      ),
    );
  }
}

/// Tên người bên kia, tuỳ mình đang là khách hay Reader của buổi đó.
String _doiPhuong(Booking b, String toiLaAi) =>
    b.readerUserId == toiLaAi ? b.customerName : b.readerName;

String? _anhDoiPhuong(Booking b, String toiLaAi) =>
    b.readerUserId == toiLaAi ? b.customerAvatar : b.readerAvatar;

void _chonCuocTroChuyen(
  BuildContext context,
  List<Booking> mo,
  String toiLaAi,
) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Mau.nen,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              'Chọn cuộc trò chuyện',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          for (final b in mo)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Mau.vang.withValues(alpha: 0.15),
                foregroundImage: _anhDoiPhuong(b, toiLaAi) == null
                    ? null
                    : NetworkImage(_anhDoiPhuong(b, toiLaAi)!),
                child: Text(
                  _doiPhuong(b, toiLaAi).characters.first.toUpperCase(),
                  style: const TextStyle(color: Mau.vang),
                ),
              ),
              title: Text(_doiPhuong(b, toiLaAi)),
              subtitle: Text(_moTaBuoi(b)),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ChatScreen(booking: b)),
                );
              },
            ),
        ],
      ),
    ),
  );
}

String _moTaBuoi(Booking b) {
  final g = b.batDau;
  final hh = g.hour.toString().padLeft(2, '0');
  final mm = g.minute.toString().padLeft(2, '0');
  final dd = g.day.toString().padLeft(2, '0');
  final mo = g.month.toString().padLeft(2, '0');
  return 'Buổi $hh:$mm ngày $dd-$mo · ${b.phut} phút';
}
