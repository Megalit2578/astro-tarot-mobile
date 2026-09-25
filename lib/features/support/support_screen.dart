import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../../widgets/hop_thoai.dart';
import '../../widgets/trang_thai.dart';
import 'support_repository.dart';

class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = ref.watch(ticketsCuaToiProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Hỗ trợ')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _moTao(context, ref),
        backgroundColor: Mau.vang,
        foregroundColor: const Color(0xFF1A1206),
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Gửi yêu cầu'),
      ),
      body: RefreshIndicator(
        color: Mau.vang,
        backgroundColor: Mau.the,
        onRefresh: () => ref.refresh(ticketsCuaToiProvider.future),
        child: ds.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: Mau.vang)),
          error: (e, _) => KhoiLoi(
            thongDiep: e is ApiException
                ? e.message
                : 'Không tải được yêu cầu hỗ trợ.',
            thuLai: () => ref.invalidate(ticketsCuaToiProvider),
          ),
          data: (list) => list.isEmpty
              ? const KhoiTrong(
                  icon: Icons.support_agent_outlined,
                  tieuDe: 'Chưa có yêu cầu nào',
                  moTa: 'Gặp trục trặc gì thì gửi cho chúng tôi một yêu cầu. '
                      'Nhân viên sẽ trả lời ngay trong phiếu.',
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _TheTicket(t: list[i]),
                ),
        ),
      ),
    );
  }

  Future<void> _moTao(BuildContext context, WidgetRef ref) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const _TaoTicketScreen()),
    );
    if (ok == true) ref.invalidate(ticketsCuaToiProvider);
  }
}

class _TheTicket extends StatelessWidget {
  const _TheTicket({required this.t});
  final Ticket t;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TicketDetailScreen(ticket: t)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        title: Text(t.tieuDe,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, height: 1.4)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            [
              nhanTrangThaiTicket(t.trangThai),
              if (t.soTin > 0) '${t.soTin} tin',
              if (t.luc != null) Dinh.ngayGio(t.luc),
            ].join(' · '),
            style: const TextStyle(fontSize: 11.5, color: Mau.chuMo),
          ),
        ),
        trailing: const Icon(Icons.chevron_right, size: 20, color: Mau.chuMo),
      ),
    );
  }
}

class _TaoTicketScreen extends ConsumerStatefulWidget {
  const _TaoTicketScreen();

  @override
  ConsumerState<_TaoTicketScreen> createState() => _TaoTicketScreenState();
}

class _TaoTicketScreenState extends ConsumerState<_TaoTicketScreen> {
  final _form = GlobalKey<FormState>();
  final _tieuDe = TextEditingController();
  final _noiDung = TextEditingController();
  bool _dangGui = false;

  @override
  void dispose() {
    _tieuDe.dispose();
    _noiDung.dispose();
    super.dispose();
  }

  Future<void> _gui() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _dangGui = true);
    try {
      await ref
          .read(supportRepositoryProvider)
          .tao(_tieuDe.text, _noiDung.text);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Mau.the),
      );
    } finally {
      if (mounted) setState(() => _dangGui = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gửi yêu cầu hỗ trợ')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          children: [
            TextFormField(
              controller: _tieuDe,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'Tiêu đề — vấn đề của bạn là gì?',
              ),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return 'Vui lòng nhập tiêu đề';
                if (t.length > 200) return 'Tiêu đề tối đa 200 ký tự';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noiDung,
              minLines: 6,
              maxLines: 12,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Mô tả cụ thể: bạn đang làm gì, thấy gì, và mong '
                    'điều gì xảy ra.',
              ),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return 'Vui lòng nhập nội dung';
                if (t.length > 5000) return 'Nội dung tối đa 5000 ký tự';
                return null;
              },
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _dangGui ? null : _gui,
              child: _dangGui
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Gửi'),
            ),
          ],
        ),
      ),
    );
  }
}

class TicketDetailScreen extends ConsumerStatefulWidget {
  const TicketDetailScreen({
    super.key,
    required this.ticket,
    this.nhanVien = false,
  });
  final Ticket ticket;

  /// Mở từ hàng chờ của nhân viên: có nút đổi trạng thái.
  final bool nhanVien;

  @override
  ConsumerState<TicketDetailScreen> createState() =>
      _TicketDetailScreenState();
}

class _TicketDetailScreenState extends ConsumerState<TicketDetailScreen> {
  final _o = TextEditingController();
  bool _dangGui = false;

  @override
  void dispose() {
    _o.dispose();
    super.dispose();
  }

  Future<void> _traLoi() async {
    final t = _o.text.trim();
    if (t.isEmpty || _dangGui) return;
    setState(() => _dangGui = true);
    try {
      await ref
          .read(supportRepositoryProvider)
          .traLoi(widget.ticket.id, t);
      _o.clear();
      ref.invalidate(ticketChiTietProvider(widget.ticket.id));
      ref.invalidate(ticketsCuaToiProvider);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Mau.the),
      );
    } finally {
      if (mounted) setState(() => _dangGui = false);
    }
  }

  Future<void> _doiTrangThai(String moi) async {
    try {
      await ref
          .read(supportRepositoryProvider)
          .doiTrangThai(widget.ticket.id, moi);
      ref.invalidate(ticketChiTietProvider(widget.ticket.id));
      if (mounted) {
        baoTin(context,
            'Đã chuyển sang "${nhanTrangThaiTicket(moi, nhanVien: true)}".');
      }
    } catch (e) {
      if (mounted) baoLoi(context, e, 'Không đổi được trạng thái.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ct = ref.watch(ticketChiTietProvider(widget.ticket.id));
    // Đọc trạng thái từ bản chi tiết mới nhất, không từ dòng trong danh sách
    // lúc bấm vào: nhân viên vừa đóng phiếu thì ô trả lời phải khoá ngay.
    final trangThai =
        (ct.asData?.value['status'] ?? widget.ticket.trangThai).toString();
    final dong = trangThai.toUpperCase() == 'CLOSED';
    final u = ref.watch(authControllerProvider).user;
    // Quản lý có SUPPORT_VIEW nhưng KHÔNG có SUPPORT_RESPOND: họ giám sát hàng
    // chờ chứ không trả lời khách.
    final traLoiDuoc = !widget.nhanVien || (u?.co('SUPPORT_RESPOND') ?? false);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ticket.tieuDe,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15)),
        actions: [
          if (widget.nhanVien && traLoiDuoc)
            PopupMenuButton<String>(
              tooltip: 'Đổi trạng thái',
              color: Mau.the,
              icon: const Icon(Icons.flag_outlined),
              onSelected: _doiTrangThai,
              itemBuilder: (_) => [
                for (final t in trangThaiNhanVienChuyen)
                  if (t != trangThai.toUpperCase())
                    PopupMenuItem(
                      value: t,
                      child: Text(nhanTrangThaiTicket(t, nhanVien: true)),
                    ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ct.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: Mau.vang)),
              error: (e, _) => KhoiLoi(
                thongDiep: e is ApiException
                    ? e.message
                    : 'Không tải được nội dung phiếu.',
                thuLai: () =>
                    ref.invalidate(ticketChiTietProvider(widget.ticket.id)),
              ),
              data: (d) {
                final raw = d['messages'];
                final ds = raw is List
                    ? raw
                        .whereType<Map<String, dynamic>>()
                        .map(TinHoTro.fromJson)
                        .toList()
                    : <TinHoTro>[];
                if (ds.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(30),
                      child: Text('Phiếu này chưa có nội dung nào.',
                          style: TextStyle(color: Mau.chuMo, fontSize: 13)),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  itemCount: ds.length,
                  itemBuilder: (_, i) => _BongTin(tin: ds[i]),
                );
              },
            ),
          ),
          if (!dong && !traLoiDuoc)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Mau.the,
              child: const Text(
                'Bạn đang xem ở chế độ giám sát — tài khoản này không trả lời '
                'khách.',
                style: TextStyle(fontSize: 11.5, color: Mau.chuMo),
              ),
            )
          else if (dong)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: const Color(0x18E0B341),
              child: const Text(
                'Phiếu đã đóng. Cần thêm trợ giúp thì gửi một yêu cầu mới.',
                style: TextStyle(fontSize: 11.5, height: 1.5),
              ),
            )
          else
            Container(
              padding: EdgeInsets.fromLTRB(
                  12, 10, 12, 10 + MediaQuery.of(context).padding.bottom),
              decoration: const BoxDecoration(
                color: Mau.the,
                border: Border(top: BorderSide(color: Mau.vien)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _o,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Trả lời…',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 44,
                    width: 44,
                    child: IconButton.filled(
                      onPressed: _dangGui ? null : _traLoi,
                      style: IconButton.styleFrom(
                        backgroundColor: Mau.vang,
                        foregroundColor: const Color(0xFF1A1206),
                      ),
                      icon: _dangGui
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send, size: 18),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BongTin extends StatelessWidget {
  const _BongTin({required this.tin});
  final TinHoTro tin;

  @override
  Widget build(BuildContext context) {
    // Tin của nhân viên nằm bên trái, tin của mình bên phải — quy ước giống
    // hộp trò chuyện với Reader, để người dùng không phải học lại.
    final trai = tin.cuaNhanVien;
    return Align(
      alignment: trai ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: trai ? const Color(0xFF241F33) : const Color(0xFF3A3218),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment:
              trai ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            if (trai && tin.nguoiGui.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(tin.nguoiGui,
                    style:
                        const TextStyle(fontSize: 10.5, color: Mau.vang)),
              ),
            Text(tin.noiDung,
                style: const TextStyle(fontSize: 13.5, height: 1.5)),
            if (tin.luc != null) ...[
              const SizedBox(height: 4),
              Text(Dinh.ngayGio(tin.luc),
                  style: const TextStyle(fontSize: 9.5, color: Mau.chuMo)),
            ],
          ],
        ),
      ),
    );
  }
}
