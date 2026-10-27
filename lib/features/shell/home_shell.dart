import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/endpoints.dart';
import '../../core/auth/app_user.dart';
import '../../core/ngon_ngu.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/realtime/dinh_tuyen_su_kien.dart';
import '../../core/theo_doi.dart';
import '../../theme.dart';
import '../account/account_screen.dart';
import '../bookings/bookings_repository.dart';
import '../bookings/bookings_screen.dart';
import '../bookings/nut_chat_noi.dart';
import '../home/home_screen.dart';
import '../khuyenmai/khuyen_mai_repository.dart';
import '../khuyenmai/loi_chuc_dip_le.dart';
import '../money/money_repository.dart';
import '../notifications/notifications_screen.dart';
import '../readers/readers_screen.dart';
import '../staff/staff_screen.dart';
import '../support/support_repository.dart';
import '../tarot/tarot_screen.dart';

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
  VoidCallback? _huyNgheKhuyenMai;

  @override
  void initState() {
    super.initState();
    // Nghe kênh sự kiện chung ở KHUNG chứ không ở màn thông báo: chấm đỏ trên
    // chuông phải cập nhật kể cả khi người dùng đang ở tab khác. Đặt trong
    // màn thông báo thì nó chỉ chạy đúng lúc màn ấy đang mở — tức là đúng lúc
    // không cần nữa.
    _huyNgheSuKien = ref.read(realtimeProvider).nghe(Endpoints.queueEvents, (
      goi,
    ) {
      if (!mounted) return;
      // Gói tin phải được ĐỌC, không phải vứt đi. Trước đây chỗ này nhận `_`
      // rồi chỉ làm mới chuông, nên tiền về ví mà số dư vẫn là số cũ, Reader
      // xác nhận lịch mà danh sách không đổi — người dùng thấy thông báo
      // hiện lên rồi tưởng app hỏng.
      ref.invalidate(soChuaDocProvider);
      ref.read(thucThongBaoProvider.notifier).thuc();

      final phan = phanDaCu(goi);
      if (phan.contains(PhanDuLieu.lichHen)) {
        ref.invalidate(myBookingsProvider);
        ref.invalidate(readerBookingsProvider);
      }
      if (phan.contains(PhanDuLieu.tien)) {
        ref.invalidate(soDuProvider);
        ref.invalidate(giaoDichProvider);
        ref.invalidate(yeuCauRutProvider);
      }
      if (phan.contains(PhanDuLieu.hoTro)) {
        ref.invalidate(ticketsCuaToiProvider);
      }
    });

    // Nạp mã khách rồi ghi lượt mở app. Nạp TRƯỚC khi ghi: mã đọc từ
    // Keystore nên chưa sẵn ngay, và sự kiện gửi lúc chưa có mã thì máy chủ
    // ghi NULL, hành trình của phiên này không nối được với phiên sau.
    ref.read(maKhachProvider).nap().then((_) {
      if (!mounted) return;
      ref.read(theoDoiProvider).moApp();
    });

    // Lời chúc dịp lễ. Đặt ở KHUNG chứ không ở một màn cụ thể: người dùng
    // vào app rơi vào tab nào là tuỳ vai trò, gắn vào một màn thì Reader và
    // Nhân viên không bao giờ thấy.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      hienLoiChucNeuCo(context, ref);
    });

    // Quản trị vừa tạo đợt mới thì người đang mở app cũng thấy giá đổi theo.
    _huyNgheKhuyenMai = ref.read(realtimeProvider).nghe('/topic/khuyen-mai', (
      _,
    ) {
      if (!mounted) return;
      ref.invalidate(giaGoiProvider);
      ref.invalidate(khuyenMaiDangChayProvider);
    });
  }

  @override
  void dispose() {
    _huyNgheSuKien?.call();
    _huyNgheKhuyenMai?.call();
    super.dispose();
  }

  List<_Tab> _tabs(AppUser u) {
    return [
      const _Tab('Trang chủ', Icons.home_outlined, HomeScreen()),
      // Tarot AI là trụ cột số một của sản phẩm, và trên web nó nằm ngay
      // thanh điều hướng chính. Trên app nó từng chỉ là MỘT THẺ giữa trang
      // chủ, phải cuộn qua lời chào và bản đồ sao mới thấy — thứ người ta mở
      // app để làm lại là thứ khó với tới nhất.
      if (u.co('CUSTOMER_ACTIONS'))
        const _Tab('Tarot AI', Icons.auto_awesome_outlined, TarotScreen()),
      const _Tab('Reader', Icons.people_outline, ReadersScreen()),
      // Tab này gọi /bookings/me, mà endpoint ấy đòi CUSTOMER_ACTIONS — quyền
      // chỉ Thành viên có kể từ 12/10/2026. Trước khi gác lại, Nhân viên bấm
      // vào đây nhận đúng một dòng "Bạn không có quyền thực hiện thao tác
      // này" giữa màn trống.
      //
      // Reader KHÔNG mất gì: lịch của họ nằm ở Bàn làm việc → Lịch hẹn, lấy
      // từ /bookings/reader, một endpoint khác với một quyền khác.
      if (u.co('CUSTOMER_ACTIONS'))
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
      body: IndexedStack(index: chon, children: [for (final t in tabs) t.man]),
      // Đặt ở KHUNG chứ không ở từng màn: có người nhắn lúc đang xem Shop hay
      // Tarot thì vẫn phải với tới được. Nút tự ẩn khi không có buổi nào đang
      // mở chat, nên màn hình của người chưa đặt lịch không bị che gì.
      floatingActionButton: const NutChatNoi(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: chon,
        onDestinationSelected: (i) {
          setState(() => _chon = i);
          // Ghi tên tab, không ghi chỉ số: số thứ tự đổi theo vai trò (Reader
          // có thêm Bàn làm việc), nên "tab 2" của người này không cùng màn
          // với "tab 2" của người kia.
          ref.read(theoDoiProvider).xemMan(tabs[i].nhan);
        },
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: Icon(t.icon, color: Mau.chuMo),
              selectedIcon: Icon(t.icon, color: Mau.vang),
              label: Ngu.d(t.nhan),
            ),
        ],
      ),
    );
  }
}
