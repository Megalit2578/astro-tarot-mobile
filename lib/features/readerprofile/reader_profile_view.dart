import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../theme.dart';
import 'ngay_nghi_view.dart';
import '../../widgets/trang_thai.dart';
import '../readerapply/reader_apply_screen.dart';
import '../readers/readers_repository.dart';
import 'reader_profile_repository.dart';

/// Hồ sơ Reader của chính mình — một mục trong Bàn làm việc.
///
/// Đây là màn quyết định Reader có kiếm được tiền hay không: thiếu giá hoặc
/// thiếu khung rảnh thì họ **không hề xuất hiện** trong danh sách công khai,
/// và backend không báo cho họ biết điều đó. Màn này nói thẳng ra.
class ReaderProfileView extends ConsumerWidget {
  const ReaderProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hs = ref.watch(hoSoReaderProvider);

    // Material trong suốt: màn này đầy ô nhập và nút, mà nó nhúng trong Bàn
    // làm việc nên không tự dựng Scaffold. Dựa vào Scaffold của cha là một
    // ràng buộc ngầm — nó vỡ ngay lúc ai đó nhúng màn này ở chỗ khác.
    return Material(
      type: MaterialType.transparency,
      child: RefreshIndicator(
        color: Mau.vang,
        backgroundColor: Mau.the,
        onRefresh: () async {
          ref.invalidate(hoSoReaderProvider);
          ref.invalidate(khungRanhProvider);
          ref.invalidate(ngayNghiProvider);
          await ref.read(hoSoReaderProvider.future);
        },
        child: hs.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: Mau.vang)),
          error: (e, _) => KhoiLoi(
            thongDiep: e is ApiException
                ? e.message
                : 'Không tải được hồ sơ Reader.',
            thuLai: () => ref.invalidate(hoSoReaderProvider),
          ),
          data: (h) => h == null
              ? KhoiTrong(
                  icon: Icons.badge_outlined,
                  tieuDe: 'Bạn chưa có hồ sơ Reader',
                  moTa:
                      'Nộp đơn để bắt đầu nhận lịch. Nhân viên được duyệt '
                      'ngay, không phải xếp hàng chờ.',
                  // Trước đây chỗ này chỉ nói "màn nộp đơn chưa dựng trong app"
                  // và đẩy người dùng sang website — trong khi màn nộp đơn ĐÃ
                  // có sẵn, chỉ là không ai nối vào đây. Một ngõ cụt: nhân viên
                  // mở Hồ sơ Reader, đọc một câu nhờ vả, rồi không có nút nào
                  // để bấm.
                  hanhDong: FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ReaderApplyScreen(),
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 46),
                    ),
                    child: const Text('Nộp đơn làm Reader'),
                  ),
                )
              : _Noi(h: h),
        ),
      ),
    );
  }
}

class _Noi extends ConsumerStatefulWidget {
  const _Noi({required this.h});
  final HoSoReader h;

  @override
  ConsumerState<_Noi> createState() => _NoiState();
}

class _NoiState extends ConsumerState<_Noi> {
  late final TextEditingController _gioiThieu;
  late final TextEditingController _soNam;
  late final TextEditingController _g15;
  late final TextEditingController _g30;
  late final TextEditingController _g60;
  late final TextEditingController _chuyenMon;
  bool _dangLuu = false;

  @override
  void initState() {
    super.initState();
    final h = widget.h;
    _gioiThieu = TextEditingController(text: h.gioiThieu ?? '');
    _soNam = TextEditingController(text: h.soNam?.toString() ?? '');
    _g15 = TextEditingController(text: h.gia15?.toString() ?? '');
    _g30 = TextEditingController(text: h.gia30?.toString() ?? '');
    _g60 = TextEditingController(text: h.gia60?.toString() ?? '');
    _chuyenMon = TextEditingController(text: h.chuyenMon.join(', '));
  }

  @override
  void dispose() {
    _gioiThieu.dispose();
    _soNam.dispose();
    _g15.dispose();
    _g30.dispose();
    _g60.dispose();
    _chuyenMon.dispose();
    super.dispose();
  }

  int? _so(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  Future<void> _luu() async {
    FocusScope.of(context).unfocus();
    setState(() => _dangLuu = true);
    try {
      await ref
          .read(readerProfileRepositoryProvider)
          .luu(
            gioiThieu: _gioiThieu.text.trim(),
            soNam: _so(_soNam),
            gia15: _so(_g15),
            gia30: _so(_g30),
            gia60: _so(_g60),
            chuyenMon: _chuyenMon.text
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList(),
          );
      ref.invalidate(hoSoReaderProvider);
      // Danh sách Reader công khai có thể vừa đổi (thêm/bớt chính mình).
      ref.invalidate(readersProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã lưu hồ sơ Reader'),
          backgroundColor: Mau.the,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Mau.the),
      );
    } finally {
      if (mounted) setState(() => _dangLuu = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.h;
    final ranh = ref.watch(khungRanhProvider);
    final coKhung = (ranh.asData?.value ?? const []).isNotEmpty;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        _KhoiTinhTrang(h: h, coKhung: coKhung),

        const SizedBox(height: 10),
        const _Nhan('Giới thiệu'),
        const SizedBox(height: 6),
        TextField(
          controller: _gioiThieu,
          minLines: 4,
          maxLines: 8,
          maxLength: 2000,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Bạn xem theo hướng nào, hợp với ai, phong cách ra sao.',
            counterText: '',
          ),
        ),

        const SizedBox(height: 14),
        const _Nhan('Thế mạnh'),
        const SizedBox(height: 6),
        TextField(
          controller: _chuyenMon,
          decoration: const InputDecoration(
            hintText: 'Tarot, Chiêm tinh, Thần số học',
          ),
        ),

        const SizedBox(height: 14),
        const _Nhan('Số năm kinh nghiệm'),
        const SizedBox(height: 6),
        TextField(
          controller: _soNam,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Ví dụ: 3'),
        ),

        const SizedBox(height: 20),
        const _Nhan('Giá theo thời lượng (đồng)'),
        const SizedBox(height: 4),
        const Text(
          'Để trống mức nào thì khách không chọn được mức đó. Phải có ít '
          'nhất một mức, nếu không hồ sơ của bạn không hiện ra.',
          style: TextStyle(fontSize: 11.5, color: Mau.chuMo, height: 1.6),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _OGia(nhan: '15 phút', c: _g15),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _OGia(nhan: '30 phút', c: _g30),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _OGia(nhan: '60 phút', c: _g60),
            ),
          ],
        ),

        const SizedBox(height: 22),
        FilledButton(
          onPressed: _dangLuu ? null : _luu,
          child: _dangLuu
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Lưu hồ sơ'),
        ),

        const SizedBox(height: 28),
        const _Nhan('Khung giờ rảnh hằng tuần'),
        const SizedBox(height: 10),
        _KhungRanh(ranh: ranh),

        const SizedBox(height: 28),
        const _Nhan('Ngày nghỉ'),
        const SizedBox(height: 4),
        const Text(
          'Ngày bạn bận việc riêng hay đi xa. Khách không đặt được vào những '
          'ngày này, lịch đã nhận thì không bị ảnh hưởng.',
          style: TextStyle(fontSize: 11.5, color: Mau.chuMo, height: 1.6),
        ),
        const SizedBox(height: 10),
        const NgayNghiView(),
      ],
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

/// Ô giá cho một mốc thời lượng, kèm dòng nhắc bên dưới.
///
/// Dòng nhắc đổi theo nội dung đang gõ, khớp với web:
///
/// - Để trống  → "Không nhận buổi này". Một ô trống trông giống hệt một ô
///   chưa kịp điền, nên phải nói rõ rằng để trống LÀ một lựa chọn có nghĩa.
/// - Có số     → số tiền đã định dạng. Ô nhập là số trần, nên gõ thừa một số
///   0 nhìn không khác gì đúng; "600.000 đ" thì khác hẳn "60.000 đ".
class _OGia extends StatefulWidget {
  const _OGia({required this.nhan, required this.c});
  final String nhan;
  final TextEditingController c;

  @override
  State<_OGia> createState() => _OGiaState();
}

class _OGiaState extends State<_OGia> {
  @override
  void initState() {
    super.initState();
    widget.c.addListener(_doi);
  }

  @override
  void dispose() {
    widget.c.removeListener(_doi);
    super.dispose();
  }

  void _doi() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final so = int.tryParse(widget.c.text.trim());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.nhan,
          style: const TextStyle(fontSize: 11, color: Mau.chuMo),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: widget.c,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: '—', isDense: true),
        ),
        const SizedBox(height: 3),
        Text(
          so == null ? 'Không nhận buổi này' : Dinh.tien(so),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10.5,
            color: so == null ? Mau.chuMo : Mau.vang,
          ),
        ),
      ],
    );
  }
}

/// Nói thẳng hồ sơ có đang hiện ra cho khách hay không, và thiếu gì.
class _KhoiTinhTrang extends StatelessWidget {
  const _KhoiTinhTrang({required this.h, required this.coKhung});
  final HoSoReader h;
  final bool coKhung;

  @override
  Widget build(BuildContext context) {
    final ok = h.hienCongKhai && coKhung;
    final coGia = h.gia15 != null || h.gia30 != null || h.gia60 != null;
    final thieu = <String>[
      // Cờ nhận lịch do máy chủ quản, Reader không tự bật được — nói rõ để
      // họ biết phải hỏi ai thay vì đi tìm một công tắc không tồn tại.
      if (!h.nhanLich) 'quản trị viên mở lại quyền nhận lịch cho hồ sơ',
      if (!coGia) 'điền ít nhất một mức giá',
      if (!coKhung) 'thêm khung giờ rảnh',
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ok ? const Color(0x186BBF7B) : const Color(0x18E0B341),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ok ? const Color(0x556BBF7B) : const Color(0x55E0B341),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle_outline : Icons.info_outline,
            size: 19,
            color: ok ? const Color(0xFF6BBF7B) : const Color(0xFFE0B341),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ok
                  ? 'Hồ sơ của bạn đang hiện trong danh sách Reader và khách '
                        'đặt lịch được.'
                  : 'Khách CHƯA thấy hồ sơ của bạn. Cần ${thieu.join(' và ')}.',
              style: const TextStyle(fontSize: 12.5, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _KhungRanh extends ConsumerWidget {
  const _KhungRanh({required this.ranh});
  final AsyncValue<List<KhungRanh>> ranh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ranh.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Mau.vang),
          ),
        ),
      ),
      error: (e, _) => Text(
        e is ApiException ? e.message : 'Không tải được khung giờ rảnh.',
        style: const TextStyle(fontSize: 12.5, color: Mau.chuMo),
      ),
      data: (ds) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ds.isEmpty)
            const Text(
              'Chưa có khung nào. Khách chỉ đặt được trong những khung bạn '
              'khai ở đây.',
              style: TextStyle(fontSize: 12.5, color: Mau.chuMo, height: 1.6),
            )
          else
            for (final k in ds) _DongKhung(k: k),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _themKhung(context, ref),
            icon: const Icon(Icons.add, size: 17),
            label: const Text('Thêm khung giờ'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              foregroundColor: Mau.vang,
              side: const BorderSide(color: Mau.vien),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _themKhung(BuildContext context, WidgetRef ref) async {
    int thu = 1;
    TimeOfDay batDau = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay ketThuc = const TimeOfDay(hour: 17, minute: 0);

    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Mau.the,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Thêm khung giờ rảnh',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              const Text(
                'Thứ',
                style: TextStyle(fontSize: 12, color: Mau.chuMo),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 1; i <= 7; i++)
                    ChoiceChip(
                      selected: thu == i,
                      onSelected: (_) => setSheet(() => thu = i),
                      // Nhãn ngắn viết sẵn. Bản đầu cắt "Thứ " khỏi tên đầy đủ
                      // rồi thêm "T" — ra "THai", "TBa", "TSáu".
                      label: Text(_thuNgan[i]),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: thu == i ? Mau.vang : Mau.chuMo,
                      ),
                      backgroundColor: Mau.nen,
                      selectedColor: Mau.vang.withValues(alpha: 0.16),
                      side: BorderSide(color: thu == i ? Mau.vang : Mau.vien),
                      showCheckmark: false,
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _NutGio(
                      nhan: 'Bắt đầu',
                      gio: batDau,
                      onPick: (t) => setSheet(() => batDau = t),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _NutGio(
                      nhan: 'Kết thúc',
                      gio: ketThuc,
                      onPick: (t) => setSheet(() => ketThuc = t),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  // Chặn khung ngược ngay tại chỗ. Backend cũng chặn, nhưng
                  // để người dùng bấm xong mới biết là bắt họ làm lại.
                  final a = batDau.hour * 60 + batDau.minute;
                  final b = ketThuc.hour * 60 + ketThuc.minute;
                  if (b <= a) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Giờ kết thúc phải sau giờ bắt đầu.'),
                        backgroundColor: Mau.nen,
                      ),
                    );
                    return;
                  }
                  Navigator.of(ctx).pop(true);
                },
                child: const Text('Thêm'),
              ),
            ],
          ),
        ),
      ),
    );

    if (ok != true) return;
    String hms(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:00';
    try {
      await ref
          .read(readerProfileRepositoryProvider)
          .themKhung(thu: thu, batDau: hms(batDau), ketThuc: hms(ketThuc));
      ref.invalidate(khungRanhProvider);
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Mau.the),
      );
    }
  }
}

/// Nhãn ngắn của thứ, chỉ số khớp [tenThu] (1 = Thứ Hai … 7 = Chủ nhật).
const _thuNgan = ['', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

class _NutGio extends StatelessWidget {
  const _NutGio({required this.nhan, required this.gio, required this.onPick});

  final String nhan;
  final TimeOfDay gio;
  final void Function(TimeOfDay) onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(nhan, style: const TextStyle(fontSize: 11, color: Mau.chuMo)),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final t = await showTimePicker(context: context, initialTime: gio);
            if (t != null) onPick(t);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: Mau.nen,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Mau.vien),
            ),
            child: Text(
              '${gio.hour.toString().padLeft(2, '0')}:'
              '${gio.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }
}

class _DongKhung extends ConsumerWidget {
  const _DongKhung({required this.k});
  final KhungRanh k;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${tenThu[k.thu.clamp(1, 7)]} · '
              '${KhungRanh.gonGio(k.batDau)}–${KhungRanh.gonGio(k.ketThuc)}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          IconButton(
            onPressed: () async {
              try {
                await ref.read(readerProfileRepositoryProvider).xoaKhung(k.id);
                ref.invalidate(khungRanhProvider);
              } on ApiException catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.message), backgroundColor: Mau.the),
                );
              }
            },
            tooltip: 'Xoá khung này',
            icon: const Icon(Icons.close, size: 17, color: Color(0xFFE5645E)),
          ),
        ],
      ),
    );
  }
}
