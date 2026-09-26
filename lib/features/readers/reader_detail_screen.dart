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
import '../../widgets/lich_thang.dart';

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
      ref.invalidate(lichThangProvider);
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
                _LichDat(
                  readerId: reader.id,
                  phut: phutHopLe,
                  ngay: ngay,
                  chon: chon,
                  doiNgay: doiNgay,
                  doiChon: doiChon,
                ),
                _GoiYNgayTrong(
                  readerId: reader.id,
                  phut: phutHopLe,
                  ngay: ngay,
                  doiNgay: doiNgay,
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

/// Lịch tháng của một Reader và ô giờ của ngày đang chọn.
///
/// Khung đã có người đặt vẫn hiện, mờ, không bấm được. Hai người cùng mở lịch
/// này thấy cùng một Reader, nên ô vừa kín thì người kia thấy ngay lần tải sau.
class _LichDat extends ConsumerWidget {
  const _LichDat({
    required this.readerId,
    required this.phut,
    required this.ngay,
    required this.chon,
    required this.doiNgay,
    required this.doiChon,
  });

  final String readerId;
  final int phut;
  final DateTime ngay;
  final Slot? chon;
  final void Function(DateTime) doiNgay;
  final void Function(Slot) doiChon;

  bool _thangDat(DateTime t) {
    final n = DateTime.now();
    final hien = n.year * 12 + n.month;
    final xin = t.year * 12 + t.month;
    return xin >= hien && xin <= hien + 2;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = LichQuery(
      readerId: readerId,
      nam: ngay.year,
      thang: ngay.month,
      phut: phut,
    );
    final ds = ref.watch(lichThangProvider(query));
    final truoc = DateTime(ngay.year, ngay.month - 1, 1);
    final sau = DateTime(ngay.year, ngay.month + 1, 1);

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
              e is ApiException ? e.message : 'Không tải được lịch của Reader.',
              style: const TextStyle(fontSize: 12.5, color: Mau.chuMo),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => ref.invalidate(lichThangProvider(query)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Mau.vang,
                side: const BorderSide(color: Mau.vien),
              ),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
      data: (thang) {
        final hom = thang.cua(ngay);
        final loai = {
          for (final n in thang.ngay) LuoiThang.khoa(n.ngay): n.loai,
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LuoiThang(
              thang: ngay,
              chon: ngay,
              loai: loai,
              coTruoc: _thangDat(truoc),
              coSau: _thangDat(sau),
              doiNgay: doiNgay,
              doiThang: (delta) {
                final moi = DateTime(ngay.year, ngay.month + delta, 1);
                final bayGio = DateTime.now();
                final homNay = DateTime(bayGio.year, bayGio.month, bayGio.day);
                doiNgay(
                  moi.year == homNay.year && moi.month == homNay.month
                      ? homNay
                      : moi,
                );
              },
            ),
            const SizedBox(height: 8),
            const Wrap(
              spacing: 12,
              children: [
                _Chu('Còn trống', Mau.vang, false),
                _Chu('Đã kín', Mau.chuMo, false),
                _Chu('Nghỉ', Mau.chuMo, true),
              ],
            ),
            const SizedBox(height: 16),
            const _Nhan('Khung giờ'),
            const SizedBox(height: 10),
            if ((hom?.o ?? const <Slot>[])
                .where((s) => s.trang != TrangO.past)
                .isEmpty)
              Text(
                _loiNgay(hom),
                style: const TextStyle(
                  color: Mau.chuMo,
                  fontSize: 12.5,
                  height: 1.6,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in (hom?.o ?? const <Slot>[]).where(
                    (s) => s.trang != TrangO.past,
                  ))
                    _OGio(
                      slot: s,
                      chon: chon != null && chon!.batDau == s.batDau,
                      onTap: s.datDuoc ? () => doiChon(s) : null,
                    ),
                ],
              ),
          ],
        );
      },
    );
  }

  String _loiNgay(NgayLich? hom) {
    final laHomNay =
        DateTime(ngay.year, ngay.month, ngay.day) ==
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return switch (hom?.loai) {
      LoaiNgay.off => 'Reader nghỉ ngày này.',
      LoaiNgay.closed => 'Reader không làm việc ngày này.',
      LoaiNgay.full => 'Ngày này đã kín.',
      LoaiNgay.over =>
        laHomNay
            ? 'Hôm nay đã qua giờ làm việc của Reader.'
            : 'Ngày này đã qua giờ làm việc.',
      LoaiNgay.past => 'Ngày đã qua.',
      _ => 'Ngày này không còn khung trống.',
    };
  }
}

class _Chu extends StatelessWidget {
  const _Chu(this.chu, this.mau, this.vien);
  final String chu;
  final Color mau;
  final bool vien;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 6,
          width: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: vien ? Colors.transparent : mau,
            border: vien ? Border.all(color: mau) : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(chu, style: const TextStyle(fontSize: 10, color: Mau.chuMo)),
      ],
    );
  }
}

class _OGio extends StatelessWidget {
  const _OGio({required this.slot, required this.chon, required this.onTap});

  final Slot slot;
  final bool chon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mo = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        splashColor: Mau.vang.withValues(alpha: 0.2),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: chon
                ? Mau.vang.withValues(alpha: 0.18)
                : mo
                ? Mau.the
                : Mau.the.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: chon
                  ? Mau.vang
                  : mo
                  ? Mau.vien
                  : Mau.vien.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Dinh.gio(slot.batDau),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: chon ? FontWeight.w600 : FontWeight.w400,
                  color: chon
                      ? Mau.vang
                      : mo
                      ? Mau.chu
                      : Mau.chuMo,
                  decoration: mo ? null : TextDecoration.lineThrough,
                  decorationColor: Mau.chuMo,
                ),
              ),
              if (!mo)
                Text(
                  slot.trang == TrangO.taken ? 'Đã kín' : 'Đã qua',
                  style: const TextStyle(fontSize: 9, color: Mau.chuMo),
                ),
            ],
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
