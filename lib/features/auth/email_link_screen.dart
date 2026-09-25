import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_controller.dart';
import '../../theme.dart';

/// Loại liên kết đọc được từ thư của hệ thống.
enum LoaiLienKet { xacMinh, datLaiMatKhau }

/// Kết quả bóc một liên kết trong email.
class LienKetEmail {
  const LienKetEmail(this.loai, this.token);
  final LoaiLienKet loai;
  final String token;

  /// Đọc liên kết dạng `https://astrotarot.date/verify-email?token=…` hoặc
  /// `…/reset-password?token=…`.
  ///
  /// Nhận cả khi người dùng chỉ dán phần mã: lúc ấy không biết là loại nào,
  /// nên trả null ở [loai] — màn hình sẽ hỏi.
  static LienKetEmail? doc(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final uri = Uri.tryParse(s);
    final token = uri?.queryParameters['token'];
    if (uri == null || token == null || token.isEmpty) return null;
    final duong = uri.path.toLowerCase();
    if (duong.contains('verify-email')) {
      return LienKetEmail(LoaiLienKet.xacMinh, token);
    }
    if (duong.contains('reset-password')) {
      return LienKetEmail(LoaiLienKet.datLaiMatKhau, token);
    }
    return null;
  }
}

/// Mở liên kết trong email ngay trong app.
///
/// Thư xác minh và thư đặt lại mật khẩu trỏ về trang web — app chưa đăng ký
/// liên kết sâu (App Links cần xác minh tên miền, một việc riêng). Thay vì bắt
/// người dùng chạy sang máy tính, cho họ chép liên kết trong thư rồi dán vào
/// đây. Ô dán tự nhận ra đó là thư nào.
class EmailLinkScreen extends ConsumerStatefulWidget {
  const EmailLinkScreen({super.key});

  @override
  ConsumerState<EmailLinkScreen> createState() => _EmailLinkScreenState();
}

class _EmailLinkScreenState extends ConsumerState<EmailLinkScreen> {
  final _lienKet = TextEditingController();
  final _matKhau = TextEditingController();
  final _nhapLai = TextEditingController();
  final _form = GlobalKey<FormState>();

  LienKetEmail? _doc;
  bool _dangChay = false;
  String? _loi;
  String? _xong;

  @override
  void dispose() {
    _lienKet.dispose();
    _matKhau.dispose();
    _nhapLai.dispose();
    super.dispose();
  }

  void _khiDoi(String v) => setState(() {
        _doc = LienKetEmail.doc(v);
        _loi = null;
      });

  Future<void> _dan() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final t = d?.text ?? '';
    _lienKet.text = t;
    _khiDoi(t);
  }

  Future<void> _chay() async {
    final doc = _doc;
    if (doc == null) return;
    if (doc.loai == LoaiLienKet.datLaiMatKhau &&
        !(_form.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _dangChay = true;
      _loi = null;
    });
    final auth = ref.read(authControllerProvider.notifier);
    try {
      if (doc.loai == LoaiLienKet.xacMinh) {
        final email = await auth.xacMinhEmail(doc.token);
        _xong = email.isEmpty
            ? 'Tài khoản đã được kích hoạt. Bạn có thể đăng nhập ngay.'
            : 'Tài khoản $email đã được kích hoạt. Bạn có thể đăng nhập ngay.';
      } else {
        await auth.datLaiMatKhau(doc.token, _matKhau.text);
        _xong = 'Đã đặt mật khẩu mới. Đăng nhập bằng mật khẩu vừa đặt nhé.';
      }
    } on ApiException catch (e) {
      _loi = e.message;
    } catch (_) {
      _loi = 'Không xử lý được liên kết này.';
    } finally {
      if (mounted) setState(() => _dangChay = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    return Scaffold(
      appBar: AppBar(title: const Text('Liên kết trong email')),
      body: SafeArea(
        child: _xong != null
            ? _KetQua(noiDung: _xong!)
            : Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
                  children: [
                    const Text(
                      'Mở thư xác minh hoặc thư đặt lại mật khẩu, giữ ngón tay '
                      'lên nút trong thư để chép liên kết, rồi dán vào đây.',
                      style: TextStyle(
                          color: Mau.chuMo, fontSize: 13, height: 1.6),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      key: const ValueKey('o-lien-ket'),
                      controller: _lienKet,
                      onChanged: _khiDoi,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'https://astrotarot.date/…?token=…',
                        suffixIcon: IconButton(
                          tooltip: 'Dán',
                          icon: const Icon(Icons.content_paste, size: 20),
                          onPressed: _dan,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_lienKet.text.trim().isNotEmpty && doc == null)
                      const Text(
                        'Chưa nhận ra liên kết. Hãy chép nguyên liên kết trong '
                        'thư — có cả phần "?token=".',
                        style: TextStyle(
                            fontSize: 12.5, color: Color(0xFFE5645E)),
                      ),
                    if (doc != null)
                      Text(
                        doc.loai == LoaiLienKet.xacMinh
                            ? 'Đây là liên kết xác minh email.'
                            : 'Đây là liên kết đặt lại mật khẩu. Nhập mật khẩu '
                                'mới bên dưới.',
                        style:
                            const TextStyle(fontSize: 12.5, color: Mau.vang),
                      ),
                    if (doc?.loai == LoaiLienKet.datLaiMatKhau) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const ValueKey('o-mat-khau-moi'),
                        controller: _matKhau,
                        obscureText: true,
                        decoration:
                            const InputDecoration(hintText: 'Mật khẩu mới'),
                        // Khớp @Size(min = 8, max = 128) của backend.
                        validator: (v) => (v == null || v.length < 8)
                            ? 'Mật khẩu phải từ 8 ký tự'
                            : (v.length > 128
                                ? 'Mật khẩu tối đa 128 ký tự'
                                : null),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        key: const ValueKey('o-nhap-lai'),
                        controller: _nhapLai,
                        obscureText: true,
                        decoration: const InputDecoration(
                            hintText: 'Nhập lại mật khẩu mới'),
                        validator: (v) => v != _matKhau.text
                            ? 'Mật khẩu nhập lại không khớp'
                            : null,
                      ),
                    ],
                    if (_loi != null) ...[
                      const SizedBox(height: 14),
                      Text(_loi!,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFFE5645E))),
                      const SizedBox(height: 4),
                      const Text(
                        'Liên kết chỉ dùng được một lần và có hạn. Nếu đã quá '
                        'hạn, hãy yêu cầu thư mới từ màn đăng nhập.',
                        style: TextStyle(fontSize: 11.5, color: Mau.chuMo),
                      ),
                    ],
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: doc == null || _dangChay ? null : _chay,
                      child: _dangChay
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(doc?.loai == LoaiLienKet.datLaiMatKhau
                              ? 'Đặt mật khẩu mới'
                              : 'Xác minh'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _KetQua extends StatelessWidget {
  const _KetQua({required this.noiDung});
  final String noiDung;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 70, 28, 28),
      children: [
        const Icon(Icons.check_circle_outline,
            size: 48, color: Color(0xFF34D399)),
        const SizedBox(height: 18),
        Text(noiDung,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, height: 1.6)),
        const SizedBox(height: 26),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Về đăng nhập'),
        ),
      ],
    );
  }
}
