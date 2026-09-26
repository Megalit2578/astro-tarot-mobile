import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/hop_thoai.dart';
import '../../core/api/trang.dart';
import '../../widgets/danh_sach_phan_trang.dart';
import '../../widgets/trang_thai.dart';
import '../bookings/bookings_screen.dart';
import '../readerapply/reader_apply_screen.dart';
import '../staff/staff_screen.dart';
import '../support/support_screen.dart';

/// Màn cần mở khi bấm một thông báo — cùng luật với `notificationLink` của
/// web. Trả null khi không có đích rõ ràng: bấm vào chỉ đánh dấu đã đọc, tốt
/// hơn là đẩy người dùng tới một màn chẳng liên quan.
///
/// Một buổi xem có hai người và HAI danh sách khác nhau: màn Lịch hẹn của
/// khách, và tab Lịch hẹn ở Bàn làm việc của Reader. Loại thông báo KHÔNG đủ
/// để chọn giữa hai cái đó — BOOKING_CANCELLED gửi cho bên kia (khách huỷ thì
/// Reader nhận, Reader huỷ thì khách nhận), còn PAYMENT_CONFIRMED gửi cho cả
/// hai — nên phía lấy từ metadata do người gửi ghi ra.
///
/// Trước khi có khoá ấy, mọi BOOKING_* đều mở màn phía khách. Reader nhận
/// "Có lịch hẹn mới" — loại thông báo CHỈ Reader mới nhận được — rồi bấm vào
/// và thấy một danh sách trống. Trống một cách hoàn toàn đúng đắn, vì chính
/// họ không đặt gì cả; nhưng đọc lên thì giống hệt "lịch hẹn không tới nơi".
Widget? manChoThongBao(ThongBao tb) {
  final loai = tb.loai;
  if (loai == null) return null;

  if (tb.phia == 'reader') return const StaffScreen(tabDau: 'bookings');
  if (tb.phia == 'customer') return const BookingsScreen();

  // Tin CŨ, chưa có khoá "side". Suy theo loại, và chấp nhận đoán sai ở hai
  // loại đi được cả hai chiều — chỗ nào chắc chắn thì vẫn phải đi đúng.
  if (loai == 'BOOKING_CREATED' || loai == 'REVIEW_RECEIVED') {
    return const StaffScreen(tabDau: 'bookings');
  }
  if (loai == 'SUPPORT_MESSAGE') return const StaffScreen(tabDau: 'support');
  // Lệnh rút tiền chỉ Reader mới có, và nó nằm ở tab Thu nhập — màn lịch hẹn
  // phía khách không liên quan gì tới tiền của Reader.
  if (loai.startsWith('PAYOUT_')) {
    return const StaffScreen(tabDau: 'earnings');
  }
  if (loai.startsWith('BOOKING_') || loai.startsWith('PAYMENT_')) {
    return const BookingsScreen();
  }
  if (loai.startsWith('READER_APPLICATION_')) return const ReaderApplyScreen();
  if (loai == 'SUPPORT_REPLY') return const SupportScreen();
  return null;
}

/// Đọc khoá `side` trong metadata thô của backend.
///
/// Metadata là một chuỗi JSON nằm trong một cột chuỗi. Một chuỗi hỏng ở MỘT
/// dòng không được phép làm sập cả hộp thông báo, nên hỏng thì trả null và để
/// [manChoThongBao] suy theo loại.
String? _phiaCua(Object? metadata) {
  if (metadata is! String || metadata.isEmpty) return null;
  try {
    final d = jsonDecode(metadata);
    if (d is! Map) return null;
    final s = d['side'];
    return s == 'reader' || s == 'customer' ? s as String : null;
  } catch (_) {
    return null;
  }
}

/// Các thao tác trên hộp thông báo.
///
/// Đánh dấu đã đọc và ghim là **PATCH**, không phải POST. Bản đầu dùng POST:
/// máy chủ từ chối, lỗi bị nuốt, nên chấm đỏ không bao giờ tắt và nút "Đọc
/// hết" chỉ hiện một câu lỗi khó hiểu.
class NotificationsRepository {
  NotificationsRepository(this._api);
  final ApiClient _api;

  Future<void> daDoc(String id) =>
      _api.patch('${Endpoints.notifications}/$id/read');

  Future<void> docHet() => _api.patch('${Endpoints.notifications}/read-all');

  Future<void> ghim(String id, bool ghim) => _api.patch(
      '${Endpoints.notifications}/$id/pin',
      body: {'pinned': ghim});

  /// Xoá mọi thông báo đã đọc, trừ tin đã ghim. Trả số tin đã xoá.
  Future<int> xoaDaDoc() async {
    final d = await _api.delete<dynamic>('${Endpoints.notifications}/read');
    return d is Map ? (d['deleted'] as num?)?.toInt() ?? 0 : 0;
  }

  /// Xoá một thông báo. Tin ghim bị máy chủ bỏ qua.
  Future<void> xoa(String id) => _api.dio
      .delete<dynamic>(Endpoints.notifications, data: {'ids': [id]});
}

final notificationsRepositoryProvider =
    Provider((ref) => NotificationsRepository(ref.watch(apiClientProvider)));

class ThongBao {
  const ThongBao({
    required this.id,
    required this.tieuDe,
    required this.noiDung,
    required this.daDoc,
    required this.ghim,
    this.loai,
    this.luc,
    this.phia,
  });

  final String id;
  final String tieuDe;
  final String noiDung;
  final bool daDoc;
  final bool ghim;

  /// Xem NotificationTypes bên backend. Quyết định màn mở ra khi bấm.
  final String? loai;
  final DateTime? luc;

  /// Phía của buổi xem mà tin này nói tới: 'reader' hoặc 'customer'.
  ///
  /// Null với tin cũ tạo ra trước khi backend ghi khoá này, và với metadata
  /// không đọc được. Xem [manChoThongBao].
  final String? phia;

  factory ThongBao.fromJson(Map<String, dynamic> j) => ThongBao(
        id: (j['id'] ?? '').toString(),
        tieuDe: (j['title'] ?? '') as String,
        noiDung: (j['message'] ?? '') as String,
        daDoc: j['read'] == true,
        ghim: j['pinned'] == true,
        loai: j['type'] as String?,
        luc: DateTime.tryParse((j['createdAt'] ?? '').toString()),
        phia: _phiaCua(j['metadata']),
      );
}

/// Nhịp báo "có thông báo mới, tải lại đi".
///
/// Danh sách thông báo phân trang nên nó không còn là một provider để nơi
/// khác invalidate. Nhưng KHUNG app vẫn phải thúc được nó: kênh sự kiện
/// realtime chạy ở khung chứ không ở màn này, vì chấm đỏ trên chuông phải cập
/// nhật kể cả khi người dùng đang ở tab khác.
///
/// Một số đếm tăng dần là cách nhẹ nhất: màn thông báo `ref.listen` nó và tải
/// lại mỗi lần đổi, còn khung chỉ việc gọi [ThucThongBao.thuc].
class ThucThongBao extends Notifier<int> {
  @override
  int build() => 0;

  void thuc() => state = state + 1;
}

final thucThongBaoProvider =
    NotifierProvider<ThucThongBao, int>(ThucThongBao.new);

/// Tải MỘT trang thông báo.
///
/// Không sắp xếp lại ở máy khách. Backend sắp sẵn bằng chính tên truy vấn
/// (`findByUserIdOrderByPinnedDescCreatedAtDesc`) và controller truyền
/// `PageRequest.of(page, size)` không kèm Sort riêng, nên thứ tự ghim-trước
/// là bảo đảm.
///
/// Sắp lại ở đây KHÔNG phải thừa một cách vô hại — nó sai khi có nhiều trang:
/// một tin ghim nằm ở trang hai sẽ bị xếp xuống dưới những tin thường của
/// trang một, tức là đúng thứ "ghim lên đầu" hứa hẹn thì không xảy ra.
Future<Trang<ThongBao>> _taiTrangThongBao(WidgetRef ref, int trang) async {
  final api = ref.read(apiClientProvider);
  final d = await api.get<dynamic>(
    Endpoints.notifications,
    query: {'page': trang, 'size': 30},
  );
  return Trang.tu(d, ThongBao.fromJson);
}

final soChuaDocProvider = FutureProvider<int>((ref) async {
  try {
    final api = ref.watch(apiClientProvider);
    final d = await api.get<dynamic>('${Endpoints.notifications}/unread-count');
    if (d is Map) {
      final v = d['count'] ?? d['unread'] ?? d['value'];
      if (v is num) return v.toInt();
    }
    if (d is num) return d.toInt();
    return 0;
  } catch (_) {
    // Con số này chỉ là chấm đỏ trên biểu tượng. Hỏng thì coi như không có,
    // đừng để nó làm hỏng màn hình chứa nó.
    return 0;
  }
});

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  /// Chạy một thao tác rồi tải lại danh sách và chấm đỏ.
  ///
  /// [taiLai] đến từ [DieuKhienDanhSach] của màn: danh sách có phân trang nên
  /// không còn provider nào để invalidate, và không gọi lại thì thẻ vừa ghim
  /// vẫn nằm nguyên chỗ cũ.
  static Future<void> _chay(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() viec,
    Future<void> Function() taiLai,
  ) async {
    try {
      await viec();
    } catch (e) {
      if (context.mounted) baoLoi(context, e, 'Thao tác không thành công.');
    }
    await taiLai();
    ref.invalidate(soChuaDocProvider);
  }

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _dieuKhien = DieuKhienDanhSach();

  @override
  Widget build(BuildContext context) {
    // Có thông báo mới đẩy về trong lúc màn này đang mở thì tải lại ngay.
    ref.listen(thucThongBaoProvider, (_, _) => _dieuKhien.taiLai());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          TextButton(
            onPressed: () => NotificationsScreen._chay(
              context,
              ref,
              () => ref.read(notificationsRepositoryProvider).docHet(),
              _dieuKhien.taiLai,
            ),
            style: TextButton.styleFrom(foregroundColor: Mau.chuMo),
            child: const Text('Đọc hết', style: TextStyle(fontSize: 12.5)),
          ),
          PopupMenuButton<String>(
            tooltip: 'Thêm',
            color: Mau.the,
            onSelected: (_) => NotificationsScreen._chay(context, ref, () async {
              final n =
                  await ref.read(notificationsRepositoryProvider).xoaDaDoc();
              if (context.mounted) baoTin(context, 'Đã xoá $n thông báo.');
            }, _dieuKhien.taiLai),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'xoa-da-doc',
                child: Text('Xoá thông báo đã đọc (trừ tin ghim)'),
              ),
            ],
          ),
        ],
      ),
      body: DanhSachPhanTrang<ThongBao>(
        dieuKhien: _dieuKhien,
        tai: (t) => _taiTrangThongBao(ref, t),
        loiDuPhong: 'Không tải được thông báo.',
        trong: const KhoiTrong(
          icon: Icons.notifications_none,
          tieuDe: 'Chưa có thông báo nào',
          moTa: 'Khi có người nhận lịch, nhắn tin hay thanh toán, '
              'bạn sẽ thấy ở đây.',
        ),
        dong: (_, tb) => _The(tb: tb, taiLai: _dieuKhien.taiLai),
      ),
    );
  }
}

class _The extends ConsumerWidget {
  const _The({required this.tb, required this.taiLai});
  final ThongBao tb;

  /// Tải lại danh sách sau khi ghim / xoá / đánh dấu đã đọc.
  final Future<void> Function() taiLai;

  /// Giữ ngón tay trên một thông báo: ghim / bỏ ghim / xoá.
  Future<void> _menu(BuildContext context, WidgetRef ref) async {
    final chon = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Mau.the,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(tb.ghim ? Icons.push_pin_outlined : Icons.push_pin),
              title: Text(tb.ghim ? 'Bỏ ghim' : 'Ghim lên đầu'),
              onTap: () => Navigator.of(ctx).pop('ghim'),
            ),
            if (!tb.ghim)
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: Color(0xFFE5645E)),
                title: const Text('Xoá thông báo'),
                onTap: () => Navigator.of(ctx).pop('xoa'),
              ),
          ],
        ),
      ),
    );
    if (chon == null || !context.mounted) return;
    final repo = ref.read(notificationsRepositoryProvider);
    await NotificationsScreen._chay(
      context,
      ref,
      () => chon == 'ghim' ? repo.ghim(tb.id, !tb.ghim) : repo.xoa(tb.id),
      taiLai,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final repo = ref.read(notificationsRepositoryProvider);
          if (!tb.daDoc) {
            try {
              await repo.daDoc(tb.id);
            } catch (_) {
              // Đánh dấu đã đọc hỏng không được chặn việc mở màn đích.
            }
            await taiLai();
            ref.invalidate(soChuaDocProvider);
          }
          final man = manChoThongBao(tb);
          if (man != null && context.mounted) {
            await Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => man));
          }
        },
        onLongPress: () => _menu(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Chấm chưa đọc. Dùng chấm thay vì in đậm cả khối: danh sách
              // toàn chữ đậm thì mắt không còn phân biệt được gì nữa.
              Container(
                margin: const EdgeInsets.only(top: 5, right: 11),
                height: 7,
                width: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tb.daDoc ? Colors.transparent : Mau.vang,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (tb.ghim)
                          const Padding(
                            padding: EdgeInsets.only(right: 5),
                            child: Icon(Icons.push_pin,
                                size: 12, color: Mau.vang),
                          ),
                        Expanded(
                          child: Text(
                            tb.tieuDe,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: tb.daDoc
                                  ? FontWeight.w400
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (tb.noiDung.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(tb.noiDung,
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: Mau.chuMo,
                              height: 1.5)),
                    ],
                    if (tb.luc != null) ...[
                      const SizedBox(height: 5),
                      Text(Dinh.ngayGio(tb.luc),
                          style: const TextStyle(
                              fontSize: 10.5, color: Mau.chuMo)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
