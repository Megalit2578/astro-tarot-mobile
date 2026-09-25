import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _matKhau = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _hien = false;

  @override
  void dispose() {
    _email.dispose();
    _matKhau.dispose();
    super.dispose();
  }

  Future<void> _gui() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    // Cất bàn phím trước: trên màn nhỏ nó che mất chỗ hiện lỗi, và người dùng
    // tưởng bấm xong không có gì xảy ra.
    FocusScope.of(context).unfocus();
    await ref
        .read(authControllerProvider.notifier)
        .dangNhap(_email.text, _matKhau.text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.auto_awesome, color: Mau.vang, size: 44),
                    const SizedBox(height: 16),
                    Text(
                      'ASTROTAROT',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            letterSpacing: 4,
                            fontWeight: FontWeight.w300,
                          ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Đăng nhập để đặt lịch và trò chuyện với Reader',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Mau.chuMo, fontSize: 13),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline, size: 20),
                      ),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Email chưa đúng định dạng'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _matKhau,
                      obscureText: !_hien,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _gui(),
                      decoration: InputDecoration(
                        hintText: 'Mật khẩu',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _hien ? Icons.visibility_off : Icons.visibility,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _hien = !_hien),
                          tooltip: _hien ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 6)
                          ? 'Mật khẩu tối thiểu 6 ký tự'
                          : null,
                    ),
                    if (auth.loi != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0x22E5645E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x55E5645E)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                size: 18, color: Color(0xFFE5645E)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                auth.loi!,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: auth.dangXuLy ? null : _gui,
                      child: auth.dangXuLy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Đăng nhập'),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Chưa có tài khoản? Hãy đăng ký trên astrotarot.date — '
                      'tài khoản phải xác minh email mới đăng nhập được.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Mau.chuMo, fontSize: 12, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
