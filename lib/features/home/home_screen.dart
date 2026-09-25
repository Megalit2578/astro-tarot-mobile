import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../bookings/booking.dart';
import '../bookings/bookings_repository.dart';
import '../bookings/chat_screen.dart';
import '../notifications/notifications_screen.dart';
import '../astrology/astrology_screen.dart';
import '../blog/blog_screen.dart';
import '../shop/shop_screen.dart';
import '../tarot/tarot_history_screen.dart';
import '../tarot/tarot_screen.dart';
import '../readerapply/reader_apply_screen.dart';
import 'daily_card.dart';
import 'home_repository.dart';

/// Trang chủ.
///
/// Nguyên tắc: **mỗi khối tự ẩn khi không có dữ liệu.** Tài khoản mới mở app
/// ra mà thấy bốn ô rỗng thì tưởng app hỏng. Thà ngắn mà thật.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = ref.watch(authControllerProvider).user;
    final bookings = ref.watch(myBookingsProvider);
    final readings = ref.watch(lichSuTraiBaiProvider);
    final banDoSao = ref.watch(banDoSaoProvider);

    // Danh sách MỚI, sửa được: bản đầu lùi về `const []` khi lịch hẹn chưa
    // tải xong rồi gọi sort() trên nó — ném "Cannot modify an unmodifiable
    // list", và nếu API lịch hẹn lỗi thì cả trang chủ thành ô xám mãi.
    final sapToi = <Booking>[
      ...?bookings.asData?.value.where(_sapToi),
    ]..sort((a, b) => a.batDau.compareTo(b.batDau));

    return Scaffold(
      appBar: AppBar(
        title: const Text('ASTROTAROT',
            style: TextStyle(letterSpacing: 3, fontSize: 15)),
        actions: [
          _ChuongThongBao(
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const NotificationsScreen()),
              );
              // Người dùng có thể đã đọc vài cái; số trên chuông phải theo.
              ref.invalidate(soChuaDocProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: Mau.vang,
        backgroundColor: Mau.the,
        onRefresh: () async {
          ref.invalidate(myBookingsProvider);
          ref.invalidate(lichSuTraiBaiProvider);
          ref.invalidate(banDoSaoProvider);
          ref.invalidate(donCuaToiProvider);
          await ref.read(myBookingsProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text(
              'Chào ${tenGoi(u?.fullName)},',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'Hôm nay bạn muốn hỏi điều gì?',
              style: TextStyle(color: Mau.chuMo, fontSize: 13),
            ),

            if (u != null &&
                u.co('READER_APPLY') &&
                !u.co('READER_MANAGE_PROFILE'))
              const _TrangThaiDonReader(),

            const SizedBox(height: 18),
            // Tarot AI là một trong hai trụ cột của sản phẩm, nhưng KHÔNG đưa
            // lên thanh tab: thêm vào là sáu mục, và trên máy 360dp thì mỗi
            // mục còn khoảng sáu mươi pixel, nhãn bị cắt. Đặt ở đây hợp hơn —
            // trang chủ vừa hỏi xong "hôm nay bạn muốn hỏi điều gì".
            _TheTarot(),
            const SizedBox(height: 12),
            // Web có khối "Lối tắt" sáu ô. Trên điện thoại gom thành một hàng
            // bốn ô nhỏ — đủ để tới gian hàng, bài viết mà không phải vào tab
            // Tài khoản, và không đẩy lịch hẹn sắp tới xuống quá sâu.
            Row(
              children: [
                _LoiTat(
                  icon: Icons.history,
                  nhan: 'Lịch sử bài',
                  onTap: () => _mo(context, const TarotHistoryScreen()),
                ),
                _LoiTat(
                  icon: Icons.auto_awesome_outlined,
                  nhan: 'Bản đồ sao',
                  onTap: () => _mo(context, const AstrologyScreen()),
                ),
                _LoiTat(
                  icon: Icons.storefront_outlined,
                  nhan: 'Gian hàng',
                  onTap: () => _mo(context, const ShopScreen()),
                ),
                _LoiTat(
                  icon: Icons.article_outlined,
                  nhan: 'Bài viết',
                  onTap: () => _mo(context, const BlogScreen()),
                ),
              ],
            ),

            if (sapToi.isNotEmpty) ...[
              const SizedBox(height: 26),
              const _Nhan('Buổi sắp tới'),
              const SizedBox(height: 10),
              for (final b in sapToi.take(2)) _TheSapToi(booking: b),
            ],

            const SizedBox(height: 18),
            const RutBaiHangNgay(),

            ...switch (readings.asData?.value) {
              final ds? when ds.isNotEmpty => [
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Expanded(child: _Nhan('Lần trải bài gần đây')),
                      TextButton(
                        onPressed: () => _mo(context, const TarotHistoryScreen()),
                        style: TextButton.styleFrom(foregroundColor: Mau.vang),
                        child: const Text('Xem tất cả',
                            style: TextStyle(fontSize: 12.5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  for (final r in ds)
                    _TheTraiBai(
                      lan: r,
                      onTap: () => _mo(context, const TarotHistoryScreen()),
                    ),
                ],
              _ => const <Widget>[],
            },

            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: _Nhan('Bản đồ sao của bạn')),
                TextButton(
                  onPressed: () => _mo(context, const AstrologyScreen()),
                  style: TextButton.styleFrom(foregroundColor: Mau.vang),
                  child: const Text('Quản lý', style: TextStyle(fontSize: 12.5)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _TheBanDoSao(
              duLieu: banDoSao.asData?.value,
              khai: () => _mo(context, const AstrologyScreen()),
            ),
          ],
        ),
      ),
    );
  }

  static void _mo(BuildContext context, Widget man) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => man));

  /// Buổi "sắp tới": chưa huỷ, chưa xong, và chưa quá giờ kết thúc.
  ///
  /// Xét theo giờ KẾT THÚC chứ không phải giờ bắt đầu: buổi đang diễn ra dở
  /// vẫn là buổi cần nhìn thấy nhất, mà lọc theo giờ bắt đầu thì nó biến mất
  /// ngay lúc bắt đầu.
  static bool _sapToi(Booking b) =>
      b.trangThai != TrangThaiBuoi.cancelled &&
      b.trangThai != TrangThaiBuoi.completed &&
      b.ketThuc.toLocal().isAfter(DateTime.now());
}

/// Trạng thái đơn xin làm Reader — chỉ hiện khi có đơn đang chờ hoặc bị từ
/// chối. Chưa nộp thì im lặng: trang chủ không phải chỗ mời chào.
class _TrangThaiDonReader extends ConsumerWidget {
  const _TrangThaiDonReader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(donCuaToiProvider).asData?.value;
    if (d == null || d.trangThai == 'APPROVED') return const SizedBox.shrink();
    final cho = d.trangThai == 'PENDING';
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        child: ListTile(
          leading: Icon(cho ? Icons.schedule : Icons.info_outline,
              color: cho ? Mau.vang : const Color(0xFFE5645E)),
          title: Text(
              cho ? 'Đơn làm Reader đang chờ duyệt' : 'Đơn làm Reader chưa được duyệt',
              style: const TextStyle(fontSize: 13.5)),
          subtitle: Text(
            cho
                ? 'Bạn sẽ nhận thông báo khi có kết quả.'
                // Như web: nói luôn lý do, khỏi bấm vào mới biết.
                : '${d.lyDoTuChoi ?? 'Không có lý do cụ thể.'} Bấm để sửa và gửi lại.',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, color: Mau.chuMo),
          ),
          trailing: const Icon(Icons.chevron_right, color: Mau.chuMo),
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ReaderApplyScreen())),
        ),
      ),
    );
  }
}

/// Chuông kèm số chưa đọc.
///
/// Số lấy từ endpoint riêng chứ không đếm từ danh sách: danh sách chỉ tải 50
/// cái mới nhất, đếm trong đó sẽ ra con số sai khi người dùng bỏ quên lâu.
class _ChuongThongBao extends ConsumerWidget {
  const _ChuongThongBao({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final so = ref.watch(soChuaDocProvider).asData?.value ?? 0;
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          onPressed: onTap,
          tooltip: 'Thông báo',
          icon: const Icon(Icons.notifications_none, size: 22),
        ),
        if (so > 0)
          Positioned(
            top: 9,
            right: 8,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
              constraints: const BoxConstraints(minWidth: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFE5645E),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                // Quá 99 thì hiện "99+": ô tròn nhỏ không chứa nổi ba chữ số
                // mà con số chính xác lúc đó cũng chẳng còn ý nghĩa gì.
                so > 99 ? '99+' : '$so',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 9.5,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}

class _TheTarot extends StatelessWidget {
  const _TheTarot();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const TarotScreen())),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Mau.vang.withValues(alpha: 0.16),
              Mau.vang.withValues(alpha: 0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Mau.vang.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Mau.vang, size: 26),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Trải bài Tarot ngay',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  SizedBox(height: 3),
                  Text('Đặt một câu hỏi, AI rút bài và giải nghĩa',
                      style: TextStyle(fontSize: 12, color: Mau.chuMo)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Mau.vang, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Tên để chào. Tên người Việt đặt tên gọi ở CUỐI ("Hoàng Văn An" → "An");
/// lấy chữ đầu thì thành chào bằng họ.
String tenGoi(String? hoTen) {
  final t = (hoTen ?? '').trim();
  if (t.isEmpty) return 'bạn';
  return t.split(RegExp(r'\s+')).last;
}

/// "1998-04-10" → "10/04/1998". Chuỗi lạ thì để nguyên.
String? ngayIso(Object? v) {
  if (v == null) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(v.toString());
  return m == null ? v.toString() : '${m[3]}/${m[2]}/${m[1]}';
}

/// "12:00:00" → "12:00".
String? gioNgan(Object? v) {
  if (v == null) return null;
  final m = RegExp(r'^(\d{1,2}:\d{2})').firstMatch(v.toString());
  return m == null ? v.toString() : m[1];
}

class _LoiTat extends StatelessWidget {
  const _LoiTat({required this.icon, required this.nhan, required this.onTap});
  final IconData icon;
  final String nhan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Mau.the,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Mau.vien),
                ),
                child: Icon(icon, size: 20, color: Mau.vang),
              ),
              const SizedBox(height: 6),
              Text(
                nhan,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Mau.chu),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Nhan extends StatelessWidget {
  const _Nhan(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontSize: 12, color: Mau.chuMo, letterSpacing: 0.4),
      );
}

class _TheSapToi extends StatelessWidget {
  const _TheSapToi({required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    b.readerName.isEmpty ? 'Reader' : b.readerName,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  nhanTrangThai(b.trangThai),
                  style: const TextStyle(fontSize: 11, color: Mau.chuMo),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              '${Dinh.ngayGio(b.batDau)} · ${b.phut} phút · ${Dinh.tien(b.tongTien)}',
              style: const TextStyle(color: Mau.chuMo, fontSize: 12.5),
            ),
            if (b.chuaTra) ...[
              const SizedBox(height: 6),
              const Text('Chưa thanh toán — vào tab Lịch hẹn để trả',
                  style:
                      TextStyle(fontSize: 11.5, color: Color(0xFFE0B341))),
            ],
            if (b.chatMo) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ChatScreen(booking: b)),
                ),
                icon: const Icon(Icons.chat_bubble_outline, size: 15),
                label: const Text('Nhắn tin'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  foregroundColor: Mau.vang,
                  side: const BorderSide(color: Mau.vien),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TheTraiBai extends StatelessWidget {
  const _TheTraiBai({required this.lan, required this.onTap});
  final LanTraiBai lan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.style_outlined, size: 18, color: Mau.vang),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lan.cauHoi,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                  if (lan.luc != null) ...[
                    const SizedBox(height: 3),
                    Text(Dinh.ngay(lan.luc),
                        style: const TextStyle(
                            fontSize: 11, color: Mau.chuMo)),
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

class _TheBanDoSao extends StatelessWidget {
  const _TheBanDoSao({required this.duLieu, required this.khai});
  final Map<String, dynamic>? duLieu;
  final VoidCallback khai;

  @override
  Widget build(BuildContext context) {
    final d = duLieu;
    if (d == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bạn chưa khai ngày giờ nơi sinh',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              const Text(
                'Khai rồi thì lời giải Tarot và tử vi bám vào bản đồ sao của '
                'chính bạn, thay vì trả lời chung chung.',
                style:
                    TextStyle(color: Mau.chuMo, fontSize: 12.5, height: 1.6),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: khai,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Mau.vang,
                  side: const BorderSide(color: Mau.vien),
                ),
                child: const Text('Khai ngày giờ nơi sinh'),
              ),
            ],
          ),
        ),
      );
    }

    final ngaySinh = ngayIso(d['birthDate'] ?? d['birth_date']);
    final gioSinh = gioNgan(d['birthTime'] ?? d['birth_time']);
    final noiSinh = d['birthPlace'] ?? d['birth_place'] ?? d['placeName'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (ngaySinh != null)
              _Dong(nhan: 'Ngày sinh', giaTri: ngaySinh.toString()),
            if (gioSinh != null)
              _Dong(nhan: 'Giờ sinh', giaTri: gioSinh.toString()),
            if (noiSinh != null)
              _Dong(nhan: 'Nơi sinh', giaTri: noiSinh.toString()),
          ],
        ),
      ),
    );
  }
}

class _Dong extends StatelessWidget {
  const _Dong({required this.nhan, required this.giaTri});
  final String nhan;
  final String giaTri;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(nhan,
                style: const TextStyle(fontSize: 12, color: Mau.chuMo)),
          ),
          Expanded(
            child: Text(giaTri, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
