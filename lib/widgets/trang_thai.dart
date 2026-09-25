import 'package:flutter/material.dart';

import '../theme.dart';

/// Khối báo lỗi kèm nút thử lại.
///
/// Luôn có nút thử lại, và luôn nói lý do bằng câu máy chủ gửi về. Màn hình
/// lỗi không có đường đi tiếp là ngõ cụt: người dùng chỉ còn cách thoát app.
class KhoiLoi extends StatelessWidget {
  const KhoiLoi({super.key, required this.thongDiep, required this.thuLai});

  final String thongDiep;
  final VoidCallback thuLai;

  @override
  Widget build(BuildContext context) {
    return ListView(
      // ListView chứ không phải Center: để RefreshIndicator bao ngoài vẫn kéo
      // xuống được khi màn hình đang ở trạng thái lỗi — đó chính là lúc người
      // dùng muốn thử lại nhất.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(28, 80, 28, 28),
      children: [
        const Icon(Icons.cloud_off, size: 38, color: Mau.chuMo),
        const SizedBox(height: 16),
        Text(
          thongDiep,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13.5, height: 1.6),
        ),
        const SizedBox(height: 22),
        Center(
          child: OutlinedButton.icon(
            onPressed: thuLai,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Thử lại'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Mau.vang,
              side: const BorderSide(color: Mau.vien),
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Khối "chưa có gì" — khác hẳn khối lỗi.
///
/// Tách riêng vì hai chuyện khác nhau hoàn toàn: danh sách rỗng là bình
/// thường, còn lỗi là hỏng. Gộp chung thì người dùng thấy "không tải được"
/// trong khi thật ra chỉ là chưa có dữ liệu — hoặc ngược lại, tệ hơn: thấy
/// "chưa có gì" trong khi máy chủ đang hỏng.
class KhoiTrong extends StatelessWidget {
  const KhoiTrong({
    super.key,
    required this.icon,
    required this.tieuDe,
    this.moTa,
    this.hanhDong,
  });

  final IconData icon;
  final String tieuDe;
  final String? moTa;
  final Widget? hanhDong;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(28, 90, 28, 28),
      children: [
        Icon(icon, size: 38, color: Mau.vang.withValues(alpha: 0.5)),
        const SizedBox(height: 16),
        Text(
          tieuDe,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        if (moTa != null) ...[
          const SizedBox(height: 8),
          Text(
            moTa!,
            textAlign: TextAlign.center,
            style:
                const TextStyle(color: Mau.chuMo, fontSize: 13, height: 1.6),
          ),
        ],
        if (hanhDong != null) ...[
          const SizedBox(height: 22),
          Center(child: hanhDong!),
        ],
      ],
    );
  }
}
