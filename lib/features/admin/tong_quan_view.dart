import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/bieu_do.dart';
import '../../widgets/hop_thoai.dart';
import '../../widgets/trang_thai.dart';
import 'admin_repository.dart';

const _mauVaiTro = {
  'USER': MauTrangThai.xanh,
  'STAFF': MauTrangThai.tot,
  'MANAGER': MauTrangThai.tim,
  'ADMIN': Mau.vang,
};

const _tenTrangThaiBuoi = {
  'PENDING': 'Chờ xác nhận',
  'CONFIRMED': 'Đã xác nhận',
  'COMPLETED': 'Hoàn tất',
  'CANCELLED': 'Đã huỷ',
};

const _mauTrangThaiBuoi = {
  'PENDING': MauTrangThai.cho,
  'CONFIRMED': MauTrangThai.xanh,
  'COMPLETED': MauTrangThai.tot,
  'CANCELLED': MauTrangThai.xau,
};

/// Tổng quan — câu hỏi đầu tiên mỗi lần người quản trị mở app: hệ thống có
/// bao nhiêu người, bao nhiêu việc đang chờ tay mình.
///
/// Mọi con số đọc từ một lần gọi `/api/v1/admin/stats` — toàn phép đếm ở
/// tầng CSDL, không kéo bản ghi về máy để đếm.
class TongQuanView extends ConsumerWidget {
  const TongQuanView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = ref.watch(thongKeProvider);
    return RefreshIndicator(
      color: Mau.vang,
      backgroundColor: Mau.the,
      onRefresh: () => ref.refresh(thongKeProvider.future),
      child: tk.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Mau.vang)),
        error: (e, _) => KhoiLoi(
          thongDiep:
              e is ApiException ? e.message : 'Không tải được số liệu tổng quan.',
          thuLai: () => ref.invalidate(thongKeProvider),
        ),
        data: (s) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            LuoiSoLieu(o: _kpi(s)),
            if (s.coKhoi('traction')) ..._traction(s),
            if (s.coKhoi('revenue')) ..._doanhThu(s),
            BieuDoThanh(
              tieuDe: 'Tài khoản theo vai trò',
              thanh: [
                for (final v in vaiTroTaiKhoan)
                  ThanhSo(tenVaiTro[v]!, s.bang('users', 'byRole')[v] ?? 0,
                      mau: _mauVaiTro[v]!),
              ],
            ),
            BieuDoThanh(
              tieuDe: 'Đặt lịch theo trạng thái',
              thanh: [
                for (final e in _tenTrangThaiBuoi.entries)
                  ThanhSo(e.value, s.bang('bookings', 'byStatus')[e.key] ?? 0,
                      mau: _mauTrangThaiBuoi[e.key]!),
              ],
            ),
            BieuDoThanh(
              tieuDe: 'Hồ sơ Reader',
              thanh: [
                ThanhSo('Chờ duyệt', s.so('readers', 'pendingApplications'),
                    mau: MauTrangThai.cho),
                ThanhSo('Hồ sơ đang có', s.so('readers', 'activeProfiles'),
                    mau: MauTrangThai.tot),
              ],
            ),
            BieuDoThanh(
              tieuDe: 'Cửa hàng liên kết',
              thanh: [
                ThanhSo('Sản phẩm đang bán', s.so('shop', 'activeProducts')),
                ThanhSo('Bấm 30 ngày', s.so('shop', 'clicksLast30Days'),
                    mau: MauTrangThai.xanh),
                ThanhSo('Bấm tổng cộng', s.so('shop', 'clicksTotal'),
                    mau: MauTrangThai.tim),
              ],
            ),
            if (s.coKhoi('ai')) ..._ai(s),
          ],
        ),
      ),
    );
  }

  List<Widget> _kpi(ThongKe s) {
    final choDuyet = s.so('readers', 'pendingApplications');
    final baoCao = s.so('moderation', 'pendingReports');
    return [
      OSoLieu(
        icon: Icons.people_outline,
        nhan: 'Tài khoản',
        so: dinhSo(s.so('users', 'total')),
        goiY: '+${dinhSo(s.so('users', 'newLast7Days'))} trong 7 ngày',
      ),
      OSoLieu(
        icon: Icons.how_to_reg_outlined,
        nhan: 'Hồ sơ Reader chờ duyệt',
        so: dinhSo(choDuyet),
        goiY: '${dinhSo(s.so('readers', 'activeProfiles'))} hồ sơ đang có',
        canChuY: choDuyet > 0,
      ),
      OSoLieu(
        icon: Icons.event_outlined,
        nhan: 'Lượt đặt lịch',
        so: dinhSo(s.so('bookings', 'total')),
        goiY:
            '${dinhSo(s.bang('bookings', 'byStatus')['PENDING'] ?? 0)} đang chờ xác nhận',
      ),
      OSoLieu(
        icon: Icons.flag_outlined,
        nhan: 'Báo cáo chờ xử lý',
        so: dinhSo(baoCao),
        goiY: baoCao > 0 ? 'Cần xem' : 'Không tồn đọng',
        canChuY: baoCao > 0,
      ),
      OSoLieu(
        icon: Icons.ads_click,
        nhan: 'Lượt sang sàn (30 ngày)',
        so: dinhSo(s.so('shop', 'clicksLast30Days')),
        goiY: '${dinhSo(s.so('shop', 'clicksTotal'))} tổng cộng',
      ),
      if (s.coKhoi('ai'))
        OSoLieu(
          icon: Icons.smart_toy_outlined,
          nhan: 'Token Tarot AI',
          so: dinhSo(s.so('ai', 'totalTokens')),
          goiY: '${dinhSo(s.so('ai', 'tokensLast30Days'))} trong 30 ngày · '
              '~\$${s.thuc('ai', 'estimatedCostUsd').toStringAsFixed(2)}',
        ),
    ];
  }

  List<Widget> _traction(ThongKe s) {
    final phanHoi = s.so('traction', 'feedbackCount');
    final datMucTieu = s.tho['traction'] is Map &&
        (s.tho['traction'] as Map)['feedbackGoalMet'] == true;
    return [
      const TieuDeKhoi('Traction'),
      LuoiSoLieu(o: [
        OSoLieu(
            nhan: 'Người dùng',
            so: dinhSo(s.so('traction', 'registeredUsers'))),
        OSoLieu(
            nhan: 'Thanh toán thành công',
            so: dinhSo(s.so('traction', 'successfulPayments'))),
        OSoLieu(
            nhan: 'Buổi hoàn tất',
            so: dinhSo(s.so('traction', 'completedBookings'))),
        OSoLieu(
            nhan: 'Đánh giá Reader',
            so: dinhSo(s.so('traction', 'reviewsCount'))),
        OSoLieu(
          nhan: 'Phản hồi khảo sát',
          so: '${dinhSo(phanHoi)}/20',
          goiY: datMucTieu ? 'Đã đạt mục tiêu' : 'Chưa đạt mục tiêu',
        ),
        OSoLieu(
            nhan: 'Affiliate 30 ngày',
            so: dinhSo(s.so('traction', 'affiliateClicks30d'))),
      ]),
    ];
  }

  List<Widget> _doanhThu(ThongKe s) {
    final phi = s.so('revenue', 'platformFeePercent');
    final theoThang = s.bang('revenue', 'revenueByMonth');
    final khoa = theoThang.keys.toList()..sort();
    final gan = khoa.length > 12 ? khoa.sublist(khoa.length - 12) : khoa;
    return [
      const TieuDeKhoi('Doanh thu và lợi nhuận'),
      LuoiSoLieu(o: [
        OSoLieu(
          nhan: 'Doanh thu gộp',
          so: Dinh.tien(s.so('revenue', 'grossRevenue')),
          goiY:
              '${Dinh.tien(s.so('revenue', 'grossRevenueLast30Days'))} trong 30 ngày',
        ),
        OSoLieu(
          nhan: 'Phí nền tảng ($phi%)',
          so: Dinh.tien(s.so('revenue', 'platformFee')),
          goiY:
              '${Dinh.tien(s.so('revenue', 'readerShare'))} còn lại là của Reader',
        ),
        OSoLieu(
          nhan: 'Chi phí AI',
          so: Dinh.tien(s.so('revenue', 'aiCostVnd')),
          goiY: 'Quy đổi từ token đã tiêu thụ',
        ),
        OSoLieu(
          nhan: 'Lợi nhuận ròng',
          so: Dinh.tien(s.so('revenue', 'netProfit')),
          goiY: 'Phí nền tảng trừ chi phí AI',
        ),
      ]),
      BieuDoThanh(
        tieuDe: 'Doanh thu theo tháng',
        thanh: [
          for (final k in gan)
            ThanhSo(_thang(k), theoThang[k] ?? 0,
                mau: MauTrangThai.tot, chuSo: Dinh.tien(theoThang[k] ?? 0)),
        ],
      ),
      BieuDoThanh(
        tieuDe: 'Tiền đi về đâu',
        ghiChu: 'Phần lớn tiền khách trả là của Reader; nền tảng giữ $phi%.',
        thanh: [
          ThanhSo('Reader nhận', s.so('revenue', 'readerShare'),
              mau: MauTrangThai.xanh,
              chuSo: Dinh.tien(s.so('revenue', 'readerShare'))),
          ThanhSo('Phí nền tảng', s.so('revenue', 'platformFee'),
              chuSo: Dinh.tien(s.so('revenue', 'platformFee'))),
          ThanhSo('Chi phí AI', s.so('revenue', 'aiCostVnd'),
              mau: MauTrangThai.xau,
              chuSo: Dinh.tien(s.so('revenue', 'aiCostVnd'))),
        ],
      ),
    ];
  }

  List<Widget> _ai(ThongKe s) {
    final theoModel = s.bang('ai', 'tokensByModel');
    return [
      BieuDoThanh(
        tieuDe: 'Token Tarot AI',
        thanh: [
          ThanhSo('Prompt (vào)', s.so('ai', 'promptTokens'),
              mau: MauTrangThai.xanh),
          ThanhSo('Completion (ra)', s.so('ai', 'completionTokens'),
              mau: MauTrangThai.tim),
          ThanhSo('Tổng token', s.so('ai', 'totalTokens')),
          ThanhSo('30 ngày gần đây', s.so('ai', 'tokensLast30Days'),
              mau: MauTrangThai.tot),
        ],
      ),
      if (theoModel.isNotEmpty)
        BieuDoThanh(
          tieuDe: 'Token theo model AI',
          thanh: [
            for (final e in theoModel.entries) ThanhSo(e.key, e.value),
          ],
        ),
    ];
  }

  /// `2026-09` → `09/2026`
  static String _thang(String k) {
    final p = k.split('-');
    return p.length == 2 ? '${p[1]}/${p[0]}' : k;
  }
}
