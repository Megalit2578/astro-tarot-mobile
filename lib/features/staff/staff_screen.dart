import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/trang_thai.dart';
import '../bookings/booking.dart';
import '../bookings/bookings_repository.dart';
import '../bookings/chat_screen.dart';

/// Bàn làm việc: lịch hẹn Reader nhận được.
///
/// Đây là phần Reader thật sự dùng trên điện thoại. Hàng chờ hỗ trợ và thu
/// nhập nằm trong kế hoạch nhưng để sau: nhận lịch và đánh dấu hoàn tất là
/// hai việc gắn với thời điểm — Reader cần làm được ngay lúc đang di chuyển,
/// còn đọc báo cáo thu nhập thì ngồi máy tính vẫn hơn.
class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = ref.watch(readerBookingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Bàn làm việc')),
      body: RefreshIndicator(
        color: Mau.vang,
        backgroundColor: Mau.the,
        onRefresh: () => ref.refresh(readerBookingsProvider.future),
        child: ds.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: Mau.vang)),
          error: (e, _) => KhoiLoi(
            thongDiep: e is ApiException
                ? e.message
                : 'Không tải được lịch hẹn của bạn.',
            thuLai: () => ref.invalidate(readerBookingsProvider),
          ),
          data: (list) => list.isEmpty
              ? const KhoiTrong(
                  icon: Icons.work_outline,
                  tieuDe: 'Chưa có lịch hẹn nào',
                  moTa: 'Khách đặt buổi với bạn thì sẽ hiện ở đây. Nhớ đặt '
                      'giá và khung giờ rảnh trong hồ sơ Reader.',
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _TheViec(booking: list[i]),
                ),
        ),
      ),
    );
  }
}

class _TheViec extends ConsumerStatefulWidget {
  const _TheViec({required this.booking});
  final Booking booking;

  @override
  ConsumerState<_TheViec> createState() => _TheViecState();
}

class _TheViecState extends ConsumerState<_TheViec> {
  bool _dangChay = false;

  Booking get b => widget.booking;

  Future<void> _chay(Future<Booking> Function() viec, String xong) async {
    if (_dangChay) return;
    setState(() => _dangChay = true);
    try {
      await viec();
      ref.invalidate(readerBookingsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(xong), backgroundColor: Mau.the),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Mau.the),
      );
    } finally {
      if (mounted) setState(() => _dangChay = false);
    }
  }

  Future<void> _huy() async {
    final lyDo = await _hoiChu(
      tieuDe: 'Huỷ buổi hẹn',
      goiY: 'Lý do huỷ (khách sẽ đọc được)',
      batBuoc: false,
    );
    // null = người dùng bấm Thoát. Chuỗi rỗng = họ xác nhận nhưng không ghi
    // lý do. Hai chuyện khác nhau, đừng gộp.
    if (lyDo == null) return;
    await _chay(
      () => ref.read(bookingsRepositoryProvider).huy(b.id, lyDo.isEmpty ? null : lyDo),
      'Đã huỷ buổi hẹn',
    );
  }

  Future<void> _vietGhiChu() async {
    final n = await _hoiChu(
      tieuDe: 'Ghi chú buổi xem',
      goiY: 'Tóm tắt buổi xem cho khách đọc lại',
      batBuoc: true,
      banDau: b.ghiChuReader ?? '',
    );
    if (n == null || n.isEmpty) return;
    await _chay(
      () => ref.read(bookingsRepositoryProvider).ghiChu(b.id, n),
      'Đã lưu ghi chú',
    );
  }

  Future<String?> _hoiChu({
    required String tieuDe,
    required String goiY,
    required bool batBuoc,
    String banDau = '',
  }) {
    final o = TextEditingController(text: banDau);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Mau.the,
        title: Text(tieuDe, style: const TextStyle(fontSize: 16)),
        content: TextField(
          controller: o,
          autofocus: true,
          maxLines: 4,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: goiY),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Thoát'),
          ),
          FilledButton(
            onPressed: () {
              final v = o.text.trim();
              if (batBuoc && v.isEmpty) return;
              Navigator.of(ctx).pop(v);
            },
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 42),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: const Text('Xong'),
          ),
        ],
      ),
    ).whenComplete(o.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(bookingsRepositoryProvider);
    final quaGio = b.ketThuc.toLocal().isBefore(DateTime.now());

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
                        b.customerName.isEmpty ? 'Khách' : b.customerName,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${Dinh.ngayGio(b.batDau)} · ${b.phut} phút',
                        style:
                            const TextStyle(color: Mau.chuMo, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      nhanTrangThai(b.trangThai),
                      style: const TextStyle(fontSize: 11, color: Mau.chuMo),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      Dinh.tien(b.tongTien),
                      style: const TextStyle(
                          color: Mau.vang,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
            if (b.chuaTra) ...[
              const SizedBox(height: 8),
              const Text(
                'Khách chưa thanh toán',
                style: TextStyle(fontSize: 11.5, color: Color(0xFFE0B341)),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (b.trangThai == TrangThaiBuoi.pending)
                  _Nut(
                    nhan: 'Nhận lịch',
                    icon: Icons.check,
                    chinh: true,
                    tat: _dangChay,
                    onTap: () => _chay(
                      () => repo.nhanLich(b.id),
                      'Đã nhận lịch',
                    ),
                  ),
                if (b.trangThai == TrangThaiBuoi.confirmed)
                  _Nut(
                    nhan: 'Đánh dấu hoàn tất',
                    icon: Icons.task_alt,
                    chinh: true,
                    tat: _dangChay,
                    onTap: () => _chay(
                      () => repo.hoanTat(b.id),
                      'Đã đánh dấu hoàn tất',
                    ),
                  ),
                if (b.trangThai == TrangThaiBuoi.pending ||
                    b.trangThai == TrangThaiBuoi.confirmed)
                  _Nut(
                    nhan: 'Huỷ lịch',
                    icon: Icons.close,
                    nguyHiem: true,
                    tat: _dangChay,
                    onTap: _huy,
                  ),
                if (b.chatMo)
                  _Nut(
                    nhan: 'Nhắn tin',
                    icon: Icons.chat_bubble_outline,
                    tat: false,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(booking: b),
                      ),
                    ),
                  ),
                // Ghi chú chỉ có nghĩa sau khi buổi đã diễn ra.
                if (quaGio && b.trangThai != TrangThaiBuoi.cancelled)
                  _Nut(
                    nhan: b.ghiChuReader == null || b.ghiChuReader!.isEmpty
                        ? 'Viết ghi chú'
                        : 'Sửa ghi chú',
                    icon: Icons.edit_note,
                    tat: _dangChay,
                    onTap: _vietGhiChu,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Nut extends StatelessWidget {
  const _Nut({
    required this.nhan,
    required this.icon,
    required this.onTap,
    required this.tat,
    this.chinh = false,
    this.nguyHiem = false,
  });

  final String nhan;
  final IconData icon;
  final VoidCallback onTap;
  final bool tat;
  final bool chinh;
  final bool nguyHiem;

  @override
  Widget build(BuildContext context) {
    final mau = nguyHiem ? const Color(0xFFE5645E) : Mau.vang;
    if (chinh) {
      return FilledButton.icon(
        onPressed: tat ? null : onTap,
        icon: Icon(icon, size: 16),
        label: Text(nhan),
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: tat ? null : onTap,
      icon: Icon(icon, size: 16),
      label: Text(nhan),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        foregroundColor: mau,
        side: BorderSide(color: mau.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}
