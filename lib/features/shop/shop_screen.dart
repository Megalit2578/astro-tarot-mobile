import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/trang_thai.dart';
import 'shop_repository.dart';

class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = ref.watch(sanPhamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gian hàng')),
      body: RefreshIndicator(
        color: Mau.vang,
        backgroundColor: Mau.the,
        onRefresh: () => ref.refresh(sanPhamProvider.future),
        child: ds.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: Mau.vang)),
          error: (e, _) => KhoiLoi(
            thongDiep: e is ApiException
                ? e.message
                : 'Không tải được gian hàng.',
            thuLai: () => ref.invalidate(sanPhamProvider),
          ),
          data: (list) => list.isEmpty
              ? const KhoiTrong(
                  icon: Icons.storefront_outlined,
                  tieuDe: 'Gian hàng đang trống',
                  moTa: 'Chưa có sản phẩm nào được đưa lên.',
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  children: [
                    // Nói thẳng đây là liên kết tiếp thị. Người dùng có quyền
                    // biết mình sắp rời app sang sàn khác, và biết rằng chúng
                    // ta hưởng hoa hồng.
                    const Text(
                      'Đây là những món chúng tôi chọn lọc. Bấm mua sẽ mở '
                      'sàn thương mại điện tử; chúng tôi nhận hoa hồng cho '
                      'mỗi đơn, còn giá bạn trả không đổi.',
                      style: TextStyle(
                          fontSize: 11.5, color: Mau.chuMo, height: 1.6),
                    ),
                    const SizedBox(height: 14),
                    for (final p in list) _TheSanPham(p: p),
                  ],
                ),
        ),
      ),
    );
  }
}

class _TheSanPham extends ConsumerStatefulWidget {
  const _TheSanPham({required this.p});
  final SanPham p;

  @override
  ConsumerState<_TheSanPham> createState() => _TheSanPhamState();
}

class _TheSanPhamState extends ConsumerState<_TheSanPham> {
  bool _dangMo = false;

  Future<void> _mua() async {
    final p = widget.p;
    final url = p.lienKet;
    if (url == null || url.isEmpty) return;
    setState(() => _dangMo = true);
    try {
      // Ghi nhận TRƯỚC khi mở, nhưng không chờ kết quả quyết định: xem chú
      // thích ở ShopRepository.ghiNhanBam.
      await ref.read(shopRepositoryProvider).ghiNhanBam(p.id);
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Không mở được liên kết.'),
              backgroundColor: Mau.the),
        );
      }
    } finally {
      if (mounted) setState(() => _dangMo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final anh = p.anhDayDu;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (anh != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      anh,
                      height: 74,
                      width: 74,
                      fit: BoxFit.cover,
                      // Ảnh hỏng thì để ô trống có viền, đừng để biểu tượng
                      // vỡ của hệ thống — nó trông như app lỗi.
                      errorBuilder: (_, _, _) => Container(
                        height: 74,
                        width: 74,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F0F16),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Mau.vien),
                        ),
                        child: const Icon(Icons.image_not_supported_outlined,
                            size: 20, color: Mau.chuMo),
                      ),
                    ),
                  ),
                if (anh != null) const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.ten,
                          style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              height: 1.35)),
                      if (p.danhMuc != null) ...[
                        const SizedBox(height: 3),
                        Text(p.danhMuc!,
                            style: const TextStyle(
                                fontSize: 11, color: Mau.chuMo)),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(Dinh.tien(p.gia),
                              style: const TextStyle(
                                  fontSize: 15,
                                  color: Mau.vang,
                                  fontWeight: FontWeight.w600)),
                          if (p.coGiamGia) ...[
                            const SizedBox(width: 8),
                            Text(
                              Dinh.tien(p.giaGoc),
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Mau.chuMo,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (p.moTa != null && p.moTa!.trim().isNotEmpty) ...[
              const SizedBox(height: 11),
              Text(p.moTa!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12.5, color: Mau.chuMo, height: 1.55)),
            ],
            if (p.anhMinhHoa) ...[
              const SizedBox(height: 8),
              const Text(
                'Ảnh mang tính minh hoạ',
                style: TextStyle(fontSize: 10.5, color: Mau.chuMo),
              ),
            ],
            const SizedBox(height: 12),
            if (p.lienKet != null && p.lienKet!.isNotEmpty)
              FilledButton.icon(
                onPressed: _dangMo ? null : _mua,
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(
                  p.san == null || p.san!.isEmpty
                      ? 'Mua trên sàn liên kết'
                      // Nói TÊN sàn: người dùng cần biết mình sắp mở ứng dụng
                      // nào trước khi rời app.
                      : 'Mua trên ${_tenSan(p.san!)}',
                ),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44)),
              )
            else
              const Text('Món này chưa có liên kết mua.',
                  style: TextStyle(fontSize: 11.5, color: Mau.chuMo)),
          ],
        ),
      ),
    );
  }

  static String _tenSan(String s) => switch (s.toUpperCase()) {
        'SHOPEE' => 'Shopee',
        'LAZADA' => 'Lazada',
        'TIKI' => 'Tiki',
        'TIKTOK' => 'TikTok Shop',
        _ => s,
      };
}
