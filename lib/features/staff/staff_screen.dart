import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../theme.dart';
import '../../widgets/dai_chon.dart';
import '../money/earnings_screen.dart';
import '../readerprofile/reader_profile_view.dart';
import 'staff_bookings_view.dart';
import 'staff_support_view.dart';

/// Bàn làm việc của Nhân viên / Reader.
///
/// Ba mục, và mỗi mục chỉ hiện khi tài khoản có đúng quyền cho nó. Một người
/// chỉ trực hỗ trợ mà thấy tab "Thu nhập" rỗng thì tưởng mình bị thiếu tiền;
/// ngược lại, một Reader thuần không có quyền trả lời hỗ trợ mà thấy hàng chờ
/// thì bấm vào là 403.
///
/// Dùng dải chọn ngang chứ không phải TabBar: chỉ có hai đến ba mục, và
/// TabBar kéo theo cả cơ chế vuốt ngang — vuốt nhầm giữa lúc đang cuộn danh
/// sách là chuyện xảy ra suốt.
class StaffScreen extends ConsumerStatefulWidget {
  const StaffScreen({super.key, this.tabDau});

  /// Tab mở sẵn khi vào màn: 'bookings', 'support', 'profile', 'earnings'.
  ///
  /// Chỉ định bằng KHOÁ chứ không bằng chỉ số: danh sách tab dựng theo quyền,
  /// nên cùng một con số trỏ vào tab khác nhau tuỳ tài khoản — Reader không
  /// làm hỗ trợ có ba tab, nhân viên đủ quyền có bốn.
  ///
  /// Khoá trỏ tới tab đang bị ẩn vì thiếu quyền thì rơi về tab đầu.
  final String? tabDau;

  @override
  ConsumerState<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends ConsumerState<StaffScreen> {
  /// Null nghĩa là người dùng chưa tự bấm tab nào — lúc ấy [StaffScreen.tabDau]
  /// quyết định. Sau cú bấm đầu tiên thì lựa chọn của họ thắng, kể cả khi màn
  /// được dựng lại.
  int? _chon;

  @override
  Widget build(BuildContext context) {
    final u = ref.watch(authControllerProvider).user;
    if (u == null) return const SizedBox.shrink();

    final muc = <({String khoa, String nhan, Widget man})>[
      if (u.co('READER_MANAGE_PROFILE'))
        (khoa: 'bookings', nhan: 'Lịch hẹn', man: const StaffBookingsView()),
      if (u.co('SUPPORT_RESPOND') || u.co('SUPPORT_VIEW'))
        (khoa: 'support', nhan: 'Hỗ trợ', man: const StaffSupportView()),
      if (u.co('READER_MANAGE_PROFILE'))
        (khoa: 'profile', nhan: 'Hồ sơ', man: const ReaderProfileView()),
      if (u.co('PAYOUT_REQUEST'))
        (khoa: 'earnings', nhan: 'Thu nhập', man: const EarningsScreen()),
    ];

    if (muc.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bàn làm việc')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(30),
            child: Text(
              'Tài khoản của bạn chưa có phần việc nào ở đây.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Mau.chuMo, fontSize: 13),
            ),
          ),
        ),
      );
    }

    // Chưa bấm tab nào thì mở tab được yêu cầu. indexWhere trả -1 khi khoá
    // trỏ tới tab đang bị ẩn vì thiếu quyền — rơi về tab đầu, không để màn
    // trắng vì một khoá sai.
    final theoKhoa = widget.tabDau == null
        ? 0
        : muc.indexWhere((m) => m.khoa == widget.tabDau);
    // Quyền có thể đổi giữa phiên, làm số mục ít đi. Không kẹp thì chỉ số cũ
    // trỏ ra ngoài mảng và app đổ.
    final chon = (_chon ?? (theoKhoa < 0 ? 0 : theoKhoa))
        .clamp(0, muc.length - 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bàn làm việc'),
        bottom: muc.length < 2
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(46),
                child: DaiChon(
                  nhan: [for (final m in muc) m.nhan],
                  chon: chon,
                  khiChon: (i) => setState(() => _chon = i),
                ),
              ),
      ),
      body: IndexedStack(
        index: chon,
        children: [for (final m in muc) m.man],
      ),
    );
  }
}
