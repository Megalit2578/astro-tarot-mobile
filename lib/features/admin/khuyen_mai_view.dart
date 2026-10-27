import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../theme.dart';
import '../../widgets/trang_thai.dart';
import 'admin_repository.dart';

/// Một đợt khuyến mãi dịp lễ.
class KhuyenMai {
  const KhuyenMai({
    required this.id,
    required this.ten,
    required this.loiChuc,
    required this.loaiGiam,
    required this.giaTri,
    required this.giamToiDa,
    required this.batDau,
    required this.ketThuc,
    required this.dangBat,
    required this.dangChay,
  });

  final String id;
  final String ten;
  final String? loiChuc;

  /// `PHAN_TRAM` hoặc `SO_TIEN`.
  final String loaiGiam;
  final int giaTri;

  /// Trần giảm, chỉ có nghĩa với [loaiGiam] là `PHAN_TRAM`.
  final int? giamToiDa;
  final DateTime? batDau;
  final DateTime? ketThuc;

  /// Người quản trị đã bật đợt này chưa.
  final bool dangBat;

  /// Bật VÀ đang trong khoảng ngày — máy chủ tự tính, không suy ở đây.
  final bool dangChay;

  factory KhuyenMai.fromJson(Map<String, dynamic> j) => KhuyenMai(
    id: (j['id'] ?? '').toString(),
    ten: (j['ten'] ?? '') as String,
    loiChuc: j['loiChuc'] as String?,
    loaiGiam: (j['loaiGiam'] ?? 'SO_TIEN') as String,
    giaTri: (j['giaTri'] as num?)?.toInt() ?? 0,
    giamToiDa: (j['giamToiDa'] as num?)?.toInt(),
    batDau: DateTime.tryParse((j['batDau'] ?? '').toString())?.toLocal(),
    ketThuc: DateTime.tryParse((j['ketThuc'] ?? '').toString())?.toLocal(),
    dangBat: j['dangBat'] == true,
    dangChay: j['dangChay'] == true,
  );

  /// `30%` hoặc `50.000 ₫`.
  String get mucGiam => loaiGiam == 'PHAN_TRAM'
      ? '$giaTri%${giamToiDa != null ? ' (tối đa ${_tien(giamToiDa!)})' : ''}'
      : _tien(giaTri);
}

String _tien(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return '$b ₫';
}

String _ngay(DateTime? d) =>
    d == null ? '—' : '${d.day}/${d.month}/${d.year}';

final khuyenMaiAdminProvider = FutureProvider<List<KhuyenMai>>(
  (ref) => ref.read(adminRepositoryProvider).khuyenMai(),
);

/// Khuyến mãi dịp lễ.
///
/// ## Vì sao nút sửa và xoá phụ thuộc [suaDuoc]
///
/// Backend cho `USERS_MANAGE` hoặc `AUDIT_VIEW` ĐỌC danh sách, nhưng chỉ
/// `USERS_MANAGE` mới tạo, sửa và xoá được — xem `KhuyenMaiController`. Bày
/// nút cho người chỉ có `AUDIT_VIEW` là dẫn họ tới một lượt 403.
class KhuyenMaiView extends ConsumerWidget {
  const KhuyenMaiView({super.key, required this.suaDuoc});

  final bool suaDuoc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = ref.watch(khuyenMaiAdminProvider);

    return Stack(
      children: [
        ds.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: Mau.vang),
          ),
          error: (e, _) => KhoiLoi(
            thongDiep: e is ApiException
                ? e.message
                : 'Không tải được danh sách khuyến mãi.',
            thuLai: () => ref.invalidate(khuyenMaiAdminProvider),
          ),
          data: (list) => list.isEmpty
              ? const KhoiTrong(
                  icon: Icons.local_offer_outlined,
                  tieuDe: 'Chưa có đợt khuyến mãi nào',
                  moTa: 'Tạo một đợt để giảm giá gói AI trong dịp lễ.',
                )
              : RefreshIndicator(
                  color: Mau.vang,
                  backgroundColor: Mau.the,
                  onRefresh: () async =>
                      ref.invalidate(khuyenMaiAdminProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                    itemCount: list.length,
                    itemBuilder: (_, i) =>
                        _TheDot(k: list[i], suaDuoc: suaDuoc),
                  ),
                ),
        ),
        if (suaDuoc)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              heroTag: 'them-khuyen-mai',
              backgroundColor: Mau.vang,
              foregroundColor: Mau.nen,
              onPressed: () => _moForm(context, ref, null),
              icon: const Icon(Icons.add),
              label: const Text('Thêm đợt'),
            ),
          ),
      ],
    );
  }
}

Future<void> _moForm(BuildContext context, WidgetRef ref, KhuyenMai? cu) async {
  final xong = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Mau.the,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _FormDot(cu: cu),
  );
  if (xong == true) ref.invalidate(khuyenMaiAdminProvider);
}

class _TheDot extends ConsumerWidget {
  const _TheDot({required this.k, required this.suaDuoc});

  final KhuyenMai k;
  final bool suaDuoc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Mau.the,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: k.dangChay ? Mau.vang.withValues(alpha: 0.5) : Mau.vien,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  k.ten,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Mau.chu,
                  ),
                ),
              ),
              // Ba trạng thái khác nhau, đừng gộp: "đang chạy" là bật VÀ
              // trong khoảng ngày; "đã bật" mà chưa chạy nghĩa là chưa tới
              // ngày hoặc đã hết hạn — người quản trị cần phân biệt được.
              _Chip(
                chu: k.dangChay
                    ? 'Đang chạy'
                    : (k.dangBat ? 'Đã bật, ngoài kỳ' : 'Đang tắt'),
                nhan: k.dangChay,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Giảm ${k.mucGiam}',
            style: const TextStyle(fontSize: 13, color: Mau.vang),
          ),
          const SizedBox(height: 2),
          Text(
            '${_ngay(k.batDau)} → ${_ngay(k.ketThuc)}',
            style: const TextStyle(fontSize: 12, color: Mau.chuMo),
          ),
          if (k.loiChuc != null && k.loiChuc!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              k.loiChuc!,
              style: const TextStyle(
                fontSize: 12,
                color: Mau.chuMo,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (suaDuoc) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _moForm(context, ref, k),
                  style: TextButton.styleFrom(foregroundColor: Mau.vang),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Sửa', style: TextStyle(fontSize: 12)),
                ),
                TextButton.icon(
                  onPressed: () => _xoa(context, ref, k),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                  ),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Xoá', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _xoa(BuildContext context, WidgetRef ref, KhuyenMai k) async {
    // Hỏi trước: xoá một đợt không hoàn lại được, và tên các đợt lễ khá giống
    // nhau nên bấm nhầm dòng là chuyện có thật.
    final chac = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Mau.the,
        title: const Text('Xoá đợt này?', style: TextStyle(color: Mau.chu)),
        content: Text(
          '"${k.ten}" sẽ bị xoá hẳn. Không hoàn lại được.',
          style: const TextStyle(color: Mau.chuMo),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Thôi'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (chac != true || !context.mounted) return;

    try {
      await ref.read(adminRepositoryProvider).xoaKhuyenMai(k.id);
      ref.invalidate(khuyenMaiAdminProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.chu, required this.nhan});
  final String chu;
  final bool nhan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: nhan ? Mau.vang.withValues(alpha: 0.15) : Colors.white10,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        chu,
        style: TextStyle(
          fontSize: 10,
          color: nhan ? Mau.vang : Mau.chuMo,
        ),
      ),
    );
  }
}

class _FormDot extends ConsumerStatefulWidget {
  const _FormDot({this.cu});
  final KhuyenMai? cu;

  @override
  ConsumerState<_FormDot> createState() => _FormDotState();
}

class _FormDotState extends ConsumerState<_FormDot> {
  final _khoa = GlobalKey<FormState>();
  late final TextEditingController _ten;
  late final TextEditingController _loiChuc;
  late final TextEditingController _giaTri;
  late final TextEditingController _giamToiDa;
  late String _loai;
  late DateTime _batDau;
  late DateTime _ketThuc;
  late bool _bat;
  bool _dangLuu = false;
  String? _loi;

  @override
  void initState() {
    super.initState();
    final c = widget.cu;
    final n = DateTime.now();
    _ten = TextEditingController(text: c?.ten ?? '');
    _loiChuc = TextEditingController(text: c?.loiChuc ?? '');
    _giaTri = TextEditingController(text: c == null ? '' : '${c.giaTri}');
    _giamToiDa = TextEditingController(
      text: c?.giamToiDa == null ? '' : '${c!.giamToiDa}',
    );
    _loai = c?.loaiGiam ?? 'PHAN_TRAM';
    _batDau = c?.batDau ?? DateTime(n.year, n.month, n.day);
    _ketThuc = c?.ketThuc ?? DateTime(n.year, n.month, n.day + 7);
    _bat = c?.dangBat ?? true;
  }

  @override
  void dispose() {
    _ten.dispose();
    _loiChuc.dispose();
    _giaTri.dispose();
    _giamToiDa.dispose();
    super.dispose();
  }

  Future<void> _chonNgay({required bool dau}) async {
    final n = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: dau ? _batDau : _ketThuc,
      firstDate: DateTime(n.year - 1),
      lastDate: DateTime(n.year + 3),
    );
    if (d == null) return;
    setState(() {
      if (dau) {
        _batDau = d;
        // Kéo ngày kết thúc theo nếu nó rơi về trước ngày bắt đầu — để người
        // dùng khỏi gửi một khoảng ngược rồi nhận lỗi từ máy chủ.
        if (!_ketThuc.isAfter(_batDau)) {
          _ketThuc = DateTime(d.year, d.month, d.day + 7);
        }
      } else {
        _ketThuc = d;
      }
    });
  }

  Future<void> _luu() async {
    if (!_khoa.currentState!.validate()) return;
    if (!_ketThuc.isAfter(_batDau)) {
      setState(() => _loi = 'Ngày kết thúc phải sau ngày bắt đầu.');
      return;
    }
    setState(() {
      _dangLuu = true;
      _loi = null;
    });
    try {
      final repo = ref.read(adminRepositoryProvider);
      final body = {
        'ten': _ten.text.trim(),
        'loiChuc': _loiChuc.text.trim().isEmpty ? null : _loiChuc.text.trim(),
        'loaiGiam': _loai,
        'giaTri': int.parse(_giaTri.text.trim()),
        'giamToiDa': _loai == 'PHAN_TRAM' && _giamToiDa.text.trim().isNotEmpty
            ? int.parse(_giamToiDa.text.trim())
            : null,
        'batDau': _batDau.toUtc().toIso8601String(),
        'ketThuc': _ketThuc.toUtc().toIso8601String(),
        'dangBat': _bat,
      };
      if (widget.cu == null) {
        await repo.taoKhuyenMai(body);
      } else {
        await repo.suaKhuyenMai(widget.cu!.id, body);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() {
        _dangLuu = false;
        _loi = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final phanTram = _loai == 'PHAN_TRAM';
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _khoa,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.cu == null ? 'Thêm đợt khuyến mãi' : 'Sửa đợt khuyến mãi',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Mau.chu,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ten,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Tên đợt'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nhập tên đợt' : null,
              ),
              TextFormField(
                controller: _loiChuc,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Lời chúc (không bắt buộc)',
                  helperText: 'Hiện một lần khi người dùng đăng nhập',
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'PHAN_TRAM', label: Text('Theo %')),
                  ButtonSegment(value: 'SO_TIEN', label: Text('Số tiền')),
                ],
                selected: {_loai},
                onSelectionChanged: (s) => setState(() => _loai = s.first),
                // Không để màu mặc định: nó lấy sắc tím của Material, lạc
                // hẳn giữa một giao diện vàng trên nền tối.
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: Mau.vang.withValues(alpha: 0.2),
                  selectedForegroundColor: Mau.vang,
                  foregroundColor: Mau.chuMo,
                  side: const BorderSide(color: Mau.vien),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _giaTri,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: phanTram ? 'Giảm bao nhiêu %' : 'Giảm bao nhiêu ₫',
                ),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  if (n == null || n <= 0) return 'Nhập số lớn hơn 0';
                  if (phanTram && n > 100) return 'Phần trăm tối đa là 100';
                  return null;
                },
              ),
              if (phanTram)
                TextFormField(
                  controller: _giamToiDa,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Trần giảm (không bắt buộc)',
                    helperText: 'Giảm % nhưng không quá số tiền này',
                  ),
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return null;
                    final n = int.tryParse(s);
                    return (n == null || n <= 0) ? 'Nhập số lớn hơn 0' : null;
                  },
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _NutNgay(
                      nhan: 'Bắt đầu',
                      ngay: _batDau,
                      bam: () => _chonNgay(dau: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _NutNgay(
                      nhan: 'Kết thúc',
                      ngay: _ketThuc,
                      bam: () => _chonNgay(dau: false),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                value: _bat,
                onChanged: (v) => setState(() => _bat = v),
                title: const Text(
                  'Bật đợt này',
                  style: TextStyle(fontSize: 14, color: Mau.chu),
                ),
                subtitle: const Text(
                  'Tắt thì giữ lại cấu hình mà không áp dụng',
                  style: TextStyle(fontSize: 12, color: Mau.chuMo),
                ),
                contentPadding: EdgeInsets.zero,
                activeThumbColor: Mau.vang,
              ),
              if (_loi != null) ...[
                const SizedBox(height: 4),
                Text(
                  _loi!,
                  style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _dangLuu ? null : _luu,
                  style: FilledButton.styleFrom(
                    backgroundColor: Mau.vang,
                    foregroundColor: Mau.nen,
                  ),
                  child: _dangLuu
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Lưu'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NutNgay extends StatelessWidget {
  const _NutNgay({required this.nhan, required this.ngay, required this.bam});

  final String nhan;
  final DateTime ngay;
  final VoidCallback bam;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: bam,
      style: OutlinedButton.styleFrom(
        foregroundColor: Mau.chu,
        side: const BorderSide(color: Mau.vien),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Column(
        children: [
          Text(
            nhan,
            style: const TextStyle(fontSize: 11, color: Mau.chuMo),
          ),
          Text(_ngay(ngay), style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
