import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../theme.dart';
import 'money_repository.dart';

Future<bool> moXinRut(BuildContext context, SoDu soDu) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Mau.the,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _XinRutSheet(soDu: soDu),
  );
  return ok == true;
}

class _XinRutSheet extends ConsumerStatefulWidget {
  const _XinRutSheet({required this.soDu});
  final SoDu soDu;

  @override
  ConsumerState<_XinRutSheet> createState() => _XinRutSheetState();
}

class _XinRutSheetState extends ConsumerState<_XinRutSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _soTien;
  final _nganHang = TextEditingController();
  final _soTaiKhoan = TextEditingController();
  final _chuTaiKhoan = TextEditingController();
  final _maNganHang = TextEditingController();

  bool _dangGui = false;
  String? _loi;

  @override
  void initState() {
    super.initState();
    // Điền sẵn toàn bộ số dư: rút hết là lựa chọn của gần như mọi người, và
    // họ vẫn sửa được nếu muốn rút ít hơn.
    _soTien = TextEditingController(text: widget.soDu.soDu.toString());
  }

  @override
  void dispose() {
    _soTien.dispose();
    _nganHang.dispose();
    _soTaiKhoan.dispose();
    _chuTaiKhoan.dispose();
    _maNganHang.dispose();
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
      await ref.read(moneyRepositoryProvider).xinRut(
            soTien: int.parse(_soTien.text.trim()),
            nganHang: _nganHang.text,
            soTaiKhoan: _soTaiKhoan.text,
            chuTaiKhoan: _chuTaiKhoan.text,
            maNganHang: _maNganHang.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loi = e.message);
    } finally {
      if (mounted) setState(() => _dangGui = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          22, 18, 22, 18 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  height: 4,
                  width: 38,
                  decoration: BoxDecoration(
                    color: Mau.chuMo.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text('Yêu cầu rút tiền',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                'Rút được tối đa ${Dinh.tien(widget.soDu.soDu)}',
                style: const TextStyle(fontSize: 12, color: Mau.chuMo),
              ),
              const SizedBox(height: 18),

              _O(
                c: _soTien,
                nhan: 'Số tiền (đồng)',
                kieu: TextInputType.number,
                kiem: (v) {
                  final n = int.tryParse(v);
                  if (n == null || n <= 0) return 'Số tiền phải lớn hơn 0';
                  if (n > widget.soDu.soDu) {
                    return 'Vượt quá số dư rút được';
                  }
                  if (n < widget.soDu.mucRutToiThieu) {
                    return 'Tối thiểu ${Dinh.tien(widget.soDu.mucRutToiThieu)}';
                  }
                  return null;
                },
              ),
              _O(c: _nganHang, nhan: 'Tên ngân hàng', batBuoc: true),
              _O(
                c: _soTaiKhoan,
                nhan: 'Số tài khoản',
                kieu: TextInputType.number,
                batBuoc: true,
              ),
              _O(
                c: _chuTaiKhoan,
                nhan: 'Tên chủ tài khoản',
                batBuoc: true,
                hoa: true,
              ),
              _O(
                c: _maNganHang,
                nhan: 'Mã ngân hàng (6 chữ số, không bắt buộc)',
                kieu: TextInputType.number,
                kiem: (v) => (v.isEmpty || RegExp(r'^[0-9]{6}$').hasMatch(v))
                    ? null
                    : 'Mã ngân hàng phải là 6 chữ số',
              ),

              if (_loi != null) ...[
                const SizedBox(height: 6),
                Text(_loi!,
                    style: const TextStyle(
                        color: Color(0xFFE5645E), fontSize: 12.5)),
              ],

              const SizedBox(height: 10),
              // Nhắc kiểm lại số tài khoản. Chuyển nhầm là mất tiền thật, và
              // không ai đọc lại số tài khoản nếu giao diện không nhắc.
              const Text(
                'Kiểm lại số tài khoản và tên chủ tài khoản trước khi gửi. '
                'Chuyển nhầm thì rất khó lấy lại.',
                style:
                    TextStyle(fontSize: 11, color: Mau.chuMo, height: 1.6),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _dangGui ? null : _gui,
                child: _dangGui
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Gửi yêu cầu'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _O extends StatelessWidget {
  const _O({
    required this.c,
    required this.nhan,
    this.kieu,
    this.batBuoc = false,
    this.hoa = false,
    this.kiem,
  });

  final TextEditingController c;
  final String nhan;
  final TextInputType? kieu;
  final bool batBuoc;
  final bool hoa;
  final String? Function(String)? kiem;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: kieu,
        textCapitalization:
            hoa ? TextCapitalization.characters : TextCapitalization.words,
        decoration: InputDecoration(hintText: nhan, isDense: true),
        validator: (v) {
          final t = (v ?? '').trim();
          if (batBuoc && t.isEmpty) return 'Không được để trống';
          return kiem?.call(t);
        },
      ),
    );
  }
}
