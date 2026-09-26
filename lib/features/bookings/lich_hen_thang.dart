import 'package:flutter/material.dart';
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
class LichHenThang extends ConsumerStatefulWidget {
  const LichHenThang({super.key, required this.cuaReader});

  final bool cuaReader;

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
                        ? 'Ngày ${chon.day}/${chon.month} không có buổi nào.'
                        : trongNgay
                              .map(
                                (b) =>
                                    '${_gio(b)} ${widget.cuaReader ? b.customerName : b.readerName}',
                              )
                              .join(' · '),
                    style: const TextStyle(fontSize: 12, color: Mau.chuMo),
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
