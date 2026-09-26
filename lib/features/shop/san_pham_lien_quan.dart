import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme.dart';
import 'shop_repository.dart';
import 'shop_screen.dart';

/// Vài sản phẩm cùng danh mục, gắn vào chỗ người dùng vừa làm xong một việc.
///
/// Gian hàng là liên kết tiếp thị: mình giới thiệu, người ta mua trên sàn,
/// mình ăn hoa hồng. Nên chỗ đặt gợi ý quan trọng ngang nội dung gợi ý — đặt
/// sau khi người dùng vừa rút một lá bài thì liên hệ là có thật, không phải
/// quảng cáo chen ngang.
///
/// Khớp `RelatedProducts` của web, gồm cả cách ẩn: chưa tải xong hoặc không
/// có gì thì **ẩn hẳn**, không chừa khoảng trống. Một ô rỗng giữa trang trông
/// như lỗi tải, và nó đẩy phần nội dung thật xuống dưới màn hình.
class SanPhamLienQuan extends ConsumerWidget {
  const SanPhamLienQuan({
    super.key,
    required this.tieuDe,
    this.danhMucSlug,
    this.goiY,
    this.soLuong = 2,
  });

  final String tieuDe;

  /// Lọc theo danh mục. Bỏ trống thì lấy sản phẩm bất kỳ.
  final String? danhMucSlug;

  /// Một câu nói rõ vì sao gợi ý này liên quan. Không có thì bỏ dòng ấy đi
  /// chứ không hiện chuỗi rỗng.
  final String? goiY;

  /// Hai thẻ vừa một hàng trên điện thoại. Web để ba vì màn rộng hơn.
  final int soLuong;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = ref.watch(sanPhamGoiYProvider(danhMucSlug));
    final list = ds.asData?.value ?? const [];
    if (list.isEmpty) return const SizedBox.shrink();

    final hien = list.take(soLuong).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: Mau.vien, height: 1),
          const SizedBox(height: 14),
          Text(tieuDe,
              style: const TextStyle(fontSize: 14.5, color: Mau.vangNhat)),
          if (goiY != null) ...[
            const SizedBox(height: 4),
            Text(goiY!,
                style: const TextStyle(
                    fontSize: 11.5, color: Mau.chuMo, height: 1.5)),
          ],
          const SizedBox(height: 10),
          // IntrinsicHeight để hai thẻ cùng hàng cao bằng nhau dù tên sản phẩm
          // dài ngắn khác nhau — lệch nhau trông như lỗi dựng.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < hien.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: TheSanPham(p: hien[i])),
                ],
                // Lẻ một thẻ thì chừa chỗ trống bên phải, không kéo thẻ duy
                // nhất ra rộng cả hàng.
                if (hien.length < soLuong) ...[
                  const SizedBox(width: 10),
                  for (var i = hien.length; i < soLuong; i++)
                    const Expanded(child: SizedBox.shrink()),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sản phẩm gợi ý theo danh mục. `family` để mỗi danh mục có cache riêng.
final sanPhamGoiYProvider =
    FutureProvider.family<List<SanPham>, String?>((ref, danhMuc) async {
  final t = await ref
      .watch(shopRepositoryProvider)
      .sanPham(danhMuc: danhMuc, trang: 0);
  return t.muc;
});
