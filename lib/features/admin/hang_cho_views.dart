import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/danh_sach_phan_trang.dart';
import '../../widgets/hop_thoai.dart';
import '../../widgets/trang_thai.dart';
import 'admin_repository.dart';

/// Ô chọn lọc trạng thái đứng đầu mỗi hàng chờ.
///
/// Mặc định lọc "đang chờ" như web: người trực mở hàng chờ là để xử lý việc
/// tồn đọng, không phải để cuộn qua hàng trăm giao dịch đã xong. Bản đầu của
/// app không lọc gì — việc cần làm chìm giữa việc đã làm.
class LocTrangThai extends StatelessWidget {
  const LocTrangThai({
    super.key,
    required this.giaTri,
    required this.nhan,
    required this.doi,
  });

  final String giaTri;
  final Map<String, String> nhan;
  final ValueChanged<String> doi;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        key: const ValueKey('loc-trang-thai'),
        initialValue: giaTri,
        isExpanded: true,
        dropdownColor: Mau.the,
        decoration: const InputDecoration(
          isDense: true,
          prefixIcon: Icon(Icons.filter_list, size: 18),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        items: [
          const DropdownMenuItem(value: '', child: Text('Tất cả')),
          for (final e in nhan.entries)
            DropdownMenuItem(value: e.key, child: Text(e.value)),
        ],
        onChanged: (v) => doi(v ?? ''),
      ),
    );
  }
}

/// Hàng nút thao tác dưới mỗi thẻ.
class _HangNut extends StatelessWidget {
  const _HangNut({required this.nut});
  final List<Widget> nut;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Wrap(spacing: 8, runSpacing: 8, children: nut),
      );
}

Widget _nutChinh(String nhan, VoidCallback? bam) => FilledButton(
      onPressed: bam,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 18),
      ),
      child: Text(nhan),
    );

Widget _nutNguyHiem(String nhan, VoidCallback? bam) => OutlinedButton(
      onPressed: bam,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        foregroundColor: MauTrangThai.xau,
        side: const BorderSide(color: Color(0x55E5645E)),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      child: Text(nhan),
    );

/// Chạy một thao tác duyệt: khoá nút, báo kết quả, tải lại danh sách.
Future<void> _chayDuyet(
  BuildContext context,
  DieuKhienDanhSach dk,
  Future<void> Function() viec,
  String xong,
) async {
  try {
    await viec();
    if (!context.mounted) return;
    baoTin(context, xong);
    await dk.taiLai();
  } catch (e) {
    if (context.mounted) baoLoi(context, e, 'Thao tác không thành công.');
  }
}

Color _mauTrangThai(String t) => switch (t) {
      'PENDING' || 'REQUESTED' => MauTrangThai.cho,
      'SUCCESS' || 'PAID' || 'RESOLVED' || 'APPROVED' => MauTrangThai.tot,
      'FAILED' || 'REJECTED' || 'CANCELLED' => MauTrangThai.xau,
      'REVIEWED' => MauTrangThai.xanh,
      _ => Mau.chuMo,
    };

// ============================================================
// Thanh toán
// ============================================================

class ThanhToanView extends ConsumerStatefulWidget {
  const ThanhToanView({super.key});

  @override
  ConsumerState<ThanhToanView> createState() => _ThanhToanViewState();
}

class _ThanhToanViewState extends ConsumerState<ThanhToanView> {
  String _loc = 'PENDING';
  final _dk = DieuKhienDanhSach();

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(adminRepositoryProvider);
    return DanhSachPhanTrang<GiaoDich>(
      key: ValueKey('tt-$_loc'),
      dieuKhien: _dk,
      tai: (t) => repo.giaoDich(trangThai: _loc, trang: t),
      loiDuPhong: 'Không tải được giao dịch.',
      dau: [
        LocTrangThai(
            giaTri: _loc,
            nhan: tenTrangThaiGiaoDich,
            doi: (v) => setState(() => _loc = v)),
      ],
      trong: const KhoiTrong(
        icon: Icons.inbox_outlined,
        tieuDe: 'Không có giao dịch nào',
        moTa: 'Không có giao dịch nào khớp bộ lọc.',
      ),
      dong: (ctx, g) => _TheGiaoDich(g: g, dk: _dk),
    );
  }
}

class _TheGiaoDich extends ConsumerStatefulWidget {
  const _TheGiaoDich({required this.g, required this.dk});
  final GiaoDich g;
  final DieuKhienDanhSach dk;

  @override
  ConsumerState<_TheGiaoDich> createState() => _TheGiaoDichState();
}

class _TheGiaoDichState extends ConsumerState<_TheGiaoDich> {
  bool _ban = false;

  Future<void> _lam(Future<void> Function() viec, String xong) async {
    setState(() => _ban = true);
    await _chayDuyet(context, widget.dk, viec, xong);
    if (mounted) setState(() => _ban = false);
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final repo = ref.read(adminRepositoryProvider);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g.nguoiTra,
                          style: const TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w600)),
                      if (g.emailNguoiTra != null)
                        Text(g.emailNguoiTra!,
                            style: const TextStyle(
                                fontSize: 11.5, color: Mau.chuMo)),
                      if (g.reader != null)
                        Text('Reader: ${g.reader}',
                            style: const TextStyle(
                                fontSize: 11.5, color: Mau.chuMo)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(Dinh.tien(g.soTien),
                        style: const TextStyle(
                            color: Mau.vang,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    NhanTrangThai(
                        tenTrangThaiGiaoDich[g.trangThai] ?? g.trangThai,
                        mau: _mauTrangThai(g.trangThai)),
                  ],
                ),
              ],
            ),
            if (g.maThamChieu != null) ...[
              const SizedBox(height: 8),
              // Mã tham chiếu là thứ người trực dò trong sao kê — cho chép
              // bằng một chạm, gõ lại bằng tay là dễ sai một ký tự.
              InkWell(
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: g.maThamChieu!));
                  if (context.mounted) baoTin(context, 'Đã chép mã tham chiếu.');
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Mã: ${g.maThamChieu}',
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12.5,
                            color: Mau.vangNhat)),
                    const SizedBox(width: 6),
                    const Icon(Icons.copy, size: 14, color: Mau.chuMo),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              [
                if (g.phuongThuc != null) g.phuongThuc!,
                if (g.buoiLuc != null) 'Buổi ${Dinh.ngayGio(g.buoiLuc)}',
                if (g.luc != null) 'Tạo ${Dinh.ngayGio(g.luc)}',
              ].join(' · '),
              style: const TextStyle(fontSize: 11, color: Mau.chuMo),
            ),
            if (g.trangThai == 'PENDING')
              _HangNut(nut: [
                _nutChinh(
                  'Xác nhận đã nhận',
                  _ban
                      ? null
                      : () async {
                          final ok = await hoiXacNhan(
                            context,
                            tieuDe: 'Xác nhận đã nhận tiền',
                            noiDung:
                                'Xác nhận đã nhận ${Dinh.tien(g.soTien)} từ '
                                '${g.nguoiTra}? Buổi xem sẽ chuyển sang đã '
                                'thanh toán.',
                          );
                          if (ok) {
                            await _lam(() => repo.xacNhanGiaoDich(g.id),
                                'Đã xác nhận thanh toán.');
                          }
                        },
                ),
                _nutNguyHiem(
                  'Từ chối',
                  _ban
                      ? null
                      : () async {
                          final lyDo = await hoiNoiDung(
                            context,
                            tieuDe: 'Từ chối giao dịch',
                            goiY: 'Ví dụ: không có khoản nào khớp mã này '
                                'trong sao kê hôm nay',
                          );
                          if (lyDo != null) {
                            await _lam(
                                () => repo.tuChoiGiaoDich(
                                    g.id, lyDo.isEmpty ? null : lyDo),
                                'Đã từ chối giao dịch.');
                          }
                        },
                ),
              ]),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Rút tiền
// ============================================================

class RutTienView extends ConsumerStatefulWidget {
  const RutTienView({super.key});

  @override
  ConsumerState<RutTienView> createState() => _RutTienViewState();
}

class _RutTienViewState extends ConsumerState<RutTienView> {
  String _loc = 'PENDING';
  final _dk = DieuKhienDanhSach();

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(adminRepositoryProvider);
    return DanhSachPhanTrang<LenhRut>(
      key: ValueKey('rt-$_loc'),
      dieuKhien: _dk,
      tai: (t) => repo.lenhRut(trangThai: _loc, trang: t),
      loiDuPhong: 'Không tải được yêu cầu rút tiền.',
      dau: [
        LocTrangThai(
            giaTri: _loc,
            nhan: tenTrangThaiLenhRut,
            doi: (v) => setState(() => _loc = v)),
      ],
      trong: const KhoiTrong(
        icon: Icons.inbox_outlined,
        tieuDe: 'Không có yêu cầu nào',
        moTa: 'Không có yêu cầu rút tiền nào khớp bộ lọc.',
      ),
      dong: (ctx, r) => _TheLenhRut(r: r, dk: _dk),
    );
  }
}

class _TheLenhRut extends ConsumerStatefulWidget {
  const _TheLenhRut({required this.r, required this.dk});
  final LenhRut r;
  final DieuKhienDanhSach dk;

  @override
  ConsumerState<_TheLenhRut> createState() => _TheLenhRutState();
}

class _TheLenhRutState extends ConsumerState<_TheLenhRut> {
  bool _ban = false;

  Future<void> _lam(Future<void> Function() viec, String xong) async {
    setState(() => _ban = true);
    await _chayDuyet(context, widget.dk, viec, xong);
    if (mounted) setState(() => _ban = false);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    final repo = ref.read(adminRepositoryProvider);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.reader,
                          style: const TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w600)),
                      if (r.emailReader != null)
                        Text(r.emailReader!,
                            style: const TextStyle(
                                fontSize: 11.5, color: Mau.chuMo)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(Dinh.tien(r.soTien),
                        style: const TextStyle(
                            color: Mau.vang,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    NhanTrangThai(
                        tenTrangThaiLenhRut[r.trangThai] ?? r.trangThai,
                        mau: _mauTrangThai(r.trangThai)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              [
                r.nganHang ?? 'Chưa rõ ngân hàng',
                if (r.soTaiKhoanChe != null) r.soTaiKhoanChe!,
                if (r.chuTaiKhoan != null) r.chuTaiKhoan!,
              ].join(' · '),
              style: const TextStyle(fontSize: 12.5),
            ),
            if (r.yeuCauLuc != null)
              Text('Yêu cầu ${Dinh.ngayGio(r.yeuCauLuc)}',
                  style: const TextStyle(fontSize: 11, color: Mau.chuMo)),
            if (r.lyDoTuChoi != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Lý do từ chối: ${r.lyDoTuChoi}',
                    style: const TextStyle(
                        fontSize: 11.5, color: MauTrangThai.xau)),
              ),
            if (r.trangThai == 'PENDING' || r.trangThai == 'APPROVED')
              _HangNut(nut: [
                if (r.trangThai == 'PENDING')
                  _nutChinh(
                    'Duyệt',
                    _ban
                        ? null
                        : () => _lam(() => repo.duyetLenhRut(r.id),
                            'Đã duyệt lệnh rút.'),
                  ),
                if (r.trangThai == 'APPROVED')
                  _nutChinh(
                    'Đã chuyển khoản',
                    _ban
                        ? null
                        : () async {
                            final ok = await hoiXacNhan(
                              context,
                              tieuDe: 'Đánh dấu đã chi',
                              noiDung: 'Chỉ bấm sau khi đã chuyển '
                                  '${Dinh.tien(r.soTien)} cho ${r.reader}. '
                                  'Việc này không hoàn tác được.',
                              dongY: 'Đã chuyển',
                            );
                            if (ok) {
                              await _lam(() => repo.daChiLenhRut(r.id),
                                  'Đã đánh dấu đã chi.');
                            }
                          },
                  ),
                _nutNguyHiem(
                  'Từ chối',
                  _ban
                      ? null
                      : () async {
                          final lyDo = await hoiNoiDung(
                            context,
                            tieuDe: 'Từ chối lệnh rút',
                            goiY: 'Ví dụ: tên chủ tài khoản không khớp hồ sơ',
                          );
                          if (lyDo != null) {
                            await _lam(
                                () => repo.tuChoiLenhRut(
                                    r.id, lyDo.isEmpty ? null : lyDo),
                                'Đã từ chối lệnh rút. Tiền trả lại số dư của '
                                'Reader.');
                          }
                        },
                ),
              ]),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Đơn xin làm Reader
// ============================================================

class DonReaderView extends ConsumerWidget {
  const DonReaderView({super.key, required this.xetDuoc});

  /// Có quyền ADMIN_READERS_REVIEW không — chỉ xem thì ẩn nút.
  final bool xetDuoc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = ref.watch(donReaderProvider);
    return RefreshIndicator(
      color: Mau.vang,
      backgroundColor: Mau.the,
      onRefresh: () => ref.refresh(donReaderProvider.future),
      child: ds.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Mau.vang)),
        error: (e, _) => KhoiLoi(
          thongDiep:
              e is ApiException ? e.message : 'Không tải được hồ sơ Reader.',
          thuLai: () => ref.invalidate(donReaderProvider),
        ),
        data: (list) => list.isEmpty
            ? const KhoiTrong(
                icon: Icons.how_to_reg_outlined,
                tieuDe: 'Không có hồ sơ nào',
                moTa: 'Không có đơn xin làm Reader nào đang chờ duyệt.',
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: list.length,
                itemBuilder: (_, i) => _TheDonReader(d: list[i], xetDuoc: xetDuoc),
              ),
      ),
    );
  }
}

class _TheDonReader extends ConsumerStatefulWidget {
  const _TheDonReader({required this.d, required this.xetDuoc});
  final DonReader d;
  final bool xetDuoc;

  @override
  ConsumerState<_TheDonReader> createState() => _TheDonReaderState();
}

class _TheDonReaderState extends ConsumerState<_TheDonReader> {
  bool _ban = false;

  Future<void> _xet(bool duyet) async {
    final d = widget.d;
    String? lyDo;
    if (!duyet) {
      lyDo = await hoiNoiDung(
        context,
        tieuDe: 'Từ chối hồ sơ',
        goiY: 'Ví dụ: hồ sơ chưa nêu rõ kinh nghiệm thực tế... '
            '(người nộp sẽ đọc được)',
      );
      if (lyDo == null) return;
    } else {
      final ok = await hoiXacNhan(
        context,
        tieuDe: 'Duyệt hồ sơ',
        noiDung: 'Duyệt ${d.hoTen}? Người này sẽ thành Nhân viên và nhận '
            'được lịch hẹn với tư cách Reader.',
        dongY: 'Duyệt',
      );
      if (!ok) return;
    }
    if (!mounted) return;
    setState(() => _ban = true);
    try {
      await ref.read(adminRepositoryProvider).xetDonReader(
            d.id,
            duyet: duyet,
            lyDo: lyDo == null || lyDo.isEmpty ? null : lyDo,
          );
      if (!mounted) return;
      baoTin(context,
          duyet ? 'Đã duyệt — người này giờ là Nhân viên.' : 'Đã từ chối hồ sơ.');
      ref.invalidate(donReaderProvider);
    } catch (e) {
      if (mounted) baoLoi(context, e, 'Không xét được hồ sơ.');
    } finally {
      if (mounted) setState(() => _ban = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              d.soNam == null
                  ? d.hoTen
                  : '${d.hoTen} · ${d.soNam} năm kinh nghiệm',
              style:
                  const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
            ),
            if (d.email != null)
              Text(d.email!,
                  style: const TextStyle(fontSize: 11.5, color: Mau.chuMo)),
            if (d.luc != null)
              Text('Nộp ${Dinh.ngayGio(d.luc)}',
                  style: const TextStyle(fontSize: 11, color: Mau.chuMo)),
            if (d.gioiThieu != null) ...[
              const SizedBox(height: 10),
              Text(d.gioiThieu!,
                  style: const TextStyle(fontSize: 13, height: 1.55)),
            ],
            if (d.chuyenMon.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in d.chuyenMon) NhanTrangThai(c, mau: Mau.vang),
                ],
              ),
            ],
            if (widget.xetDuoc)
              _HangNut(nut: [
                _nutChinh('Duyệt', _ban ? null : () => _xet(true)),
                _nutNguyHiem('Từ chối', _ban ? null : () => _xet(false)),
              ]),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Báo cáo vi phạm
// ============================================================

class BaoCaoView extends ConsumerStatefulWidget {
  const BaoCaoView({super.key});

  @override
  ConsumerState<BaoCaoView> createState() => _BaoCaoViewState();
}

class _BaoCaoViewState extends ConsumerState<BaoCaoView> {
  String _loc = 'PENDING';
  final _dk = DieuKhienDanhSach();

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(adminRepositoryProvider);
    return DanhSachPhanTrang<BaoCao>(
      key: ValueKey('bc-$_loc'),
      dieuKhien: _dk,
      tai: (t) => repo.baoCao(trangThai: _loc, trang: t),
      loiDuPhong: 'Không tải được báo cáo vi phạm.',
      dau: [
        LocTrangThai(
            giaTri: _loc,
            nhan: tenTrangThaiBaoCao,
            doi: (v) => setState(() => _loc = v)),
      ],
      trong: const KhoiTrong(
        icon: Icons.flag_outlined,
        tieuDe: 'Không có báo cáo nào',
        moTa: 'Không có báo cáo nào khớp bộ lọc.',
      ),
      dong: (ctx, b) => _TheBaoCao(b: b, dk: _dk),
    );
  }
}

class _TheBaoCao extends StatelessWidget {
  const _TheBaoCao({required this.b, required this.dk});
  final BaoCao b;
  final DieuKhienDanhSach dk;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(tenLoaiViPham(b.loai),
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w600)),
                ),
                NhanTrangThai(tenTrangThaiBaoCao[b.trangThai] ?? b.trangThai,
                    mau: _mauTrangThai(b.trangThai)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Bị báo cáo: ${b.nguoiBiBao}'
                '${b.vaiTroBiBao != null ? ' (${tenVaiTro[b.vaiTroBiBao] ?? b.vaiTroBiBao})' : ''}',
                style: const TextStyle(fontSize: 12.5)),
            // Tên người báo chỉ người xử lý thấy — ở đây là màn quản trị.
            Text('Người báo: ${b.nguoiBao}',
                style: const TextStyle(fontSize: 11.5, color: Mau.chuMo)),
            if (b.luc != null)
              Text(Dinh.ngayGio(b.luc),
                  style: const TextStyle(fontSize: 11, color: Mau.chuMo)),
            if (b.moTa != null) ...[
              const SizedBox(height: 8),
              Text(b.moTa!, style: const TextStyle(fontSize: 13, height: 1.55)),
            ],
            if (b.tienPhat > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Đã phạt ${Dinh.tien(b.tienPhat)}',
                    style: const TextStyle(
                        fontSize: 12, color: MauTrangThai.xau)),
              ),
            if (b.ketLuan != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Kết luận: ${b.ketLuan}'
                    '${b.nguoiXuLy != null ? ' — ${b.nguoiXuLy}' : ''}',
                    style: const TextStyle(
                        fontSize: 12, color: MauTrangThai.tot)),
              ),
            if (b.conMo)
              _HangNut(nut: [
                _nutChinh(
                  'Kết luận',
                  () async {
                    final xong = await showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Mau.the,
                      builder: (_) => _KetLuanSheet(b: b),
                    );
                    if (xong == true) await dk.taiLai();
                  },
                ),
              ]),
          ],
        ),
      ),
    );
  }
}

class _KetLuanSheet extends ConsumerStatefulWidget {
  const _KetLuanSheet({required this.b});
  final BaoCao b;

  @override
  ConsumerState<_KetLuanSheet> createState() => _KetLuanSheetState();
}

class _KetLuanSheetState extends ConsumerState<_KetLuanSheet> {
  String _ketLuan = 'RESOLVED';
  final _ghiChu = TextEditingController();
  final _tienPhat = TextEditingController();
  bool _dangGui = false;

  @override
  void dispose() {
    _ghiChu.dispose();
    _tienPhat.dispose();
    super.dispose();
  }

  Future<void> _gui() async {
    setState(() => _dangGui = true);
    try {
      await ref.read(adminRepositoryProvider).xuLyBaoCao(
            widget.b.id,
            ketLuan: _ketLuan,
            ghiChu: _ghiChu.text.trim().isEmpty ? null : _ghiChu.text.trim(),
            tienPhat: int.tryParse(_tienPhat.text.trim()) ?? 0,
          );
      if (!mounted) return;
      baoTin(context, 'Đã lưu kết luận.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) baoLoi(context, e, 'Không lưu được kết luận.');
    } finally {
      if (mounted) setState(() => _dangGui = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          18, 18, 18, 18 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Kết luận báo cáo', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            RadioGroup<String>(
              groupValue: _ketLuan,
              onChanged: (v) => setState(() => _ketLuan = v ?? _ketLuan),
              child: Column(
                children: [
                  for (final k in const ['REVIEWED', 'RESOLVED', 'REJECTED'])
                    RadioListTile<String>(
                      key: ValueKey('ket-luan-$k'),
                      value: k,
                      contentPadding: EdgeInsets.zero,
                      title: Text(tenTrangThaiBaoCao[k]!,
                          style: const TextStyle(fontSize: 13.5)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _ghiChu,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                  hintText: 'Nội dung kết luận — người báo cáo sẽ đọc được.'),
            ),
            if (_ketLuan == 'RESOLVED') ...[
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('o-tien-phat'),
                controller: _tienPhat,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Tiền phạt (đ)',
                  hintText: '0',
                  helperText:
                      'Để trống hoặc 0 là nhắc nhở. Thiếu số dư thì ghi nợ và '
                      'tự trừ vào các buổi sau.',
                  helperMaxLines: 3,
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _dangGui ? null : _gui,
              child: const Text('Lưu kết luận'),
            ),
          ],
        ),
      ),
    );
  }
}
