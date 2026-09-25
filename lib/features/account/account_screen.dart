import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/app_user.dart';
import '../../core/auth/auth_controller.dart';
import '../../theme.dart';
import '../admin/admin_hub.dart';
import '../blog/blog_screen.dart';
import '../profile/profile_screen.dart';
import '../shop/shop_screen.dart';
import '../support/support_screen.dart';

/// Tài khoản, và cũng là cửa vào khu Quản trị.
///
/// Màn này chạy dữ liệu THẬT — nó hiển thị chính xác những gì máy chủ trả về
/// ở `/api/v1/me`, kể cả danh sách quyền. Nhờ vậy nó vừa là màn hồ sơ, vừa là
/// công cụ gỡ lỗi phân quyền: thấy nút nào đó không hiện thì mở đây ra xem
/// máy chủ có cấp quyền ấy không, khỏi phải đoán.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  static const _tenVaiTro = {
    AppRole.guest: 'Khách',
    AppRole.user: 'Người dùng',
    AppRole.staff: 'Nhân viên',
    AppRole.manager: 'Quản lý',
    AppRole.admin: 'Quản trị viên',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = ref.watch(authControllerProvider).user;
    if (u == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Mau.the,
                backgroundImage:
                    (u.avatar != null && u.avatar!.isNotEmpty)
                        ? NetworkImage(u.avatar!)
                        : null,
                child: (u.avatar == null || u.avatar!.isEmpty)
                    ? Text(
                        u.fullName.isNotEmpty
                            ? u.fullName.characters.first.toUpperCase()
                            : '?',
                        style: const TextStyle(fontSize: 22, color: Mau.vang),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u.fullName.isEmpty ? u.username : u.fullName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      u.email ?? u.username,
                      style: const TextStyle(color: Mau.chuMo, fontSize: 12.5),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: Mau.vang.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _tenVaiTro[u.role] ?? '—',
                        style: const TextStyle(fontSize: 11, color: Mau.vang),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),

          if (u.laQuanTri)
            _Muc(
              icon: Icons.shield_outlined,
              nhan: 'Khu quản trị',
              phu: 'Tài khoản, đơn hàng, thanh toán, duyệt Reader',
              onTap: () => _mo(context, const AdminHub()),
            ),

          _Muc(
            icon: Icons.person_outline,
            nhan: 'Hồ sơ cá nhân',
            phu: 'Tên, ảnh đại diện, ngày giờ nơi sinh',
            onTap: () => _mo(context, const ProfileScreen()),
          ),

          _Muc(
            icon: Icons.article_outlined,
            nhan: 'Bài viết',
            phu: 'Kiến thức Tarot và chiêm tinh',
            onTap: () => _mo(context, const BlogScreen()),
          ),

          _Muc(
            icon: Icons.storefront_outlined,
            nhan: 'Gian hàng',
            phu: 'Bài Tarot, sách, vật phẩm chúng tôi chọn lọc',
            onTap: () => _mo(context, const ShopScreen()),
          ),

          _Muc(
            icon: Icons.support_agent_outlined,
            nhan: 'Hỗ trợ',
            phu: 'Gửi yêu cầu và xem phản hồi',
            onTap: () => _mo(context, const SupportScreen()),
          ),

          const SizedBox(height: 22),
          _HopQuyen(quyen: u.permissions),

          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: () =>
                ref.read(authControllerProvider.notifier).dangXuat(),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Đăng xuất'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              foregroundColor: const Color(0xFFE5645E),
              side: const BorderSide(color: Color(0x55E5645E)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _mo(BuildContext context, Widget man) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => man));
  }
}

class _Muc extends StatelessWidget {
  const _Muc({
    required this.icon,
    required this.nhan,
    required this.phu,
    required this.onTap,
  });

  final IconData icon;
  final String nhan;
  final String phu;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Icon(icon, color: Mau.vang, size: 22),
        title: Text(nhan, style: const TextStyle(fontSize: 14.5)),
        subtitle: Text(
          phu,
          style: const TextStyle(color: Mau.chuMo, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: Mau.chuMo, size: 20),
      ),
    );
  }
}

/// Liệt kê quyền máy chủ đã cấp cho phiên này.
class _HopQuyen extends StatelessWidget {
  const _HopQuyen({required this.quyen});

  final Set<String> quyen;

  @override
  Widget build(BuildContext context) {
    final ds = quyen.toList()..sort();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Mau.vien),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quyền máy chủ cấp cho phiên này',
            style: TextStyle(fontSize: 12, color: Mau.chuMo),
          ),
          const SizedBox(height: 4),
          const Text(
            'App không tự suy ra quyền từ vai trò — chỉ hiển thị đúng thứ '
            'backend gửi về.',
            style: TextStyle(fontSize: 11, color: Mau.chuMo, height: 1.5),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final q in ds)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0x33D4AF37)),
                  ),
                  child: Text(
                    q,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10.5,
                      color: Mau.vangNhat,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
