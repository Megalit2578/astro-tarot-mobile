import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../readers/readers_screen.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
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
                      // KHÔNG kiểm độ dài ở màn đăng nhập. Luật 8 ký tự chỉ
                      // áp cho mật khẩu MỚI; tài khoản tạo từ trước có thể
                      // ngắn hơn, và chặn ở đây là khoá họ ra khỏi chính tài
                      // khoản của mình. Để máy chủ phán quyết.
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Hãy nhập mật khẩu'
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
                    const SizedBox(height: 14),
                    // Xem Reader không cần đăng nhập — endpoint /api/v1/readers
                    // là công khai, và web cũng cho khách duyệt trước. Bắt
                    // đăng nhập mới được nhìn là dựng tường ngay trước thứ
                    // khiến người ta muốn đăng ký.
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ReadersScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.people_outline, size: 18),
                      label: const Text('Xem Reader trước khi đăng nhập'),
                      style: TextButton.styleFrom(foregroundColor: Mau.vang),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const RegisterScreen(),
                            ),
                          ),
                          style:
                              TextButton.styleFrom(foregroundColor: Mau.chu),
                          child: const Text('Tạo tài khoản'),
                        ),
                        const Text('·',
                            style: TextStyle(color: Mau.chuMo)),
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ForgotPasswordScreen(),
                            ),
                          ),
                          style:
                              TextButton.styleFrom(foregroundColor: Mau.chuMo),
                          child: const Text('Quên mật khẩu'),
                        ),
                      ],
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
