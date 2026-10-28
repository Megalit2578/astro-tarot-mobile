import 'package:flutter/material.dart';

import '../../core/ngon_ngu.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../theme.dart';
import '../../widgets/lich_thang.dart';
import 'booking.dart';
import 'bookings_repository.dart';

typedef _Khoa = ({bool reader, int nam, int thang});

final lichHenThangProvider = FutureProvider.family<List<Booking>, _Khoa>((
  ref,
  k,
) {
  return ref
      .watch(bookingsRepositoryProvider)
      .lichThang(cuaReader: k.reader, nam: k.nam, thang: k.thang);
});

/// Lịch tháng của chính mình: khách thấy buổi đã đặt, Reader thấy buổi khách đặt.
///
/// ## Vì sao thu gọn được
///
/// Lưới tháng chiếm sáu hàng ô vuông, tức khoảng nửa màn hình điện thoại.
/// Đặt cố định trên đầu thì danh sách buổi hẹn chỉ còn một khe hẹp bên dưới,
/// và người dùng phải cuộn trong một ô nhỏ xíu trong khi nửa màn hình trên
/// đứng yên. Mở màn ra là thấy chật.
///
/// Nên khi cuộn danh sách, lưới thu lại thành MỘT DÒNG tóm tắt vẫn dính trên
/// đầu — không biến mất hẳn, vì tháng đang xem và số buổi trong ngày đã chọn
/// là thứ người ta cần nhìn trong lúc đọc danh sách. Bấm vào dòng ấy thì lưới
/// mở lại.
///
/// Trạng thái mở/thu do widget cha giữ: cha là nơi nghe được tiếng cuộn của
/// danh sách (danh sách là anh em, không nằm trong cây con của lịch).
class LichHenThang extends ConsumerStatefulWidget {
  const LichHenThang({
    super.key,
    required this.cuaReader,
    this.moRong = true,
    this.doiMoRong,
  });

  final bool cuaReader;

  /// Đang bày cả lưới tháng, hay chỉ còn dòng tóm tắt.
  final bool moRong;

  /// Bấm vào dòng tóm tắt. `null` thì không cho đổi — lịch luôn mở.
  final VoidCallback? doiMoRong;

  @override
  ConsumerState<LichHenThang> createState() => _LichHenThangState();
}

class _LichHenThangState extends ConsumerState<LichHenThang> {
  late DateTime _thang;
  DateTime? _chon;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _thang = DateTime(n.year, n.month, 1);
    _chon = DateTime(n.year, n.month, n.day);
  }

  bool _hopLe(DateTime t) {
    final n = DateTime.now();
    final hien = n.year * 12 + n.month;
    final xin = t.year * 12 + t.month;
    return xin >= hien - 12 && xin <= hien + 6;
  }

  @override
  Widget build(BuildContext context) {
    final khoa = (
      reader: widget.cuaReader,
      nam: _thang.year,
      thang: _thang.month,
    );
    final ds = ref.watch(lichHenThangProvider(khoa));

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: ds.when(
        loading: () => const SizedBox(
          height: 36,
          child: Center(
            child: SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Mau.vang),
            ),
          ),
        ),
        error: (e, _) => Row(
          children: [
            Expanded(
              child: Text(
                e is ApiException ? e.message : 'Không tải được lịch tháng.',
                style: const TextStyle(fontSize: 12, color: Mau.chuMo),
              ),
            ),
            IconButton(
              tooltip: 'Tải lại lịch',
              onPressed: () => ref.invalidate(lichHenThangProvider(khoa)),
              icon: const Icon(Icons.refresh, color: Mau.vang, size: 18),
            ),
          ],
        ),
        data: (list) {
          final dem = <String, int>{};
          for (final b in list) {
            if (b.trangThai == TrangThaiBuoi.cancelled) continue;
            final l = b.batDau.toLocal();
            final k = LuoiThang.khoa(DateTime(l.year, l.month, l.day));
            dem[k] = (dem[k] ?? 0) + 1;
          }
          final chon = _chon;
          final trongNgay = chon == null
              ? const <Booking>[]
              : list.where((b) {
                  final l = b.batDau.toLocal();
                  return l.year == chon.year &&
                      l.month == chon.month &&
                      l.day == chon.day;
                }).toList();
          final trongThang = dem.values.fold<int>(0, (a, b) => a + b);

          // Một dòng duy nhất khi thu: tháng đang xem, số buổi của tháng, và
          // phần tóm tắt của ngày đang chọn nếu có.
          if (!widget.moRong) {
            return _DongTomTat(
              nhan: tenThangNgan(_thang),
              phu: chon == null
                  ? (trongThang == 0
                        ? Ngu.d('không có buổi nào')
                        : '$trongThang ${Ngu.d('buổi')}')
                  : (trongNgay.isEmpty
                        ? 'ngày ${chon.day}/${chon.month}: không có buổi'
                        : 'ngày ${chon.day}/${chon.month}: ${trongNgay.length} buổi'),
              bam: widget.doiMoRong,
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LuoiThang(
                thang: _thang,
                chon: _chon,
                soBuoi: dem,
                coTruoc: _hopLe(DateTime(_thang.year, _thang.month - 1)),
                coSau: _hopLe(DateTime(_thang.year, _thang.month + 1)),
                doiNgay: (d) => setState(() {
                  _chon =
                      _chon != null &&
                          _chon!.year == d.year &&
                          _chon!.month == d.month &&
                          _chon!.day == d.day
                      ? null
                      : d;
                }),
                doiThang: (delta) => setState(() {
                  _thang = DateTime(_thang.year, _thang.month + delta, 1);
                  _chon = null;
                }),
              ),
              if (chon != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 2),
                  child: Text(
                    trongNgay.isEmpty
                        ? '${Ngu.d('Ngày')} ${chon.day}/${chon.month} ${Ngu.d('không có buổi nào')}.'
                        : trongNgay
                              .map(
                                (b) =>
                                    '${_gio(b)} ${widget.cuaReader ? b.customerName : b.readerName}',
                              )
                              .join(' · '),
                    style: const TextStyle(fontSize: 12, color: Mau.chuMo),
                  ),
                ),
              if (widget.doiMoRong != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: widget.doiMoRong,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: Mau.vang,
                    ),
                    icon: const Icon(Icons.expand_less, size: 16),
                    label: Text(
                      Ngu.d('Thu gọn lịch'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _gio(Booking b) {
    final l = b.batDau.toLocal();
    final h = l.hour.toString().padLeft(2, '0');
    final m = l.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

/// Dòng tóm tắt khi lịch đã thu.
class _DongTomTat extends StatelessWidget {
  const _DongTomTat({required this.nhan, required this.phu, this.bam});

  final String nhan;
  final String phu;
  final VoidCallback? bam;

  @override
  Widget build(BuildContext context) {
    // Tự bọc Material: InkWell đòi một Material tổ tiên, và dựa vào Scaffold
    // của màn cha là một ràng buộc ngầm — nó vỡ ngay lúc ai đó nhúng lịch ở
    // chỗ khác, mà lỗi lúc ấy lại nói về InkWell chứ không nói về chỗ nhúng.
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: bam,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              const Icon(Icons.calendar_month, size: 16, color: Mau.vang),
              const SizedBox(width: 6),
              Text(
                nhan,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Mau.vang,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  phu,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Mau.chuMo),
                ),
              ),
              if (bam != null)
                const Icon(Icons.expand_more, size: 18, color: Mau.chuMo),
            ],
          ),
        ),
      ),
    );
  }
}
