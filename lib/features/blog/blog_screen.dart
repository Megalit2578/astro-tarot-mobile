import '../../core/ngon_ngu.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../core/api/trang.dart';
import '../../widgets/danh_sach_phan_trang.dart';
import '../../widgets/hop_thoai.dart';
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

/// Tải MỘT trang bài viết.
///
/// Danh sách bài viết chỉ dài thêm theo thời gian, nên một con số cứng ở đây
/// là một hạn mức sẽ âm thầm chạm tới — và lúc ấy những bài cũ nhất biến mất
/// mà không ai biết là chúng từng ở đó.
Future<Trang<BaiViet>> _taiTrangBaiViet(
  WidgetRef ref,
  int trang, {
  String tuKhoa = '',
}) async {
  final api = ref.read(apiClientProvider);
  final d = await api.get<dynamic>(
    Endpoints.blogs,
    query: {
      'page': trang,
      'size': 20,
      if (tuKhoa.isNotEmpty) 'keyword': tuKhoa,
    },
  );
  return Trang.tu(d, BaiViet.fromJson);
}

/// Ước lượng thời gian đọc, theo phút.
///
/// Giữ đúng công thức của web (`estimateReadTime`): 200 từ một phút, tối
/// thiểu một phút. Hai bên ra số khác nhau cho cùng một bài thì người đọc
/// thấy app và web mâu thuẫn nhau ở một chi tiết rất dễ kiểm.
int phutDoc(String? noiDung) {
  if (noiDung == null || noiDung.trim().isEmpty) return 1;
  final soTu = noiDung.trim().split(RegExp(r'\s+')).length;
  return (soTu / 200).ceil().clamp(1, 1 << 30);
}

/// Trang đầu danh sách công khai, dùng cho khối "Đọc tiếp".
///
/// Riêng một provider để nó được chia sẻ và lưu đệm giữa các bài: đọc liền
/// năm bài thì chỉ tốn một lượt gọi, không phải năm.
final baiVietTrangDauProvider = FutureProvider<List<BaiViet>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final d = await api.get<dynamic>(
    Endpoints.blogs,
    query: {'page': 0, 'size': 6},
  );
  return Trang.tu(d, BaiViet.fromJson).muc;
});

final baiVietChiTietProvider = FutureProvider.family<BaiViet, String>((
  ref,
  slug,
) async {
  final api = ref.watch(apiClientProvider);
  return BaiViet.fromJson(
    await api.get<Map<String, dynamic>>(Endpoints.blog(slug)),
  );
});

class BlogScreen extends ConsumerStatefulWidget {
  const BlogScreen({super.key});

  @override
  ConsumerState<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends ConsumerState<BlogScreen> {
  final _tim = TextEditingController();
  Timer? _hen;
  String _tuKhoa = '';

  @override
  void dispose() {
    _hen?.cancel();
    _tim.dispose();
    super.dispose();
  }

  /// Chờ người dùng ngừng gõ một chút rồi mới tìm — mỗi phím một lượt gọi là
  /// dồn tải cho máy chủ gói free vô ích. Cùng nhịp 350ms với gian hàng.
  void _khiGo(String v) {
    _hen?.cancel();
    _hen = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _tuKhoa = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(Ngu.d('Bài viết'))),
      body: DanhSachPhanTrang<BaiViet>(
        // Đổi từ khoá thì dựng lại từ trang đầu.
        key: ValueKey('blog-$_tuKhoa'),
        tai: (t) => _taiTrangBaiViet(ref, t, tuKhoa: _tuKhoa),
        loiDuPhong: Ngu.d('Không tải được bài viết.'),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        dau: [
          // Web có ô tìm từ lâu, app thì chưa. Danh sách bài chỉ dài thêm
          // theo thời gian, nên không có ô tìm thì bài cũ coi như mất.
          TextField(
            key: const ValueKey('o-tim-bai-viet'),
            controller: _tim,
            onChanged: _khiGo,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: Ngu.d('Tìm bài viết, tác giả...'),
              prefixIcon: Icon(Icons.search, size: 20),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
        ],
        trong: KhoiTrong(
          icon: _tuKhoa.isEmpty
              ? Icons.article_outlined
              : Icons.search_off_outlined,
          tieuDe: _tuKhoa.isEmpty
              ? Ngu.d('Chưa có bài viết nào')
              : Ngu.d('Không tìm thấy bài nào'),
          moTa: _tuKhoa.isEmpty
              ? Ngu.d('Khi có bài được duyệt và xuất bản, bạn sẽ thấy ở đây.')
              : Ngu.d('Thử một từ khoá khác, hoặc xoá ô tìm để xem tất cả.'),
        ),
        dong: (_, b) => _The(b: b),
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
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => BlogDetailScreen(bai: b))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (anh != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
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
                  Text(
                    b.tieuDe,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  if (b.tomTat != null && b.tomTat!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      b.tomTat!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Mau.chuMo,
                        height: 1.55,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    [
                      if (b.tacGia != null) b.tacGia!,
                      if (b.luc != null) Dinh.ngay(b.luc),
                    ].join(' · '),
                    style: const TextStyle(fontSize: 11, color: Mau.chuMo),
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
        title: Text(
          bai.tieuDe,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          // Chép liên kết thay vì mở khay chia sẻ của hệ điều hành: khay ấy
          // cần thêm một phụ thuộc, mà bài viết nằm trên web nên thứ người ta
          // thật sự muốn gửi đi là cái địa chỉ.
          IconButton(
            tooltip: Ngu.d('Chép liên kết bài viết'),
            icon: const Icon(Icons.link, size: 20),
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: '${AppConfig.webBaseUrl}/blog/${bai.slug}'),
              );
              if (context.mounted) {
                baoTin(context, Ngu.d('Đã chép liên kết bài viết.'));
              }
            },
          ),
        ],
      ),
      body: ct.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Mau.vang)),
        error: (e, _) => KhoiLoi(
          thongDiep: e is ApiException
              ? e.message
              : Ngu.d('Không tải được bài viết.'),
          thuLai: () => ref.invalidate(baiVietChiTietProvider(bai.slug)),
        ),
        data: (b) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          children: [
            Text(
              b.tieuDe,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              [
                if (b.tacGia != null) b.tacGia!,
                if (b.luc != null) Dinh.ngay(b.luc),
                // Thời gian đọc: web có từ lâu. Nó trả lời đúng câu người ta
                // hỏi trước khi bấm vào — "dài bao nhiêu".
                '${phutDoc(b.noiDung ?? b.tomTat)} phút đọc',
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
                  ? Ngu.d('Bài viết này chưa có nội dung.')
                  : (b.noiDung ?? b.tomTat)!,
              style: const TextStyle(fontSize: 14, height: 1.8),
            ),
            _BaiLienQuan(slugDangDoc: b.slug),
          ],
        ),
      ),
    );
  }
}

/// Mấy bài khác dưới chân bài đang đọc.
///
/// Web có khối này, app thì chưa: đọc xong một bài là hết đường đi tiếp, phải
/// bấm quay lại rồi tự dò trong danh sách. Người đọc hết một bài là người sẵn
/// sàng đọc bài thứ hai nhất.
///
/// Lấy ngay trang đầu của danh sách công khai chứ không gọi thêm endpoint
/// nào: backend chưa có "bài liên quan", và bịa ra một lượt gọi nữa chỉ để
/// lọc ở máy khách thì không đáng.
class _BaiLienQuan extends ConsumerWidget {
  const _BaiLienQuan({required this.slugDangDoc});
  final String slugDangDoc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = ref.watch(baiVietTrangDauProvider).asData?.value ?? const [];
    final khac = ds.where((b) => b.slug != slugDangDoc).take(3).toList();
    if (khac.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        const Divider(height: 1, color: Mau.vien),
        const SizedBox(height: 18),
        Text(
          Ngu.d('ĐỌC TIẾP'),
          style: TextStyle(
            fontSize: 10.5,
            letterSpacing: 1.4,
            color: Mau.vang.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: 10),
        for (final b in khac)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            // pushReplacement chứ không push: đọc lần lượt năm bài rồi bấm
            // quay lại phải về danh sách, không phải lần ngược từng bài một.
            onTap: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => BlogDetailScreen(bai: b)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.tieuDe,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${phutDoc(b.noiDung ?? b.tomTat)} phút đọc',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Mau.chuMo,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18, color: Mau.chuMo),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
