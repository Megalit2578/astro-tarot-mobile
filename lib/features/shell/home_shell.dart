import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/app_user.dart';
import '../../core/auth/auth_controller.dart';
import '../../theme.dart';
import '../placeholder/chua_lam.dart';
import '../account/account_screen.dart';
import '../readers/readers_screen.dart';

/// Một mục trên thanh điều hướng.
class _Tab {
  const _Tab(this.nhan, this.icon, this.man);
  final String nhan;
  final IconData icon;
  final Widget man;
}

/// Khung chính sau khi đăng nhập.
///
/// ## Vì sao thanh tab tối đa năm mục, và vì sao Quản trị không nằm trên đó
///
/// Vai trò Quản trị viên có tới sáu khu vực. Nhét hết lên thanh dưới thì mỗi
/// mục còn khoảng sáu mươi pixel bề ngang trên máy 360dp — nhãn bị cắt, và
/// ngón cái bấm nhầm sang ô bên cạnh.
///
/// Nên: bốn mục cố định cho việc hằng ngày, thêm "Bàn làm việc" cho ai có
/// quyền nhân sự, còn khu Quản trị đặt trong tab Tài khoản. Đây cũng đúng với
/// tần suất dùng thật — duyệt đơn và đối soát tiền là việc ngồi máy tính, hiếm
/// khi làm trên điện thoại giữa đường.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _chon = 0;

  List<_Tab> _tabs(AppUser u) {
    return [
      const _Tab('Trang chủ', Icons.home_outlined, ChuaLam(
        ten: 'Trang chủ',
        moTa: 'Lá bài hôm nay, lịch hẹn sắp tới, lần trải bài gần đây.',
        endpoints: [
          'GET /api/v1/astrology/daily-card',
          'GET /api/v1/bookings/me',
          'GET /api/v1/ai/readings/history',
        ],
      )),
      const _Tab('Reader', Icons.people_outline, ReadersScreen()),
      const _Tab('Lịch hẹn', Icons.event_outlined, ChuaLam(
        ten: 'Lịch hẹn của tôi',
        moTa: 'Buổi đã đặt, thanh toán, và hộp trò chuyện + gọi khi buổi đã '
            'xác nhận.',
        endpoints: [
          'GET /api/v1/bookings/me',
          'POST /api/v1/bookings/{id}/payment',
          'GET /api/v1/bookings/{id}/messages',
          'STOMP /app/bookings/{id}/chat',
          'STOMP /app/bookings/{id}/call',
        ],
      )),
      if (u.laNhanSu)
        const _Tab('Bàn làm việc', Icons.work_outline, ChuaLam(
          ten: 'Bàn làm việc',
          moTa: 'Hàng chờ hỗ trợ, lịch hẹn nhận được, thu nhập, hồ sơ Reader.',
          endpoints: [
            'GET /api/v1/support/tickets',
            'GET /api/v1/bookings/reader',
            'PATCH /api/v1/bookings/{id}/confirm',
            'GET /api/v1/money/earnings',
          ],
        )),
      const _Tab('Tài khoản', Icons.person_outline, AccountScreen()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final u = ref.watch(authControllerProvider).user;
    if (u == null) return const SizedBox.shrink();

    final tabs = _tabs(u);
    // Vai trò có thể đổi giữa phiên (được cất lên Nhân viên chẳng hạn) làm số
    // tab ít đi. Không kẹp lại thì chỉ số cũ trỏ ra ngoài mảng và app đổ.
    final chon = _chon.clamp(0, tabs.length - 1);

    return Scaffold(
      body: IndexedStack(
        index: chon,
        children: [for (final t in tabs) t.man],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: chon,
        onDestinationSelected: (i) => setState(() => _chon = i),
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: Icon(t.icon, color: Mau.chuMo),
              selectedIcon: Icon(t.icon, color: Mau.vang),
              label: t.nhan,
            ),
        ],
      ),
    );
  }
}
