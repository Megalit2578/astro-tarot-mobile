import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_controller.dart';
import '../../theme.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _hoTen = TextEditingController();
  final _email = TextEditingController();
  final _matKhau = TextEditingController();
  final _nhacLai = TextEditingController();

  bool _hien = false;
  bool _dangGui = false;
  String? _loi;
  String? _xong;

  @override
  void dispose() {
    _hoTen.dispose();
    _email.dispose();
    _matKhau.dispose();
    _nhacLai.dispose();
    super.dispose();
  }

  Future<void> _gui() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _dangGui = true;
      _loi = null;
    });
    try {
      final cau = await ref.read(authControllerProvider.notifier).dangKy(
            email: _email.text,
            matKhau: _matKhau.text,
            hoTen: _hoTen.text,
          );
      if (!mounted) return;
      setState(() => _xong = cau);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loi = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loi = 'Không tạo được tài khoản.');
    } finally {
      if (mounted) setState(() => _dangGui = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo tài khoản')),
      body: SafeArea(
        child: _xong != null ? _ManXong(cau: _xong!) : _manForm(),
      ),
    );
  }

  Widget _manForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _hoTen,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(
                  hintText: 'Họ và tên',
                  prefixIcon: Icon(Icons.badge_outlined, size: 20),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Hãy nhập họ tên'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  hintText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline, size: 20),
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  // Kiểm tra tối thiểu, đúng bằng thứ backend kiểm. Đặt luật
                  // chặt hơn ở đây là chặn nhầm những email hợp lệ mà hiếm
                  // gặp, và người dùng không hiểu vì sao bị từ chối.
                  final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t);
                  return ok ? null : 'Email chưa đúng định dạng';
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _matKhau,
                obscureText: !_hien,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  hintText: 'Mật khẩu',
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(_hien ? Icons.visibility_off : Icons.visibility,
                        size: 20),
                    onPressed: () => setState(() => _hien = !_hien),
                    tooltip: _hien ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
                  ),
                ),
                // 8 ký tự, khớp đúng @Size(min = 8) bên backend. Đặt 6 như màn
                // đăng nhập thì người dùng gõ xong mới bị máy chủ từ chối.
                validator: (v) => (v == null || v.length < 8)
                    ? 'Mật khẩu phải từ 8 ký tự'
                    : (v.length > 128 ? 'Mật khẩu tối đa 128 ký tự' : null),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nhacLai,
                obscureText: !_hien,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _gui(),
                decoration: const InputDecoration(
                  hintText: 'Nhắc lại mật khẩu',
                  prefixIcon: Icon(Icons.lock_outline, size: 20),
                ),
                validator: (v) =>
                    v == _matKhau.text ? null : 'Hai lần nhập không khớp',
              ),
              if (_loi != null) ...[
                const SizedBox(height: 14),
                _HopLoi(cau: _loi!),
              ],
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _dangGui ? null : _gui,
                child: _dangGui
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Tạo tài khoản'),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tạo xong bạn sẽ nhận một thư xác minh. Phải bấm liên kết '
                'trong thư mới đăng nhập được.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: Mau.chuMo, fontSize: 12, height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManXong extends StatelessWidget {
  const _ManXong({required this.cau});
  final String cau;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mark_email_unread_outlined,
                size: 44, color: Mau.vang),
            const SizedBox(height: 20),
            Text(
              cau,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, height: 1.7),
            ),
            const SizedBox(height: 26),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Quay lại đăng nhập'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HopLoi extends StatelessWidget {
  const _HopLoi({required this.cau});
  final String cau;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x22E5645E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x55E5645E)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: Color(0xFFE5645E)),
          const SizedBox(width: 8),
          Expanded(child: Text(cau, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
