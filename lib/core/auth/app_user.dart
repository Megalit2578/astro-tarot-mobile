/// Vai trò dùng trong giao diện. `guest` = chưa đăng nhập, không có trong DB.
enum AppRole { guest, user, staff, manager, admin }

AppRole appRoleFrom(String? role) {
  switch (role) {
    case 'ADMIN':
      return AppRole.admin;
    case 'MANAGER':
      return AppRole.manager;
    case 'STAFF':
      return AppRole.staff;
    case 'USER':
      return AppRole.user;
    // 'READER' đã bị gộp vào STAFF ở migration V2_15 và backend không còn
    // sinh ra giá trị đó. Giữ nhánh này vì kho token của máy có thể còn phiên
    // cũ; trả guest ở đây là khoá sạch giao diện của họ mà không ai đoán ra
    // phải đăng xuất rồi đăng nhập lại.
    case 'READER':
      return AppRole.staff;
    default:
      return AppRole.guest;
  }
}

/// Người dùng đang đăng nhập.
///
/// ## Vì sao ở đây KHÔNG có bảng vai-trò → quyền
///
/// Backend đã trả thẳng danh sách `permissions` trong phản hồi đăng nhập và ở
/// `GET /api/v1/me`. Bên web có một bản sao của bảng ấy, kèm chú thích "sửa
/// một bên thì phải sửa bên kia" — chép thêm lần nữa sang đây là tạo bản sao
/// thứ BA của cùng một sự thật, và bản sao thứ ba chắc chắn sẽ lệch trước
/// tiên vì nó ít được đụng tới nhất.
///
/// Lệch theo hướng nào cũng tệ: thừa quyền thì app bày ra những nút bấm vào
/// nhận 403; thiếu quyền thì tính năng biến mất mà không ai hiểu vì sao.
///
/// Nên ở đây chỉ TIÊU THỤ thứ máy chủ gửi. Không đoán, không suy ra từ vai
/// trò. Xem [AppUser.co].
class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.permissions,
    this.email,
    this.avatar,
  });

  final String id;
  final String username;
  final String fullName;
  final String? email;
  final String? avatar;
  final AppRole role;
  final Set<String> permissions;

  /// Quyền tối thiểu khi máy chủ không gửi kèm `permissions`.
  ///
  /// Cố tình hẹp: chỉ đủ dùng những thứ cơ bản. Đoán rộng ra là bày nhầm cả
  /// màn quản trị cho người không có quyền, rồi mọi thao tác đều 403 — tệ hơn
  /// hẳn so với việc thiếu vài mục cho tới lần gọi `/me` kế tiếp.
  static const Set<String> _toiThieu = {'USER_BASIC'};

  factory AppUser.fromJson(Map<String, dynamic> j) {
    final raw = j['permissions'];
    final ds = raw is List ? raw.whereType<String>().toSet() : null;
    return AppUser(
      id: (j['userId'] ?? j['id']) as String,
      username: (j['username'] ?? '') as String,
      fullName: (j['fullName'] ?? j['full_name'] ?? '') as String,
      email: j['email'] as String?,
      avatar: j['avatar'] as String?,
      role: appRoleFrom(j['role'] as String?),
      permissions: (ds == null || ds.isEmpty) ? _toiThieu : ds,
    );
  }

  bool co(String quyen) => permissions.contains(quyen);
  bool coBatKy(Iterable<String> ds) => ds.any(co);

  /// Có bàn làm việc nhân viên/Reader không.
  bool get laNhanSu => coBatKy(const [
        'SUPPORT_VIEW',
        'READER_MANAGE_PROFILE',
        'STAFF_VIEW',
      ]);

  /// Có khu quản trị không.
  ///
  /// Khớp đúng các mục trong `mucQuanTri` — thiếu một quyền ở đây là Quản lý
  /// chỉ có REPORT_REVIEW sẽ không bao giờ thấy cửa vào hàng chờ báo cáo.
  bool get laQuanTri => coBatKy(const [
        'USERS_MANAGE',
        'AUDIT_VIEW',
        'STAFF_VIEW',
        'ADMIN_READERS_VIEW',
        'PAYMENTS_MANAGE',
        'PAYOUT_REVIEW',
        'REPORT_REVIEW',
        'CATALOG_MANAGE',
      ]);
}
