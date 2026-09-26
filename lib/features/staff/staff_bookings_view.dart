import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/dai_chon.dart';
import '../../widgets/danh_sach_phan_trang.dart';
import '../../widgets/hop_thoai.dart';
import '../../widgets/trang_thai.dart';
import '../bookings/booking.dart';
import '../bookings/bookings_repository.dart';
import '../bookings/chat_screen.dart';

/// Lịch hẹn Reader nhận được — một mục trong Bàn làm việc.
///
/// Có bộ lọc trạng thái và phân trang như trang `/staff` của web. Bộ lọc gửi
/// xuống máy chủ chứ không lọc trong trang đã tải: Reader làm lâu sẽ có hàng
/// trăm buổi, và lọc ở máy khách chỉ lọc trong hai mươi buổi gần nhất — hiện
/// ra ít hơn thật mà không báo gì.
class StaffBookingsView extends ConsumerStatefulWidget {
  const StaffBookingsView({super.key});

  @override
  ConsumerState<StaffBookingsView> createState() => _StaffBookingsViewState();
}

class _StaffBookingsViewState extends ConsumerState<StaffBookingsView> {
  static const _loc = <(String, TrangThaiBuoi?)>[
    ('Tất cả', null),
    ('Chờ nhận', TrangThaiBuoi.pending),
    ('Đã nhận', TrangThaiBuoi.confirmed),
    ('Hoàn tất', TrangThaiBuoi.completed),
    ('Đã huỷ', TrangThaiBuoi.cancelled),
  ];
  int _chon = 0;

  /// Để các thẻ con bắt danh sách tải lại sau khi nhận / hoàn tất / huỷ.
  final _dieuKhien = DieuKhienDanhSach();

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(bookingsRepositoryProvider);
    final loc = _loc[_chon].$2;

    // Material trong suốt: DaiChon có ô bấm nên cần một Material phía trên.
    // Màn này nhúng trong Bàn làm việc nên KHÔNG tự dựng Scaffold — mà dựa
    // vào Scaffold của cha là một ràng buộc ngầm, và nó vỡ ngay lúc ai đó
    // nhúng màn này ở chỗ khác.
    return Material(
      type: MaterialType.transparency,
      child: Column(
        children: [
          DaiChon(
            cuon: true,
            nhan: [for (final l in _loc) l.$1],
            chon: _chon,
            khiChon: (i) => setState(() => _chon = i),
          ),
          Expanded(
            child: DanhSachPhanTrang<Booking>(
              // Đổi bộ lọc thì dựng lại từ trang đầu.
              key: ValueKey(_chon),
              dieuKhien: _dieuKhien,
              tai: (t) => repo.cuaReader(trang: t, loc: loc),
              loiDuPhong: 'Không tải được lịch hẹn của bạn.',
              trong: loc == null
                  ? const KhoiTrong(
                      icon: Icons.work_outline,
                      tieuDe: 'Chưa có lịch hẹn nào',
                      moTa:
                          'Khách đặt buổi với bạn thì sẽ hiện ở đây. Nhớ đặt '
                          'giá và khung giờ rảnh trong hồ sơ Reader.',
                    )
                  : KhoiTrong(
                      icon: Icons.filter_alt_off_outlined,
                      tieuDe: 'Không có buổi nào "${_loc[_chon].$1}"',
                      moTa: 'Chọn "Tất cả" để xem toàn bộ lịch hẹn.',
                    ),
              dong: (_, b) => _TheViec(booking: b, taiLai: _dieuKhien.taiLai),
            ),
          ),
        ],
      ),
    );
  }
}

class _TheViec extends ConsumerStatefulWidget {
  const _TheViec({required this.booking, required this.taiLai});
  final Booking booking;

  /// Tải lại danh sách sau khi đổi trạng thái. Không có nó thì thẻ vừa thao
  /// tác vẫn hiện trạng thái cũ cho tới khi người dùng tự kéo xuống làm mới.
  final Future<void> Function() taiLai;

  @override
  ConsumerState<_TheViec> createState() => _TheViecState();
}

class _TheViecState extends ConsumerState<_TheViec> {
  bool _dangChay = false;

  Booking get b => widget.booking;

  Future<void> _chay(Future<Booking> Function() viec, String xong) async {
    if (_dangChay) return;
    setState(() => _dangChay = true);
    // baoTin/baoLoi ẩn thông báo cũ trước khi hiện cái mới: bấm liền vài
    // thao tác thì câu lỗi hiện ngay, không phải chờ các thông báo trước
    // lần lượt hết giờ.
    try {
      await viec();
      await widget.taiLai();
      // Trang chủ và chấm đỏ đọc provider này; nó đã cũ sau thao tác vừa rồi.
      ref.invalidate(readerBookingsProvider);
      if (mounted) baoTin(context, xong);
    } catch (e) {
      if (mounted) baoLoi(context, e, 'Thao tác không thành công.');
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
      () => ref
          .read(bookingsRepositoryProvider)
          .huy(b.id, lyDo.isEmpty ? null : lyDo),
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

  /// Hỏi một đoạn chữ qua hộp thoại chung. Bản riêng trước đây huỷ
  /// TextEditingController ngay khi hộp thoại trả kết quả, trong lúc hiệu
  /// ứng đóng vẫn còn vẽ ô nhập.
  Future<String?> _hoiChu({
    required String tieuDe,
    required String goiY,
    required bool batBuoc,
    String banDau = '',
  }) => hoiNoiDung(
    context,
    tieuDe: tieuDe,
    goiY: goiY,
    giaTriDau: banDau,
    gui: 'Xong',
    batBuoc: batBuoc,
  );

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
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${Dinh.ngayGio(b.batDau)} · ${b.phut} phút',
                        style: const TextStyle(
                          color: Mau.chuMo,
                          fontSize: 12.5,
                        ),
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
                        fontWeight: FontWeight.w600,
                      ),
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
                    onTap: () =>
                        _chay(() => repo.nhanLich(b.id), 'Đã nhận lịch'),
                  ),
                if (b.trangThai == TrangThaiBuoi.confirmed)
                  _Nut(
                    nhan: 'Đánh dấu hoàn tất',
                    icon: Icons.task_alt,
                    chinh: true,
                    tat: _dangChay,
                    onTap: () =>
                        _chay(() => repo.hoanTat(b.id), 'Đã đánh dấu hoàn tất'),
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
                      MaterialPageRoute(builder: (_) => ChatScreen(booking: b)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }
}
