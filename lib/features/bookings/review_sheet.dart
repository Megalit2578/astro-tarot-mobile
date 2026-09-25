import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../theme.dart';
import 'booking.dart';
import 'bookings_repository.dart';

/// Chấm điểm một buổi đã hoàn tất.
///
/// Dùng bottom sheet chứ không phải màn hình riêng: đây là việc làm trong
/// mười giây ngay sau khi nhìn thấy buổi trong danh sách. Đẩy sang màn khác
/// là thêm hai lần chuyển cảnh cho một thao tác chạm năm cái.
Future<bool> moDanhGia(BuildContext context, Booking b) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Mau.the,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _DanhGiaSheet(booking: b),
  );
  return ok == true;
}

class _DanhGiaSheet extends ConsumerStatefulWidget {
  const _DanhGiaSheet({required this.booking});
  final Booking booking;

  @override
  ConsumerState<_DanhGiaSheet> createState() => _DanhGiaSheetState();
}

class _DanhGiaSheetState extends ConsumerState<_DanhGiaSheet> {
  int _diem = 0;
  final _nhanXet = TextEditingController();
  bool _dangGui = false;
  String? _loi;

  @override
  void dispose() {
    _nhanXet.dispose();
    super.dispose();
  }

  Future<void> _gui() async {
    if (_diem == 0) {
      setState(() => _loi = 'Hãy chọn số sao trước');
      return;
    }
    setState(() {
      _dangGui = true;
      _loi = null;
    });
    try {
      await ref
          .read(bookingsRepositoryProvider)
          .danhGia(widget.booking.id, _diem, _nhanXet.text);
      ref.invalidate(myBookingsProvider);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loi = e.message);
    } finally {
      if (mounted) setState(() => _dangGui = false);
    }
  }

  static const _moTa = {
    1: 'Rất không hài lòng',
    2: 'Không hài lòng',
    3: 'Tạm được',
    4: 'Hài lòng',
    5: 'Rất hài lòng',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Đẩy theo bàn phím, nếu không ô nhận xét bị che khi người dùng gõ.
      padding: EdgeInsets.fromLTRB(
          22, 18, 22, 18 + MediaQuery.of(context).viewInsets.bottom),
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
          Text(
            'Buổi với ${widget.booking.readerName}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Đánh giá của bạn hiện công khai trên hồ sơ Reader.',
            style: TextStyle(fontSize: 11.5, color: Mau.chuMo, height: 1.5),
          ),
          const SizedBox(height: 18),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    onPressed: () => setState(() {
                      _diem = i;
                      _loi = null;
                    }),
                    // Vùng chạm rộng: năm ngôi sao sát nhau là chỗ bấm nhầm
                    // kinh điển trên điện thoại.
                    constraints:
                        const BoxConstraints(minWidth: 52, minHeight: 52),
                    icon: Icon(
                      i <= _diem ? Icons.star : Icons.star_border,
                      size: 32,
                      color: i <= _diem ? Mau.vang : Mau.chuMo,
                    ),
                  ),
              ],
            ),
          ),
          Center(
            child: Text(
              _diem == 0 ? 'Chạm để chấm sao' : _moTa[_diem]!,
              style: TextStyle(
                fontSize: 12.5,
                color: _diem == 0 ? Mau.chuMo : Mau.vang,
              ),
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _nhanXet,
            minLines: 3,
            maxLines: 5,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Nhận xét thêm (không bắt buộc)',
              counterText: '',
            ),
          ),
          if (_loi != null) ...[
            const SizedBox(height: 10),
            Text(_loi!,
                style:
                    const TextStyle(color: Color(0xFFE5645E), fontSize: 12.5)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _dangGui ? null : _gui,
            child: _dangGui
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Gửi đánh giá'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
