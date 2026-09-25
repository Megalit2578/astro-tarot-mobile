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
  const NutMuaTrenSan({super.key, required this.p, this.cao = 44});

  final SanPham p;
  final double cao;

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
      icon: const Icon(Icons.open_in_new, size: 16),
      // Nói TÊN sàn: người dùng cần biết mình sắp mở ứng dụng nào trước khi
      // rời app.
      label: Text('Mua trên ${tenSan(p.san)}'),
      style: FilledButton.styleFrom(minimumSize: Size.fromHeight(widget.cao)),
    );
  }
}

/// Thẻ một sản phẩm trong danh sách. Bấm thẻ mở màn chi tiết.
class TheSanPham extends StatelessWidget {
  const TheSanPham({super.key, required this.p});
  final SanPham p;

  @override
  Widget build(BuildContext context) {
    final anh = p.anhDayDu;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ProductDetailScreen(slug: p.slug, banDau: p))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (anh != null) ...[
                    AnhSanPham(url: anh),
                    const SizedBox(width: 13),
                  ],
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
                        GiaSanPham(p: p),
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
              NutMuaTrenSan(p: p),
            ],
          ),
        ),
      ),
    );
  }
}
