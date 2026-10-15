import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/format.dart';
import '../../core/ngon_ngu.dart';
import '../../theme.dart';
import '../../widgets/trang_thai.dart';
import 'goi_ai_repository.dart';
import 'google_billing.dart';
import 'vi_repository.dart';

/// Gói AI và ví — phần web đã có mà app chưa có.
///
/// ## Vì sao gộp ví vào cùng màn
///
/// Trên web, ví và gói AI nằm ở hai chỗ. Trên điện thoại thì tách ra lại thành
/// phiền: muốn mua gói phải nhớ sang màn khác nạp tiền trước, rồi quay lại tìm
/// đúng gói. Đặt số dư ngay trên đầu danh sách gói thì người dùng thấy ngay
/// mình đủ tiền hay chưa, trước khi bấm vào gói nào.
///
/// ## Vì sao trên Android mua qua Google Play, không mua bằng ví
///
/// Chính sách Thanh toán của Google xếp gói nội dung số dùng trong ứng dụng
/// vào diện BẮT BUỘC dùng hệ thống thanh toán của Play, và Việt Nam không nằm
/// trong chương trình thanh toán thay thế nào. Bán bằng ví là bị gỡ app.
///
/// Ví vẫn ở lại màn này, nhưng trên Android nó chỉ còn để trả buổi xem với
/// Reader — dịch vụ một-kèm-một giữa hai người, Google miễn trừ khoản ấy.
/// Trên nền tảng khác (máy tính lúc phát triển) thì mua gói bằng ví như cũ.
class GoiAiScreen extends ConsumerStatefulWidget {
  const GoiAiScreen({super.key});

  @override
  ConsumerState<GoiAiScreen> createState() => _GoiAiScreenState();
}

class _GoiAiScreenState extends ConsumerState<GoiAiScreen> {
  StreamSubscription<KetQuaMua>? _nghe;

  @override
  void initState() {
    super.initState();
    if (!nenDungGooglePlay) return;
    // Lắng nghe NGAY khi mở màn, trước cú bấm mua đầu tiên: Google có thể
    // phát lại một lượt mua còn dở từ phiên trước ngay lúc này — đó là cách
    // khách lấy được gói khi lần trước mạng hỏng giữa đường.
    try {
      final b = ref.read(googleBillingProvider);
      b.mo();
      _nghe = b.ketQua.listen(_nhanKetQua);
    } catch (e) {
      // Máy Android không có Play Billing đăng ký: màn vẫn mở được, chỉ mất
      // lối mua — `sanPhamGoogleProvider` cũng trả rỗng nên nút đã tự khoá.
      debugPrint('Không bật được Google Play Billing: $e');
    }
  }

  @override
  void dispose() {
    _nghe?.cancel();
    super.dispose();
  }

  void _nhanKetQua(KetQuaMua k) {
    if (!mounted) return;
    final dangMua = ref.read(dangMuaGoogleProvider.notifier);
    switch (k.loai) {
      case LoaiKetQua.dangCho:
        // KHÔNG tắt trạng thái đang mua: lượt mua vẫn sống, Google còn chờ
        // khách trả tiền (chuyển khoản, thẻ chờ xác thực) rồi mới trả kết quả.
        _nhan(Ngu.d('Google đang xử lý thanh toán. Gói vào ngay khi xong.'));
      case LoaiKetQua.xong:
        dangMua.dat(null);
        ref.invalidate(goiCuaToiProvider);
        ref.invalidate(luotDungHomNayProvider);
        _nhan(Ngu.d('Đã kích hoạt gói.'));
      case LoaiKetQua.huy:
        // Khách tự bỏ giữa luồng của Google: không báo gì, họ biết mình vừa
        // bấm huỷ.
        dangMua.dat(null);
      case LoaiKetQua.loi:
        dangMua.dat(null);
        _nhan(k.thongBao ?? Ngu.d('Thanh toán không xong.'));
    }
  }

  void _nhan(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final ds = ref.watch(goiDangBanProvider);
    final sanPham = ref.watch(sanPhamGoogleProvider);
    // Màn này gộp hai thứ: VÍ của người dùng, và GÓI AI đang bán.
    //
    // Chỉ phần gói là việc của khách — mua gói và nạp ví đều đòi
    // CUSTOMER_ACTIONS. Còn ví thì backend cố ý để `isAuthenticated()`: người
    // từng là khách rồi được cất lên Nhân viên vẫn phải nhìn thấy tiền cũ của
    // mình.
    //
    // Bản trước tôi gác cả màn, nên Nhân viên mất luôn đường tới ví — chặt
    // hơn backend, và ngược với chính lý do đã viết ra khi mở backend.
    final laKhach =
        ref.watch(authControllerProvider).user?.co('CUSTOMER_ACTIONS') ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(laKhach ? Ngu.d('Gói AI') : Ngu.d('Ví ASTROTAROT')),
      ),
      body: RefreshIndicator(
        color: Mau.vang,
        backgroundColor: Mau.the,
        onRefresh: () async {
          ref.invalidate(goiDangBanProvider);
          ref.invalidate(viCuaToiProvider);
          ref.invalidate(goiCuaToiProvider);
          ref.invalidate(luotDungHomNayProvider);
          ref.invalidate(sanPhamGoogleProvider);
          await ref.read(goiDangBanProvider.future);
        },
        child: ds.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: Mau.vang)),
          error: (e, _) => KhoiLoi(
            thongDiep: e is ApiException
                ? e.message
                : Ngu.d('Không tải được danh sách gói. Thử lại sau.'),
            thuLai: () => ref.invalidate(goiDangBanProvider),
          ),
          data: (goi) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _TheVi(napDuoc: laKhach),
              if (laKhach) ...[
                const SizedBox(height: 12),
                const _HanMucHomNay(),
                const SizedBox(height: 20),
                Text(
                  Ngu.d('Chọn gói'),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (goi.isEmpty)
                  KhoiTrong(
                    icon: Icons.auto_awesome,
                    tieuDe: Ngu.d('Chưa có gói nào đang bán'),
                  )
                else
                  for (final g in goi)
                    _TheGoi(
                      goi: g,
                      sanPham: g.maGooglePlay == null
                          ? null
                          : sanPham.asData?.value[g.maGooglePlay],
                      choGia: sanPham.isLoading,
                    ),
              ],
              const SizedBox(height: 20),
              // Hai khối này là LỊCH SỬ của chính họ, giữ cho mọi vai trò.
              const _LuotMuaCuaToi(),
              const SizedBox(height: 20),
              const _SoViCuaToi(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Số dư ví, kèm lối nạp thêm.
class _TheVi extends ConsumerWidget {
  const _TheVi({required this.napDuoc});

  /// Nạp ví đòi CUSTOMER_ACTIONS ở backend. Bày nút cho người không có quyền
  /// là hứa một việc máy chủ sẽ từ chối — số dư thì vẫn hiện, vì đó là tiền
  /// của họ.
  final bool napDuoc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vi = ref.watch(viCuaToiProvider);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Mau.vang.withValues(alpha: 0.35)),
        color: Mau.the,
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet_outlined, color: Mau.vang),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Ngu.d('Số dư ví'),
                  style: TextStyle(fontSize: 12, color: Mau.chuMo),
                ),
                const SizedBox(height: 2),
                Text(
                  vi.when(
                    loading: () => '…',
                    error: (_, _) => '—',
                    data: (v) => Dinh.tien(v.soDu),
                  ),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Mau.vangNhat,
                  ),
                ),
              ],
            ),
          ),
          if (napDuoc)
            OutlinedButton(
              onPressed: () => _moNap(context, ref),
              child: Text(Ngu.d('Nạp tiền')),
            ),
        ],
      ),
    );
  }
}

/// Hạn mức hôm nay: đã dùng bao nhiêu trên tổng bao nhiêu.
class _HanMucHomNay extends ConsumerWidget {
  const _HanMucHomNay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daDung = ref.watch(luotDungHomNayProvider).asData?.value ?? 0;
    final goi = ref.watch(goiCuaToiProvider).asData?.value ?? const [];
    final dangChay = goi.where((g) => g.dangChay).toList();

    // Không có gói nào đang chạy thì vẫn còn hạn mức miễn phí của hệ thống.
    // Không bịa con số ấy ra ở đây: chỉ nói đang dùng gói miễn phí, để mình
    // không nói một đằng mà máy chủ chặn một nẻo.
    final ten = dangChay.isEmpty
        ? Ngu.d('Gói miễn phí')
        : dangChay.first.tenGoi;
    final tong = dangChay.isEmpty ? null : dangChay.first.hanMucNgay;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Mau.vien),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ten,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                tong == null ? '$daDung lượt hôm nay' : '$daDung / $tong',
                style: const TextStyle(color: Mau.chuMo, fontSize: 13),
              ),
            ],
          ),
          if (tong != null && tong > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (daDung / tong).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: Mau.vien,
                valueColor: const AlwaysStoppedAnimation(Mau.vang),
              ),
            ),
          ],
          if (dangChay.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Còn ${dangChay.first.soNgayConLai} ngày',
              style: const TextStyle(color: Mau.chuMo, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _TheGoi extends ConsumerStatefulWidget {
  const _TheGoi({required this.goi, this.sanPham, this.choGia = false});

  final GoiAi goi;

  /// Gói tương ứng bên Google, kèm giá đã quy đổi theo nước của khách.
  ///
  /// Null nghĩa là không mua được qua Play: máy không có Google Play, hoặc
  /// Play Console chưa khai mã sản phẩm này.
  final ProductDetails? sanPham;

  /// Còn đang hỏi giá Google.
  final bool choGia;

  @override
  ConsumerState<_TheGoi> createState() => _TheGoiState();
}

class _TheGoiState extends ConsumerState<_TheGoi> {
  /// Chỉ dùng cho đường mua bằng ví.
  ///
  /// Đường Google không giữ trạng thái ở đây được: kết quả về qua stream, có
  /// thể về sau khi hệ điều hành đã thu hồi app rồi mở lại, lúc ấy thẻ này đã
  /// bị dựng lại từ đầu. Nó đọc [dangMuaGoogleProvider] thay thế.
  bool _dangMuaVi = false;

  /// Lý do không cho mua, null là mua được.
  ///
  /// Chép đúng luật `assertMayAcquirePlan` bên máy chủ, và phải chép: đường
  /// Google không chặn được ở máy chủ nữa, vì lúc máy chủ biết chuyện thì
  /// Google đã trừ tiền khách rồi. Chặn muộn là khách mất tiền.
  String? _vuongMac() {
    final g = widget.goi;
    final daMua = ref.watch(goiCuaToiProvider).asData?.value ?? const [];
    final conHieuLuc = daMua.where((p) => p.conHieuLuc).toList();

    if (conHieuLuc.any((p) => p.maGoi == g.id)) {
      return Ngu.d('Bạn đang dùng gói này rồi.');
    }
    if (g.loai != 'MONTHLY') return null;

    // Gói tháng đang chạy thì chỉ cho nâng cấp. So bằng giá trong cơ sở dữ
    // liệu chứ không phải giá Google hiện ra: máy chủ cũng so bằng giá ấy,
    // lệch nhau là app cho bấm rồi máy chủ mới chặn.
    final dangBan = ref.watch(goiDangBanProvider).asData?.value ?? const [];
    for (final p in conHieuLuc) {
      String? loaiCu;
      for (final x in dangBan) {
        if (x.id == p.maGoi) loaiCu = x.loai;
      }
      if (loaiCu != 'MONTHLY') continue;
      if (g.hanMucNgay <= p.hanMucNgay && g.gia <= p.gia) {
        return Ngu.d(
          'Bạn đang có gói tháng. Chỉ đổi lên được gói có hạn mức hoặc '
          'giá cao hơn.',
        );
      }
    }
    return null;
  }

  /// Mở luồng thanh toán của Google.
  ///
  /// Không có hộp xác nhận của mình: Google đã có màn xác nhận giá và phương
  /// thức thanh toán riêng, thêm một lớp nữa chỉ là một cú bấm thừa.
  Future<void> _muaQuaGoogle(ProductDetails sp) async {
    ref.read(dangMuaGoogleProvider.notifier).dat(widget.goi.id);
    try {
      await ref.read(googleBillingProvider).mua(sp);
    } catch (e) {
      ref.read(dangMuaGoogleProvider.notifier).dat(null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${Ngu.d('Không mở được thanh toán Google')}: $e'),
        ),
      );
    }
    // Không tắt trạng thái ở nhánh thành công: luồng mới chỉ MỞ ra thôi. Kết
    // quả về qua stream, và màn gói tắt trạng thái ở đó.
  }

  Future<void> _muaBangVi() async {
    final g = widget.goi;
    final soDu = ref.read(viCuaToiProvider).asData?.value.soDu ?? 0;

    // Chặn ở đây thay vì để máy chủ trả lỗi: câu "số dư không đủ" nói rõ còn
    // thiếu bao nhiêu thì người dùng biết phải nạp bao nhiêu, còn lỗi từ máy
    // chủ chỉ nói là thất bại.
    if (soDu < g.gia) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Số dư còn ${Dinh.tien(soDu)}, thiếu '
            '${Dinh.tien(g.gia - soDu)} để mua ${g.ten}.',
          ),
        ),
      );
      return;
    }

    final dong = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Mau.the,
        title: Text(Ngu.d('Xác nhận mua')),
        content: Text(
          'Mua ${g.ten} với giá ${Dinh.tien(g.gia)}?\n\n'
          'Tiền trừ thẳng từ số dư ví. Sau khi mua, số dư còn '
          '${Dinh.tien(soDu - g.gia)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(Ngu.d('Thôi')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Mua'),
          ),
        ],
      ),
    );
    if (dong != true) return;

    setState(() => _dangMuaVi = true);
    try {
      await ref.read(goiAiRepositoryProvider).mua(g.id);
      ref.invalidate(viCuaToiProvider);
      ref.invalidate(goiCuaToiProvider);
      ref.invalidate(giaoDichViProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Đã mua ${g.ten}.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : Ngu.d('Mua không thành công.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _dangMuaVi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.goi;
    final sp = widget.sanPham;
    final vuongMac = _vuongMac();
    final maDangMua = ref.watch(dangMuaGoogleProvider);

    // Giá hiện ra: trên Android lấy của Google, không lấy của máy chủ mình.
    //
    // Google bắt hiện đúng con số thư viện trả về — đã gồm thuế và đúng tiền
    // tệ từng nước — và con số ấy chỉnh ở Play Console. Giá trên app cao hơn
    // giá web vì Google thu hoa hồng mỗi lượt mua.
    final gia = sp?.price ?? Dinh.tien(g.gia);

    final String nhan;
    final VoidCallback? bam;
    if (nenDungGooglePlay) {
      if (widget.choGia) {
        nhan = Ngu.d('Đang lấy giá…');
        bam = null;
      } else if (sp == null) {
        nhan = Ngu.d('Chưa mở bán trong ứng dụng');
        bam = null;
      } else if (vuongMac != null) {
        nhan = Ngu.d('Không mua được');
        bam = null;
      } else if (maDangMua != null) {
        // Khoá mọi thẻ khi có một lượt mua đang chạy: Google chỉ xử lý một
        // luồng mua một lúc, bấm thẻ thứ hai chỉ nhận về lỗi.
        nhan = Ngu.d(maDangMua == g.id ? 'Đang mua…' : 'Mua qua Google Play');
        bam = null;
      } else {
        nhan = Ngu.d('Mua qua Google Play');
        bam = () => _muaQuaGoogle(sp);
      }
    } else {
      if (_dangMuaVi) {
        nhan = Ngu.d('Đang mua…');
        bam = null;
      } else if (vuongMac != null) {
        nhan = Ngu.d('Không mua được');
        bam = null;
      } else {
        nhan = Ngu.d('Mua bằng ví');
        bam = _muaBangVi;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Mau.vien),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  g.ten,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                gia,
                style: const TextStyle(
                  color: Mau.vangNhat,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${g.hanMucNgay} lượt AI mỗi ngày · ${nhanLoaiGoi(g.loai)} · '
            '${g.soNgay} ngày',
            style: const TextStyle(color: Mau.chuMo, fontSize: 12.5),
          ),
          if (g.moTa != null && g.moTa!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              g.moTa!,
              style: const TextStyle(color: Mau.chuMo, fontSize: 12.5),
            ),
          ],
          if (vuongMac != null) ...[
            const SizedBox(height: 6),
            Text(
              vuongMac,
              style: const TextStyle(color: Color(0xFFE0B341), fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: bam, child: Text(nhan)),
          ),
        ],
      ),
    );
  }
}

/// Sổ ví — tiền vào, tiền ra.
///
/// `giaoDichViProvider` đã có từ trước và được làm mới sau mỗi lần nạp lẫn mỗi
/// lần mua gói, nhưng KHÔNG màn nào đọc nó: dữ liệu tải về rồi bỏ đó. Người
/// dùng trên app thấy số dư tụt mà không có chỗ nào xem vì sao, trong khi bản
/// web có trang ví đầy đủ.
class _SoViCuaToi extends ConsumerWidget {
  const _SoViCuaToi();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = ref.watch(giaoDichViProvider).asData?.value ?? const [];
    if (ds.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          Ngu.d('Sổ ví'),
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        for (final g in ds)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              g.tienVao ? Icons.south_west : Icons.north_east,
              size: 20,
              color: g.tienVao ? const Color(0xFF6BBF7B) : Mau.chuMo,
            ),
            title: Text(
              nhanLoaiGiaoDich(g.loai),
              style: const TextStyle(fontSize: 14),
            ),
            subtitle: Text(
              g.moTa?.isNotEmpty == true ? g.moTa! : Dinh.ngayGio(g.luc),
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Dấu tự đặt ở đây. Máy chủ trả amount LUÔN DƯƠNG kể cả giao
                // dịch trừ ví, nên chiều tiền phải đọc ở chênh lệch số dư —
                // xem GiaoDichVi.tienVao.
                Text(
                  '${g.tienVao ? '+' : '−'}${Dinh.tien(g.soTien)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: g.tienVao ? const Color(0xFF6BBF7B) : Mau.chu,
                  ),
                ),
                Text(
                  'Còn ${Dinh.tien(g.soDuSau)}',
                  style: const TextStyle(fontSize: 11, color: Mau.chuMo),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _LuotMuaCuaToi extends ConsumerWidget {
  const _LuotMuaCuaToi();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = ref.watch(goiCuaToiProvider).asData?.value ?? const [];
    if (ds.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          Ngu.d('Gói đã mua'),
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        for (final m in ds)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              m.dangChay ? Icons.check_circle_outline : Icons.history,
              color: m.dangChay ? Mau.vang : Mau.chuMo,
            ),
            title: Text(m.tenGoi, style: const TextStyle(fontSize: 14)),
            subtitle: Text(
              m.dangChay
                  ? 'Đang dùng · còn ${m.soNgayConLai} ngày'
                  : 'Đã hết hạn ${Dinh.ngayGio(m.ketThuc)}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Text(
              Dinh.tien(m.gia),
              style: const TextStyle(fontSize: 13, color: Mau.chuMo),
            ),
          ),
      ],
    );
  }
}

/// Mở ô nhập số tiền nạp.
Future<void> _moNap(BuildContext context, WidgetRef ref) async {
  final o = TextEditingController();
  final soTien = await showDialog<int>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: Mau.the,
      title: Text(Ngu.d('Nạp tiền vào ví')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: o,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              labelText: Ngu.d('Số tiền'),
              suffixText: 'đ',
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final m in [50000, 100000, 200000, 500000])
                ActionChip(
                  label: Text(Dinh.tien(m)),
                  onPressed: () => o.text = '$m',
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: Text(Ngu.d('Thôi')),
        ),
        FilledButton(
          onPressed: () {
            final v = int.tryParse(o.text.trim());
            if (v != null && v > 0) Navigator.pop(c, v);
          },
          child: Text(Ngu.d('Tạo mã nạp')),
        ),
      ],
    ),
  );
  if (soTien == null) return;

  try {
    final h = await ref.read(viRepositoryProvider).nap(soTien);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Mau.the,
        title: Text(Ngu.d('Chuyển khoản để nạp')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Số tiền: ${Dinh.tien(h.soTien)}'),
            if (h.tenNganHang != null) Text('Ngân hàng: ${h.tenNganHang}'),
            if (h.soTaiKhoan != null) Text('Số tài khoản: ${h.soTaiKhoan}'),
            if (h.chuTaiKhoan != null) Text('Chủ tài khoản: ${h.chuTaiKhoan}'),
            if (h.noiDung != null) ...[
              const SizedBox(height: 8),
              Text(
                Ngu.d('Nội dung chuyển khoản — ghi ĐÚNG:'),
                style: TextStyle(fontSize: 12, color: Mau.chuMo),
              ),
              SelectableText(
                h.noiDung!,
                style: const TextStyle(
                  color: Mau.vangNhat,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                Ngu.d(
                  'Sai nội dung thì hệ thống không khớp được lượt chuyển với ví của bạn, và tiền phải đối soát tay.',
                ),
                style: TextStyle(fontSize: 11.5, color: Mau.chuMo),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              ref.invalidate(viCuaToiProvider);
              ref.invalidate(giaoDichViProvider);
            },
            child: const Text('Xong'),
          ),
        ],
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          e is ApiException ? e.message : Ngu.d('Không tạo được lệnh nạp.'),
        ),
      ),
    );
  }
}
