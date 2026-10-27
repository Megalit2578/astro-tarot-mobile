import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../theme.dart';
import '../../widgets/trang_thai.dart';
import 'admin_repository.dart';

/// Báo cáo lưu lượng lấy từ Google Analytics 4.
class BaoCaoGa4 {
  const BaoCaoGa4({
    required this.daCauHinh,
    required this.nguoiDung,
    required this.nguoiMoi,
    required this.phien,
    required this.luotXem,
    required this.tiLeThoat,
    required this.giayMoiPhien,
    required this.dangOnline,
    required this.nguon,
    required this.thongDiep,
  });

  final bool daCauHinh;
  final int nguoiDung;
  final int nguoiMoi;
  final int phien;
  final int luotXem;
  final double tiLeThoat;
  final double giayMoiPhien;

  /// -1 nghĩa là không hỏi được; 0 là hỏi được và đúng là không có ai.
  final int dangOnline;
  final List<NguonTruyCap> nguon;
  final String? thongDiep;

  factory BaoCaoGa4.fromJson(Map<String, dynamic> j) {
    final o = (j['overview'] as Map?)?.cast<String, dynamic>() ?? const {};
    final ds = (j['trafficSources'] as List?) ?? const [];
    return BaoCaoGa4(
      daCauHinh: j['configured'] == true,
      nguoiDung: (o['activeUsers'] as num?)?.toInt() ?? 0,
      nguoiMoi: (o['newUsers'] as num?)?.toInt() ?? 0,
      phien: (o['sessions'] as num?)?.toInt() ?? 0,
      luotXem: (o['screenPageViews'] as num?)?.toInt() ?? 0,
      tiLeThoat: (o['bounceRate'] as num?)?.toDouble() ?? 0,
      giayMoiPhien: (o['averageSessionDuration'] as num?)?.toDouble() ?? 0,
      dangOnline: (j['realtimeActiveUsers'] as num?)?.toInt() ?? -1,
      nguon: [
        for (final e in ds)
          if (e is Map) NguonTruyCap.fromJson(e.cast<String, dynamic>()),
      ],
      thongDiep: j['message'] as String?,
    );
  }
}

class NguonTruyCap {
  const NguonTruyCap({
    required this.nguon,
    required this.kenh,
    required this.phien,
    required this.nguoiDung,
  });

  final String nguon;
  final String kenh;
  final int phien;
  final int nguoiDung;

  factory NguonTruyCap.fromJson(Map<String, dynamic> j) => NguonTruyCap(
    nguon: (j['source'] ?? '(không rõ)') as String,
    kenh: (j['medium'] ?? '') as String,
    phien: (j['sessions'] as num?)?.toInt() ?? 0,
    nguoiDung: (j['activeUsers'] as num?)?.toInt() ?? 0,
  );
}

final ga4Provider = FutureProvider.family<BaoCaoGa4, String>(
  (ref, khoang) => ref.read(adminRepositoryProvider).ga4(khoang),
);

/// Lưu lượng & GA4.
///
/// ## Vì sao không vẽ biểu đồ như web
///
/// Bản web có biểu đồ đường theo ngày. Trên màn điện thoại rộng chừng 360dp,
/// một biểu đồ 30 điểm cho ra những cột sát nhau không đọc được con số nào —
/// nó chỉ chiếm chỗ. Số tổng và bảng nguồn truy cập mới là thứ trả lời được
/// câu hỏi người ta mở màn này để hỏi: hôm nay có ai vào không, và từ đâu.
class Ga4View extends ConsumerStatefulWidget {
  const Ga4View({super.key});

  @override
  ConsumerState<Ga4View> createState() => _Ga4ViewState();
}

class _Ga4ViewState extends ConsumerState<Ga4View> {
  String _khoang = '30daysAgo';

  static const _nhanKhoang = <String, String>{
    '7daysAgo': '7 ngày qua',
    '14daysAgo': '14 ngày qua',
    '30daysAgo': '30 ngày qua',
    '90daysAgo': '90 ngày qua',
  };

  @override
  Widget build(BuildContext context) {
    final bc = ref.watch(ga4Provider(_khoang));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final e in _nhanKhoang.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.value, style: const TextStyle(fontSize: 12)),
                      selected: _khoang == e.key,
                      onSelected: (_) => setState(() => _khoang = e.key),
                      selectedColor: Mau.vang.withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                        color: _khoang == e.key ? Mau.vang : Mau.chuMo,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: bc.when(
            loading: () =>
                const Center(child: CircularProgressIndicator(color: Mau.vang)),
            error: (e, _) => KhoiLoi(
              thongDiep: e is ApiException
                  ? e.message
                  : 'Không tải được số liệu GA4.',
              thuLai: () => ref.invalidate(ga4Provider(_khoang)),
            ),
            data: (b) => !b.daCauHinh
                ? KhoiTrong(
                    icon: Icons.insights_outlined,
                    tieuDe: 'Chưa nối Google Analytics',
                    moTa:
                        b.thongDiep ??
                        'Đặt GA4_PROPERTY_ID và khoá dịch vụ trên máy chủ rồi mở lại.',
                  )
                : RefreshIndicator(
                    color: Mau.vang,
                    backgroundColor: Mau.the,
                    onRefresh: () async => ref.invalidate(ga4Provider(_khoang)),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [
                        _DangOnline(so: b.dangOnline),
                        const SizedBox(height: 10),
                        _LuoiSo(b: b),
                        const SizedBox(height: 16),
                        const Text(
                          'Khách đến từ đâu',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Mau.chu,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (b.nguon.isEmpty)
                          const Text(
                            'Chưa có dữ liệu nguồn truy cập cho khoảng này.',
                            style: TextStyle(fontSize: 12, color: Mau.chuMo),
                          )
                        else
                          for (final n in b.nguon) _DongNguon(n: n),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Số người đang ở trên web trong 30 phút qua.
///
/// Tách riêng và để lên đầu vì nó là con số DUY NHẤT ở màn này không bị trễ:
/// báo cáo thường của GA4 trễ 24–48 giờ với tài sản mới, nên mọi ô bên dưới
/// có thể đứng im ở 0 suốt hai ngày đầu dù web vẫn có khách.
class _DangOnline extends StatelessWidget {
  const _DangOnline({required this.so});
  final int so;

  @override
  Widget build(BuildContext context) {
    final khongHoiDuoc = so < 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Mau.the,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Mau.vang.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.sensors,
            size: 18,
            color: khongHoiDuoc ? Mau.chuMo : Mau.vang,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Đang truy cập (30 phút qua)',
              style: TextStyle(fontSize: 13, color: Mau.chu),
            ),
          ),
          Text(
            khongHoiDuoc ? '—' : '$so',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: khongHoiDuoc ? Mau.chuMo : Mau.vang,
            ),
          ),
        ],
      ),
    );
  }
}

class _LuoiSo extends StatelessWidget {
  const _LuoiSo({required this.b});
  final BaoCaoGa4 b;

  @override
  Widget build(BuildContext context) {
    final phut = (b.giayMoiPhien / 60).floor();
    final giay = (b.giayMoiPhien % 60).round();
    final o = <(String, String)>[
      ('Người dùng', '${b.nguoiDung}'),
      ('Người mới', '${b.nguoiMoi}'),
      ('Phiên truy cập', '${b.phien}'),
      ('Lượt xem trang', '${b.luotXem}'),
      ('Tỉ lệ thoát', '${(b.tiLeThoat * 100).toStringAsFixed(0)}%'),
      ('Thời lượng/phiên', '${phut}p ${giay}s'),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.1,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        for (final (nhan, gt) in o)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Mau.the,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Mau.vien),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  gt,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Mau.vang,
                  ),
                ),
                Text(
                  nhan,
                  style: const TextStyle(fontSize: 11, color: Mau.chuMo),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DongNguon extends StatelessWidget {
  const _DongNguon({required this.n});
  final NguonTruyCap n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.nguon,
                  style: const TextStyle(fontSize: 13, color: Mau.chu),
                ),
                if (n.kenh.isNotEmpty)
                  Text(
                    n.kenh,
                    style: const TextStyle(fontSize: 11, color: Mau.chuMo),
                  ),
              ],
            ),
          ),
          Text(
            '${n.phien} phiên · ${n.nguoiDung} người',
            style: const TextStyle(fontSize: 12, color: Mau.chuMo),
          ),
        ],
      ),
    );
  }
}
