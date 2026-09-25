import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/hop_thoai.dart';
import '../../widgets/trang_thai.dart';
import 'admin_repository.dart';
import 'tai_khoan_view.dart';

/// Chi tiết một tài khoản và mọi thao tác trên nó.
///
/// Trả `true` qua `Navigator.pop` khi có thay đổi, để danh sách phía sau nạp
/// lại — không thì vai trò hay trạng thái cũ vẫn nằm đó và người trực tưởng
/// thao tác không ăn.
class TaiKhoanChiTietScreen extends ConsumerStatefulWidget {
  const TaiKhoanChiTietScreen({
    super.key,
    required this.id,
    required this.vaiTroGanDuoc,
  });

  final String id;
  final List<String> vaiTroGanDuoc;

  @override
  ConsumerState<TaiKhoanChiTietScreen> createState() =>
      _TaiKhoanChiTietScreenState();
}

class _TaiKhoanChiTietScreenState extends ConsumerState<TaiKhoanChiTietScreen> {
  bool _daDoi = false;
  bool _dangChay = false;

  AdminRepository get _repo => ref.read(adminRepositoryProvider);

  /// Chạy một thao tác, báo kết quả, rồi nạp lại chi tiết.
  Future<void> _chay(Future<void> Function() viec, String xong) async {
    setState(() => _dangChay = true);
    try {
      await viec();
      _daDoi = true;
      ref.invalidate(chiTietTaiKhoanProvider(widget.id));
      if (mounted) baoTin(context, xong);
    } catch (e) {
      if (mounted) baoLoi(context, e, 'Thao tác không thành công.');
    } finally {
      if (mounted) setState(() => _dangChay = false);
    }
  }

  Future<void> _doiVaiTro(ChiTietTaiKhoan ct) async {
    final t = ct.co;
    final moi = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Mau.the,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Đổi vai trò', style: TextStyle(fontSize: 15)),
            ),
            for (final v in widget.vaiTroGanDuoc)
              ListTile(
                selected: v == t.vaiTro,
                selectedColor: Mau.vang,
                title: Text(tenVaiTro[v]!),
                subtitle: Text(moTaVaiTro[v]!,
                    style: const TextStyle(fontSize: 12, color: Mau.chuMo)),
                trailing: v == t.vaiTro ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(ctx).pop(v),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (moi == null || moi == t.vaiTro || !mounted) return;
    await _chay(() => _repo.doiVaiTro(t.id, moi),
        '${t.tenHienThi} giờ là ${tenVaiTro[moi]}.');
  }

  Future<void> _khoaMo(TaiKhoan t) async {
    final khoa = !t.biKhoa;
    final ok = await hoiXacNhan(
      context,
      tieuDe: khoa ? 'Khoá tài khoản' : 'Mở khoá tài khoản',
      noiDung: khoa
          ? 'Khoá ${t.tenHienThi}? Họ sẽ không đăng nhập được cho tới khi '
              'được mở khoá.'
          : 'Mở khoá ${t.tenHienThi}?',
      dongY: khoa ? 'Khoá' : 'Mở khoá',
      nguyHiem: khoa,
    );
    if (!ok) return;
    await _chay(
      () => _repo.doiTrangThai(t.id, khoa ? 'BANNED' : 'ACTIVE'),
      khoa ? 'Đã khoá ${t.tenHienThi}.' : 'Đã mở khoá ${t.tenHienThi}.',
    );
  }

  Future<void> _sua(ChiTietTaiKhoan ct) async {
    final kq = await Navigator.of(context).push<Map<String, String>>(
      MaterialPageRoute(builder: (_) => _SuaThongTinScreen(ct: ct)),
    );
    if (kq == null) return;
    await _chay(() => _repo.suaThongTin(ct.co.id, kq), 'Đã lưu thông tin.');
  }

  Future<void> _xoa(TaiKhoan t) async {
    final ok = await hoiXacNhan(
      context,
      tieuDe: 'Xoá tài khoản',
      noiDung: 'Xoá mềm ${t.tenHienThi}. Đơn hàng và lịch sử của họ vẫn giữ '
          'nguyên, nhưng tài khoản sẽ biến mất khỏi mọi danh sách và không '
          'đăng nhập được nữa.',
      dongY: 'Xoá tài khoản',
      nguyHiem: true,
    );
    if (!ok || !mounted) return;
    setState(() => _dangChay = true);
    try {
      await _repo.xoaTaiKhoan(t.id);
      if (!mounted) return;
      baoTin(context, 'Đã xoá tài khoản.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        baoLoi(context, e, 'Không xoá được tài khoản.');
        setState(() => _dangChay = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ct = ref.watch(chiTietTaiKhoanProvider(widget.id));
    final toi = ref.watch(authControllerProvider).user;
    final xoaDuoc = toi?.co('USERS_MANAGE') ?? false;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (daPop, _) {
        if (!daPop) Navigator.of(context).pop(_daDoi);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(ct.asData?.value.co.tenHienThi ?? 'Tài khoản'),
          bottom: _dangChay
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(2),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              : null,
        ),
        body: ct.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: Mau.vang)),
          error: (e, _) => KhoiLoi(
            thongDiep: e is ApiException
                ? e.message
                : 'Không tải được chi tiết tài khoản.',
            thuLai: () => ref.invalidate(chiTietTaiKhoanProvider(widget.id)),
          ),
          data: (c) => _than(c, xoaDuoc),
        ),
      ),
    );
  }

  Widget _than(ChiTietTaiKhoan c, bool xoaDuoc) {
    final t = c.co;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Mau.the,
              backgroundImage: t.anh != null ? NetworkImage(t.anh!) : null,
              child: t.anh == null
                  ? Text(
                      t.tenHienThi.isEmpty
                          ? '?'
                          : t.tenHienThi.characters.first.toUpperCase(),
                      style: const TextStyle(fontSize: 20, color: Mau.vang))
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.tenHienThi, style: const TextStyle(fontSize: 17)),
                  const SizedBox(height: 2),
                  Text(t.email ?? '@${t.tenDangNhap}',
                      style:
                          const TextStyle(fontSize: 12.5, color: Mau.chuMo)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    NhanVaiTro(t.vaiTro),
                    NhanTrangThai(
                        tenTrangThaiTaiKhoan[t.trangThai] ?? t.trangThai,
                        mau: mauTrangThaiTaiKhoan(t.trangThai)),
                    if (!t.daXacMinh && t.email != null)
                      const NhanTrangThai('Chưa xác minh email',
                          mau: MauTrangThai.cho),
                  ]),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _So('Phiên đang mở', '${c.phienMo}')),
          const SizedBox(width: 8),
          Expanded(child: _So('Đơn hàng', '${c.soDon}')),
          const SizedBox(width: 8),
          Expanded(child: _So('Đã chi', Dinh.tien(c.daChi))),
        ]),
        TieuDeKhoi('Thông tin'),
        _Dong('Tên đăng nhập', t.tenDangNhap),
        _Dong('Số điện thoại', c.dienThoai),
        _Dong('Thành phố', c.thanhPho),
        _Dong('Địa chỉ', c.diaChi),
        _Dong('Đăng nhập bằng', c.dangNhapBang),
        _Dong('Đăng nhập gần nhất',
            t.dangNhapCuoi == null ? null : Dinh.ngayGio(t.dangNhapCuoi)),
        _Dong('Tham gia', t.taoLuc == null ? null : Dinh.ngay(t.taoLuc)),
        if (c.coHoSoReader) const _Dong('Hồ sơ Reader', 'Đã có'),
        if (c.coDonReaderCho) const _Dong('Đơn xin làm Reader', 'Đang chờ duyệt'),
        if (t.suaDuoc)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _dangChay ? null : () => _sua(c),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Sửa thông tin'),
            ),
          ),
        TieuDeKhoi('Vai trò này được làm gì'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final q in c.quyen)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Mau.vien),
                ),
                child: Text(q,
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: Mau.vangNhat)),
              ),
          ],
        ),
        if (t.suaDuoc) ...[
          TieuDeKhoi('Thao tác'),
          _NutThaoTac(
            icon: Icons.badge_outlined,
            nhan: 'Đổi vai trò',
            goiY: 'Hiện là ${tenVaiTro[t.vaiTro] ?? t.vaiTro}.',
            bam: _dangChay ? null : () => _doiVaiTro(c),
          ),
          _NutThaoTac(
            icon: t.biKhoa ? Icons.lock_open : Icons.lock_outline,
            nhan: t.biKhoa ? 'Mở khoá tài khoản' : 'Khoá tài khoản',
            goiY: t.biKhoa
                ? 'Cho phép đăng nhập trở lại.'
                : 'Chặn đăng nhập cho tới khi mở khoá.',
            nguyHiem: !t.biKhoa,
            bam: _dangChay ? null : () => _khoaMo(t),
          ),
          _NutThaoTac(
            icon: Icons.key_outlined,
            nhan: 'Gửi liên kết đặt lại mật khẩu',
            goiY: 'Không ai đặt mật khẩu hộ người khác — họ tự đặt qua email.',
            bam: _dangChay || t.email == null
                ? null
                : () => _chay(() => _repo.guiDatLaiMatKhau(t.id),
                    'Đã gửi liên kết đặt lại mật khẩu.'),
          ),
          if (!t.daXacMinh)
            _NutThaoTac(
              icon: Icons.mark_email_read_outlined,
              nhan: 'Gửi lại mail xác minh',
              goiY: 'Tài khoản chưa xác minh thì chưa đăng nhập được.',
              bam: _dangChay
                  ? null
                  : () => _chay(() => _repo.guiLaiXacMinh(t.id),
                      'Đã gửi lại mail xác minh.'),
            ),
          _NutThaoTac(
            icon: Icons.logout,
            nhan: 'Buộc đăng xuất mọi thiết bị',
            goiY: 'Đang có ${c.phienMo} phiên mở.',
            bam: _dangChay || c.phienMo == 0
                ? null
                : () => _chay(
                    () => _repo.thuHoiPhien(t.id), 'Đã thu hồi mọi phiên.'),
          ),
          if (xoaDuoc)
            _NutThaoTac(
              icon: Icons.delete_outline,
              nhan: 'Xoá tài khoản',
              goiY: 'Xoá mềm — lịch sử vẫn giữ.',
              nguyHiem: true,
              bam: _dangChay ? null : () => _xoa(t),
            ),
        ] else
          const Padding(
            padding: EdgeInsets.only(top: 18),
            child: Text(
              'Bạn không sửa được tài khoản này — hoặc đây là chính bạn, hoặc '
              'vai trò của họ nằm ngoài phạm vi của bạn.',
              style: TextStyle(fontSize: 12, color: Mau.chuMo, height: 1.5),
            ),
          ),
      ],
    );
  }
}

class _So extends StatelessWidget {
  const _So(this.nhan, this.so);
  final String nhan;
  final String so;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Mau.the,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Mau.vien),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(so,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(nhan, style: const TextStyle(fontSize: 11, color: Mau.chuMo)),
        ],
      ),
    );
  }
}

class _Dong extends StatelessWidget {
  const _Dong(this.nhan, this.giaTri);
  final String nhan;
  final String? giaTri;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(nhan,
                style: const TextStyle(fontSize: 12.5, color: Mau.chuMo)),
          ),
          Expanded(
            child: Text(giaTri ?? '—', style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _NutThaoTac extends StatelessWidget {
  const _NutThaoTac({
    required this.icon,
    required this.nhan,
    required this.goiY,
    required this.bam,
    this.nguyHiem = false,
  });

  final IconData icon;
  final String nhan;
  final String goiY;
  final VoidCallback? bam;
  final bool nguyHiem;

  @override
  Widget build(BuildContext context) {
    final mau = nguyHiem ? MauTrangThai.xau : Mau.vang;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        enabled: bam != null,
        onTap: bam,
        leading: Icon(icon, color: bam == null ? Mau.chuMo : mau),
        title: Text(nhan,
            style: TextStyle(
                fontSize: 14, color: nguyHiem && bam != null ? mau : null)),
        subtitle: Text(goiY,
            style: const TextStyle(fontSize: 11.5, color: Mau.chuMo)),
      ),
    );
  }
}

/// Sửa họ tên, điện thoại, thành phố, địa chỉ. Trả về các trường đã đổi.
class _SuaThongTinScreen extends StatefulWidget {
  const _SuaThongTinScreen({required this.ct});
  final ChiTietTaiKhoan ct;

  @override
  State<_SuaThongTinScreen> createState() => _SuaThongTinScreenState();
}

class _SuaThongTinScreenState extends State<_SuaThongTinScreen> {
  late final _hoTen = TextEditingController(text: widget.ct.co.hoTen);
  late final _dienThoai = TextEditingController(text: widget.ct.dienThoai);
  late final _thanhPho = TextEditingController(text: widget.ct.thanhPho);
  late final _diaChi = TextEditingController(text: widget.ct.diaChi);
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _hoTen.dispose();
    _dienThoai.dispose();
    _thanhPho.dispose();
    _diaChi.dispose();
    super.dispose();
  }

  void _luu() {
    if (!(_form.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop({
      'fullName': _hoTen.text.trim(),
      'phone': _dienThoai.text.trim(),
      'city': _thanhPho.text.trim(),
      'address': _diaChi.text.trim(),
    });
  }

  Widget _o(String nhan, TextEditingController c,
          {String? Function(String?)? kiem, TextInputType? kieu}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: c,
          validator: kiem,
          keyboardType: kieu,
          decoration: InputDecoration(labelText: nhan),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sửa thông tin')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          children: [
            _o('Họ tên', _hoTen,
                kiem: (v) => (v == null || v.trim().isEmpty)
                    ? 'Họ tên là bắt buộc'
                    : null),
            _o('Số điện thoại', _dienThoai, kieu: TextInputType.phone),
            _o('Thành phố', _thanhPho),
            _o('Địa chỉ', _diaChi),
            const SizedBox(height: 8),
            FilledButton(onPressed: _luu, child: const Text('Lưu')),
          ],
        ),
      ),
    );
  }
}
