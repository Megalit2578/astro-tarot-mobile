import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../theme.dart';
import 'profile_repository.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState
    extends ConsumerState<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _hienTai = TextEditingController();
  final _moi = TextEditingController();
  final _nhacLai = TextEditingController();
  bool _hien = false;
  bool _dangGui = false;
  String? _loi;

  @override
  void dispose() {
    _hienTai.dispose();
    _moi.dispose();
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
      await ref
          .read(profileRepositoryProvider)
          .doiMatKhau(_hienTai.text, _moi.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Đã đổi mật khẩu'), backgroundColor: Mau.the),
      );
      Navigator.of(context).pop();
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
      appBar: AppBar(title: const Text('Đổi mật khẩu')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _hienTai,
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'Mật khẩu hiện tại',
                      prefixIcon: Icon(Icons.lock_outline, size: 20),
                    ),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Hãy nhập mật khẩu hiện tại'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _moi,
                    obscureText: !_hien,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      hintText: 'Mật khẩu mới',
                      prefixIcon: const Icon(Icons.lock_reset, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _hien ? Icons.visibility_off : Icons.visibility,
                            size: 20),
                        onPressed: () => setState(() => _hien = !_hien),
                        tooltip: _hien ? 'Ẩn' : 'Hiện',
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.length < 8) {
                        return 'Mật khẩu phải từ 8 ký tự';
                      }
                      if (v.length > 128) return 'Tối đa 128 ký tự';
                      // Chặn ngay ở đây thay vì để máy chủ từ chối: đổi sang
                      // đúng mật khẩu đang dùng là thao tác vô nghĩa, và câu
                      // lỗi từ máy chủ sẽ không nói rõ điều đó.
                      if (v == _hienTai.text) {
                        return 'Mật khẩu mới trùng mật khẩu hiện tại';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nhacLai,
                    obscureText: !_hien,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _gui(),
                    decoration: const InputDecoration(
                      hintText: 'Nhắc lại mật khẩu mới',
                      prefixIcon: Icon(Icons.lock_outline, size: 20),
                    ),
                    validator: (v) =>
                        v == _moi.text ? null : 'Hai lần nhập không khớp',
                  ),
                  if (_loi != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0x22E5645E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x55E5645E)),
                      ),
                      child: Text(_loi!,
                          style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _dangGui ? null : _gui,
                    child: _dangGui
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Đổi mật khẩu'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Đổi xong, các thiết bị khác vẫn đăng nhập cho tới khi '
                    'phiên của chúng hết hạn.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Mau.chuMo, fontSize: 11.5, height: 1.6),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
