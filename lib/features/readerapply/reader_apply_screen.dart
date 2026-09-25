import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/api/trang.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/hop_thoai.dart';
import '../../widgets/trang_thai.dart';

/// Đơn xin làm Reader gần nhất của chính mình.
class DonCuaToi {
  const DonCuaToi({
    required this.trangThai,
    this.gioiThieu,
    this.soNam,
    this.chuyenMon = const [],
    this.lyDoTuChoi,
    this.luc,
  });

  final String trangThai;
  final String? gioiThieu;
  final int? soNam;
  final List<String> chuyenMon;
  final String? lyDoTuChoi;
  final DateTime? luc;

  factory DonCuaToi.fromJson(Map<String, dynamic> j) => DonCuaToi(
        trangThai: (j['status'] ?? 'PENDING') as String,
        gioiThieu: chuoi(j['bio']),
        soNam: soNguyen(j['experience']),
        chuyenMon: j['specialties'] is List
            ? (j['specialties'] as List).map((e) => '$e').toList()
            : const [],
        lyDoTuChoi: chuoi(j['rejectionReason']),
        luc: thoiDiem(j['createdAt']),
      );
}

/// Đơn gần nhất; `null` khi chưa từng nộp — không phải lỗi.
final donCuaToiProvider = FutureProvider<DonCuaToi?>((ref) async {
  final d = await ref
      .watch(apiClientProvider)
      .get<dynamic>(Endpoints.myReaderApplication);
  return d is Map<String, dynamic> ? DonCuaToi.fromJson(d) : null;
});

/// Đăng ký làm Reader, khớp hộp "Đăng ký làm Reader" của web.
///
/// Mở ra là đọc luôn đơn gần nhất để hiện trạng thái, thay vì bắt điền lại
/// từ đầu. Đơn bị từ chối thì điền sẵn nội dung cũ — bắt gõ lại chỉ làm
/// người ta bỏ cuộc.
class ReaderApplyScreen extends ConsumerWidget {
  const ReaderApplyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final don = ref.watch(donCuaToiProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký làm Reader')),
      body: don.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Mau.vang)),
        error: (e, _) => KhoiLoi(
          thongDiep: e is ApiException
              ? e.message
              : 'Không kiểm tra được đơn của bạn.',
          thuLai: () => ref.invalidate(donCuaToiProvider),
        ),
        data: (d) => switch (d?.trangThai) {
          'PENDING' => _Hop(
              icon: Icons.schedule,
              mau: Mau.vang,
              tieuDe: 'Đơn đang chờ duyệt',
              noiDung: 'Bạn đã gửi đơn ngày ${Dinh.ngay(d!.luc)}. Quản trị '
                  'viên sẽ xem và phản hồi qua thông báo.',
              phu: d.gioiThieu,
            ),
          'APPROVED' => const _Hop(
              icon: Icons.check_circle_outline,
              mau: MauTrangThai.tot,
              tieuDe: 'Đơn đã được duyệt',
              noiDung: 'Bạn đã là Reader. Vào Bàn làm việc để đặt bảng giá và '
                  'khai khung giờ rảnh — chưa có hai thứ đó thì khách không '
                  'đặt lịch được.',
            ),
          _ => _FormDon(tuChoi: d?.trangThai == 'REJECTED' ? d : null),
        },
      ),
    );
  }
}

class _Hop extends StatelessWidget {
  const _Hop({
    required this.icon,
    required this.mau,
    required this.tieuDe,
    required this.noiDung,
    this.phu,
  });

  final IconData icon;
  final Color mau;
  final String tieuDe;
  final String noiDung;
  final String? phu;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 30, 22, 28),
      children: [
        Icon(icon, size: 44, color: mau),
        const SizedBox(height: 14),
        Text(tieuDe,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19)),
        const SizedBox(height: 10),
        Text(noiDung,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, height: 1.6)),
        if (phu != null) ...[
          const SizedBox(height: 16),
          Text(phu!,
              style: const TextStyle(
                  fontSize: 12.5, color: Mau.chuMo, height: 1.6)),
        ],
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
      ],
    );
  }
}

class _FormDon extends ConsumerStatefulWidget {
  const _FormDon({this.tuChoi});
  final DonCuaToi? tuChoi;

  @override
  ConsumerState<_FormDon> createState() => _FormDonState();
}

class _FormDonState extends ConsumerState<_FormDon> {
  late final _gioiThieu =
      TextEditingController(text: widget.tuChoi?.gioiThieu);
  late final _chuyenMon =
      TextEditingController(text: widget.tuChoi?.chuyenMon.join(', '));
  late final _soNam = TextEditingController(
      text: widget.tuChoi?.soNam == null ? '' : '${widget.tuChoi!.soNam}');
  bool _dangGui = false;
  String? _loi;

  @override
  void dispose() {
    _gioiThieu.dispose();
    _chuyenMon.dispose();
    _soNam.dispose();
    super.dispose();
  }

  Future<void> _gui() async {
    setState(() {
      _dangGui = true;
      _loi = null;
    });
    try {
      final kq = await ref.read(apiClientProvider).post<dynamic>(
        Endpoints.readerApply,
        body: {
          'bio': _gioiThieu.text.trim(),
          'experience': int.tryParse(_soNam.text.trim()) ?? 0,
          // "Tarot, Chiêm tinh" → ["Tarot", "Chiêm tinh"]; backend nhận mảng.
          'specialties': _chuyenMon.text
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList(),
        },
      );
      if (!mounted) return;
      // Backend trả "APPROVED_IMMEDIATELY" cho nhân viên (có hồ sơ ngay) và
      // "SUBMITTED" cho người ngoài. Báo chung "đã gửi đơn" sẽ khiến nhân
      // viên ngồi đợi một lần duyệt không bao giờ tới.
      baoTin(
        context,
        kq == 'APPROVED_IMMEDIATELY'
            ? 'Đã tạo hồ sơ Reader. Khai báo khung giờ rảnh để khách đặt được.'
            : 'Đã gửi đơn đăng ký Reader.',
      );
      ref.invalidate(donCuaToiProvider);
      await ref.read(authControllerProvider.notifier).lamMoiToi();
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      // Không báo thành công khi hỏng — đó chính là lỗi cũ của form bên web.
      setState(() => _loi = e.message);
    } catch (_) {
      setState(() => _loi = 'Không gửi được đơn. Thử lại sau.');
    } finally {
      if (mounted) setState(() => _dangGui = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = widget.tuChoi;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
      children: [
        const Text(
          'Chia sẻ trí tuệ — kết nối với những người đang tìm kiếm ánh sáng.',
          style: TextStyle(fontSize: 13, color: Mau.chuMo),
        ),
        if (tc != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0x22E5645E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x55E5645E)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Đơn trước chưa được duyệt',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(tc.lyDoTuChoi ?? 'Không có lý do cụ thể.',
                    style: const TextStyle(fontSize: 12.5)),
                const SizedBox(height: 4),
                const Text(
                    'Bạn có thể chỉnh lại nội dung bên dưới và gửi lại.',
                    style: TextStyle(fontSize: 12, color: Mau.chuMo)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('o-gioi-thieu'),
          controller: _gioiThieu,
          minLines: 5,
          maxLines: 10,
          maxLength: 2000,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Giới thiệu bản thân: bạn đọc bài theo hướng nào, đã '
                'đồng hành với ai, vì sao muốn nhận khách ở đây…',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _chuyenMon,
          decoration: const InputDecoration(
            hintText: 'Thế mạnh, cách nhau bằng dấu phẩy (Tarot, Chiêm tinh…)',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _soNam,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Số năm kinh nghiệm'),
        ),
        if (_loi != null) ...[
          const SizedBox(height: 12),
          Text(_loi!,
              style: const TextStyle(fontSize: 13, color: MauTrangThai.xau)),
        ],
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _dangGui || _gioiThieu.text.trim().isEmpty ? null : _gui,
          child: Text(_dangGui ? 'Đang gửi…' : 'Gửi đơn đăng ký'),
        ),
      ],
    );
  }
}
