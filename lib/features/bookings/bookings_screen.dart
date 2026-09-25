import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/dai_chon.dart';
import '../../widgets/hop_thoai.dart';
import '../../widgets/trang_thai.dart';
import '../money/payment_sheet.dart';
import 'booking.dart';
import 'bookings_repository.dart';
import 'chat_screen.dart';
import 'report_sheet.dart';
import 'review_sheet.dart';

class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key});

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  /// Lọc theo trạng thái như web. null = tất cả.
  static const _loc = <(String, TrangThaiBuoi?)>[
    ('Tất cả', null),
    ('Chờ nhận', TrangThaiBuoi.pending),
    ('Đã nhận', TrangThaiBuoi.confirmed),
    ('Hoàn tất', TrangThaiBuoi.completed),
    ('Đã huỷ', TrangThaiBuoi.cancelled),
  ];
  int _chon = 0;

  @override
  Widget build(BuildContext context) {
    final ds = ref.watch(myBookingsProvider);
    final loc = _loc[_chon].$2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch hẹn của tôi'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: DaiChon(
            cuon: true,
            nhan: [for (final l in _loc) l.$1],
            chon: _chon,
            khiChon: (i) => setState(() => _chon = i),
          ),
        ),
      ),
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
          data: (tatCa) {
            final list = loc == null
                ? tatCa
                : [for (final b in tatCa) if (b.trangThai == loc) b];
            if (tatCa.isEmpty) {
              return const KhoiTrong(
                icon: Icons.event_available,
                tieuDe: 'Chưa có lịch hẹn nào',
                moTa: 'Vào tab Reader, chọn người bạn muốn xem cùng rồi đặt '
                    'một khung giờ.',
              );
            }
            if (list.isEmpty) {
              return KhoiTrong(
                icon: Icons.filter_alt_off_outlined,
                tieuDe: 'Không có buổi nào "${_loc[_chon].$1}"',
                moTa: 'Chọn "Tất cả" để xem toàn bộ lịch hẹn.',
              );
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: list.length,
              itemBuilder: (_, i) => _TheBuoi(booking: list[i]),
            );
          },
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
      final h = await ref.read(bookingsRepositoryProvider).taoThanhToan(b.id);
      if (!mounted) return;
      await moHuongDanThanhToan(context, h);
    } catch (e) {
      if (mounted) baoLoi(context, e, 'Không tạo được thanh toán.');
    } finally {
      if (mounted) setState(() => _dangTra = false);
    }
  }

  /// Khách huỷ buổi chưa diễn ra. Lý do không bắt buộc; Reader đọc được.
  Future<void> _huy() async {
    final lyDo = await hoiNoiDung(
      context,
      tieuDe: 'Huỷ lịch hẹn?',
      goiY: 'Lý do huỷ — Reader sẽ đọc được (không bắt buộc)',
      gui: 'Xác nhận huỷ',
    );
    // null = bấm Thoát, giữ lịch. Chuỗi rỗng = huỷ mà không ghi lý do.
    if (lyDo == null || !mounted) return;
    setState(() => _dangTra = true);
    try {
      await ref
          .read(bookingsRepositoryProvider)
          .huy(b.id, lyDo.trim().isEmpty ? null : lyDo.trim());
      ref.invalidate(myBookingsProvider);
      if (mounted) baoTin(context, 'Đã huỷ lịch hẹn');
    } catch (e) {
      if (mounted) baoLoi(context, e, 'Không huỷ được lịch hẹn.');
    } finally {
      if (mounted) setState(() => _dangTra = false);
    }
  }

  bool get _huyDuoc =>
      b.trangThai == TrangThaiBuoi.pending ||
      b.trangThai == TrangThaiBuoi.confirmed;

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
                // Báo cáo chỉ cho buổi đã xong, như web: trước đó chưa có gì
                // để báo, và nút đỏ trên buổi sắp tới chỉ làm khách lo lắng.
                if (b.trangThai == TrangThaiBuoi.completed)
                  TextButton.icon(
                    onPressed: () => moBaoCao(
                      context,
                      nguoiBiBao: b.readerUserId,
                      tenNguoiBiBao: b.readerName,
                      bookingId: b.id,
                    ),
                    icon: const Icon(Icons.flag_outlined, size: 16),
                    label: const Text('Báo cáo'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFE5645E),
                      minimumSize: const Size(0, 40),
                    ),
                  ),
                if (_huyDuoc)
                  TextButton.icon(
                    onPressed: _dangTra ? null : _huy,
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Huỷ lịch'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFE5645E),
                      minimumSize: const Size(0, 40),
                    ),
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
