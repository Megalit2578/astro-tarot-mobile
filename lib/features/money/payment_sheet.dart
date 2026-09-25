import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/trang.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/hop_thoai.dart';

/// Hướng dẫn thanh toán máy chủ trả về cho một buổi xem.
class HuongDanThanhToan {
  const HuongDanThanhToan({
    required this.soTien,
    required this.maThamChieu,
    required this.noiDung,
    required this.nganHang,
    required this.soTaiKhoan,
    required this.chuTaiKhoan,
    this.phuongThuc,
    this.linkThanhToan,
  });

  final int soTien;
  final String? phuongThuc;
  final String maThamChieu;

  /// Khách gõ đúng chuỗi này vào nội dung chuyển khoản.
  final String noiDung;
  final String nganHang;
  final String soTaiKhoan;
  final String chuTaiKhoan;

  /// Link PayOS, chỉ có khi cổng PayOS đang bật.
  final String? linkThanhToan;

  bool get laPayOs =>
      (linkThanhToan != null && linkThanhToan!.isNotEmpty) ||
      phuongThuc == 'PAYOS';

  /// Backend trả nguyên văn chuỗi này khi chưa khai tài khoản nhận tiền.
  bool get chuaCauHinh => !laPayOs && soTaiKhoan == 'Chưa cấu hình';

  factory HuongDanThanhToan.fromJson(Map<String, dynamic> j) =>
      HuongDanThanhToan(
        soTien: soNguyen(j['amount']) ?? 0,
        phuongThuc: chuoi(j['paymentMethod']),
        maThamChieu: (j['referenceCode'] ?? '') as String,
        noiDung: (j['transferContent'] ?? j['referenceCode'] ?? '') as String,
        nganHang: (j['bankName'] ?? '') as String,
        soTaiKhoan: (j['bankAccountNumber'] ?? '') as String,
        chuTaiKhoan: (j['bankAccountHolder'] ?? '') as String,
        linkThanhToan:
            chuoi(j['checkoutUrl'] ?? j['paymentUrl'] ?? j['url']),
      );
}

/// Bảng hướng dẫn thanh toán: PayOS (mở link) hoặc chuyển khoản tay.
///
/// Bản đầu của app chỉ biết mở link PayOS. Khi cổng PayOS tắt, máy chủ trả
/// thông tin chuyển khoản mà không có link — app báo "không có liên kết
/// thanh toán" và khách **không trả tiền được**. Giờ hiện đủ số tài khoản và
/// nội dung chuyển khoản như web, kèm nút chép cho từng dòng.
Future<void> moHuongDanThanhToan(
    BuildContext context, HuongDanThanhToan h) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Mau.the,
    builder: (ctx) => _BangThanhToan(h: h),
  );
}

class _BangThanhToan extends StatelessWidget {
  const _BangThanhToan({required this.h});
  final HuongDanThanhToan h;

  Future<void> _moPayOs(BuildContext context) async {
    final ok = await launchUrl(
      Uri.parse(h.linkThanhToan!),
      // Trình duyệt ngoài chứ không phải WebView: trang thanh toán thường
      // chặn WebView, và người dùng cần thấy thanh địa chỉ để tin là đúng
      // nơi.
      mode: LaunchMode.externalApplication,
    );
    if (!context.mounted) return;
    if (!ok) {
      baoTin(context, 'Không mở được trang thanh toán.');
      return;
    }
    Navigator.of(context).pop();
    baoTin(context, 'Thanh toán xong thì quay lại đây và kéo xuống để làm mới.');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              const Icon(Icons.account_balance_outlined, color: Mau.vang),
              const SizedBox(width: 8),
              Text(h.laPayOs ? 'Thanh toán PayOS' : 'Chuyển khoản',
                  style: const TextStyle(fontSize: 18)),
            ]),
            const SizedBox(height: 6),
            Text(
              h.laPayOs
                  ? 'Mở PayOS để quét VietQR hoặc chuyển khoản. Hệ thống xác '
                      'nhận tự động sau khi nhận tiền.'
                  : 'Chuyển đúng số tiền và đúng nội dung bên dưới. Chúng tôi '
                      'đối soát rồi xác nhận, thường trong vài giờ làm việc.',
              style: const TextStyle(
                  fontSize: 12.5, color: Mau.chuMo, height: 1.5),
            ),
            if (h.chuaCauHinh) ...[
              const SizedBox(height: 12),
              const Text(
                'Hệ thống chưa cấu hình tài khoản nhận tiền. Báo với quản trị '
                'viên trước khi chuyển khoản.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFFE5645E)),
              ),
            ],
            const SizedBox(height: 16),
            _Truong(nhan: 'Số tiền', giaTri: Dinh.tien(h.soTien), lon: true),
            if (h.laPayOs)
              _Truong(
                  nhan: 'Mã đơn PayOS',
                  giaTri: h.maThamChieu,
                  mono: true,
                  chep: true)
            else ...[
              _Truong(
                  nhan: 'Nội dung chuyển khoản',
                  giaTri: h.noiDung,
                  mono: true,
                  lon: true,
                  chep: true),
              _Truong(nhan: 'Ngân hàng', giaTri: h.nganHang),
              _Truong(
                  nhan: 'Số tài khoản',
                  giaTri: h.soTaiKhoan,
                  mono: true,
                  chep: true),
              _Truong(nhan: 'Chủ tài khoản', giaTri: h.chuTaiKhoan),
            ],
            const SizedBox(height: 18),
            if (h.linkThanhToan != null && h.linkThanhToan!.isNotEmpty) ...[
              FilledButton.icon(
                onPressed: () => _moPayOs(context),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Thanh toán với PayOS'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                    'Đóng — trạng thái cập nhật ở trang Lịch hẹn'),
              ),
            ] else
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Tôi đã chuyển khoản'),
              ),
            if (!h.laPayOs)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Ghi thiếu hoặc sai nội dung thì khoản tiền không khớp được '
                  'với lịch hẹn của bạn và sẽ phải xử lý tay.',
                  style:
                      TextStyle(fontSize: 11, color: Mau.chuMo, height: 1.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Truong extends StatelessWidget {
  const _Truong({
    required this.nhan,
    required this.giaTri,
    this.mono = false,
    this.lon = false,
    this.chep = false,
  });

  final String nhan;
  final String giaTri;
  final bool mono;
  final bool lon;
  final bool chep;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Mau.vien),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nhan,
                    style: const TextStyle(fontSize: 11, color: Mau.chuMo)),
                const SizedBox(height: 3),
                SelectableText(giaTri,
                    style: TextStyle(
                        fontSize: lon ? 17 : 14,
                        color: lon ? Mau.vang : Mau.chu,
                        fontFamily: mono ? 'monospace' : null)),
              ],
            ),
          ),
          if (chep)
            IconButton(
              tooltip: 'Chép $nhan',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: giaTri));
                if (context.mounted) baoTin(context, 'Đã chép $nhan.');
              },
              icon: const Icon(Icons.copy, size: 18),
            ),
        ],
      ),
    );
  }
}
