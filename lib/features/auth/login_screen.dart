import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../widgets/hop_thoai.dart';
import '../readers/readers_screen.dart';
import 'email_link_screen.dart';
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
  bool _dangGuiLai = false;

  /// Backend trả nguyên văn câu có cụm này khi tài khoản chưa xác minh email.
  /// Web nhận diện đúng cách này; giữ một cách cho hai nơi khỏi lệch.
  static bool _chuaXacMinh(String? loi) =>
      loi != null && loi.contains('chưa được xác minh');

  Future<void> _guiLaiXacMinh() async {
    final email = _email.text.trim();
    if (!email.contains('@')) return;
    setState(() => _dangGuiLai = true);
    try {
      await ref.read(authControllerProvider.notifier).guiLaiXacMinh(email);
      if (!mounted) return;
      baoTin(context, 'Đã gửi lại thư xác minh tới $email.');
    } catch (e) {
      if (!mounted) return;
      baoLoi(context, e, 'Không gửi lại được thư xác minh.');
    } finally {
      if (mounted) setState(() => _dangGuiLai = false);
    }
  }

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
                      // Chưa xác minh thì chỉ báo lỗi là ngõ cụt: thư cũ có
                      // thể đã hết hạn (24 giờ) hoặc rơi vào thư rác.
                      if (_chuaXacMinh(auth.loi))
                        TextButton.icon(
                          onPressed: _dangGuiLai ? null : _guiLaiXacMinh,
                          icon: const Icon(Icons.mark_email_read_outlined,
                              size: 18),
                          label: const Text('Gửi lại thư xác minh'),
                          style:
                              TextButton.styleFrom(foregroundColor: Mau.vang),
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
                    // Wrap chứ không phải Row: người dùng đặt cỡ chữ lớn
                    // trong máy thì hai nút không còn vừa một hàng, và Row
                    // sẽ tràn ra ngoài màn.
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
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
                    // Liên kết trong thư xác minh / đặt lại mật khẩu trỏ về
                    // trang web. Chưa có liên kết sâu vào app, nên cho dán
                    // liên kết ấy vào đây — khỏi bắt người dùng sang máy tính.
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const EmailLinkScreen(),
                        ),
                      ),
                      style: TextButton.styleFrom(foregroundColor: Mau.chuMo),
                      child: const Text('Tôi có liên kết trong email',
                          style: TextStyle(fontSize: 12.5)),
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
