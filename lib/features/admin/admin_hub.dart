import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/app_user.dart';
import '../../core/auth/auth_controller.dart';
import '../../theme.dart';
import '../../widgets/dai_chon.dart';
import 'admin_repository.dart';
import 'hang_cho_views.dart';
import 'nhat_ky_view.dart';
import 'phan_quyen_view.dart';
import 'san_pham_admin_view.dart';
import 'tai_khoan_view.dart';
import 'tong_quan_view.dart';

/// Một mục trong khu quản trị.
class MucQuanTri {
  const MucQuanTri(this.nhan, this.dung);
  final String nhan;
  final Widget Function() dung;
}

/// Các mục người dùng này được thấy — mỗi mục gắn đúng quyền API nó cần.
///
/// ## Vì sao gộp /manager và /admin của web làm một
///
/// Web tách hai trang, nhưng quyền của hai vai trò chồng nhau gần hết. Trên
/// điện thoại, hai mục tên gần giống nhau trong cùng một menu là mời người
/// dùng bấm nhầm. Nên chỉ có một "Khu quản trị", và các mục tự hiện theo quyền
/// máy chủ cấp: Quản lý thấy Nhân sự / Hồ sơ Reader / Báo cáo / Gian hàng,
/// Quản trị viên thấy thêm Tổng quan, tiền, nhật ký và phân quyền.
///
/// Bày một mục rồi bấm vào nhận 403 là giao diện nói dối người dùng — nên
/// điều kiện ở đây khớp từng dòng `@PreAuthorize` của backend.
List<MucQuanTri> mucQuanTri(AppUser u) {
  final quanTriVien = u.co('USERS_MANAGE');
  return [
    if (quanTriVien || u.co('AUDIT_VIEW'))
      MucQuanTri('Tổng quan', () => const TongQuanView()),
    if (quanTriVien || u.co('STAFF_VIEW'))
      MucQuanTri(
        quanTriVien ? 'Tài khoản' : 'Nhân sự',
        () => TaiKhoanView(
          // Quản lý chỉ cất nhắc thành viên lên nhân viên hoặc ngược lại;
          // đổi vai trò của quản lý và quản trị viên là việc của quản trị viên.
          vaiTroGanDuoc:
              quanTriVien ? vaiTroTaiKhoan : const ['USER', 'STAFF'],
          taoDuoc: quanTriVien || u.co('STAFF_MANAGE'),
        ),
      ),
    if (u.co('ADMIN_READERS_VIEW'))
      MucQuanTri('Hồ sơ Reader',
          () => DonReaderView(xetDuoc: u.co('ADMIN_READERS_REVIEW'))),
    if (u.co('PAYMENTS_MANAGE'))
      MucQuanTri('Thanh toán', () => const ThanhToanView()),
    if (u.co('PAYOUT_REVIEW'))
      MucQuanTri('Rút tiền', () => const RutTienView()),
    if (u.co('REPORT_REVIEW'))
      MucQuanTri('Báo cáo vi phạm', () => const BaoCaoView()),
    if (u.co('AUDIT_VIEW'))
      MucQuanTri('Nhật ký', () => const NhatKyView()),
    if (quanTriVien)
      MucQuanTri('Phân quyền', () => const PhanQuyenView()),
    if (u.co('CATALOG_MANAGE'))
      MucQuanTri('Sản phẩm liên kết', () => const SanPhamAdminView()),
  ];
}

/// Khu quản trị, mở từ tab Tài khoản.
class AdminHub extends ConsumerStatefulWidget {
  const AdminHub({super.key});

  @override
  ConsumerState<AdminHub> createState() => _AdminHubState();
}

class _AdminHubState extends ConsumerState<AdminHub> {
  int _chon = 0;

  @override
  Widget build(BuildContext context) {
    final u = ref.watch(authControllerProvider).user;
    if (u == null) return const SizedBox.shrink();
    final muc = mucQuanTri(u);

    if (muc.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Khu quản trị')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(30),
            child: Text(
              'Tài khoản của bạn không có quyền quản trị nào.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Mau.chuMo, fontSize: 13),
            ),
          ),
        ),
      );
    }

    // Quyền có thể đổi giữa phiên, làm số mục ít đi. Không kẹp thì chỉ số cũ
    // trỏ ra ngoài mảng và app đổ.
    final chon = _chon.clamp(0, muc.length - 1);

    return Scaffold(
      appBar: AppBar(
        title: Text(u.co('USERS_MANAGE') ? 'Quản trị' : 'Quản lý'),
        bottom: muc.length < 2
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(46),
                child: DaiChon(
                  cuon: true,
                  nhan: [for (final m in muc) m.nhan],
                  chon: chon,
                  khiChon: (i) => setState(() => _chon = i),
                ),
              ),
      ),
      // Chỉ dựng mục đang chọn: dựng cả chín cùng lúc là chín loạt gọi API
      // mỗi lần mở khu quản trị, trên máy chủ gói free.
      body: KeyedSubtree(key: ValueKey(muc[chon].nhan), child: muc[chon].dung()),
    );
  }
}
