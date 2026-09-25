import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme.dart';
import '../../widgets/hop_thoai.dart';
import '../admin/admin_repository.dart';
import 'bookings_repository.dart';

/// Mở bảng báo cáo một người trong buổi xem.
Future<void> moBaoCao(
  BuildContext context, {
  required String nguoiBiBao,
  required String tenNguoiBiBao,
  String? bookingId,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Mau.the,
      builder: (_) => BaoCaoSheet(
        nguoiBiBao: nguoiBiBao,
        tenNguoiBiBao: tenNguoiBiBao,
        bookingId: bookingId,
      ),
    );

/// Báo cáo một buổi xem có vấn đề.
///
/// Nói rõ rằng danh tính người báo không lộ ra — đó là điều khiến người ta
/// dám bấm nút này, nhất là khi còn phải gặp lại Reader đó.
class BaoCaoSheet extends ConsumerStatefulWidget {
  const BaoCaoSheet({
    super.key,
    required this.nguoiBiBao,
    required this.tenNguoiBiBao,
    this.bookingId,
  });

  final String nguoiBiBao;
  final String tenNguoiBiBao;
  final String? bookingId;

  @override
  ConsumerState<BaoCaoSheet> createState() => _BaoCaoSheetState();
}

class _BaoCaoSheetState extends ConsumerState<BaoCaoSheet> {
  String _loai = loaiViPham.first.$1;
  final _moTa = TextEditingController();
  bool _dangGui = false;

  @override
  void dispose() {
    _moTa.dispose();
    super.dispose();
  }

  Future<void> _gui() async {
    setState(() => _dangGui = true);
    try {
      await ref.read(bookingsRepositoryProvider).baoCao(
            nguoiBiBao: widget.nguoiBiBao,
            loai: _loai,
            moTa: _moTa.text,
            bookingId: widget.bookingId,
          );
      if (!mounted) return;
      baoTin(context, 'Đã ghi nhận. Chúng tôi sẽ xem xét và báo lại cho bạn.');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) baoLoi(context, e, 'Không gửi được báo cáo.');
    } finally {
      if (mounted) setState(() => _dangGui = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const Icon(Icons.flag_outlined, color: Color(0xFFE5645E)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Báo cáo ${widget.tenNguoiBiBao}',
                    style: const TextStyle(fontSize: 17)),
              ),
            ]),
            const SizedBox(height: 6),
            const Text(
              'Người bị báo cáo không biết ai đã báo. Chỉ đội ngũ xử lý đọc '
              'được nội dung này, và bạn sẽ nhận thông báo khi có kết luận.',
              style: TextStyle(fontSize: 12, color: Mau.chuMo, height: 1.5),
            ),
            const SizedBox(height: 12),
            const Text('Chuyện gì đã xảy ra?',
                style: TextStyle(fontSize: 12.5, color: Mau.chuMo)),
            RadioGroup<String>(
              groupValue: _loai,
              onChanged: (v) => setState(() => _loai = v ?? _loai),
              child: Column(
                children: [
                  for (final (ma, nhan) in loaiViPham)
                    RadioListTile<String>(
                      key: ValueKey('loai-$ma'),
                      value: ma,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(nhan, style: const TextStyle(fontSize: 13.5)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _moTa,
              minLines: 3,
              maxLines: 6,
              maxLength: 2000,
              decoration: const InputDecoration(
                hintText: 'Mô tả thêm (không bắt buộc). Càng cụ thể thì càng '
                    'xử lý nhanh: thời điểm, nội dung trao đổi...',
              ),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _dangGui ? null : _gui,
              child: Text(_dangGui ? 'Đang gửi…' : 'Gửi báo cáo'),
            ),
          ],
        ),
      ),
    );
  }
}
