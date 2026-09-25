import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/endpoints.dart';
import '../../core/auth/app_user.dart';
import '../../core/auth/auth_controller.dart';
import '../../theme.dart';
import 'admin_models.dart';
import 'hang_cho_screen.dart';

/// Cửa vào khu quản trị.
///
/// Mỗi mục chỉ hiện khi tài khoản **thật sự có quyền** tương ứng, và quyền
/// lấy từ danh sách máy chủ gửi chứ không suy từ vai trò. Bày ra một mục rồi
/// bấm vào nhận 403 là kiểu giao diện nói dối người dùng.
class AdminHub extends ConsumerWidget {
  const AdminHub({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = ref.watch(authControllerProvider).user;
    if (u == null) return const SizedBox.shrink();

    final muc = <Widget>[
      if (u.co('PAYMENTS_MANAGE'))
        _Muc(
          icon: Icons.payments_outlined,
          nhan: 'Đối soát thanh toán',
          phu: 'Xác nhận hoặc từ chối giao dịch khách đã trả',
          man: HangChoScreen(
            tieuDe: 'Đối soát thanh toán',
            duong: Endpoints.adminPayments,
            moTaTrong: 'Không có giao dịch nào đang chờ đối soát.',
            hanhDong: [
              HanhDongDuyet(
                nhan: 'Xác nhận',
                duong: Endpoints.adminPaymentConfirm,
              ),
              HanhDongDuyet(
                nhan: 'Từ chối',
                duong: Endpoints.adminPaymentReject,
                nguyHiem: true,
                hoiLyDo: true,
                body: (lyDo) => {'reason': lyDo},
              ),
            ],
          ),
        ),

      if (u.co('PAYOUT_REVIEW'))
        _Muc(
          icon: Icons.account_balance_outlined,
          nhan: 'Yêu cầu rút tiền',
          phu: 'Duyệt, từ chối, hoặc đánh dấu đã chi cho Reader',
          man: HangChoScreen(
            tieuDe: 'Yêu cầu rút tiền',
            duong: Endpoints.adminPayouts,
            moTaTrong: 'Không có yêu cầu rút tiền nào đang chờ.',
            hanhDong: [
              HanhDongDuyet(
                nhan: 'Duyệt',
                duong: Endpoints.adminPayoutApprove,
              ),
              HanhDongDuyet(
                nhan: 'Đã chi',
                duong: Endpoints.adminPayoutPaid,
              ),
              HanhDongDuyet(
                nhan: 'Từ chối',
                duong: Endpoints.adminPayoutReject,
                nguyHiem: true,
                hoiLyDo: true,
                body: (lyDo) => {'reason': lyDo},
              ),
            ],
          ),
        ),

      if (u.co('ADMIN_READERS_REVIEW'))
        _Muc(
          icon: Icons.how_to_reg_outlined,
          nhan: 'Duyệt đơn Reader',
          phu: 'Hồ sơ người ngoài xin làm Reader',
          man: HangChoScreen(
            tieuDe: 'Duyệt đơn Reader',
            duong: Endpoints.adminReaderApplications,
            moTaTrong: 'Không có đơn nào đang chờ duyệt.',
            hanhDong: [
              HanhDongDuyet(
                nhan: 'Duyệt',
                duong: Endpoints.adminReaderReview,
                body: (_) => {'action': 'APPROVED'},
              ),
              HanhDongDuyet(
                nhan: 'Từ chối',
                duong: Endpoints.adminReaderReview,
                nguyHiem: true,
                hoiLyDo: true,
                body: (lyDo) => {'action': 'REJECTED', 'reason': lyDo},
              ),
            ],
          ),
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Khu quản trị')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        children: [
          const Text(
            'Ba hàng chờ dưới đây là việc gắn với thời điểm — khách đang đợi '
            'được xác nhận, Reader đang đợi được chi tiền. Phần còn lại của '
            'khu quản trị (tài khoản, đơn hàng, gian hàng, nhật ký) làm trên '
            'web tiện hơn nhiều.',
            style: TextStyle(color: Mau.chuMo, fontSize: 12.5, height: 1.6),
          ),
          const SizedBox(height: 20),
          if (muc.isEmpty)
            const Text(
              'Tài khoản của bạn không có quyền quản trị nào trong nhóm này.',
              style: TextStyle(fontSize: 13, color: Mau.chuMo),
            )
          else
            ...muc,
          const SizedBox(height: 22),
          _Quyen(u: u),
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
    required this.man,
  });

  final IconData icon;
  final String nhan;
  final String phu;
  final Widget man;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => man)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Icon(icon, color: Mau.vang, size: 22),
        title: Text(nhan, style: const TextStyle(fontSize: 14.5)),
        subtitle: Text(phu,
            style: const TextStyle(color: Mau.chuMo, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: Mau.chuMo, size: 20),
      ),
    );
  }
}

class _Quyen extends StatelessWidget {
  const _Quyen({required this.u});
  final AppUser u;

  @override
  Widget build(BuildContext context) {
    final ds = u.permissions.toList()..sort();
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Mau.vien),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quyền máy chủ cấp cho phiên này',
              style: TextStyle(fontSize: 11.5, color: Mau.chuMo)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final q in ds)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0x33D4AF37)),
                  ),
                  child: Text(q,
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: Mau.vangNhat)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
