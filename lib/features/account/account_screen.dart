import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/app_user.dart';
import '../../core/auth/auth_controller.dart';
import '../../theme.dart';
import '../admin/admin_hub.dart';
import '../astrology/astrology_screen.dart';
import '../blog/blog_screen.dart';
import '../feedback/feedback_screen.dart';
import '../profile/profile_screen.dart';
import '../readerapply/reader_apply_screen.dart';
import '../shop/shop_screen.dart';
import '../support/support_screen.dart';
import '../tarot/tarot_history_screen.dart';

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
          const SizedBox(height: 22),

          // Khu quản trị đứng riêng một thẻ viền vàng: với nhân sự đây là
          // lối vào dùng nhiều nhất, không để lẫn giữa các mục cá nhân.
          if (u.laQuanTri) ...[
            _Nhom(noiBat: true, muc: [
              _Muc(
                icon: Icons.shield_outlined,
                nhan: u.co('USERS_MANAGE') ? 'Khu quản trị' : 'Khu quản lý',
                phu: u.co('USERS_MANAGE')
                    ? 'Tổng quan, tài khoản, tiền, nhật ký, sản phẩm'
                    : 'Nhân sự, hồ sơ Reader, báo cáo, gian hàng',
                onTap: () => _mo(context, const AdminHub()),
              ),
            ]),
            const SizedBox(height: 18),
          ],

          // Gom mục thành nhóm trong một thẻ, ngăn bằng vạch mảnh — kiểu màn
          // Cài đặt trên điện thoại. Mỗi mục một thẻ riêng như trước thì
          // chín mục đã dài hơn hai màn hình.
          const _TieuDeNhom('Của tôi'),
          _Nhom(muc: [
            _Muc(
              icon: Icons.person_outline,
              nhan: 'Hồ sơ cá nhân',
              phu: 'Tên, ảnh đại diện, ngày sinh',
              onTap: () => _mo(context, const ProfileScreen()),
            ),
            _Muc(
              icon: Icons.auto_awesome_outlined,
              nhan: 'Bản đồ sao',
              phu: 'AI đọc bài dựa trên hồ sơ chính',
              onTap: () => _mo(context, const AstrologyScreen()),
            ),
            _Muc(
              icon: Icons.history,
              nhan: 'Lịch sử trải bài',
              phu: 'Xem lại lời giải AI đã lưu',
              onTap: () => _mo(context, const TarotHistoryScreen()),
            ),
            // Nhân sự đã có hồ sơ Reader thì mục này thừa; người dùng thường
            // thì đây là cửa duy nhất để trở thành Reader trên điện thoại.
            if (u.co('READER_APPLY') && !u.co('READER_MANAGE_PROFILE'))
              _Muc(
                icon: Icons.workspace_premium_outlined,
                nhan: 'Đăng ký làm Reader',
                phu: 'Nộp đơn hoặc xem trạng thái đơn',
                onTap: () => _mo(context, const ReaderApplyScreen()),
              ),
          ]),

          const SizedBox(height: 18),
          const _TieuDeNhom('Khám phá'),
          _Nhom(muc: [
            _Muc(
              icon: Icons.article_outlined,
              nhan: 'Bài viết',
              phu: 'Kiến thức Tarot và chiêm tinh',
              onTap: () => _mo(context, const BlogScreen()),
            ),
            _Muc(
              icon: Icons.storefront_outlined,
              nhan: 'Gian hàng',
              phu: 'Bài Tarot, đá, phụ kiện chọn lọc',
              onTap: () => _mo(context, const ShopScreen()),
            ),
          ]),

          const SizedBox(height: 18),
          const _TieuDeNhom('Trợ giúp'),
          _Nhom(muc: [
            _Muc(
              icon: Icons.support_agent_outlined,
              nhan: 'Hỗ trợ',
              phu: 'Gửi yêu cầu và xem phản hồi',
              onTap: () => _mo(context, const SupportScreen()),
            ),
            if (ref.watch(tinhTrangGopYProvider).asData?.value?.daGui != true)
              _Muc(
                icon: Icons.rate_review_outlined,
                nhan: 'Góp ý',
                phu: 'Khảo sát ngắn — ASTROTAROT có giúp bạn không?',
                onTap: () => _mo(context, const FeedbackScreen()),
              ),
          ]),

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

class _TieuDeNhom extends StatelessWidget {
  const _TieuDeNhom(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
              fontSize: 11, letterSpacing: 1.2, color: Mau.chuMo),
        ),
      );
}

/// Một thẻ chứa nhiều mục, ngăn bằng vạch mảnh.
class _Nhom extends StatelessWidget {
  const _Nhom({required this.muc, this.noiBat = false});
  final List<_Muc> muc;
  final bool noiBat;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: noiBat ? Mau.vang.withValues(alpha: 0.5) : Mau.vien),
      ),
      child: Column(
        children: [
          for (var i = 0; i < muc.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 1, indent: 52,
                  color: Color(0x1FD4AF37)),
            muc[i],
          ],
        ],
      ),
    );
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
    return ListTile(
      onTap: onTap,
      dense: true,
      minLeadingWidth: 22,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      leading: Icon(icon, color: Mau.vang, size: 21),
      title: Text(nhan, style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        phu,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Mau.chuMo, fontSize: 11.5),
      ),
      trailing: const Icon(Icons.chevron_right, color: Mau.chuMo, size: 20),
    );
  }
}

/// Liệt kê quyền máy chủ đã cấp cho phiên này.
///
/// Gập sẵn: với người dùng thường đây là chữ kỹ thuật, chiếm nửa màn hình
/// mà không giúp gì. Người gỡ lỗi phân quyền bấm một cái là mở ra.
class _HopQuyen extends StatelessWidget {
  const _HopQuyen({required this.quyen});

  final Set<String> quyen;

  @override
  Widget build(BuildContext context) {
    final ds = quyen.toList()..sort();
    // Material chứ không Container tô màu: ô bấm mở vẽ gợn sóng lên
    // Material gần nhất, nền tô ở tầng giữa sẽ che mất.
    return Material(
      color: const Color(0xFF0F0F16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Mau.vien),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          dense: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          iconColor: Mau.chuMo,
          collapsedIconColor: Mau.chuMo,
          title: Text(
            'Quyền máy chủ cấp cho phiên này (${ds.length})',
            style: const TextStyle(fontSize: 12, color: Mau.chuMo),
          ),
          children: [
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
      ),
    );
  }
}
