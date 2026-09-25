import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/bieu_do.dart';
import '../../widgets/danh_sach_phan_trang.dart';
import '../../widgets/hop_thoai.dart';
import '../../widgets/trang_thai.dart';
import '../shop/shop_repository.dart';
import '../shop/shop_screen.dart';
import 'admin_repository.dart';

/// Quản lý sản phẩm liên kết: thống kê lượt bấm, danh sách (gồm cả sản phẩm
/// đã ẩn), thêm, sửa, ẩn/hiện.
class SanPhamAdminView extends ConsumerStatefulWidget {
  const SanPhamAdminView({super.key});

  @override
  ConsumerState<SanPhamAdminView> createState() => _SanPhamAdminViewState();
}

class _SanPhamAdminViewState extends ConsumerState<SanPhamAdminView> {
  final _tim = TextEditingController();
  final _dk = DieuKhienDanhSach();
  Timer? _hen;
  String _tuKhoa = '';

  @override
  void dispose() {
    _hen?.cancel();
    _tim.dispose();
    super.dispose();
  }

  void _khiGo(String v) {
    _hen?.cancel();
    _hen = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _tuKhoa = v.trim());
    });
  }

  Future<void> _moForm([SanPham? p]) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SanPhamFormScreen(p: p)),
    );
    if (ok == true) {
      ref.invalidate(thongKeTiepThiProvider);
      await _dk.taiLai();
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(adminRepositoryProvider);
    final tk = ref.watch(thongKeTiepThiProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _moForm(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm sản phẩm'),
      ),
      body: DanhSachPhanTrang<SanPham>(
        key: ValueKey('sp-$_tuKhoa'),
        dieuKhien: _dk,
        tai: (t) => repo.sanPham(tuKhoa: _tuKhoa, trang: t),
        loiDuPhong: 'Không tải được sản phẩm.',
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        dau: [
          if (tk.asData?.value case final s?) ...[
            LuoiSoLieu(o: [
              OSoLieu(nhan: '${s.soNgay} ngày qua', so: dinhSo(s.bamTrongKy)),
              OSoLieu(nhan: 'Tổng lượt bấm', so: dinhSo(s.tongBam)),
              OSoLieu(nhan: 'Đã gắn link', so: dinhSo(s.coLink)),
              OSoLieu(
                nhan: 'Chưa gắn link',
                so: dinhSo(s.chuaCoLink),
                canChuY: s.chuaCoLink > 0,
              ),
            ]),
            OSoLieu(
              nhan: 'Hoa hồng ước tính',
              so: Dinh.tien(s.uocTinhHoaHong),
              goiY: 'Ước lượng từ giá × tỉ lệ × lượt bấm — KHÔNG phải doanh '
                  'thu thật.',
            ),
            const SizedBox(height: 10),
            if (s.dauBang.isNotEmpty)
              BieuDoThanh(
                tieuDe: 'Được bấm nhiều nhất',
                thanh: [
                  for (final p in s.dauBang.take(5))
                    ThanhSo(p.ten, p.luotBam ?? 0),
                ],
              ),
          ],
          TextField(
            key: const ValueKey('o-tim-sp-admin'),
            controller: _tim,
            onChanged: _khiGo,
            decoration: const InputDecoration(
              hintText: 'Tên sản phẩm...',
              prefixIcon: Icon(Icons.search, size: 20),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
        ],
        trong: const KhoiTrong(
          icon: Icons.inventory_2_outlined,
          tieuDe: 'Chưa có sản phẩm nào',
        ),
        dong: (_, p) => _DongSanPham(
          p: p,
          sua: () => _moForm(p),
          doi: () async {
            ref.invalidate(thongKeTiepThiProvider);
            await _dk.taiLai();
          },
        ),
      ),
    );
  }
}

class _DongSanPham extends ConsumerStatefulWidget {
  const _DongSanPham({required this.p, required this.sua, required this.doi});
  final SanPham p;
  final VoidCallback sua;
  final Future<void> Function() doi;

  @override
  ConsumerState<_DongSanPham> createState() => _DongSanPhamState();
}

class _DongSanPhamState extends ConsumerState<_DongSanPham> {
  bool _ban = false;

  Future<void> _batTat() async {
    final p = widget.p;
    setState(() => _ban = true);
    try {
      await ref.read(adminRepositoryProvider).batTatSanPham(p.id, !p.dangBan);
      if (!mounted) return;
      baoTin(context, p.dangBan ? 'Đã ẩn "${p.ten}".' : 'Đã hiện "${p.ten}".');
      await widget.doi();
    } catch (e) {
      if (mounted) baoLoi(context, e, 'Không đổi được trạng thái sản phẩm.');
    } finally {
      if (mounted) setState(() => _ban = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        child: Row(
          children: [
            Opacity(
              opacity: p.dangBan ? 1 : 0.45,
              child: AnhSanPham(url: p.anhDayDu, co: 54),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.ten,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5)),
                  const SizedBox(height: 3),
                  Text(
                    [
                      Dinh.tien(p.gia),
                      p.danhMuc ?? 'Chưa phân loại',
                      '${p.luotBam ?? 0} lượt bấm',
                    ].join(' · '),
                    style: const TextStyle(fontSize: 11, color: Mau.chuMo),
                  ),
                  const SizedBox(height: 5),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    if (!p.dangBan)
                      const NhanTrangThai('Đang ẩn', mau: Mau.chuMo),
                    if (p.noiBat)
                      const NhanTrangThai('Nổi bật', mau: Mau.vang),
                    if (!p.coLienKet)
                      const NhanTrangThai('Chưa có link',
                          mau: MauTrangThai.cho),
                  ]),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Sửa ${p.ten}',
              onPressed: _ban ? null : widget.sua,
              icon: const Icon(Icons.edit_outlined, size: 20),
            ),
            IconButton(
              tooltip: p.dangBan ? 'Ẩn ${p.ten}' : 'Hiện ${p.ten}',
              onPressed: _ban ? null : _batTat,
              icon: Icon(
                  p.dangBan
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thêm hoặc sửa một sản phẩm liên kết.
class SanPhamFormScreen extends ConsumerStatefulWidget {
  const SanPhamFormScreen({super.key, this.p});
  final SanPham? p;

  @override
  ConsumerState<SanPhamFormScreen> createState() => _SanPhamFormScreenState();
}

class _SanPhamFormScreenState extends ConsumerState<SanPhamFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _ten = TextEditingController(text: widget.p?.ten);
  late final _moTa = TextEditingController(text: widget.p?.moTa);
  late final _gia = TextEditingController(text: widget.p?.gia.toString());
  late final _giaGoc =
      TextEditingController(text: widget.p?.giaGoc?.toString());
  late final _anh = TextEditingController(text: widget.p?.anh);
  late final _lienKet = TextEditingController(text: widget.p?.lienKet);
  late final _hoaHong = TextEditingController(
      text: widget.p?.hoaHong == null ? '' : '${widget.p!.hoaHong}');
  late String _san = (widget.p?.san ?? 'SHOPEE').toUpperCase();
  late String? _danhMucId = widget.p?.danhMucId;
  late bool _minhHoa = widget.p?.anhMinhHoa ?? false;
  late bool _noiBat = widget.p?.noiBat ?? false;
  late bool _dangBan = widget.p?.dangBan ?? true;
  bool _dangLuu = false;
  String? _loi;

  @override
  void dispose() {
    for (final c in [_ten, _moTa, _gia, _giaGoc, _anh, _lienKet, _hoaHong]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _rongThanhNull(String s) => s.trim().isEmpty ? null : s.trim();

  Future<void> _luu() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _dangLuu = true;
      _loi = null;
    });
    try {
      await ref.read(adminRepositoryProvider).luuSanPham(widget.p?.id, {
        'name': _ten.text.trim(),
        'description': _rongThanhNull(_moTa.text),
        'price': int.parse(_gia.text.trim()),
        'compareAtPrice': int.tryParse(_giaGoc.text.trim()),
        'imageUrl': _rongThanhNull(_anh.text),
        'imageIsIllustrative': _minhHoa,
        'affiliateUrl': _rongThanhNull(_lienKet.text),
        'affiliatePlatform': _san,
        'commissionPercent': double.tryParse(_hoaHong.text.trim()) ?? 0,
        'featured': _noiBat,
        'active': _dangBan,
        'categoryId': _danhMucId,
      });
      if (!mounted) return;
      baoTin(context,
          widget.p == null ? 'Đã tạo sản phẩm.' : 'Đã cập nhật sản phẩm.');
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _loi = e.toString());
    } finally {
      if (mounted) setState(() => _dangLuu = false);
    }
  }

  Widget _o(String nhan, TextEditingController c,
      {String? goiY,
      String? Function(String?)? kiem,
      bool so = false,
      int dong = 1,
      TextInputType? kieu}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        validator: kiem,
        minLines: dong,
        maxLines: dong == 1 ? 1 : dong + 2,
        keyboardType: so ? TextInputType.number : kieu,
        inputFormatters: so ? [FilteringTextInputFormatter.digitsOnly] : null,
        decoration: InputDecoration(labelText: nhan, hintText: goiY),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dsDanhMuc = ref.watch(danhMucProvider).asData?.value ?? const [];
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.p == null ? 'Thêm sản phẩm' : 'Sửa sản phẩm')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
          children: [
            _o('Tên sản phẩm', _ten,
                kiem: (v) {
                  final s = v?.trim() ?? '';
                  if (s.isEmpty) return 'Phải nhập tên sản phẩm';
                  if (s.length > 200) return 'Tên tối đa 200 ký tự';
                  return null;
                }),
            _o('Mô tả', _moTa, dong: 3),
            Row(children: [
              Expanded(
                child: _o('Giá tham khảo (đ)', _gia,
                    so: true,
                    kiem: (v) => (v == null || v.trim().isEmpty)
                        ? 'Phải nhập giá'
                        : null),
              ),
              const SizedBox(width: 10),
              Expanded(child: _o('Giá gạch ngang (đ)', _giaGoc, so: true)),
            ]),
            _o('Ảnh (đường dẫn)', _anh, kieu: TextInputType.url),
            _o('Liên kết tiếp thị', _lienKet,
                goiY: 'https://shopee.vn/...',
                kieu: TextInputType.url,
                kiem: (v) {
                  final s = v?.trim() ?? '';
                  if (s.isEmpty) return null;
                  return s.startsWith('http://') || s.startsWith('https://')
                      ? null
                      : 'Liên kết phải bắt đầu bằng http:// hoặc https://';
                }),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue:
                      sanLienKet.contains(_san) ? _san : sanLienKet.first,
                  dropdownColor: Mau.the,
                  decoration: const InputDecoration(labelText: 'Sàn'),
                  items: [
                    for (final s in sanLienKet)
                      DropdownMenuItem(
                          value: s,
                          child: Text(s == 'OTHER' ? 'Khác' : tenSan(s))),
                  ],
                  onChanged: (v) => setState(() => _san = v ?? _san),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _hoaHong,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Hoa hồng (%)'),
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.isEmpty) return null;
                    final n = double.tryParse(s);
                    if (n == null || n < 0 || n > 100) return 'Từ 0 đến 100';
                    return null;
                  },
                ),
              ),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: dsDanhMuc.any((c) => c.id == _danhMucId)
                  ? _danhMucId
                  : null,
              dropdownColor: Mau.the,
              decoration: const InputDecoration(labelText: 'Danh mục'),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('Chưa phân loại')),
                for (final c in dsDanhMuc)
                  DropdownMenuItem(value: c.id, child: Text(c.ten)),
              ],
              onChanged: (v) => setState(() => _danhMucId = v),
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              value: _minhHoa,
              onChanged: (v) => setState(() => _minhHoa = v),
              contentPadding: EdgeInsets.zero,
              title: const Text('Ảnh minh hoạ',
                  style: TextStyle(fontSize: 13.5)),
              subtitle: const Text('Không phải ảnh chụp đúng món hàng.',
                  style: TextStyle(fontSize: 11.5, color: Mau.chuMo)),
            ),
            SwitchListTile(
              value: _noiBat,
              onChanged: (v) => setState(() => _noiBat = v),
              contentPadding: EdgeInsets.zero,
              title: const Text('Hiện ở mục nổi bật trên trang chủ',
                  style: TextStyle(fontSize: 13.5)),
            ),
            SwitchListTile(
              value: _dangBan,
              onChanged: (v) => setState(() => _dangBan = v),
              contentPadding: EdgeInsets.zero,
              title:
                  const Text('Đang bán', style: TextStyle(fontSize: 13.5)),
            ),
            if (_loi != null) ...[
              const SizedBox(height: 8),
              Text(_loi!,
                  style:
                      const TextStyle(fontSize: 13, color: MauTrangThai.xau)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _dangLuu ? null : _luu,
              child: Text(widget.p == null ? 'Tạo sản phẩm' : 'Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}
