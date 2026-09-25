import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/danh_sach_phan_trang.dart';
import '../../widgets/hop_thoai.dart';
import '../../widgets/trang_thai.dart';
import 'product_detail_screen.dart';
import 'shop_repository.dart';

/// Mở sàn liên kết cho một sản phẩm, sau khi ghi nhận lượt bấm.
///
/// Dùng chung cho thẻ trong danh sách và màn chi tiết — hai nơi tự viết hai
/// kiểu thì sớm muộn một nơi quên ghi nhận lượt bấm, tức là mất hoa hồng.
Future<void> moTrenSan(
  BuildContext context,
  WidgetRef ref,
  SanPham p,
) async {
  final url = await ref
      .read(shopRepositoryProvider)
      .ghiNhanBam(p.slug, duPhong: p.lienKet);
  if (url == null || url.isEmpty) return;
  final ok = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  );
  if (!ok && context.mounted) baoTin(context, 'Không mở được liên kết.');
}

/// Câu nói thẳng đây là liên kết tiếp thị.
///
/// Người dùng có quyền biết mình sắp rời app sang sàn khác, và biết rằng
/// chúng ta hưởng hoa hồng.
const loiCongBoTiepThi =
    'Đây là những món chúng tôi chọn lọc. Bấm mua sẽ mở sàn thương mại điện '
    'tử; chúng tôi nhận hoa hồng cho mỗi đơn, còn giá bạn trả không đổi.';

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  final _tim = TextEditingController();
  Timer? _hen;
  String _tuKhoa = '';
  String _danhMuc = '';

  @override
  void dispose() {
    _hen?.cancel();
    _tim.dispose();
    super.dispose();
  }

  /// Chờ người dùng ngừng gõ một chút rồi mới tìm — mỗi phím một lượt gọi
  /// là dồn tải cho máy chủ gói free vô ích.
  void _khiGo(String v) {
    _hen?.cancel();
    _hen = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _tuKhoa = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final dsDanhMuc = ref.watch(danhMucProvider).asData?.value ?? const [];
    final repo = ref.watch(shopRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gian hàng')),
      body: DanhSachPhanTrang<SanPham>(
        key: ValueKey('shop-$_danhMuc-$_tuKhoa'),
        tai: (t) =>
            repo.sanPham(danhMuc: _danhMuc, tuKhoa: _tuKhoa, trang: t),
        loiDuPhong: 'Không tải được gian hàng.',
        dau: [
          const Text(loiCongBoTiepThi,
              style: TextStyle(fontSize: 11.5, color: Mau.chuMo, height: 1.6)),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('o-tim-san-pham'),
            controller: _tim,
            onChanged: _khiGo,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'Tìm bộ bài, đá, phụ kiện...',
              prefixIcon: Icon(Icons.search, size: 20),
              isDense: true,
            ),
          ),
          if (dsDanhMuc.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _ChipDanhMuc(
                    nhan: 'Tất cả',
                    chon: _danhMuc.isEmpty,
                    bam: () => setState(() => _danhMuc = ''),
                  ),
                  for (final c in dsDanhMuc)
                    _ChipDanhMuc(
                      nhan: c.ten,
                      chon: _danhMuc == c.slug,
                      bam: () => setState(() => _danhMuc = c.slug),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
        ],
        trong: KhoiTrong(
          icon: Icons.storefront_outlined,
          tieuDe: _tuKhoa.isEmpty && _danhMuc.isEmpty
              ? 'Gian hàng đang trống'
              : 'Không có sản phẩm phù hợp',
          moTa: _tuKhoa.isEmpty && _danhMuc.isEmpty
              ? 'Chưa có sản phẩm nào được đưa lên.'
              : 'Thử từ khoá khác hoặc bỏ bộ lọc.',
        ),
        // Hai cột như các app mua sắm: một màn thấy bốn đến sáu món thay vì
        // hai. Mô tả dài để dành cho màn chi tiết.
        cot: 2,
        dong: (_, p) => TheSanPham(p: p),
      ),
    );
  }
}

class _ChipDanhMuc extends StatelessWidget {
  const _ChipDanhMuc({
    required this.nhan,
    required this.chon,
    required this.bam,
  });

  final String nhan;
  final bool chon;
  final VoidCallback bam;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(nhan, style: const TextStyle(fontSize: 12)),
        selected: chon,
        onSelected: (_) => bam(),
        selectedColor: Mau.vang.withValues(alpha: 0.18),
        side: BorderSide(color: chon ? Mau.vang : Mau.vien),
        showCheckmark: false,
      ),
    );
  }
}

/// Ảnh sản phẩm, có ô thay thế khi ảnh hỏng.
class AnhSanPham extends StatelessWidget {
  const AnhSanPham({super.key, required this.url, this.co = 74});

  final String? url;
  final double co;

  @override
  Widget build(BuildContext context) {
    final trong = Container(
      height: co,
      width: co,
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Mau.vien),
      ),
      child: const Icon(Icons.image_not_supported_outlined,
          size: 20, color: Mau.chuMo),
    );
    if (url == null) return trong;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url!,
        height: co,
        width: co,
        fit: BoxFit.cover,
        // Ảnh hỏng thì để ô trống có viền, đừng để biểu tượng vỡ của hệ
        // thống — nó trông như app lỗi.
        errorBuilder: (_, _, _) => trong,
      ),
    );
  }
}

/// Dòng giá, kèm giá gốc gạch ngang khi đang giảm.
class GiaSanPham extends StatelessWidget {
  const GiaSanPham({super.key, required this.p, this.co = 15});

  final SanPham p;
  final double co;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 8,
      children: [
        Text(Dinh.tien(p.gia),
            style: TextStyle(
                fontSize: co, color: Mau.vang, fontWeight: FontWeight.w600)),
        if (p.coGiamGia)
          Text(
            Dinh.tien(p.giaGoc),
            style: const TextStyle(
              fontSize: 11.5,
              color: Mau.chuMo,
              decoration: TextDecoration.lineThrough,
            ),
          ),
      ],
    );
  }
}

/// Nút "Mua trên …". Tự khoá khi đang mở để khỏi bấm hai lần ra hai lượt.
class NutMuaTrenSan extends ConsumerStatefulWidget {
  const NutMuaTrenSan(
      {super.key, required this.p, this.cao = 44, this.gon = false});

  final SanPham p;
  final double cao;

  /// Bản gọn cho thẻ trong lưới: chữ nhỏ hơn, lề hẹp.
  final bool gon;

  @override
  ConsumerState<NutMuaTrenSan> createState() => _NutMuaTrenSanState();
}

class _NutMuaTrenSanState extends ConsumerState<NutMuaTrenSan> {
  bool _dangMo = false;

  Future<void> _mua() async {
    setState(() => _dangMo = true);
    try {
      await moTrenSan(context, ref, widget.p);
    } finally {
      if (mounted) setState(() => _dangMo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    if (!p.coLienKet) {
      return const Text('Món này chưa có liên kết mua.',
          style: TextStyle(fontSize: 11.5, color: Mau.chuMo));
    }
    return FilledButton.icon(
      onPressed: _dangMo ? null : _mua,
      icon: Icon(Icons.open_in_new, size: widget.gon ? 14 : 16),
      // Nói TÊN sàn: người dùng cần biết mình sắp mở ứng dụng nào trước khi
      // rời app.
      label: Text('Mua trên ${tenSan(p.san)}',
          maxLines: 1, overflow: TextOverflow.ellipsis),
      style: FilledButton.styleFrom(
        minimumSize: Size.fromHeight(widget.cao),
        padding: widget.gon ? const EdgeInsets.symmetric(horizontal: 8) : null,
        textStyle: widget.gon
            ? const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)
            : null,
      ),
    );
  }
}

/// Thẻ một sản phẩm trong lưới hai cột. Bấm thẻ mở màn chi tiết.
class TheSanPham extends StatelessWidget {
  const TheSanPham({super.key, required this.p});
  final SanPham p;

  @override
  Widget build(BuildContext context) {
    final anh = p.anhDayDu;
    final giam = p.phanTramGiam;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ProductDetailScreen(slug: p.slug, banDau: p))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _AnhVuong(url: anh),
                  if (giam != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _Nhan('-$giam%',
                          nen: Mau.vang, chu: const Color(0xFF1A1206)),
                    ),
                  if (p.anhMinhHoa)
                    const Positioned(
                      left: 8,
                      bottom: 8,
                      child: _Nhan('Ảnh minh hoạ',
                          nen: Color(0xCC0A0A0F), chu: Mau.chuMo),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (p.danhMuc != null)
                      Text(p.danhMuc!.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 9.5,
                              letterSpacing: 0.8,
                              color: Mau.vang)),
                    const SizedBox(height: 3),
                    Text(p.ten,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.3)),
                    const SizedBox(height: 5),
                    GiaSanPham(p: p, co: 13.5),
                    const Spacer(),
                    const SizedBox(height: 8),
                    NutMuaTrenSan(p: p, cao: 36, gon: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnhVuong extends StatelessWidget {
  const _AnhVuong({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    const trong = ColoredBox(
      color: Color(0xFF0F0F16),
      child: Center(
        child: Icon(Icons.image_not_supported_outlined,
            size: 22, color: Mau.chuMo),
      ),
    );
    if (url == null) return trong;
    return Image.network(url!,
        fit: BoxFit.cover, errorBuilder: (_, _, _) => trong);
  }
}

class _Nhan extends StatelessWidget {
  const _Nhan(this.text, {required this.nen, required this.chu});
  final String text;
  final Color nen;
  final Color chu;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: nen,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600, color: chu)),
      );
}
