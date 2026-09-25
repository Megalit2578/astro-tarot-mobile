import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../theme.dart';
import '../../widgets/hop_thoai.dart';
import '../../widgets/trang_thai.dart';
import '../home/home_repository.dart';
import 'astrology_repository.dart';

/// Bản đồ sao: xem, thêm, sửa, xoá — khớp trang `/profile/astrology` của web.
///
/// Ngày, giờ và nơi sinh quyết định lá số; AI đọc bài dựa trên hồ sơ chính,
/// nên sai một chi tiết ở đây là lời giải lệch theo. Bản đầu của app chỉ đọc
/// và mời sang web để khai — với người chỉ dùng điện thoại thì đó là ngõ cụt.
class AstrologyScreen extends ConsumerWidget {
  const AstrologyScreen({super.key});

  Future<void> _moForm(BuildContext context, WidgetRef ref, [HoSoSao? h]) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => HoSoSaoFormScreen(hoSo: h)),
    );
    if (ok == true) {
      ref.invalidate(hoSoSaoProvider);
      ref.invalidate(banDoSaoProvider);
    }
  }

  Future<void> _xoa(BuildContext context, WidgetRef ref, HoSoSao h) async {
    final ok = await hoiXacNhan(
      context,
      tieuDe: 'Xoá hồ sơ',
      noiDung: 'Xoá "${h.tieuDe}"? Không hoàn tác được.',
      dongY: 'Xoá',
      nguyHiem: true,
    );
    if (!ok) return;
    try {
      await ref.read(astrologyRepositoryProvider).xoa(h.id);
      ref.invalidate(hoSoSaoProvider);
      ref.invalidate(banDoSaoProvider);
      if (context.mounted) baoTin(context, 'Đã xoá hồ sơ.');
    } catch (e) {
      if (context.mounted) baoLoi(context, e, 'Không xoá được hồ sơ.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = ref.watch(hoSoSaoProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Bản đồ sao')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _moForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Thêm hồ sơ'),
      ),
      body: RefreshIndicator(
        color: Mau.vang,
        backgroundColor: Mau.the,
        onRefresh: () => ref.refresh(hoSoSaoProvider.future),
        child: ds.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: Mau.vang)),
          error: (e, _) => KhoiLoi(
            thongDiep: e is ApiException
                ? e.message
                : 'Không tải được danh sách hồ sơ. Thử lại sau.',
            thuLai: () => ref.invalidate(hoSoSaoProvider),
          ),
          data: (list) => list.isEmpty
              ? const KhoiTrong(
                  icon: Icons.auto_awesome,
                  tieuDe: 'Bạn chưa có hồ sơ chiêm tinh nào',
                  moTa: 'Thêm một hồ sơ ở đây, hoặc để hệ thống tự tạo khi '
                      'bạn trải bài lần đầu.',
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  children: [
                    const Text(
                      'Ngày, giờ và nơi sinh quyết định lá số của bạn. AI đọc '
                      'bài dựa trên hồ sơ chính, nên sai một chi tiết ở đây là '
                      'lời giải lệch theo.',
                      style: TextStyle(
                          fontSize: 12.5, color: Mau.chuMo, height: 1.55),
                    ),
                    const SizedBox(height: 12),
                    for (final h in list)
                      _TheHoSo(
                        h: h,
                        sua: () => _moForm(context, ref, h),
                        xoa: () => _xoa(context, ref, h),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _TheHoSo extends StatelessWidget {
  const _TheHoSo({required this.h, required this.sua, required this.xoa});
  final HoSoSao h;
  final VoidCallback sua;
  final VoidCallback xoa;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(h.tieuDe,
                      style: const TextStyle(fontSize: 16, color: Mau.vangNhat)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    if (h.chinh) const NhanTrangThai('Hồ sơ chính', mau: Mau.vang),
                    NhanTrangThai(tenKieuHoSo[h.kieu] ?? h.kieu, mau: Mau.chuMo),
                  ]),
                  const SizedBox(height: 10),
                  if (h.tenNguoi != null) _Dong('Người được xem', h.tenNguoi!),
                  _Dong('Ngày sinh', h.ngaySinhVi),
                  _Dong('Giờ sinh', h.gioSinhNgan ?? 'Chưa biết giờ'),
                  _Dong('Nơi sinh', h.noiSinh),
                  if (h.muiGio != null) _Dong('Múi giờ', h.muiGio!),
                  if (h.viDo != null && h.kinhDo != null)
                    _Dong('Toạ độ',
                        '${h.viDo!.toStringAsFixed(4)}, ${h.kinhDo!.toStringAsFixed(4)}'),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  tooltip: 'Sửa ${h.tieuDe}',
                  onPressed: sua,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                ),
                IconButton(
                  tooltip: 'Xoá hồ sơ ${h.tieuDe}',
                  onPressed: xoa,
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: MauTrangThai.xau),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Dong extends StatelessWidget {
  const _Dong(this.nhan, this.giaTri);
  final String nhan;
  final String giaTri;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(nhan,
                  style: const TextStyle(fontSize: 12, color: Mau.chuMo)),
            ),
            Expanded(
                child: Text(giaTri, style: const TextStyle(fontSize: 12.5))),
          ],
        ),
      );
}

/// Form khai hoặc sửa một bản đồ sao.
class HoSoSaoFormScreen extends ConsumerStatefulWidget {
  const HoSoSaoFormScreen({super.key, this.hoSo});
  final HoSoSao? hoSo;

  @override
  ConsumerState<HoSoSaoFormScreen> createState() => _HoSoSaoFormScreenState();
}

class _HoSoSaoFormScreenState extends ConsumerState<HoSoSaoFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _tieuDe = TextEditingController(text: widget.hoSo?.tieuDe);
  late final _tenNguoi = TextEditingController(text: widget.hoSo?.tenNguoi);
  late final _noiSinh = TextEditingController(text: widget.hoSo?.noiSinh);
  late final _muiGio = TextEditingController(
      text: widget.hoSo?.muiGio ?? 'Asia/Ho_Chi_Minh');
  late String? _ngaySinh = widget.hoSo?.ngaySinh;
  late String? _gioSinh = widget.hoSo?.gioSinhNgan;
  late double? _viDo = widget.hoSo?.viDo;
  late double? _kinhDo = widget.hoSo?.kinhDo;
  late String _kieu = widget.hoSo?.kieu ?? 'SELF';
  late bool _chinh = widget.hoSo?.chinh ?? false;

  Timer? _hen;
  List<DiaDanh> _goiY = const [];
  bool _dangTim = false;
  bool _dangLuu = false;
  String? _loi;

  @override
  void dispose() {
    _hen?.cancel();
    _tieuDe.dispose();
    _tenNguoi.dispose();
    _noiSinh.dispose();
    _muiGio.dispose();
    super.dispose();
  }

  /// Gõ nơi sinh thì tra toạ độ, chờ 500ms cho người ta gõ xong — Nominatim
  /// giới hạn một lượt mỗi giây, gọi theo từng phím là bị chặn.
  void _khiGoNoiSinh(String v) {
    // Sửa tên nơi sinh mà chưa chọn lại gợi ý thì toạ độ cũ không còn đúng.
    setState(() {
      _viDo = null;
      _kinhDo = null;
    });
    _hen?.cancel();
    _hen = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _dangTim = true);
      final kq = await ref.read(timDiaDanhProvider)(v);
      if (!mounted) return;
      setState(() {
        _goiY = kq;
        _dangTim = false;
      });
    });
  }

  void _chonDiaDanh(DiaDanh d) {
    _noiSinh.text = d.ten;
    setState(() {
      _viDo = d.viDo;
      _kinhDo = d.kinhDo;
      _goiY = const [];
    });
  }

  Future<void> _chonNgay() async {
    final dau = _ngaySinh == null ? null : DateTime.tryParse(_ngaySinh!);
    final d = await showDatePicker(
      context: context,
      initialDate: dau ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Ngày sinh',
    );
    if (d == null) return;
    setState(() => _ngaySinh =
        '${d.year.toString().padLeft(4, '0')}-${_hai(d.month)}-${_hai(d.day)}');
  }

  Future<void> _chonGio() async {
    final p = _gioSinh?.split(':');
    final t = await showTimePicker(
      context: context,
      initialTime: p != null && p.length >= 2
          ? TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]))
          : const TimeOfDay(hour: 12, minute: 0),
      helpText: 'Giờ sinh',
    );
    if (t == null) return;
    setState(() => _gioSinh = '${_hai(t.hour)}:${_hai(t.minute)}');
  }

  static String _hai(int n) => n.toString().padLeft(2, '0');

  Future<void> _luu() async {
    final formHopLe = _form.currentState?.validate() ?? false;
    if (_ngaySinh == null) {
      setState(() => _loi = 'Hãy chọn ngày sinh.');
      return;
    }
    // Backend bắt buộc toạ độ. Khi sửa mà không đụng tới nơi sinh thì toạ độ
    // cũ vẫn còn; chỉ chặn khi đã gõ tên mới mà chưa chọn gợi ý.
    if (_viDo == null || _kinhDo == null) {
      setState(() =>
          _loi = 'Hãy chọn nơi sinh trong danh sách gợi ý để có toạ độ.');
      return;
    }
    if (!formHopLe) return;
    setState(() {
      _dangLuu = true;
      _loi = null;
    });
    try {
      await ref.read(astrologyRepositoryProvider).luu(widget.hoSo?.id, {
        'title': _tieuDe.text.trim(),
        'targetName':
            _tenNguoi.text.trim().isEmpty ? null : _tenNguoi.text.trim(),
        'birthDate': _ngaySinh,
        'birthTime': _gioSinh == null ? null : '$_gioSinh:00',
        'birthPlace': _noiSinh.text.trim(),
        'latitude': _viDo,
        'longitude': _kinhDo,
        'timezone': _muiGio.text.trim().isEmpty ? null : _muiGio.text.trim(),
        'profileType': _kieu,
        'isPrimary': _chinh,
      });
      if (!mounted) return;
      baoTin(context,
          widget.hoSo == null ? 'Đã tạo hồ sơ.' : 'Đã lưu thay đổi.');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _loi = e.message);
    } catch (_) {
      setState(() => _loi = 'Không lưu được hồ sơ.');
    } finally {
      if (mounted) setState(() => _dangLuu = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.hoSo == null ? 'Thêm hồ sơ' : 'Sửa hồ sơ')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
          children: [
            TextFormField(
              key: const ValueKey('o-tieu-de'),
              controller: _tieuDe,
              decoration: const InputDecoration(
                  labelText: 'Tên hồ sơ', hintText: 'Bản đồ sao của tôi'),
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.isEmpty) return 'Hãy đặt tên hồ sơ';
                if (s.length > 100) return 'Tối đa 100 ký tự';
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _kieu,
              dropdownColor: Mau.the,
              decoration: const InputDecoration(labelText: 'Hồ sơ của ai'),
              items: [
                for (final e in tenKieuHoSo.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _kieu = v ?? _kieu),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tenNguoi,
              decoration: const InputDecoration(
                  labelText: 'Tên người được xem', hintText: 'Không bắt buộc'),
              validator: (v) =>
                  (v?.trim().length ?? 0) > 100 ? 'Tối đa 100 ký tự' : null,
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('nut-ngay-sinh'),
                  onPressed: _chonNgay,
                  icon: const Icon(Icons.cake_outlined, size: 18),
                  label: Text(_ngaySinh == null
                      ? 'Ngày sinh'
                      : ngayViTuIso(_ngaySinh!)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('nut-gio-sinh'),
                  onPressed: _chonGio,
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text(_gioSinh ?? 'Giờ sinh'),
                ),
              ),
            ]),
            if (_gioSinh != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() => _gioSinh = null),
                  child: const Text('Không biết giờ sinh',
                      style: TextStyle(fontSize: 12)),
                ),
              ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('o-noi-sinh'),
              controller: _noiSinh,
              onChanged: _khiGoNoiSinh,
              decoration: InputDecoration(
                labelText: 'Nơi sinh',
                hintText: 'Gõ tên tỉnh, thành phố...',
                suffixIcon: _dangTim
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : (_viDo != null
                        ? const Icon(Icons.check_circle,
                            color: MauTrangThai.tot, size: 20)
                        : null),
              ),
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.isEmpty) return 'Hãy nhập nơi sinh';
                if (s.length > 255) return 'Tối đa 255 ký tự';
                return null;
              },
            ),
            for (final d in _goiY)
              ListTile(
                dense: true,
                leading: const Icon(Icons.place_outlined, size: 18),
                title: Text(d.ten,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5)),
                onTap: () => _chonDiaDanh(d),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _muiGio,
              decoration: const InputDecoration(labelText: 'Múi giờ'),
              validator: (v) =>
                  (v?.trim().length ?? 0) > 50 ? 'Tối đa 50 ký tự' : null,
            ),
            SwitchListTile(
              value: _chinh,
              onChanged: (v) => setState(() => _chinh = v),
              contentPadding: EdgeInsets.zero,
              title: const Text('Đặt làm hồ sơ chính',
                  style: TextStyle(fontSize: 13.5)),
              subtitle: const Text('AI đọc bài dựa trên hồ sơ chính.',
                  style: TextStyle(fontSize: 11.5, color: Mau.chuMo)),
            ),
            if (_loi != null) ...[
              const SizedBox(height: 6),
              Text(_loi!,
                  style:
                      const TextStyle(fontSize: 13, color: MauTrangThai.xau)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _dangLuu ? null : _luu,
              child: Text(widget.hoSo == null ? 'Tạo hồ sơ' : 'Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}
