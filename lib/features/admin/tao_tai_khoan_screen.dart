import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../theme.dart';
import '../../widgets/hop_thoai.dart';
import 'admin_repository.dart';

/// Tạo tài khoản cho đồng nghiệp mà không bắt họ tự đăng ký rồi mới cất nhắc.
///
/// Không có ô mật khẩu: người được tạo nhận liên kết để tự đặt. Không ai đặt
/// mật khẩu hộ người khác.
class TaoTaiKhoanScreen extends ConsumerStatefulWidget {
  const TaoTaiKhoanScreen({super.key, required this.vaiTroGanDuoc});
  final List<String> vaiTroGanDuoc;

  @override
  ConsumerState<TaoTaiKhoanScreen> createState() => _TaoTaiKhoanScreenState();
}

class _TaoTaiKhoanScreenState extends ConsumerState<TaoTaiKhoanScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _hoTen = TextEditingController();
  final _dienThoai = TextEditingController();
  late String _vaiTro = widget.vaiTroGanDuoc.contains('STAFF')
      ? 'STAFF'
      : widget.vaiTroGanDuoc.first;
  bool _daXacMinh = false;
  bool _dangGui = false;
  String? _loi;

  static final _dangEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _email.dispose();
    _hoTen.dispose();
    _dienThoai.dispose();
    super.dispose();
  }

  Future<void> _gui() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _dangGui = true;
      _loi = null;
    });
    try {
      await ref.read(adminRepositoryProvider).taoTaiKhoan(
            email: _email.text,
            hoTen: _hoTen.text,
            vaiTro: _vaiTro,
            dienThoai: _dienThoai.text,
            daXacMinh: _daXacMinh,
          );
      if (!mounted) return;
      baoTin(
        context,
        _daXacMinh
            ? 'Đã tạo tài khoản. Họ nhận liên kết để tự đặt mật khẩu.'
            : 'Đã tạo tài khoản. Họ cần xác minh email rồi mới đăng nhập được.',
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _loi = e.message);
    } catch (_) {
      setState(() => _loi = 'Không tạo được tài khoản.');
    } finally {
      if (mounted) setState(() => _dangGui = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo tài khoản')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
          children: [
            const Text(
              'Dùng khi cần lập tài khoản cho đồng nghiệp mà không bắt họ tự '
              'đăng ký rồi mới cất nhắc.',
              style: TextStyle(fontSize: 12.5, color: Mau.chuMo, height: 1.5),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('o-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) => (v == null || !_dangEmail.hasMatch(v.trim()))
                  ? 'Email không hợp lệ'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('o-ho-ten'),
              controller: _hoTen,
              decoration: const InputDecoration(labelText: 'Họ tên'),
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.isEmpty) return 'Họ tên là bắt buộc';
                if (s.length > 120) return 'Họ tên tối đa 120 ký tự';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dienThoai,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'Số điện thoại (tuỳ chọn)'),
              validator: (v) => (v != null && v.trim().length > 20)
                  ? 'Số điện thoại tối đa 20 ký tự'
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _vaiTro,
              dropdownColor: Mau.the,
              decoration: const InputDecoration(labelText: 'Vai trò'),
              items: [
                for (final v in widget.vaiTroGanDuoc)
                  DropdownMenuItem(value: v, child: Text(tenVaiTro[v]!)),
              ],
              onChanged: (v) => setState(() => _vaiTro = v ?? _vaiTro),
            ),
            const SizedBox(height: 6),
            Text(moTaVaiTro[_vaiTro] ?? '',
                style: const TextStyle(fontSize: 11.5, color: Mau.chuMo)),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _daXacMinh,
              onChanged: (v) => setState(() => _daXacMinh = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Đánh dấu email đã xác minh',
                  style: TextStyle(fontSize: 13.5)),
              subtitle: const Text(
                'Dùng khi bạn ngồi cạnh người đó. Họ vẫn nhận liên kết để tự '
                'đặt mật khẩu. Bỏ trống thì họ nhận mail xác minh như người '
                'tự đăng ký.',
                style: TextStyle(fontSize: 11.5, color: Mau.chuMo, height: 1.5),
              ),
            ),
            if (_loi != null) ...[
              const SizedBox(height: 8),
              Text(_loi!,
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFFE5645E))),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _dangGui ? null : _gui,
              child: _dangGui
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Tạo tài khoản'),
            ),
          ],
        ),
      ),
    );
  }
}
