import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/ngon_ngu.dart';
import '../../theme.dart';
import 'khuyen_mai_repository.dart';

/// Hiện lời chúc dịp lễ một lần, ngay sau khi vào được khung chính.
///
/// ## Vì sao "một lần" do máy chủ quyết
///
/// Ghi một cờ vào bộ nhớ máy là cách rẻ nhất, và hỏng theo ba đường người
/// dùng gặp thường xuyên: cài lại app, đổi điện thoại, hoặc xoá dữ liệu ứng
/// dụng — lần nào cũng lại thấy lời chúc Tết. Ngược lại, hai tài khoản đăng
/// nhập trên cùng một máy thì người thứ hai không bao giờ được chúc.
///
/// Máy chủ giữ sổ theo `user_id`, và một lượt gọi vừa trả lời chúc vừa đánh
/// dấu đã xem. App không phải báo lại "tôi đã hiện rồi" — app có thể bị đóng
/// giữa chừng, và lần sau lời chúc lại hiện.
///
/// ## Vì sao đặt ở khung chứ không ở màn hình nào
///
/// Người dùng vào app rơi vào tab nào là tuỳ vai trò. Gắn vào một màn cụ thể
/// thì Reader hay Nhân viên không bao giờ thấy.
Future<void> hienLoiChucNeuCo(BuildContext context, WidgetRef ref) async {
  KhuyenMai? dot;
  try {
    dot = await ref.read(khuyenMaiRepositoryProvider).loiChuc();
  } catch (_) {
    // Không chúc được thì thôi. Đây là thứ làm vui thêm, không được phép
    // chắn đường ai vào app.
    return;
  }
  if (dot == null) return;
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (_) => _HopLoiChuc(dot: dot!),
  );
}

class _HopLoiChuc extends StatelessWidget {
  const _HopLoiChuc({required this.dot});

  final KhuyenMai dot;

  String get _moTaGiam {
    final phan = dot.loaiGiam == 'PHAN_TRAM'
        ? 'Dịp này giảm ${dot.giaTri}% gói AI'
        : 'Dịp này giảm ${Dinh.tien(dot.giaTri)} gói AI';
    final tran = dot.giamToiDa != null
        ? ', tối đa ${Dinh.tien(dot.giamToiDa!)}'
        : '';
    return '$phan$tran.';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Mau.the,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Mau.vang.withValues(alpha: 0.4)),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('✦', style: TextStyle(fontSize: 32, color: Mau.vang)),
          const SizedBox(height: 8),
          Text(
            dot.ten,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Mau.vang,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            dot.loiChuc ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(height: 1.5),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Mau.vang.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Mau.vang.withValues(alpha: 0.25)),
            ),
            child: Text(
              _moTaGiam,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Mau.vang),
            ),
          ),
        ],
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Mau.vang),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(Ngu.d('Cảm ơn')),
          ),
        ),
      ],
    );
  }
}
