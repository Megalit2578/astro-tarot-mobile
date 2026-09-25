import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/endpoints.dart';
import '../../core/auth/app_user.dart';
import '../../core/auth/auth_controller.dart';
import '../../theme.dart';
import '../account/account_screen.dart';
import '../bookings/bookings_screen.dart';
import '../home/home_screen.dart';
import '../notifications/notifications_screen.dart';
import '../readers/readers_screen.dart';
import '../staff/staff_screen.dart';

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
  VoidCallback? _huyNgheSuKien;

  @override
  void initState() {
    super.initState();
    // Nghe kênh sự kiện chung ở KHUNG chứ không ở màn thông báo: chấm đỏ trên
    // chuông phải cập nhật kể cả khi người dùng đang ở tab khác. Đặt trong
    // màn thông báo thì nó chỉ chạy đúng lúc màn ấy đang mở — tức là đúng lúc
    // không cần nữa.
    _huyNgheSuKien = ref.read(realtimeProvider).nghe(
      Endpoints.queueEvents,
      (_) {
        if (!mounted) return;
        ref.invalidate(soChuaDocProvider);
        ref.invalidate(thongBaoProvider);
      },
    );
  }

  @override
  void dispose() {
    _huyNgheSuKien?.call();
    super.dispose();
  }

  List<_Tab> _tabs(AppUser u) {
    return [
      const _Tab('Trang chủ', Icons.home_outlined, HomeScreen()),
      const _Tab('Reader', Icons.people_outline, ReadersScreen()),
      const _Tab('Lịch hẹn', Icons.event_outlined, BookingsScreen()),
      if (u.laNhanSu)
        const _Tab('Bàn làm việc', Icons.work_outline, StaffScreen()),
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
