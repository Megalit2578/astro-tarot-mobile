import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../theme.dart';
import '../../widgets/danh_sach_phan_trang.dart';
import '../../widgets/trang_thai.dart';
import '../../widgets/loc_trang_thai.dart';
import 'admin_repository.dart';

/// Một phản hồi của người dùng, nhìn từ phía quản trị.
class GopY {
  const GopY({
    required this.id,
    required this.sao,
    required this.nguon,
    required this.noiDung,
    required this.tenNguoiGui,
    required this.anDanh,
    required this.luc,
  });

  final String id;
  final int? sao;
  final String? nguon;
  final String? noiDung;
  final String? tenNguoiGui;
  final bool anDanh;
  final DateTime? luc;

  factory GopY.fromJson(Map<String, dynamic> j) => GopY(
    id: (j['id'] ?? '').toString(),
    sao: j['rating'] as int?,
    nguon: j['source'] as String?,
    noiDung: j['comment'] as String?,
    // Ẩn danh thì máy chủ vẫn gửi tên; không được bày ra, đó là cả ý nghĩa
    // của ô "gửi ẩn danh" mà người dùng đã tick.
    tenNguoiGui: (j['isAnonymous'] == true)
        ? null
        : (j['userFullName'] ?? j['username']) as String?,
    anDanh: j['isAnonymous'] == true,
    luc: DateTime.tryParse((j['createdAt'] ?? '').toString())?.toLocal(),
  );
}

/// Thống kê gộp của toàn bộ phản hồi.
class ThongKeGopY {
  const ThongKeGopY({
    required this.tong,
    required this.trungBinh,
    required this.theoSao,
  });

  final int tong;
  final double trungBinh;
  final Map<int, int> theoSao;

  factory ThongKeGopY.fromJson(Map<String, dynamic> j) {
    final raw = j['ratingDistribution'];
    final theo = <int, int>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        final sao = int.tryParse(k.toString());
        final so = (v as num?)?.toInt();
        if (sao != null && so != null) theo[sao] = so;
      });
    }
    return ThongKeGopY(
      tong: (j['totalCount'] as num?)?.toInt() ?? 0,
      trungBinh: (j['averageRating'] as num?)?.toDouble() ?? 0,
      theoSao: theo,
    );
  }
}

final thongKeGopYProvider = FutureProvider<ThongKeGopY>((ref) async {
  final d = await ref
      .read(apiClientProvider)
      .get<Map<String, dynamic>>('/api/v1/admin/feedback/stats');
  return ThongKeGopY.fromJson(d);
});

/// Đánh giá và góp ý của người dùng.
///
/// ## Vì sao chỉ đọc
///
/// Bên web màn này cũng chỉ đọc: phản hồi là lời của người dùng, quản trị
/// viên không sửa và không xoá được. Thêm nút sửa ở đây là bày một thao tác
/// mà máy chủ không có endpoint nào nhận.
class GopYView extends ConsumerStatefulWidget {
  const GopYView({super.key});

  @override
  ConsumerState<GopYView> createState() => _GopYViewState();
}

class _GopYViewState extends ConsumerState<GopYView> {
  /// Chuỗi rỗng nghĩa là không lọc — theo đúng quy ước của LocTrangThai.
  String _sao = '';

  static const _nhanSao = <String, String>{
    '5': '5 sao',
    '4': '4 sao',
    '3': '3 sao',
    '2': '2 sao',
    '1': '1 sao',
  };

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(adminRepositoryProvider);
    final tk = ref.watch(thongKeGopYProvider);

    return Column(
      children: [
        LocTrangThai(
          giaTri: _sao,
          nhan: _nhanSao,
          nhanTatCa: 'Mọi mức sao',
          doi: (v) => setState(() => _sao = v),
        ),
        Expanded(
          child: DanhSachPhanTrang<GopY>(
            key: ValueKey(_sao),
            tai: (t) => repo.gopY(trang: t, sao: _sao),
            loiDuPhong: 'Không tải được danh sách góp ý.',
            dau: [
              tk.when(
                loading: () => const SizedBox(height: 4),
                error: (_, _) => const SizedBox(height: 4),
                data: (t) => _TheThongKe(tk: t),
              ),
            ],
            trong: KhoiTrong(
              icon: Icons.reviews_outlined,
              tieuDe: _sao.isEmpty
                  ? 'Chưa có góp ý nào'
                  : 'Không có góp ý ${(_nhanSao[_sao] ?? '').toLowerCase()}',
              moTa: _sao.isEmpty
                  ? 'Góp ý người dùng gửi từ app và web sẽ hiện ở đây.'
                  : 'Chọn "Mọi mức sao" để xem toàn bộ.',
            ),
            dong: (_, g) => _TheGopY(g: g),
          ),
        ),
      ],
    );
  }
}

class _TheThongKe extends StatelessWidget {
  const _TheThongKe({required this.tk});
  final ThongKeGopY tk;

  @override
  Widget build(BuildContext context) {
    final caoNhat = tk.theoSao.values.fold<int>(0, (a, b) => a > b ? a : b);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Mau.the,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Mau.vang.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                tk.trungBinh.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: Mau.vang,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(bottom: 3),
                child: Icon(Icons.star, size: 18, color: Mau.vang),
              ),
              const Spacer(),
              Text(
                '${tk.tong} góp ý',
                style: const TextStyle(fontSize: 12, color: Mau.chuMo),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Năm dòng cố định 5→1, kể cả mức chưa ai chọn: thiếu dòng thì mắt
          // đọc nhầm phân bổ, vì hàng dưới nhảy lên chỗ của hàng trên.
          for (var s = 5; s >= 1; s--)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    child: Text(
                      '$s',
                      style: const TextStyle(fontSize: 11, color: Mau.chuMo),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: caoNhat == 0
                            ? 0
                            : (tk.theoSao[s] ?? 0) / caoNhat,
                        minHeight: 6,
                        backgroundColor: Mau.vien,
                        valueColor: const AlwaysStoppedAnimation(Mau.vang),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 30,
                    child: Text(
                      '${tk.theoSao[s] ?? 0}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 11, color: Mau.chuMo),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TheGopY extends StatelessWidget {
  const _TheGopY({required this.g});
  final GopY g;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Mau.the,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Mau.vien),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (g.sao != null) ...[
                for (var i = 1; i <= 5; i++)
                  Icon(
                    i <= g.sao! ? Icons.star : Icons.star_border,
                    size: 14,
                    color: Mau.vang,
                  ),
                const SizedBox(width: 8),
              ],
              if (g.nguon != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Mau.vang.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    g.nguon!,
                    style: const TextStyle(fontSize: 10, color: Mau.vang),
                  ),
                ),
              const Spacer(),
              if (g.luc != null)
                Text(
                  '${g.luc!.day}/${g.luc!.month}',
                  style: const TextStyle(fontSize: 11, color: Mau.chuMo),
                ),
            ],
          ),
          if (g.noiDung != null && g.noiDung!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              g.noiDung!,
              style: const TextStyle(fontSize: 13, color: Mau.chu),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            g.anDanh ? 'Gửi ẩn danh' : (g.tenNguoiGui ?? 'Khách vãng lai'),
            style: const TextStyle(fontSize: 11, color: Mau.chuMo),
          ),
        ],
      ),
    );
  }
}
