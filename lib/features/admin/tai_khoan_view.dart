import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/danh_sach_phan_trang.dart';
import '../../widgets/hop_thoai.dart';
import '../../widgets/trang_thai.dart';
import 'admin_repository.dart';
import 'tai_khoan_chi_tiet_screen.dart';
import 'tao_tai_khoan_screen.dart';

/// Nhãn vai trò có màu, dùng chung trong khu quản trị.
class NhanVaiTro extends StatelessWidget {
  const NhanVaiTro(this.vaiTro, {super.key});
  final String vaiTro;

  static const _mau = {
    'USER': MauTrangThai.xanh,
    'STAFF': MauTrangThai.tot,
    'MANAGER': MauTrangThai.tim,
    'ADMIN': Mau.vang,
  };

  @override
  Widget build(BuildContext context) =>
      NhanTrangThai(tenVaiTro[vaiTro] ?? vaiTro, mau: _mau[vaiTro] ?? Mau.chuMo);
}

Color mauTrangThaiTaiKhoan(String t) => switch (t) {
      'PENDING' => MauTrangThai.cho,
      'ACTIVE' => MauTrangThai.tot,
      'BANNED' => MauTrangThai.xau,
      _ => Mau.chuMo,
    };

/// Danh sách tài khoản, dùng chung cho Quản lý và Quản trị viên.
///
/// Khác biệt giữa hai vai trò gói trong [vaiTroGanDuoc]: quản lý chỉ đặt được
/// USER/STAFF, quản trị viên đặt được tất cả. Còn ai được sửa hàng nào thì
/// máy chủ quyết định qua cờ `editable` — app không tự suy luận lại.
///
/// Trên điện thoại không có bảng nhiều cột như web: mỗi tài khoản là một
/// dòng, bấm vào mở chi tiết (đổi vai trò, khoá, thu hồi phiên… đều ở đó),
/// giữ ngón tay để chọn nhiều rồi đổi vai trò hàng loạt.
class TaiKhoanView extends ConsumerStatefulWidget {
  const TaiKhoanView({
    super.key,
    required this.vaiTroGanDuoc,
    required this.taoDuoc,
  });

  final List<String> vaiTroGanDuoc;
  final bool taoDuoc;

  @override
  ConsumerState<TaiKhoanView> createState() => _TaiKhoanViewState();
}

class _TaiKhoanViewState extends ConsumerState<TaiKhoanView> {
  final _tim = TextEditingController();
  final _dk = DieuKhienDanhSach();
  Timer? _hen;
  String _tuKhoa = '';
  String _vaiTro = '';
  String _trangThai = '';

  /// Chọn theo id chứ không theo vị trí dòng: đổi bộ lọc là vị trí trỏ sang
  /// người khác.
  final _daChon = <String>{};
  bool _dangDoiHangLoat = false;

  @override
  void dispose() {
    _hen?.cancel();
    _tim.dispose();
    super.dispose();
  }

  void _khiGo(String v) {
    _hen?.cancel();
    _hen = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(() {
          _tuKhoa = v.trim();
          _daChon.clear();
        });
      }
    });
  }

  Future<void> _doiHangLoat() async {
    final vaiTro = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Mau.the,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Đổi ${_daChon.length} tài khoản thành',
                  style: const TextStyle(fontSize: 15)),
            ),
            for (final v in widget.vaiTroGanDuoc)
              ListTile(
                title: Text(tenVaiTro[v]!),
                subtitle: Text(moTaVaiTro[v]!,
                    style: const TextStyle(fontSize: 12, color: Mau.chuMo)),
                onTap: () => Navigator.of(ctx).pop(v),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (vaiTro == null || !mounted) return;
    setState(() => _dangDoiHangLoat = true);
    try {
      final n = _daChon.length;
      await ref
          .read(adminRepositoryProvider)
          .doiVaiTroHangLoat(_daChon.toList(), vaiTro);
      if (!mounted) return;
      baoTin(context, 'Đã đổi vai trò cho $n tài khoản.');
      setState(_daChon.clear);
      await _dk.taiLai();
    } catch (e) {
      if (mounted) baoLoi(context, e, 'Không đổi được vai trò hàng loạt.');
    } finally {
      if (mounted) setState(() => _dangDoiHangLoat = false);
    }
  }

  Future<void> _moChiTiet(TaiKhoan t) async {
    final doi = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => TaiKhoanChiTietScreen(
        id: t.id,
        vaiTroGanDuoc: widget.vaiTroGanDuoc,
      ),
    ));
    if (doi == true) await _dk.taiLai();
  }

  Future<void> _tao() async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => TaoTaiKhoanScreen(vaiTroGanDuoc: widget.vaiTroGanDuoc),
    ));
    if (ok == true) await _dk.taiLai();
  }

  Widget _loc({
    required String nhan,
    required String giaTri,
    required Map<String, String> luaChon,
    required ValueChanged<String> doi,
  }) {
    return Expanded(
      child: DropdownButtonFormField<String>(
        initialValue: giaTri,
        isExpanded: true,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        dropdownColor: Mau.the,
        items: [
          DropdownMenuItem(value: '', child: Text(nhan)),
          for (final e in luaChon.entries)
            DropdownMenuItem(value: e.key, child: Text(e.value)),
        ],
        onChanged: (v) => doi(v ?? ''),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(adminRepositoryProvider);

    return Scaffold(
      floatingActionButton: widget.taoDuoc && _daChon.isEmpty
          ? FloatingActionButton.extended(
              onPressed: _tao,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Tạo tài khoản'),
            )
          : null,
      bottomNavigationBar: _daChon.isEmpty
          ? null
          : SafeArea(
              child: Container(
                color: Mau.the,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Đã chọn ${_daChon.length} tài khoản',
                          style: const TextStyle(fontSize: 13)),
                    ),
                    TextButton(
                      onPressed: () => setState(_daChon.clear),
                      child: const Text('Bỏ chọn'),
                    ),
                    FilledButton(
                      onPressed: _dangDoiHangLoat ? null : _doiHangLoat,
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 42)),
                      child: const Text('Đổi vai trò'),
                    ),
                  ],
                ),
              ),
            ),
      body: DanhSachPhanTrang<TaiKhoan>(
        key: ValueKey('tk-$_tuKhoa-$_vaiTro-$_trangThai'),
        dieuKhien: _dk,
        tai: (t) => repo.taiKhoan(
          vaiTro: _vaiTro,
          trangThai: _trangThai,
          tuKhoa: _tuKhoa,
          trang: t,
        ),
        loiDuPhong: 'Không tải được danh sách tài khoản.',
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        dau: [
          TextField(
            key: const ValueKey('o-tim-tai-khoan'),
            controller: _tim,
            onChanged: _khiGo,
            decoration: const InputDecoration(
              hintText: 'Tên, email hoặc tên đăng nhập...',
              prefixIcon: Icon(Icons.search, size: 20),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _loc(
                nhan: 'Mọi vai trò',
                giaTri: _vaiTro,
                luaChon: tenVaiTro,
                doi: (v) => setState(() {
                  _vaiTro = v;
                  _daChon.clear();
                }),
              ),
              const SizedBox(width: 10),
              _loc(
                nhan: 'Mọi trạng thái',
                giaTri: _trangThai,
                luaChon: tenTrangThaiTaiKhoan,
                doi: (v) => setState(() {
                  _trangThai = v;
                  _daChon.clear();
                }),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(top: 10, bottom: 8),
            child: Text(
              'Bấm để xem và thao tác. Giữ ngón tay trên một dòng để chọn '
              'nhiều tài khoản rồi đổi vai trò cùng lúc.',
              style: TextStyle(fontSize: 11.5, color: Mau.chuMo, height: 1.5),
            ),
          ),
        ],
        trong: const KhoiTrong(
          icon: Icons.person_search_outlined,
          tieuDe: 'Không có tài khoản nào',
          moTa: 'Không có tài khoản nào khớp bộ lọc.',
        ),
        dong: (_, t) => _DongTaiKhoan(
          t: t,
          chon: _daChon.contains(t.id),
          dangChonNhieu: _daChon.isNotEmpty,
          bam: () {
            if (_daChon.isNotEmpty) {
              if (!t.suaDuoc) return;
              setState(() => _daChon.contains(t.id)
                  ? _daChon.remove(t.id)
                  : _daChon.add(t.id));
            } else {
              _moChiTiet(t);
            }
          },
          // Chỉ hàng máy chủ cho sửa mới chọn được — không thì thao tác hàng
          // loạt bị rollback toàn bộ chỉ vì lỡ chọn một tài khoản ngoài tầm.
          giu: t.suaDuoc ? () => setState(() => _daChon.add(t.id)) : null,
        ),
      ),
    );
  }
}

class _DongTaiKhoan extends StatelessWidget {
  const _DongTaiKhoan({
    required this.t,
    required this.chon,
    required this.dangChonNhieu,
    required this.bam,
    this.giu,
  });

  final TaiKhoan t;
  final bool chon;
  final bool dangChonNhieu;
  final VoidCallback bam;
  final VoidCallback? giu;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: chon ? Mau.vang : Mau.vien),
      ),
      child: ListTile(
        onTap: bam,
        onLongPress: giu,
        contentPadding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        leading: dangChonNhieu
            ? Icon(
                chon ? Icons.check_circle : Icons.radio_button_unchecked,
                color: t.suaDuoc ? (chon ? Mau.vang : Mau.chuMo) : Mau.vien,
              )
            : CircleAvatar(
                radius: 19,
                backgroundColor: const Color(0xFF0F0F16),
                backgroundImage: t.anh != null ? NetworkImage(t.anh!) : null,
                child: t.anh == null
                    ? Text(
                        t.tenHienThi.isEmpty
                            ? '?'
                            : t.tenHienThi.characters.first.toUpperCase(),
                        style: const TextStyle(color: Mau.vang))
                    : null,
              ),
        title: Text(t.tenHienThi,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${t.email ?? '@${t.tenDangNhap}'}'
                '${!t.daXacMinh && t.email != null ? ' · chưa xác minh' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, color: Mau.chuMo),
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  NhanVaiTro(t.vaiTro),
                  NhanTrangThai(
                      tenTrangThaiTaiKhoan[t.trangThai] ?? t.trangThai,
                      mau: mauTrangThaiTaiKhoan(t.trangThai)),
                  if (t.taoLuc != null)
                    Text('Tham gia ${Dinh.ngay(t.taoLuc)}',
                        style:
                            const TextStyle(fontSize: 10.5, color: Mau.chuMo)),
                ],
              ),
            ],
          ),
        ),
        trailing: dangChonNhieu
            ? null
            : const Icon(Icons.chevron_right, color: Mau.chuMo, size: 20),
      ),
    );
  }
}
