import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/auth/auth_controller.dart';

/// Một khung giờ còn trống.
class Slot {
  const Slot({
    required this.batDau,
    required this.ketThuc,
    required this.gia,
    this.trang = TrangO.free,
  });

  final DateTime batDau;
  final DateTime ketThuc;
  final int gia;
  final TrangO trang;

  bool get datDuoc => trang == TrangO.free;

  factory Slot.fromJson(Map<String, dynamic> j) => Slot(
    // Máy chủ trả giờ UTC có hậu tố Z. DateTime.parse giữ nguyên là UTC;
    // mọi chỗ hiển thị phải .toLocal(), nếu không giờ hẹn lệch bảy tiếng
    // và không ai để ý cho tới khi khách đến muộn.
    batDau: DateTime.parse(j['startTime'] as String),
    ketThuc: DateTime.parse(j['endTime'] as String),
    gia: (j['price'] as num?)?.toInt() ?? 0,
    trang: switch (j['state']) {
      'TAKEN' => TrangO.taken,
      'PAST' => TrangO.past,
      _ => TrangO.free,
    },
  );
}

enum TrangO { free, taken, past }

enum LoaiNgay { off, closed, open, full, over, past, khac }

LoaiNgay loaiNgayTu(String? s) => switch (s) {
  'OFF' => LoaiNgay.off,
  'CLOSED' => LoaiNgay.closed,
  'OPEN' => LoaiNgay.open,
  'FULL' => LoaiNgay.full,
  'OVER' => LoaiNgay.over,
  'PAST' => LoaiNgay.past,
  _ => LoaiNgay.khac,
};

class NgayLich {
  const NgayLich({required this.ngay, required this.loai, required this.o});

  final DateTime ngay;
  final LoaiNgay loai;
  final List<Slot> o;

  factory NgayLich.fromJson(Map<String, dynamic> j) {
    final raw = j['date'] as String;
    final p = raw.split('-');
    return NgayLich(
      ngay: DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2])),
      loai: loaiNgayTu(j['kind'] as String?),
      o: ((j['slots'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Slot.fromJson)
          .toList(),
    );
  }
}

class ThangLich {
  const ThangLich({required this.ngay});

  final List<NgayLich> ngay;

  factory ThangLich.fromJson(Map<String, dynamic> j) => ThangLich(
    ngay: ((j['days'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(NgayLich.fromJson)
        .toList(),
  );

  NgayLich? cua(DateTime d) {
    for (final n in ngay) {
      if (n.ngay.year == d.year &&
          n.ngay.month == d.month &&
          n.ngay.day == d.day) {
        return n;
      }
    }
    return null;
  }
}

class LichQuery {
  const LichQuery({
    required this.readerId,
    required this.nam,
    required this.thang,
    required this.phut,
  });

  final String readerId;
  final int nam;
  final int thang;
  final int phut;

  @override
  bool operator ==(Object other) =>
      other is LichQuery &&
      other.readerId == readerId &&
      other.nam == nam &&
      other.thang == thang &&
      other.phut == phut;

  @override
  int get hashCode => Object.hash(readerId, nam, thang, phut);
}

final lichThangProvider = FutureProvider.family<ThangLich, LichQuery>((
  ref,
  q,
) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get<Map<String, dynamic>>(
    Endpoints.readerCalendar(q.readerId),
    query: {'year': q.nam, 'month': q.thang, 'duration': q.phut},
  );
  return ThangLich.fromJson(data);
});

/// Khoá tra khung giờ: một Reader, một ngày, một độ dài.
class SlotQuery {
  const SlotQuery({
    required this.readerId,
    required this.ngay,
    required this.phut,
  });

  final String readerId;
  final DateTime ngay;
  final int phut;

  String get ngayISO =>
      '${ngay.year.toString().padLeft(4, '0')}-'
      '${ngay.month.toString().padLeft(2, '0')}-'
      '${ngay.day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is SlotQuery &&
      other.readerId == readerId &&
      other.ngayISO == ngayISO &&
      other.phut == phut;

  @override
  int get hashCode => Object.hash(readerId, ngayISO, phut);
}

final slotsProvider = FutureProvider.family<List<Slot>, SlotQuery>((
  ref,
  q,
) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get<List<dynamic>>(
    Endpoints.readerSlots(q.readerId),
    query: {'date': q.ngayISO, 'duration': q.phut},
  );
  final ds = data.whereType<Map<String, dynamic>>().map(Slot.fromJson).toList();

  // Bỏ khung giờ đã trôi qua.
  //
  // Máy chủ trả theo NGÀY nên buổi sáng vẫn nằm trong danh sách dù bây giờ đã
  // chiều. Để nguyên thì người dùng bấm vào rồi mới bị từ chối, và câu từ chối
  // không nói rõ vì sao.
  final bayGio = DateTime.now();
  return ds.where((s) => s.batDau.toLocal().isAfter(bayGio)).toList();
});

/// Ngoại lệ mạng cho tầng giao diện đọc lại — tiện cho `when(error:)`.
typedef LoiApi = ApiException;
