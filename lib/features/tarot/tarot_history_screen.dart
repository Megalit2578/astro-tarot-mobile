import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/danh_sach_phan_trang.dart';
import '../../widgets/trang_thai.dart';
import '../home/home_repository.dart';
import 'tarot_repository.dart';
import 'tarot_screen.dart';

/// Lời giải AI đã lưu của một lượt — chỉ tải khi người dùng mở lượt ấy ra.
final loiGiaiDaLuuProvider = FutureProvider.family<List<String>, String>(
    (ref, id) => ref.watch(tarotRepositoryProvider).loiGiaiDaLuu(id));

/// Lịch sử trải bài, khớp trang `/tarot-history` của web.
///
/// Mỗi lượt là một dòng gập được; mở ra thì tải lại lời giải AI đã lưu.
/// Không tải trước lời giải của cả danh sách: mỗi lượt là một lời gọi, và
/// người dùng thường chỉ mở một hai lượt.
class TarotHistoryScreen extends ConsumerWidget {
  const TarotHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(tarotRepositoryProvider);
    void traiMoi() => Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const TarotScreen()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử trải bài'),
        actions: [
          IconButton(
            tooltip: 'Trải bài mới',
            onPressed: traiMoi,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: DanhSachPhanTrang<LanTraiBai>(
        tai: (t) => repo.lichSu(trang: t),
        loiDuPhong: 'Không tải được lịch sử. Thử lại sau.',
        dau: const [
          Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Những lần bạn hỏi bài trước đây. Mở một lượt để xem lại lời '
              'giải.',
              style: TextStyle(fontSize: 12.5, color: Mau.chuMo, height: 1.5),
            ),
          ),
        ],
        trong: KhoiTrong(
          icon: Icons.auto_awesome,
          tieuDe: 'Bạn chưa có lượt trải bài nào',
          hanhDong: FilledButton(
            onPressed: traiMoi,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
            child: const Text('Trải bài đầu tiên'),
          ),
        ),
        dong: (_, lan) => _DongLichSu(lan: lan),
      ),
    );
  }
}

class _DongLichSu extends ConsumerStatefulWidget {
  const _DongLichSu({required this.lan});
  final LanTraiBai lan;

  @override
  ConsumerState<_DongLichSu> createState() => _DongLichSuState();
}

class _DongLichSuState extends ConsumerState<_DongLichSu> {
  bool _mo = false;

  @override
  Widget build(BuildContext context) {
    final lan = widget.lan;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          ListTile(
            onTap: () => setState(() => _mo = !_mo),
            leading: const Icon(Icons.style_outlined, color: Mau.vang),
            title: Text(lan.cauHoi,
                maxLines: _mo ? null : 2,
                overflow: _mo ? null : TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5, height: 1.4)),
            subtitle: Text(
              [
                if (lan.luc != null) Dinh.ngayGio(lan.luc),
                if (lan.model != null) lan.model!,
              ].join(' · '),
              style: const TextStyle(fontSize: 11, color: Mau.chuMo),
            ),
            trailing: Icon(_mo ? Icons.expand_less : Icons.expand_more,
                color: Mau.chuMo),
          ),
          if (_mo) _LoiGiai(id: lan.id),
        ],
      ),
    );
  }
}

class _LoiGiai extends ConsumerWidget {
  const _LoiGiai({required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lg = ref.watch(loiGiaiDaLuuProvider(id));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: lg.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(12),
          child: Center(
              child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))),
        ),
        error: (e, _) => Text(
          e is ApiException ? e.message : 'Không tải được lời giải.',
          style: const TextStyle(fontSize: 12.5, color: Color(0xFFE5645E)),
        ),
        data: (ds) => ds.isEmpty
            ? const Text('Không có lời giải lưu lại cho lượt này.',
                style: TextStyle(fontSize: 12.5, color: Mau.chuMo))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final t in ds)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SelectableText(t,
                          style: const TextStyle(fontSize: 13.5, height: 1.65)),
                    ),
                ],
              ),
      ),
    );
  }
}
