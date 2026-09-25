import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_controller.dart';
import '../../theme.dart';
import '../../widgets/trang_thai.dart';
import 'change_password_screen.dart';
import 'profile_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hs = ref.watch(hoSoProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ cá nhân')),
      body: hs.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Mau.vang)),
        error: (e, _) => KhoiLoi(
          thongDiep:
              e is ApiException ? e.message : 'Không tải được hồ sơ.',
          thuLai: () => ref.invalidate(hoSoProvider),
        ),
        data: (h) => _Form(hoSo: h),
      ),
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.hoSo});
  final HoSo hoSo;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  late final TextEditingController _hoTen;
  late final TextEditingController _dienThoai;
  late final TextEditingController _gioiThieu;
  late final TextEditingController _diaChi;
  late final TextEditingController _tinh;
  late final TextEditingController _quocGia;
  late String? _gioiTinh;
  DateTime? _ngaySinh;

  final _form = GlobalKey<FormState>();
  bool _dangLuu = false;
  bool _dangTaiAnh = false;

  static const _gioiTinhs = {
    'MALE': 'Nam',
    'FEMALE': 'Nữ',
    'OTHER': 'Khác',
    'UNDISCLOSED': 'Không tiết lộ',
  };

  @override
  void initState() {
    super.initState();
    final h = widget.hoSo;
    _hoTen = TextEditingController(text: h.fullName);
    _dienThoai = TextEditingController(text: h.phone ?? '');
    _gioiThieu = TextEditingController(text: h.bio ?? '');
    _diaChi = TextEditingController(text: h.address ?? '');
    _tinh = TextEditingController(text: h.city ?? '');
    _quocGia = TextEditingController(text: h.country ?? '');
    _gioiTinh = _gioiTinhs.containsKey(h.gender) ? h.gender : null;
    _ngaySinh =
        h.dateOfBirth == null ? null : DateTime.tryParse(h.dateOfBirth!);
  }

  @override
  void dispose() {
    _hoTen.dispose();
    _dienThoai.dispose();
    _gioiThieu.dispose();
    _diaChi.dispose();
    _tinh.dispose();
    _quocGia.dispose();
    super.dispose();
  }

  Future<void> _luu() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _dangLuu = true);
    try {
      await ref.read(profileRepositoryProvider).luu({
        'fullName': _hoTen.text.trim(),
        'phone': _dienThoai.text.trim(),
        'gender': _gioiTinh,
        'dateOfBirth': _ngaySinh == null ? null : _ngayISO(_ngaySinh!),
        'bio': _gioiThieu.text.trim(),
        'address': _diaChi.text.trim(),
        'city': _tinh.text.trim(),
        'country': _quocGia.text.trim(),
      });
      ref.invalidate(hoSoProvider);
      // Tên và ảnh hiện ở nhiều màn khác; nạp lại phiên để chúng đổi theo.
      await ref.read(authControllerProvider.notifier).lamMoiToi();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu hồ sơ'), backgroundColor: Mau.the),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Mau.the),
      );
    } finally {
      if (mounted) setState(() => _dangLuu = false);
    }
  }

  /// `yyyy-MM-dd` — đúng dạng `LocalDate` bên backend nhận.
  ///
  /// Không dùng toIso8601String(): nó kèm cả phần giờ và chữ T, và backend
  /// parse LocalDate sẽ từ chối.
  String _ngayISO(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _chonNgay() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _ngaySinh ?? DateTime(now.year - 20),
      firstDate: DateTime(1900),
      // Ngày sinh phải ở quá khứ (@Past bên backend). Chặn ngay ở đây thì
      // người dùng không chọn được ngày mai rồi mới bị từ chối.
      lastDate: now.subtract(const Duration(days: 1)),
      helpText: 'Chọn ngày sinh',
    );
    if (d != null) setState(() => _ngaySinh = d);
  }

  Future<void> _doiAnh() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      // Nén trước khi gửi: ảnh gốc từ máy ảnh điện thoại thường 3–8MB, tải
      // lên bằng 4G vừa lâu vừa dễ hỏng giữa chừng, mà hiển thị thì chỉ cần
      // vài trăm pixel.
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (x == null) return;
    setState(() => _dangTaiAnh = true);
    try {
      await ref.read(profileRepositoryProvider).taiAnh(x.path);
      ref.invalidate(hoSoProvider);
      await ref.read(authControllerProvider.notifier).lamMoiToi();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Đã đổi ảnh đại diện'), backgroundColor: Mau.the),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Mau.the),
      );
    } finally {
      if (mounted) setState(() => _dangTaiAnh = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.hoSo;
    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Center(
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Mau.the,
                      backgroundImage: (h.avatar != null && h.avatar!.isNotEmpty)
                          ? NetworkImage(h.avatar!)
                          : null,
                      child: (h.avatar == null || h.avatar!.isEmpty)
                          ? const Icon(Icons.person, size: 34, color: Mau.vang)
                          : null,
                    ),
                    if (_dangTaiAnh)
                      const Positioned.fill(
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          child: SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Mau.vang),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _dangTaiAnh ? null : _doiAnh,
                  icon: const Icon(Icons.photo_camera_outlined, size: 17),
                  label: const Text('Đổi ảnh'),
                  style: TextButton.styleFrom(foregroundColor: Mau.vang),
                ),
              ],
            ),
          ),

          _O(nhan: 'Họ và tên', c: _hoTen, batBuoc: true, toiDa: 255),
          _O(
            nhan: 'Số điện thoại',
            c: _dienThoai,
            kieu: TextInputType.phone,
            // Đúng luật backend: 10 chữ số, bắt đầu bằng 0. Kiểm ở đây để
            // người dùng biết ngay, thay vì gõ xong cả form mới bị từ chối.
            kiem: (v) => (v.isEmpty || RegExp(r'^0[0-9]{9}$').hasMatch(v))
                ? null
                : 'Số điện thoại gồm 10 chữ số và bắt đầu bằng 0',
          ),

          const SizedBox(height: 4),
          _Nhan('Giới tính'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final e in _gioiTinhs.entries)
                ChoiceChip(
                  selected: _gioiTinh == e.key,
                  onSelected: (_) => setState(
                      () => _gioiTinh = _gioiTinh == e.key ? null : e.key),
                  label: Text(e.value),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: _gioiTinh == e.key ? Mau.vang : Mau.chuMo,
                  ),
                  backgroundColor: Mau.the,
                  selectedColor: Mau.vang.withValues(alpha: 0.16),
                  side: BorderSide(
                      color: _gioiTinh == e.key ? Mau.vang : Mau.vien),
                  showCheckmark: false,
                ),
            ],
          ),

          const SizedBox(height: 16),
          _Nhan('Ngày sinh'),
          const SizedBox(height: 6),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _chonNgay,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              decoration: BoxDecoration(
                color: Mau.the,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Mau.vien),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 17, color: Mau.chuMo),
                  const SizedBox(width: 11),
                  Text(
                    _ngaySinh == null
                        ? 'Chưa chọn'
                        // dd/mm/yyyy — thống nhất toàn dự án.
                        : '${_ngaySinh!.day.toString().padLeft(2, '0')}/'
                            '${_ngaySinh!.month.toString().padLeft(2, '0')}/'
                            '${_ngaySinh!.year}',
                    style: TextStyle(
                      fontSize: 14,
                      color: _ngaySinh == null ? Mau.chuMo : Mau.chu,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          _O(nhan: 'Giới thiệu', c: _gioiThieu, dong: 3, toiDa: 500),
          _O(nhan: 'Địa chỉ', c: _diaChi, toiDa: 500),
          _O(nhan: 'Tỉnh/Thành', c: _tinh, toiDa: 120),
          _O(nhan: 'Quốc gia', c: _quocGia, toiDa: 120),

          const SizedBox(height: 10),
          FilledButton(
            onPressed: _dangLuu ? null : _luu,
            child: _dangLuu
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Lưu hồ sơ'),
          ),

          const SizedBox(height: 26),
          _ChiDoc(nhan: 'Email', giaTri: h.email ?? '—'),
          _ChiDoc(
            nhan: 'Xác minh email',
            giaTri: h.emailVerified ? 'Đã xác minh' : 'Chưa xác minh',
          ),
          _ChiDoc(nhan: 'Tên đăng nhập', giaTri: h.username),
          const SizedBox(height: 6),
          // Nói rõ vì sao ba ô trên không sửa được. Không nói thì người dùng
          // đi tìm nút sửa, tưởng giao diện thiếu.
          const Text(
            'Email và tên đăng nhập không sửa ở đây: đổi email phải đi qua '
            'luồng xác minh riêng.',
            style: TextStyle(fontSize: 11.5, color: Mau.chuMo, height: 1.6),
          ),

          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const ChangePasswordScreen()),
            ),
            icon: const Icon(Icons.lock_outline, size: 18),
            label: const Text('Đổi mật khẩu'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: Mau.vang,
              side: const BorderSide(color: Mau.vien),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Nhan extends StatelessWidget {
  const _Nhan(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 12, color: Mau.chuMo));
}

class _O extends StatelessWidget {
  const _O({
    required this.nhan,
    required this.c,
    this.kieu,
    this.dong = 1,
    this.batBuoc = false,
    this.toiDa,
    this.kiem,
  });

  final String nhan;
  final TextEditingController c;
  final TextInputType? kieu;
  final int dong;
  final bool batBuoc;
  final int? toiDa;
  final String? Function(String)? kiem;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Nhan(nhan),
          const SizedBox(height: 6),
          TextFormField(
            controller: c,
            keyboardType: kieu,
            minLines: dong,
            maxLines: dong,
            textCapitalization: dong > 1
                ? TextCapitalization.sentences
                : TextCapitalization.words,
            validator: (v) {
              final t = (v ?? '').trim();
              if (batBuoc && t.isEmpty) return 'Không được để trống';
              if (toiDa != null && t.length > toiDa!) {
                return 'Tối đa $toiDa ký tự';
              }
              return kiem?.call(t);
            },
          ),
        ],
      ),
    );
  }
}

class _ChiDoc extends StatelessWidget {
  const _ChiDoc({required this.nhan, required this.giaTri});
  final String nhan;
  final String giaTri;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(nhan,
                style: const TextStyle(fontSize: 12.5, color: Mau.chuMo)),
          ),
          Expanded(
              child: Text(giaTri, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
