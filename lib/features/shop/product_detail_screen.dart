import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../theme.dart';
import '../../widgets/trang_thai.dart';
import 'shop_repository.dart';
import 'shop_screen.dart';

/// Chi tiết một sản phẩm, khớp trang `/shop/$slug` của web.
///
/// Nhận sẵn bản trong danh sách ([banDau]) để vẽ ngay, rồi mới nạp bản đầy
/// đủ — bấm vào thẻ mà thấy vòng quay trắng một giây là cảm giác app chậm,
/// dù dữ liệu cần thấy trước đã có trong tay.
class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.slug, this.banDau});

  final String slug;
  final SanPham? banDau;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ct = ref.watch(chiTietSanPhamProvider(slug));
    final p = ct.asData?.value ?? banDau;

    return Scaffold(
      appBar: AppBar(title: Text(p?.ten ?? 'Sản phẩm')),
      body: RefreshIndicator(
        color: Mau.vang,
        backgroundColor: Mau.the,
        onRefresh: () => ref.refresh(chiTietSanPhamProvider(slug).future),
        child: p == null
            ? (ct.hasError
                ? KhoiTrong(
                    icon: Icons.search_off,
                    tieuDe: 'Không tìm thấy sản phẩm',
                    moTa: ct.error is ApiException
                        ? (ct.error as ApiException).message
                        : 'Sản phẩm này có thể đã ngừng bán hoặc đường dẫn '
                            'không đúng.',
                    hanhDong: OutlinedButton(
                      onPressed: () =>
                          ref.invalidate(chiTietSanPhamProvider(slug)),
                      child: const Text('Thử lại'),
                    ),
                  )
                : const Center(
                    child: CircularProgressIndicator(color: Mau.vang)))
            : _ThanChiTiet(p: p),
      ),
    );
  }
}

class _ThanChiTiet extends StatelessWidget {
  const _ThanChiTiet({required this.p});
  final SanPham p;

  @override
  Widget build(BuildContext context) {
    final anh = p.anhDayDu;
    final giam = p.phanTramGiam;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: anh == null
                    ? Container(
                        color: const Color(0xFF0F0F16),
                        child: const Icon(Icons.auto_awesome,
                            size: 56, color: Mau.vien),
                      )
                    : Image.network(
                        anh,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: const Color(0xFF0F0F16),
                          child: const Icon(Icons.image_not_supported_outlined,
                              size: 40, color: Mau.chuMo),
                        ),
                      ),
              ),
              if (giam != null)
                Positioned(
                  left: 12,
                  top: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Mau.vang,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('-$giam%',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1206))),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (p.danhMuc != null)
          Text(p.danhMuc!.toUpperCase(),
              style: TextStyle(
                  fontSize: 10.5,
                  letterSpacing: 2,
                  color: Mau.vang.withValues(alpha: 0.75))),
        const SizedBox(height: 6),
        Text(p.ten,
            style: const TextStyle(
                fontSize: 22, height: 1.3, fontWeight: FontWeight.w500)),
        const SizedBox(height: 12),
        GiaSanPham(p: p, co: 22),
        // Không hiện tồn kho: hàng nằm trên sàn, mình không biết còn bao
        // nhiêu. Đoán sai hướng "còn hàng" thì khách bấm sang mới biết hết.
        if ((p.luotBam ?? 0) > 0) ...[
          const SizedBox(height: 6),
          Text('${p.luotBam} lượt xem trên sàn',
              style: const TextStyle(fontSize: 11.5, color: Mau.chuMo)),
        ],
        if (p.anhMinhHoa && anh != null) ...[
          const SizedBox(height: 8),
          const Text(
            'Ảnh mang tính minh hoạ — hàng thật có thể khác đôi chút.',
            style: TextStyle(fontSize: 11.5, color: Mau.chuMo),
          ),
        ],
        if (p.moTa != null && p.moTa!.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(p.moTa!,
              style: const TextStyle(
                  fontSize: 13.5, color: Mau.chuMo, height: 1.65)),
        ],
        const SizedBox(height: 22),
        NutMuaTrenSan(p: p, cao: 52),
        const SizedBox(height: 14),
        const Text(loiCongBoTiepThi,
            style: TextStyle(fontSize: 11, color: Mau.chuMo, height: 1.6)),
      ],
    );
  }
}
