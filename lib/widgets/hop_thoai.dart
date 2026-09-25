import 'package:flutter/material.dart';

import '../core/api/api_client.dart';
import '../theme.dart';

/// Báo một dòng ở chân màn hình.
void baoTin(BuildContext context, String noiDung) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(noiDung), backgroundColor: Mau.the));
}

/// Báo lỗi: dùng câu máy chủ gửi nếu có, không thì câu dự phòng.
void baoLoi(BuildContext context, Object loi, String duPhong) =>
    baoTin(context, loi is ApiException ? loi.message : duPhong);

/// Hỏi lại trước một việc khó quay đầu.
///
/// Trên điện thoại các nút nằm sát nhau và ngón cái chạm nhầm là chuyện
/// thường — nên mọi thao tác đụng tới tiền hay tài khoản người khác đều đi
/// qua đây.
Future<bool> hoiXacNhan(
  BuildContext context, {
  required String tieuDe,
  required String noiDung,
  String dongY = 'Đồng ý',
  bool nguyHiem = false,
}) async {
  final kq = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Mau.the,
      title: Text(tieuDe, style: const TextStyle(fontSize: 16)),
      content: Text(noiDung, style: const TextStyle(fontSize: 13.5, height: 1.6)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Thoát'),
        ),
        FilledButton(
          style: nguyHiem
              ? FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE5645E),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 44),
                )
              : FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(dongY),
        ),
      ],
    ),
  );
  return kq == true;
}

/// Hỏi một đoạn chữ (lý do từ chối, ghi chú…). Trả null khi bấm Thoát.
///
/// [batBuoc]: nút Gửi chỉ bật khi đã gõ gì đó.
Future<String?> hoiNoiDung(
  BuildContext context, {
  required String tieuDe,
  String goiY = '',
  String giaTriDau = '',
  String gui = 'Gửi',
  bool batBuoc = false,
  int dongToiDa = 4,
  TextInputType kieuNhap = TextInputType.multiline,
}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _HopNhap(
        tieuDe: tieuDe,
        goiY: goiY,
        giaTriDau: giaTriDau,
        gui: gui,
        batBuoc: batBuoc,
        dongToiDa: dongToiDa,
        kieuNhap: kieuNhap,
      ),
    );

/// Hộp thoại nhập chữ tự giữ controller của mình.
///
/// Bản đầu tạo controller bên ngoài rồi huỷ ngay khi `showDialog` trả kết
/// quả — nhưng lúc ấy hiệu ứng đóng hộp thoại vẫn đang vẽ ô nhập, và Flutter
/// báo "TextEditingController was used after being disposed". Để hộp thoại tự
/// huỷ trong `dispose()` thì controller sống đúng bằng ô nhập.
class _HopNhap extends StatefulWidget {
  const _HopNhap({
    required this.tieuDe,
    required this.goiY,
    required this.giaTriDau,
    required this.gui,
    required this.batBuoc,
    required this.dongToiDa,
    required this.kieuNhap,
  });

  final String tieuDe;
  final String goiY;
  final String giaTriDau;
  final String gui;
  final bool batBuoc;
  final int dongToiDa;
  final TextInputType kieuNhap;

  @override
  State<_HopNhap> createState() => _HopNhapState();
}

class _HopNhapState extends State<_HopNhap> {
  late final _o = TextEditingController(text: widget.giaTriDau);

  @override
  void dispose() {
    _o.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Mau.the,
      title: Text(widget.tieuDe, style: const TextStyle(fontSize: 16)),
      content: TextField(
        controller: _o,
        autofocus: true,
        keyboardType: widget.kieuNhap,
        minLines: widget.dongToiDa > 1 ? 2 : 1,
        maxLines: widget.dongToiDa,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(hintText: widget.goiY),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Thoát'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: widget.batBuoc && _o.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(_o.text.trim()),
          child: Text(widget.gui),
        ),
      ],
    );
  }
}

/// Nhãn trạng thái nhỏ có viền màu.
class NhanTrangThai extends StatelessWidget {
  const NhanTrangThai(this.nhan, {super.key, this.mau = Mau.chuMo});

  final String nhan;
  final Color mau;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: mau.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: mau.withValues(alpha: 0.4)),
      ),
      child: Text(nhan, style: TextStyle(fontSize: 10.5, color: mau)),
    );
  }
}

/// Màu dùng chung cho trạng thái.
class MauTrangThai {
  const MauTrangThai._();
  static const cho = Color(0xFFFBBF24);
  static const tot = Color(0xFF34D399);
  static const xau = Color(0xFFE5645E);
  static const xanh = Color(0xFF38BDF8);
  static const tim = Color(0xFFA78BFA);
}

/// Nút "Tải thêm" cuối danh sách phân trang.
///
/// Dùng nút thay vì tự tải khi cuộn tới đáy: màn quản trị hay mở trên mạng
/// chập chờn, và cuộn vô tận mà lượt tải hỏng thì người dùng chỉ thấy danh
/// sách "hết" mà không biết là hết thật hay hỏng.
class NutTaiThem extends StatelessWidget {
  const NutTaiThem({
    super.key,
    required this.dangTai,
    required this.bam,
    this.nhan = 'Tải thêm',
  });

  final bool dangTai;
  final VoidCallback bam;
  final String nhan;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Center(
        child: OutlinedButton(
          onPressed: dangTai ? null : bam,
          style: OutlinedButton.styleFrom(
            foregroundColor: Mau.vang,
            side: const BorderSide(color: Mau.vien),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          child: dangTai
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(nhan),
        ),
      ),
    );
  }
}

/// Tiêu đề nhỏ cho một khối trong màn chi tiết.
class TieuDeKhoi extends StatelessWidget {
  const TieuDeKhoi(this.nhan, {super.key});
  final String nhan;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(
        nhan.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          letterSpacing: 1.4,
          color: Mau.vang.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}
