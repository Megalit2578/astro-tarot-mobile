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
import 'y_nav_cuon.dart';

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

class _HomeShellState extends ConsumerState<HomeShell>
    with SingleTickerProviderStateMixin {
  int _chon = 0;
  VoidCallback? _huyNgheSuKien;
  VoidCallback? _huyNgheKhuyenMai;

  /// 1 là thanh điều hướng hiện đủ, 0 là đã trượt khuất hẳn xuống dưới.
  late final AnimationController _navHien;

  /// Quãng đã kéo cộng dồn từ lần quyết gần nhất. Xem [nguongDich].
  double _tichDich = 0;

  @override
  void initState() {
    super.initState();
    _navHien = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 160),
      value: 1,
    );
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
    _navHien.dispose();
    super.dispose();
  }

  /// Giấu thanh khi cuộn xuống, trả lại khi cuộn lên.
  ///
  /// ## Vì sao nghe ở KHUNG chứ không sửa từng màn
  ///
  /// Thông báo cuộn nổi bọt lên theo cây widget, nên một bộ nghe đặt quanh
  /// thân khung bắt được mọi danh sách của mọi tab. Cách còn lại là mỗi màn
  /// tự gắn một `ScrollController` rồi báo ngược lên — tức là sửa hơn chục
  /// tệp, và màn nào viết sau mà quên gắn thì thanh đứng im ở đó, không ai
  /// biết cho tới khi có người dùng kêu.
  ///
  /// Luật nằm ở [yNavTuCuon]; chỗ này chỉ dịch thông báo sang tham số rồi
  /// thi hành kết quả.
  bool _theoCuon(ScrollNotification tin) {
    // Chỉ `ScrollUpdateNotification` mới mang được hai thứ cần thiết: ngón
    // tay có còn trên màn không (`dragDetails`), và nội dung dịch theo chiều
    // nào (`scrollDelta`). Những loại thông báo khác vẫn được cho đi qua, vì
    // luật "về đầu danh sách thì hiện" chỉ cần đọc vị trí — và chính nó là
    // thứ cứu app khỏi ngõ cụt thanh-nav-khuất-vĩnh-viễn.
    final capNhat = tin is ScrollUpdateNotification ? tin : null;
    final dangKeo = capNhat?.dragDetails != null;
    // Nhấc tay là quên hết: quãng kéo của cú vuốt trước không được cộng vào
    // cú sau, nếu không thì hai cú vuốt ngắn ngược chiều lại thành một quyết
    // định.
    _tichDich = dangKeo ? _tichDich + (capNhat?.scrollDelta ?? 0) : 0;
    final y = yNavTuCuon(
      dangKeoTay: dangKeo,
      doSau: tin.depth,
      truc: tin.metrics.axis,
      daiCuonDuoc: tin.metrics.maxScrollExtent,
      caoKhungNhin: tin.metrics.viewportDimension,
      viTri: tin.metrics.pixels,
      dich: _tichDich,
    );
    switch (y) {
      case YNav.hien:
        _tichDich = 0;
        _navHien.forward();
      case YNav.giau:
        _tichDich = 0;
        _navHien.reverse();
      case YNav.giuNguyen:
        break;
    }
    // Luôn trả false: thông báo phải đi tiếp lên trên, vì còn thứ khác nghe
    // nó. Nuốt mất là một ngày nào đó có người thêm một bộ nghe nữa rồi ngồi
    // tìm xem vì sao nó không bao giờ chạy.
    return false;
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
      body: NotificationListener<ScrollNotification>(
        onNotification: _theoCuon,
        child: IndexedStack(
          index: chon,
          children: [for (final t in tabs) t.man],
        ),
      ),
      // Đặt ở KHUNG chứ không ở từng màn: có người nhắn lúc đang xem Shop hay
      // Tarot thì vẫn phải với tới được. Nút tự ẩn khi không có buổi nào đang
      // mở chat, nên màn hình của người chưa đặt lịch không bị che gì.
      floatingActionButton: const NutChatNoi(),
      // Thanh trượt khuất xuống dưới mép màn chứ không bị bóp dẹt:
      // neo phần nhìn thấy vào mép TRÊN của thanh, nên thứ bị cắt đi là phần
      // dưới. Bóp dẹt thì chữ và biểu tượng co lại trông như hỏng; trượt
      // xuống thì nó chỉ là đi khuất.
      bottomNavigationBar: SizeTransition(
        sizeFactor: _navHien,
        alignment: Alignment.topCenter,
        child: NavigationBar(
          selectedIndex: chon,
          onDestinationSelected: (i) {
            // Đổi tab thì thanh phải hiện lại. Giữ nguyên trạng thái giấu là
            // người dùng sang màn mới mà không có đường quay ra.
            _navHien.forward();
            setState(() => _chon = i);
            // Ghi tên tab, không ghi chỉ số: số thứ tự đổi theo vai trò
            // (Reader có thêm Bàn làm việc), nên "tab 2" của người này không
            // cùng màn với "tab 2" của người kia.
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
      ),
    );
  }
}
