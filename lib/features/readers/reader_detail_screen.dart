import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/trang_thai.dart';
import '../bookings/bookings_repository.dart';
import 'reader.dart';
import 'reader_reviews.dart';
import 'readers_repository.dart';
import 'slot.dart';

final _readerProvider = FutureProvider.family<Reader, String>((ref, id) async {
  return ref.watch(readersRepositoryProvider).chiTiet(id);
});

class ReaderDetailScreen extends ConsumerStatefulWidget {
  const ReaderDetailScreen({super.key, required this.readerId});

  final String readerId;

  @override
  ConsumerState<ReaderDetailScreen> createState() => _ReaderDetailScreenState();
}

class _ReaderDetailScreenState extends ConsumerState<ReaderDetailScreen> {
  int _phut = 30;
  late DateTime _ngay;
  Slot? _chon;
  bool _dangDat = false;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _ngay = DateTime(n.year, n.month, n.day);
  }

  @override
  Widget build(BuildContext context) {
    final r = ref.watch(_readerProvider(widget.readerId));

    return Scaffold(
      appBar: AppBar(title: Text(r.asData?.value.ten ?? 'Hồ sơ Reader')),
      body: r.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Mau.vang)),
        error: (e, _) => KhoiLoi(
          thongDiep: e is ApiException
              ? e.message
              : 'Không tải được hồ sơ Reader.',
          thuLai: () => ref.invalidate(_readerProvider(widget.readerId)),
        ),
        data: (reader) => _Noi(
          reader: reader,
          phut: _phut,
          ngay: _ngay,
          chon: _chon,
          dangDat: _dangDat,
          doiPhut: (p) => setState(() {
            _phut = p;
            // Đổi độ dài thì khung giờ cũ không còn đúng nữa — bỏ chọn, nếu
            // không người dùng đặt nhầm một khung tính theo độ dài trước đó.
            _chon = null;
          }),
          doiNgay: (n) => setState(() {
            _ngay = n;
            _chon = null;
          }),
          doiChon: (s) => setState(() => _chon = s),
          dat: _dat,
        ),
      ),
    );
  }

  Future<void> _dat() async {
    final s = _chon;
    if (s == null || _dangDat) return;
    setState(() => _dangDat = true);
    try {
      final b = await ref
          .read(bookingsRepositoryProvider)
          .dat(readerProfileId: widget.readerId, batDau: s.batDau, phut: _phut);
      // Danh sách lịch hẹn giờ đã cũ.
      ref.invalidate(myBookingsProvider);
      // Khung giờ vừa đặt không còn trống.
      ref.invalidate(slotsProvider);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Mau.the,
          title: const Text('Đã đặt lịch'),
          content: Text(
            '${Dinh.ngayGio(b.batDau)} · ${b.phut} phút\n'
            '${Dinh.tien(b.tongTien)}\n\n'
            'Buổi hẹn đang chờ Reader nhận. Vào tab Lịch hẹn để thanh toán.',
            style: const TextStyle(height: 1.6, fontSize: 13.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Đã hiểu'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Mau.the),
      );
    } finally {
      if (mounted) setState(() => _dangDat = false);
    }
  }
}

class _Noi extends ConsumerWidget {
  const _Noi({
    required this.reader,
    required this.phut,
    required this.ngay,
    required this.chon,
    required this.dangDat,
    required this.doiPhut,
    required this.doiNgay,
    required this.doiChon,
    required this.dat,
  });

  final Reader reader;
  final int phut;
  final DateTime ngay;
  final Slot? chon;
  final bool dangDat;
  final void Function(int) doiPhut;
  final void Function(DateTime) doiNgay;
  final void Function(Slot) doiChon;
  final VoidCallback dat;

  /// Những mức thời lượng Reader này thật sự có giá.
  ///
  /// Chỉ hiện mức đã khai giá: bày ra mức chưa có giá thì người dùng chọn vào
  /// rồi không có khung giờ nào, và không hiểu tại sao.
  List<({int phut, int gia})> get _mucGia => [
    if (reader.pricePer15m != null) (phut: 15, gia: reader.pricePer15m!),
    if (reader.pricePer30m != null) (phut: 30, gia: reader.pricePer30m!),
    if (reader.pricePer60m != null) (phut: 60, gia: reader.pricePer60m!),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muc = _mucGia;
    final phutHopLe = muc.any((m) => m.phut == phut)
        ? phut
        : (muc.isEmpty ? phut : muc.first.phut);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              _Dau(reader: reader),
              if (reader.bio != null && reader.bio!.trim().isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  reader.bio!,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.7,
                    color: Mau.chu,
                  ),
                ),
              ],
              if (reader.specialties.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in reader.specialties)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0x33D4AF37)),
                        ),
                        child: Text(
                          s,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Mau.vangNhat,
                          ),
                        ),
                      ),
                  ],
                ),
              ],

              if (!reader.isAvailable) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: const Color(0x22E0B341),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x55E0B341)),
                  ),
                  child: const Text(
                    'Reader này đang tạm ngưng nhận lịch.',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              const _Nhan('Thời lượng'),
              const SizedBox(height: 10),
              // Reader chưa đặt giá nào thì không có mốc nào để hiện.
              //
              // `findBookable` ở backend đã ẩn họ khỏi danh sách công khai, nhưng
              // vẫn tới được đây bằng đường dẫn trực tiếp — một liên kết được chia
              // sẻ từ trước, hoặc chính Reader đang xem lại hồ sơ của mình. Để
              // trống thì ba mục liền nhau (Thời lượng, Ngày, Khung giờ) đều rỗng và
              // trang trông như tải hỏng.
              if (muc.isEmpty)
                const Text(
                  'Reader này chưa đặt giá cho mốc nào, nên chưa nhận đặt lịch.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Mau.chuMo,
                    height: 1.5,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  children: [
                    for (final m in muc)
                      ChoiceChip(
                        selected: m.phut == phutHopLe,
                        onSelected: (_) => doiPhut(m.phut),
                        label: Text('${m.phut} phút · ${Dinh.tien(m.gia)}'),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: m.phut == phutHopLe ? Mau.vang : Mau.chuMo,
                        ),
                        backgroundColor: Mau.the,
                        selectedColor: Mau.vang.withValues(alpha: 0.16),
                        side: BorderSide(
                          color: m.phut == phutHopLe ? Mau.vang : Mau.vien,
                        ),
                        showCheckmark: false,
                      ),
                  ],
                ),

              // Không hỏi khung giờ khi chưa có mốc nào: câu hỏi "còn trống khung
              // 15 phút nào không" vô nghĩa khi Reader không nhận buổi 15 phút.
              if (muc.isNotEmpty) ...[
                const SizedBox(height: 22),
                const _Nhan('Ngày'),
                const SizedBox(height: 10),
                _ChonNgay(ngay: ngay, doiNgay: doiNgay),
                _GoiYNgayTrong(
                  readerId: reader.id,
                  phut: phutHopLe,
                  ngay: ngay,
                  doiNgay: doiNgay,
                ),

                const SizedBox(height: 22),
                const _Nhan('Khung giờ còn trống'),
                const SizedBox(height: 10),
                _Slots(
                  query: SlotQuery(
                    readerId: reader.id,
                    ngay: ngay,
                    phut: phutHopLe,
                  ),
                  chon: chon,
                  doiChon: doiChon,
                ),
              ],

              const SizedBox(height: 26),
              _Nhan('Đánh giá (${reader.totalReviews})'),
              const SizedBox(height: 10),
              KhoiDanhGia(readerId: reader.id, ten: reader.ten),
            ],
          ),
        ),
        // Khách chưa đăng nhập vẫn xem được hồ sơ và khung giờ, nhưng đặt
        // lịch thì phải có tài khoản. Nói thẳng ở đây thay vì để họ bấm rồi
        // nhận 401 — lúc đó công sức chọn giờ coi như mất.
        if (chon != null)
          ref.watch(authControllerProvider).user == null
              ? const _CanDangNhap()
              : _ThanhDat(
                  slot: chon!,
                  phut: phutHopLe,
                  dangDat: dangDat,
                  dat: dat,
                ),
      ],
    );
  }
}

/// "Ngày trống gần nhất: …" — bấm để nhảy tới ngày đó.
///
/// Chỉ hiện khi ngày đang chọn KHÁC ngày ấy; đang ở đúng ngày rồi mà vẫn mời
/// "chọn ngày này" thì thừa.
class _GoiYNgayTrong extends ConsumerWidget {
  const _GoiYNgayTrong({
    required this.readerId,
    required this.phut,
    required this.ngay,
    required this.doiNgay,
  });

  final String readerId;
  final int phut;
  final DateTime ngay;
  final void Function(DateTime) doiNgay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref
        .watch(ngayTrongGanNhatProvider((id: readerId, phut: phut)))
        .asData
        ?.value;
    if (g == null) return const SizedBox.shrink();
    final gn = DateTime(g.year, g.month, g.day);
    if (gn == ngay) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => doiNgay(gn),
        icon: const Icon(Icons.event_available, size: 16),
        label: Text('Ngày trống gần nhất: ${Dinh.ngay(gn)}'),
        style: TextButton.styleFrom(foregroundColor: Mau.vang),
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
    style: const TextStyle(fontSize: 12, color: Mau.chuMo, letterSpacing: 0.4),
  );
}

class _Dau extends StatelessWidget {
  const _Dau({required this.reader});
  final Reader reader;

  @override
  Widget build(BuildContext context) {
    final co = reader.avatar != null && reader.avatar!.isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 62,
          width: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Mau.vien),
            image: co
                ? DecorationImage(
                    image: NetworkImage(reader.avatar!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          alignment: Alignment.center,
          child: co
              ? null
              : Text(
                  reader.chuDau,
                  style: const TextStyle(fontSize: 24, color: Mau.vang),
                ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reader.ten,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                reader.yearsExperience != null
                    ? '${reader.yearsExperience} năm kinh nghiệm'
                    : 'Reader mới',
                style: const TextStyle(color: Mau.chuMo, fontSize: 12.5),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.star, size: 14, color: Mau.vang),
                  const SizedBox(width: 4),
                  Text(
                    Dinh.diem(reader.rating, reader.totalReviews),
                    style: const TextStyle(color: Mau.vang, fontSize: 12.5),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    reader.totalReviews > 0
                        ? '(${reader.totalReviews} đánh giá)'
                        : 'đánh giá',
                    style: const TextStyle(color: Mau.chuMo, fontSize: 12.5),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Dải 14 ngày tới.
///
/// Không dùng hộp chọn ngày của hệ điều hành: người dùng phải mở hộp thoại,
/// chọn, đóng, rồi mới thấy khung giờ. Dải ngang lướt được cho phép so sánh
/// nhanh vài ngày liền nhau — đúng việc họ đang làm.
class _ChonNgay extends StatelessWidget {
  const _ChonNgay({required this.ngay, required this.doiNgay});

  final DateTime ngay;
  final void Function(DateTime) doiNgay;

  static const _thu = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  @override
  Widget build(BuildContext context) {
    final homNay = DateTime.now();
    final goc = DateTime(homNay.year, homNay.month, homNay.day);
    return SizedBox(
      height: 66,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 14,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final n = goc.add(Duration(days: i));
          final chon =
              n.year == ngay.year && n.month == ngay.month && n.day == ngay.day;
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => doiNgay(n),
            child: Container(
              width: 54,
              decoration: BoxDecoration(
                color: chon ? Mau.vang.withValues(alpha: 0.16) : Mau.the,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: chon ? Mau.vang : Mau.vien),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    i == 0 ? 'Nay' : _thu[n.weekday - 1],
                    style: TextStyle(
                      fontSize: 11,
                      color: chon ? Mau.vang : Mau.chuMo,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${n.day}/${n.month}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: chon ? Mau.vang : Mau.chu,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Slots extends ConsumerWidget {
  const _Slots({
    required this.query,
    required this.chon,
    required this.doiChon,
  });

  final SlotQuery query;
  final Slot? chon;
  final void Function(Slot) doiChon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = ref.watch(slotsProvider(query));

    return ds.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 26),
        child: Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Mau.vang),
          ),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              e is ApiException
                  ? e.message
                  : 'Không tải được khung giờ của ngày này.',
              style: const TextStyle(fontSize: 12.5, color: Mau.chuMo),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => ref.invalidate(slotsProvider(query)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Mau.vang,
                side: const BorderSide(color: Mau.vien),
              ),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 22),
            child: Text(
              'Ngày này không còn khung trống. Thử chọn ngày khác hoặc đổi '
              'thời lượng.',
              style: TextStyle(color: Mau.chuMo, fontSize: 12.5, height: 1.6),
            ),
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in list)
              _OGio(
                slot: s,
                chon: chon != null && chon!.batDau == s.batDau,
                onTap: () => doiChon(s),
              ),
          ],
        );
      },
    );
  }
}

class _OGio extends StatelessWidget {
  const _OGio({required this.slot, required this.chon, required this.onTap});

  final Slot slot;
  final bool chon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      // KHÔNG đặt `alignment` cho Container này.
      //
      // Container có alignment sẽ dùng Align bên trong, mà Align không có
      // widthFactor thì nở ra BẰNG ràng buộc lớn nhất được phép. Trong Wrap
      // ràng buộc ấy là cả chiều ngang màn hình, nên mỗi ô giờ chiếm trọn một
      // hàng và lưới biến thành danh sách dọc dài dằng dặc. Bỏ alignment đi
      // thì Container tự co theo nội dung, và phần đệm đã canh giữa sẵn.
      child: Container(
        // Đệm dọc 12 thay cho height: 44 — vừa canh giữa chữ, vừa cho ô cao
        // khoảng 44 (đúng ngưỡng chạm tối thiểu) mà không cần alignment.
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: chon ? Mau.vang.withValues(alpha: 0.18) : Mau.the,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: chon ? Mau.vang : Mau.vien),
        ),
        child: Text(
          Dinh.gio(slot.batDau),
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: chon ? FontWeight.w600 : FontWeight.w400,
            color: chon ? Mau.vang : Mau.chu,
          ),
        ),
      ),
    );
  }
}

class _CanDangNhap extends StatelessWidget {
  const _CanDangNhap();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        14 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Mau.the,
        border: Border(top: BorderSide(color: Mau.vien)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Đăng nhập để đặt khung giờ này',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Quay lại đăng nhập'),
          ),
        ],
      ),
    );
  }
}

/// Thanh xác nhận dính đáy màn hình.
class _ThanhDat extends StatelessWidget {
  const _ThanhDat({
    required this.slot,
    required this.phut,
    required this.dangDat,
    required this.dat,
  });

  final Slot slot;
  final int phut;
  final bool dangDat;
  final VoidCallback dat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        14 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Mau.the,
        border: Border(top: BorderSide(color: Mau.vien)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${Dinh.ngayGio(slot.batDau)} · $phut phút',
                  style: const TextStyle(fontSize: 12.5, color: Mau.chuMo),
                ),
                const SizedBox(height: 3),
                Text(
                  Dinh.tien(slot.gia),
                  style: const TextStyle(
                    fontSize: 17,
                    color: Mau.vang,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 140,
            child: FilledButton(
              onPressed: dangDat ? null : dat,
              child: dangDat
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Đặt lịch'),
            ),
          ),
        ],
      ),
    );
  }
}
