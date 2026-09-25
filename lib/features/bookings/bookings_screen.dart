import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/trang_thai.dart';
import 'booking.dart';
import 'bookings_repository.dart';
import 'chat_screen.dart';
import 'review_sheet.dart';

class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = ref.watch(myBookingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Lịch hẹn của tôi')),
      body: RefreshIndicator(
        color: Mau.vang,
        backgroundColor: Mau.the,
        onRefresh: () => ref.refresh(myBookingsProvider.future),
        child: ds.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: Mau.vang),
          ),
          error: (e, _) => KhoiLoi(
            thongDiep: e is ApiException
                ? e.message
                : 'Không tải được lịch hẹn.',
            thuLai: () => ref.invalidate(myBookingsProvider),
          ),
          data: (list) => list.isEmpty
              ? const KhoiTrong(
                  icon: Icons.event_available,
                  tieuDe: 'Chưa có lịch hẹn nào',
                  moTa: 'Vào tab Reader, chọn người bạn muốn xem cùng rồi đặt '
                      'một khung giờ.',
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _TheBuoi(booking: list[i]),
                ),
        ),
      ),
    );
  }
}

class _TheBuoi extends ConsumerStatefulWidget {
  const _TheBuoi({required this.booking});
  final Booking booking;

  @override
  ConsumerState<_TheBuoi> createState() => _TheBuoiState();
}

class _TheBuoiState extends ConsumerState<_TheBuoi> {
  bool _dangTra = false;

  Booking get b => widget.booking;

  Future<void> _thanhToan() async {
    setState(() => _dangTra = true);
    try {
      final url =
          await ref.read(bookingsRepositoryProvider).taoThanhToan(b.id);
      if (url == null || url.isEmpty) {
        throw ApiException('Máy chủ không trả về liên kết thanh toán.');
      }
      final ok = await launchUrl(
        Uri.parse(url),
        // Mở trình duyệt ngoài chứ không phải WebView trong app: trang thanh
        // toán của ngân hàng thường chặn WebView, và người dùng cũng cần thấy
        // thanh địa chỉ để tin là mình đang ở đúng nơi.
        mode: LaunchMode.externalApplication,
      );
      if (!ok) throw ApiException('Không mở được trang thanh toán.');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Thanh toán xong thì quay lại đây và kéo xuống để làm mới.',
          ),
          backgroundColor: Mau.the,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Mau.the),
      );
    } finally {
      if (mounted) setState(() => _dangTra = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.readerName.isEmpty ? 'Reader' : b.readerName,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${Dinh.ngayGio(b.batDau)} · ${b.phut} phút',
                        style: const TextStyle(
                            color: Mau.chuMo, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                _Nhan(b: b),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  Dinh.tien(b.tongTien),
                  style: const TextStyle(
                      color: Mau.vang,
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                if (b.chuaTra)
                  const Text('chưa thanh toán',
                      style: TextStyle(
                          fontSize: 11.5, color: Color(0xFFE0B341)))
                else
                  const Text('đã thanh toán',
                      style: TextStyle(
                          fontSize: 11.5, color: Color(0xFF6BBF7B))),
              ],
            ),
            if (b.lyDoHuy != null && b.lyDoHuy!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Lý do huỷ: ${b.lyDoHuy}',
                  style:
                      const TextStyle(fontSize: 12, color: Mau.chuMo)),
            ],
            if (b.ghiChuReader != null && b.ghiChuReader!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F16),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Mau.vien),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ghi chú của Reader',
                        style:
                            TextStyle(fontSize: 10.5, color: Mau.chuMo)),
                    const SizedBox(height: 5),
                    Text(b.ghiChuReader!,
                        style:
                            const TextStyle(fontSize: 12.5, height: 1.5)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (b.chuaTra &&
                    b.trangThai != TrangThaiBuoi.cancelled)
                  FilledButton(
                    onPressed: _dangTra ? null : _thanhToan,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    child: _dangTra
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Thanh toán'),
                  ),
                // Nút trò chuyện chỉ hiện khi MÁY CHỦ nói hội thoại đang mở.
                // Không tự suy từ trạng thái + thanh toán: luật còn có hạn ân
                // hạn bảy ngày sau khi buổi kết thúc, đoán lại ở đây thì sớm
                // muộn nút hiện ra mà gửi tin lại bị từ chối.
                // Đánh giá chỉ có nghĩa khi buổi đã xong và chưa chấm.
                // Hiện nút cho buổi chưa xong là mời người ta chấm điểm thứ
                // chưa diễn ra.
                if (b.trangThai == TrangThaiBuoi.completed && !b.daDanhGia)
                  FilledButton.icon(
                    onPressed: () => moDanhGia(context, b),
                    icon: const Icon(Icons.star_border, size: 16),
                    label: const Text('Đánh giá'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                if (b.trangThai == TrangThaiBuoi.completed && b.daDanhGia)
                  const Padding(
                    padding: EdgeInsets.only(top: 9),
                    child: Text('Bạn đã đánh giá buổi này',
                        style:
                            TextStyle(fontSize: 11.5, color: Mau.chuMo)),
                  ),
                if (b.chatMo)
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(booking: b),
                      ),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline, size: 16),
                    label: const Text('Nhắn tin'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      foregroundColor: Mau.vang,
                      side: const BorderSide(color: Mau.vien),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Nhan extends StatelessWidget {
  const _Nhan({required this.b});
  final Booking b;

  Color get _mau => switch (b.trangThai) {
        TrangThaiBuoi.confirmed => const Color(0xFF6BA8E5),
        TrangThaiBuoi.completed => const Color(0xFF6BBF7B),
        TrangThaiBuoi.cancelled => const Color(0xFFE5645E),
        _ => const Color(0xFFE0B341),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _mau.withValues(alpha: 0.5)),
      ),
      child: Text(
        nhanTrangThai(b.trangThai),
        style: TextStyle(fontSize: 10.5, color: _mau),
      ),
    );
  }
}
