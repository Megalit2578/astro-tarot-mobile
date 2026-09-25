import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/trang_thai.dart';
import 'reader.dart';
import 'reader_detail_screen.dart';
import 'readers_repository.dart';

class ReadersScreen extends ConsumerStatefulWidget {
  const ReadersScreen({super.key});

  @override
  ConsumerState<ReadersScreen> createState() => _ReadersScreenState();
}

class _ReadersScreenState extends ConsumerState<ReadersScreen> {
  final _oTim = TextEditingController();

  @override
  void dispose() {
    _oTim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ds = ref.watch(readersDaLocProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tìm Reader'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _oTim,
              onChanged: (v) => ref.read(tuKhoaProvider.notifier).dat(v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Tên Reader hoặc chuyên môn…',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                suffixIcon: _oTim.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Xoá từ khoá',
                        onPressed: () {
                          _oTim.clear();
                          ref.read(tuKhoaProvider.notifier).dat('');
                          setState(() {});
                        },
                      ),
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        color: Mau.vang,
        backgroundColor: Mau.the,
        onRefresh: () => ref.refresh(readersProvider.future),
        child: ds.when(
          loading: () => const _KhungCho(),
          error: (e, _) => KhoiLoi(
            thongDiep: e is ApiException
                ? e.message
                : 'Không tải được danh sách Reader.',
            thuLai: () => ref.invalidate(readersProvider),
          ),
          data: (list) {
            if (list.isEmpty) {
              return KhoiTrong(
                icon: Icons.person_search,
                tieuDe: ref.read(tuKhoaProvider).isEmpty
                    ? 'Chưa có Reader nào'
                    : 'Không có Reader nào khớp',
                moTa: ref.read(tuKhoaProvider).isEmpty
                    ? 'Hồ sơ Reader phải được duyệt và đặt giá mới xuất hiện ở đây.'
                    : 'Thử từ khoá khác nhé.',
              );
            }
            return ListView.builder(
              // Luôn cuộn được, kể cả khi danh sách ngắn — không thì
              // RefreshIndicator không kéo xuống được.
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: list.length,
              itemBuilder: (_, i) => _TheReader(reader: list[i]),
            );
          },
        ),
      ),
    );
  }
}

/// Thẻ Reader.
///
/// Giữ gọn có chủ đích. Bên web từng phải thu nhỏ thẻ vì hai thẻ đã chiếm gần
/// hết chiều cao màn hình; trên điện thoại màn còn hẹp hơn nhiều, nên bắt đầu
/// từ mức gọn luôn thay vì để rộng rồi sửa sau.
class _TheReader extends StatelessWidget {
  const _TheReader({required this.reader});

  final Reader reader;

  @override
  Widget build(BuildContext context) {
    final gia = reader.giaReNhat;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReaderDetailScreen(readerId: reader.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Anh(reader: reader),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reader.ten,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          reader.yearsExperience != null
                              ? '${reader.yearsExperience} năm kinh nghiệm'
                              : 'Reader mới',
                          style: const TextStyle(
                              color: Mau.chuMo, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star,
                                size: 13, color: Mau.vang),
                            const SizedBox(width: 4),
                            Text(
                              Dinh.diem(reader.rating, reader.totalReviews),
                              style: const TextStyle(
                                  color: Mau.vang, fontSize: 12),
                            ),
                            const SizedBox(width: 4),
                            // Flexible: với cỡ chữ lớn của máy, dòng này
                            // tràn khỏi thẻ nếu không được phép co lại.
                            Flexible(
                              child: Text(
                                reader.totalReviews > 0
                                    ? '(${reader.totalReviews} đánh giá)'
                                    : 'đánh giá',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Mau.chuMo, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (gia != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('chỉ từ',
                            style: TextStyle(
                                color: Mau.chuMo, fontSize: 10.5)),
                        const SizedBox(height: 2),
                        Text(
                          Dinh.tien(gia),
                          style: const TextStyle(
                            color: Mau.vang,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              if (reader.bio != null && reader.bio!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  reader.bio!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Mau.chuMo, fontSize: 12.5, height: 1.5),
                ),
              ],
              if (reader.specialties.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in reader.specialties)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0x33D4AF37)),
                        ),
                        child: Text(
                          s,
                          style: const TextStyle(
                              fontSize: 11, color: Mau.vangNhat),
                        ),
                      ),
                  ],
                ),
              ],
              if (!reader.isAvailable) ...[
                const SizedBox(height: 10),
                const Text(
                  'Đang tạm ngưng nhận lịch',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFFE0B341)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Anh extends StatelessWidget {
  const _Anh({required this.reader});

  final Reader reader;

  @override
  Widget build(BuildContext context) {
    final co = reader.avatar != null && reader.avatar!.isNotEmpty;
    return Container(
      height: 46,
      width: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Mau.vien),
        image: co
            ? DecorationImage(
                image: NetworkImage(reader.avatar!), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: co
          ? null
          : Text(
              reader.chuDau,
              style: const TextStyle(fontSize: 17, color: Mau.vang),
            ),
    );
  }
}

class _KhungCho extends StatelessWidget {
  const _KhungCho();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        for (var i = 0; i < 5; i++)
          Container(
            height: 108,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Mau.the,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Mau.vien),
            ),
          ),
      ],
    );
  }
}
