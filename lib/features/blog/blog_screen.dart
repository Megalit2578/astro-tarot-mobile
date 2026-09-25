import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/trang_thai.dart';

class BaiViet {
  const BaiViet({
    required this.id,
    required this.tieuDe,
    required this.slug,
    this.tomTat,
    this.noiDung,
    this.anh,
    this.tacGia,
    this.luc,
  });

  final String id;
  final String tieuDe;
  final String slug;
  final String? tomTat;
  final String? noiDung;
  final String? anh;
  final String? tacGia;
  final DateTime? luc;

  String? get anhDayDu => AppConfig.anh(anh);

  factory BaiViet.fromJson(Map<String, dynamic> j) {
    final tg = j['author'];
    return BaiViet(
      id: (j['id'] ?? '').toString(),
      tieuDe: (j['title'] ?? '') as String,
      slug: (j['slug'] ?? '') as String,
      tomTat: j['summary'] as String?,
      noiDung: j['content'] as String?,
      anh: j['thumbnailUrl'] as String?,
      tacGia: tg is Map ? (tg['fullName'] ?? tg['username']) as String? : null,
      luc: DateTime.tryParse((j['createdAt'] ?? '').toString()),
    );
  }
}

final baiVietProvider = FutureProvider<List<BaiViet>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final d =
      await api.get<dynamic>(Endpoints.blogs, query: {'page': 0, 'size': 30});
  final l = d is Map ? d['content'] : d;
  if (l is! List) return const [];
  return l.whereType<Map<String, dynamic>>().map(BaiViet.fromJson).toList();
});

final baiVietChiTietProvider =
    FutureProvider.family<BaiViet, String>((ref, slug) async {
  final api = ref.watch(apiClientProvider);
  return BaiViet.fromJson(
      await api.get<Map<String, dynamic>>(Endpoints.blog(slug)));
});

class BlogScreen extends ConsumerWidget {
  const BlogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = ref.watch(baiVietProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Bài viết')),
      body: RefreshIndicator(
        color: Mau.vang,
        backgroundColor: Mau.the,
        onRefresh: () => ref.refresh(baiVietProvider.future),
        child: ds.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: Mau.vang)),
          error: (e, _) => KhoiLoi(
            thongDiep:
                e is ApiException ? e.message : 'Không tải được bài viết.',
            thuLai: () => ref.invalidate(baiVietProvider),
          ),
          data: (list) => list.isEmpty
              ? const KhoiTrong(
                  icon: Icons.article_outlined,
                  tieuDe: 'Chưa có bài viết nào',
                  moTa: 'Khi có bài được duyệt và xuất bản, bạn sẽ thấy ở đây.',
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _The(b: list[i]),
                ),
        ),
      ),
    );
  }
}

class _The extends StatelessWidget {
  const _The({required this.b});
  final BaiViet b;

  @override
  Widget build(BuildContext context) {
    final anh = b.anhDayDu;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => BlogDetailScreen(bai: b)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (anh != null)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  anh,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  // Ảnh hỏng thì bỏ hẳn khối ảnh, đừng chừa một dải xám —
                  // thẻ không ảnh trông bình thường, thẻ có ô vỡ trông như lỗi.
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.tieuDe,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.4)),
                  if (b.tomTat != null && b.tomTat!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(b.tomTat!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12.5,
                            color: Mau.chuMo,
                            height: 1.55)),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    [
                      if (b.tacGia != null) b.tacGia!,
                      if (b.luc != null) Dinh.ngay(b.luc),
                    ].join(' · '),
                    style:
                        const TextStyle(fontSize: 11, color: Mau.chuMo),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BlogDetailScreen extends ConsumerWidget {
  const BlogDetailScreen({super.key, required this.bai});
  final BaiViet bai;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Danh sách chỉ có tóm tắt; nội dung đầy đủ nằm ở endpoint theo slug.
    final ct = ref.watch(baiVietChiTietProvider(bai.slug));

    return Scaffold(
      appBar: AppBar(
        title: Text(bai.tieuDe,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15)),
      ),
      body: ct.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Mau.vang)),
        error: (e, _) => KhoiLoi(
          thongDiep:
              e is ApiException ? e.message : 'Không tải được bài viết.',
          thuLai: () => ref.invalidate(baiVietChiTietProvider(bai.slug)),
        ),
        data: (b) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          children: [
            Text(b.tieuDe,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w600, height: 1.35)),
            const SizedBox(height: 8),
            Text(
              [
                if (b.tacGia != null) b.tacGia!,
                if (b.luc != null) Dinh.ngay(b.luc),
              ].join(' · '),
              style: const TextStyle(fontSize: 11.5, color: Mau.chuMo),
            ),
            if (b.anhDayDu != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  b.anhDayDu!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Text(
              (b.noiDung ?? b.tomTat ?? '').trim().isEmpty
                  ? 'Bài viết này chưa có nội dung.'
                  : (b.noiDung ?? b.tomTat)!,
              style: const TextStyle(fontSize: 14, height: 1.8),
            ),
          ],
        ),
      ),
    );
  }
}
