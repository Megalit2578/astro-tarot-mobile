import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/api/trang.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/danh_sach_phan_trang.dart';
import '../../widgets/trang_thai.dart';

/// Một đánh giá khách để lại sau buổi xem.
class DanhGia {
  const DanhGia({
    required this.id,
    required this.tacGia,
    required this.diem,
    this.anh,
    this.nhanXet,
    this.luc,
  });

  final String id;
  final String tacGia;
  final String? anh;
  final int diem;
  final String? nhanXet;
  final DateTime? luc;

  factory DanhGia.fromJson(Map<String, dynamic> j) => DanhGia(
        id: (j['id'] ?? '').toString(),
        tacGia: (j['authorName'] ?? 'Khách') as String,
        anh: chuoi(j['authorAvatar']),
        diem: soNguyen(j['rating']) ?? 0,
        nhanXet: chuoi(j['comment']),
        luc: thoiDiem(j['createdAt']),
      );
}

/// Tải một trang đánh giá của Reader. Công khai — khách chưa đăng nhập cũng
/// đọc được, như web.
Future<Trang<DanhGia>> taiDanhGia(ApiClient api, String readerId, int trang,
    {int co = 10}) async {
  final d = await api.get<dynamic>(
      Endpoints.readerReviews(readerId),
      query: {'page': trang, 'size': co});
  return Trang.tu(d, DanhGia.fromJson);
}

/// Ba đánh giá mới nhất cho khối trong hồ sơ Reader.
final danhGiaDauProvider = FutureProvider.family<Trang<DanhGia>, String>(
    (ref, id) => taiDanhGia(ref.watch(apiClientProvider), id, 0, co: 3));

/// Ngày gần nhất Reader còn khung trống cho một thời lượng; null = trong
/// khoảng máy chủ dò không còn ngày nào.
///
/// Cần vì khung đã qua giờ bị loại: xem vào buổi tối thì hôm nay luôn trống
/// trơn, mà màn hình mặc định chọn hôm nay nên Reader trông như không nhận
/// khách.
final ngayTrongGanNhatProvider =
    FutureProvider.family<DateTime?, ({String id, int phut})>((ref, q) async {
  try {
    final d = await ref.read(apiClientProvider).get<dynamic>(
        Endpoints.readerNextAvailable(q.id),
        query: {'duration': q.phut});
    return d is String ? DateTime.tryParse(d) : null;
  } catch (_) {
    // Chỉ là gợi ý; hỏng thì ẩn, đừng làm hỏng màn đặt lịch.
    return null;
  }
});

/// Hàng sao.
class HangSao extends StatelessWidget {
  const HangSao({super.key, required this.diem, this.co = 14});
  final int diem;
  final double co;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(i <= diem ? Icons.star : Icons.star_border,
                size: co, color: Mau.vang),
        ],
      );
}

class TheDanhGia extends StatelessWidget {
  const TheDanhGia({super.key, required this.d});
  final DanhGia d;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Mau.the,
            backgroundImage: d.anh != null ? NetworkImage(d.anh!) : null,
            child: d.anh == null
                ? Text(d.tacGia.isEmpty ? '?' : d.tacGia.characters.first,
                    style: const TextStyle(fontSize: 13, color: Mau.vang))
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(d.tacGia,
                        style: const TextStyle(fontSize: 13)),
                  ),
                  HangSao(diem: d.diem, co: 12),
                ]),
                if (d.luc != null)
                  Text(Dinh.ngay(d.luc),
                      style: const TextStyle(fontSize: 10.5, color: Mau.chuMo)),
                if (d.nhanXet != null) ...[
                  const SizedBox(height: 4),
                  Text(d.nhanXet!,
                      style: const TextStyle(fontSize: 12.5, height: 1.5)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Khối đánh giá trong hồ sơ Reader: ba cái mới nhất + "Xem tất cả".
class KhoiDanhGia extends ConsumerWidget {
  const KhoiDanhGia({super.key, required this.readerId, required this.ten});
  final String readerId;
  final String ten;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = ref.watch(danhGiaDauProvider(readerId));
    final trang = ds.asData?.value;
    if (trang == null) return const SizedBox.shrink();
    if (trang.muc.isEmpty) {
      return const Text('Chưa có đánh giá nào.',
          style: TextStyle(fontSize: 12.5, color: Mau.chuMo));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final d in trang.muc) TheDanhGia(d: d),
        if (trang.tongSo > trang.muc.length)
          TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    DanhGiaReaderScreen(readerId: readerId, ten: ten))),
            style: TextButton.styleFrom(foregroundColor: Mau.vang),
            child: Text('Xem tất cả ${trang.tongSo} đánh giá'),
          ),
      ],
    );
  }
}

class DanhGiaReaderScreen extends ConsumerWidget {
  const DanhGiaReaderScreen({
    super.key,
    required this.readerId,
    required this.ten,
  });

  final String readerId;
  final String ten;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('Đánh giá · $ten')),
      body: DanhSachPhanTrang<DanhGia>(
        tai: (t) => taiDanhGia(ref.read(apiClientProvider), readerId, t),
        loiDuPhong: 'Không tải được đánh giá.',
        trong: const KhoiTrong(
            icon: Icons.star_border, tieuDe: 'Chưa có đánh giá nào'),
        dong: (_, d) => TheDanhGia(d: d),
      ),
    );
  }
}
