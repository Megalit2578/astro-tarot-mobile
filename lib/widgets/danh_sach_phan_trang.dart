import 'package:flutter/material.dart';

import '../core/api/api_client.dart';
import '../core/api/trang.dart';
import '../theme.dart';
import 'hop_thoai.dart';
import 'trang_thai.dart';

/// Danh sách phân trang dùng chung: kéo để tải lại, nút "Tải thêm" ở cuối,
/// khối lỗi có nút thử lại, khối rỗng riêng.
///
/// Đổi bộ lọc thì đổi [key] của widget — cách rõ ràng nhất để bắt đầu lại từ
/// trang đầu. Giữ trang cũ khi đã đổi bộ lọc là rơi vào trang trống, hoặc tệ
/// hơn, trộn kết quả của hai bộ lọc vào một danh sách.
class DanhSachPhanTrang<T> extends StatefulWidget {
  const DanhSachPhanTrang({
    super.key,
    required this.tai,
    required this.dong,
    required this.trong,
    this.dau = const [],
    this.loiDuPhong = 'Không tải được danh sách.',
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 24),
    this.dieuKhien,
  });

  /// Tải một trang, tính từ 0.
  final Future<Trang<T>> Function(int trang) tai;
  final Widget Function(BuildContext context, T muc) dong;

  /// Hiện khi trang đầu rỗng.
  final Widget trong;

  /// Các widget đứng trước danh sách (bộ lọc, tổng số…), cuộn cùng danh sách.
  final List<Widget> dau;
  final String loiDuPhong;
  final EdgeInsets padding;

  /// Cho phép bên ngoài bắt tải lại (sau khi sửa một dòng chẳng hạn).
  final DieuKhienDanhSach? dieuKhien;

  @override
  State<DanhSachPhanTrang<T>> createState() => _DanhSachPhanTrangState<T>();
}

/// Tay cầm để bên ngoài gọi tải lại danh sách.
class DieuKhienDanhSach {
  Future<void> Function()? _taiLai;

  Future<void> taiLai() async => _taiLai?.call();
}

class _DanhSachPhanTrangState<T> extends State<DanhSachPhanTrang<T>> {
  Trang<T>? _du;
  Object? _loi;
  bool _dangTaiThem = false;

  @override
  void initState() {
    super.initState();
    widget.dieuKhien?._taiLai = _taiLai;
    _taiLai();
  }

  @override
  void didUpdateWidget(covariant DanhSachPhanTrang<T> old) {
    super.didUpdateWidget(old);
    widget.dieuKhien?._taiLai = _taiLai;
  }

  Future<void> _taiLai() async {
    try {
      final t = await widget.tai(0);
      if (!mounted) return;
      setState(() {
        _du = t;
        _loi = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loi = e);
    }
  }

  Future<void> _taiThem() async {
    final hien = _du;
    if (hien == null || !hien.conNua || _dangTaiThem) return;
    setState(() => _dangTaiThem = true);
    try {
      final sau = await widget.tai(hien.so + 1);
      if (!mounted) return;
      setState(() => _du = hien.noi(sau));
    } catch (e) {
      if (mounted) baoLoi(context, e, 'Không tải thêm được.');
    } finally {
      if (mounted) setState(() => _dangTaiThem = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final du = _du;
    final Widget than;
    if (du == null && _loi != null) {
      than = KhoiLoi(
        thongDiep: _loi is ApiException
            ? (_loi as ApiException).message
            : widget.loiDuPhong,
        thuLai: () {
          setState(() => _loi = null);
          _taiLai();
        },
      );
    } else if (du == null) {
      than = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: widget.padding,
        children: [
          ...widget.dau,
          const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(child: CircularProgressIndicator(color: Mau.vang)),
          ),
        ],
      );
    } else if (du.muc.isEmpty) {
      than = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: widget.padding,
        children: [
          ...widget.dau,
          SizedBox(height: 380, child: widget.trong),
        ],
      );
    } else {
      final soDau = widget.dau.length;
      final tong = soDau + du.muc.length + (du.conNua ? 1 : 0);
      than = ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: widget.padding,
        itemCount: tong,
        itemBuilder: (ctx, i) {
          if (i < soDau) return widget.dau[i];
          final j = i - soDau;
          if (j < du.muc.length) return widget.dong(ctx, du.muc[j]);
          return NutTaiThem(dangTai: _dangTaiThem, bam: _taiThem);
        },
      );
    }

    return RefreshIndicator(
      color: Mau.vang,
      backgroundColor: Mau.the,
      onRefresh: _taiLai,
      child: than,
    );
  }
}
