import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_controller.dart';
import '../../theme.dart';

/// Quên mật khẩu.
///
/// Chỉ gửi thư; phần đặt lại mật khẩu diễn ra trên web qua liên kết trong
/// thư. Không dựng màn đặt lại trong app vì liên kết ấy mở trình duyệt, và
/// làm deep link cho một việc mỗi người dùng làm một lần trong đời là công
/// sức đặt sai chỗ.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _dangGui = false;
  bool _daGui = false;
  String? _loi;

  @override
  void dispose() {
    _email.dispose();
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
      await ref
          .read(authControllerProvider.notifier)
          .quenMatKhau(_email.text);
      if (!mounted) return;
      setState(() => _daGui = true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loi = e.message);
    } finally {
      if (mounted) setState(() => _dangGui = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quên mật khẩu')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _daGui ? _daGuiXong() : _form_(),
          ),
        ),
      ),
    );
  }

  Widget _form_() => Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Nhập email đã đăng ký. Chúng tôi gửi cho bạn một liên kết để '
              'đặt lại mật khẩu.',
              style: TextStyle(color: Mau.chuMo, fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _gui(),
              decoration: const InputDecoration(
                hintText: 'Email',
                prefixIcon: Icon(Icons.mail_outline, size: 20),
              ),
              validator: (v) =>
                  (v == null || !v.contains('@')) ? 'Email chưa đúng' : null,
            ),
            if (_loi != null) ...[
              const SizedBox(height: 14),
              Text(_loi!,
                  style: const TextStyle(
                      color: Color(0xFFE5645E), fontSize: 13)),
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
                  : const Text('Gửi liên kết'),
            ),
          ],
        ),
      );

  Widget _daGuiXong() => Column(
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.mark_email_read_outlined,
              size: 44, color: Mau.vang),
          const SizedBox(height: 20),
          Text(
            'Nếu ${_email.text.trim()} đã đăng ký, thư đặt lại mật khẩu đang '
            'trên đường tới. Kiểm tra cả hộp thư rác.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, height: 1.7),
          ),
          const SizedBox(height: 10),
          // Nói rõ vì sao câu trên dùng chữ "nếu". Không giải thích thì người
          // dùng tưởng hệ thống lấp lửng; giải thích rồi thì họ hiểu đó là
          // cách bảo vệ, và cũng bớt bấm gửi lại nhiều lần.
          const Text(
            'Chúng tôi trả lời giống nhau cho mọi email, kể cả email chưa '
            'đăng ký — để không ai dùng ô này dò xem người khác có tài khoản '
            'hay không.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Mau.chuMo, fontSize: 11.5, height: 1.6),
          ),
          const SizedBox(height: 26),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Quay lại đăng nhập'),
          ),
        ],
      );
}
