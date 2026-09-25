import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/format.dart';
import '../../theme.dart';
import 'booking.dart';
import 'call_controller.dart';
import 'call_panel.dart';
import 'message.dart';

/// Hộp trao đổi của một buổi tư vấn.
///
/// Gửi đi bằng WebSocket trước, rớt thì lùi về REST. Không phải cầu toàn:
/// máy chủ chạy gói free nên khởi động lại thường xuyên, và 4G chuyển trạm
/// cũng làm đứt socket. Chỉ có một đường thì mỗi lần đứt là người dùng gõ
/// xong bấm gửi và không có gì xảy ra — không lỗi, không gửi được, không hiểu
/// vì sao.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.booking});

  final Booking booking;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _o = TextEditingController();
  final _cuon = ScrollController();

  List<TinNhan> _ds = [];
  bool _dangTai = true;
  bool _dangGui = false;
  String? _loi;
  VoidCallback? _huyNghe;
  CallController? _goi;

  String get _bookingId => widget.booking.id;

  @override
  void initState() {
    super.initState();
    _tai();
    _nghe();
    _dungBoGoi();
  }

  Future<void> _dungBoGoi() async {
    final c = CallController(
      bookingId: _bookingId,
      api: ref.read(apiClientProvider),
      realtime: ref.read(realtimeProvider),
    );
    await c.khoiTaoRenderer();
    if (!mounted) {
      c.dispose();
      return;
    }
    setState(() => _goi = c);
  }

  @override
  void dispose() {
    // Dọn cuộc gọi TRƯỚC mọi thứ khác: rời màn hình mà quên tắt là đèn camera
    // vẫn sáng, và người dùng tưởng bị quay lén.
    _goi?.dispose();
    _huyNghe?.call();
    _o.dispose();
    _cuon.dispose();
    super.dispose();
  }

  Future<void> _tai() async {
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get<Map<String, dynamic>>(
        Endpoints.bookingMessages(_bookingId),
        query: {'page': 0, 'size': 50},
      );
      final content = data['content'];
      final ds = content is List
          ? content
              .whereType<Map<String, dynamic>>()
              .map(TinNhan.fromJson)
              .toList()
          : <TinNhan>[];
      if (!mounted) return;
      setState(() {
        // Máy chủ trả MỚI NHẤT TRƯỚC cho tiện phân trang; màn hình cần ngược
        // lại, cũ ở trên mới ở dưới.
        _ds = ds.reversed.toList();
        _dangTai = false;
      });
      _xuongDay();
      _danhDauDaDoc();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loi = e.message;
        _dangTai = false;
      });
    }
  }

  void _nghe() {
    final rt = ref.read(realtimeProvider);
    _huyNghe = rt.nghe(Endpoints.queueChat, (body) {
      if (body['bookingId'] != _bookingId) return;
      final m = TinNhan.fromJson(body);
      if (!mounted) return;
      setState(() {
        // Máy chủ đẩy cho CẢ người gửi, nên cùng một tin có thể tới hai lần
        // khi mở hai thiết bị. Lọc theo id.
        if (_ds.any((x) => x.id == m.id)) return;
        _ds = [..._ds, m];
      });
      _xuongDay();
    });
  }

  Future<void> _danhDauDaDoc() async {
    try {
      await ref
          .read(apiClientProvider)
          .post(Endpoints.bookingMessagesRead(_bookingId));
    } catch (_) {
      // Đánh dấu đã đọc hỏng không ảnh hưởng gì tới việc đọc tin.
    }
  }

  void _xuongDay() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_cuon.hasClients) return;
      _cuon.animateTo(
        _cuon.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _gui() async {
    final noiDung = _o.text.trim();
    if (noiDung.isEmpty || _dangGui) return;

    setState(() => _dangGui = true);
    final rt = ref.read(realtimeProvider);
    final quaSocket = rt.gui(Endpoints.stompChat(_bookingId), {'body': noiDung});

    try {
      if (!quaSocket) {
        await ref.read(apiClientProvider).post(
              Endpoints.bookingMessages(_bookingId),
              body: {'body': noiDung},
            );
        // Đường REST không dội lại qua socket khi socket đang đứt, nên phải
        // tự tải lại để thấy tin của chính mình.
        await _tai();
      }
      _o.clear();
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
    final toi = ref.watch(authControllerProvider).user;
    final rt = ref.watch(realtimeProvider);
    final doiPhuong = toi?.id == widget.booking.customerId
        ? widget.booking.readerName
        : widget.booking.customerName;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(doiPhuong, style: const TextStyle(fontSize: 16)),
            ValueListenableBuilder<bool>(
              valueListenable: rt.dangNoi,
              builder: (_, noi, _) => Row(
                children: [
                  Icon(
                    noi ? Icons.wifi : Icons.wifi_off,
                    size: 11,
                    color: noi ? const Color(0xFF6BBF7B) : Mau.chuMo,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    noi ? 'Đang kết nối tức thời' : 'Mất kết nối tức thời',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: noi ? const Color(0xFF6BBF7B) : Mau.chuMo,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (widget.booking.chatMo && _goi != null) ...[
            IconButton(
              onPressed: () => _goi!.goi(video: false),
              tooltip: 'Gọi thoại',
              icon: const Icon(Icons.call, size: 20),
            ),
            IconButton(
              onPressed: () => _goi!.goi(video: true),
              tooltip: 'Gọi video',
              icon: const Icon(Icons.videocam, size: 20),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          if (_goi != null)
            ListenableBuilder(
              listenable: _goi!,
              builder: (_, _) => Column(
                children: [
                  CallPanel(c: _goi!),
                  // Cảnh báo trước khi gọi, không phải sau khi thất bại.
                  // Dự án chạy chỉ STUN nên hai máy cùng sau NAT đối xứng sẽ
                  // không nối được — để người dùng biết trước còn hơn ngồi
                  // nhìn "đang kết nối" cho tới khi hết giờ.
                  if (!_goi!.coTurn && _goi!.trangThai == TrangThaiGoi.rong)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      color: const Color(0x18E0B341),
                      child: const Text(
                        'Cuộc gọi chỉ chạy khi hai bên cùng mạng wifi thông '
                        'thường. Dùng 4G có thể không nối được — nhắn tin vẫn '
                        'bình thường.',
                        style: TextStyle(fontSize: 10.5, height: 1.5),
                      ),
                    ),
                ],
              ),
            ),
          if (!widget.booking.chatMo)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              color: const Color(0x22E0B341),
              child: const Text(
                'Hội thoại đã đóng. Bạn vẫn đọc lại được, nhưng không gửi '
                'thêm tin.',
                style: TextStyle(fontSize: 11.5, height: 1.5),
              ),
            ),
          Expanded(child: _than(toi?.id)),
          if (widget.booking.chatMo) _oNhap(),
        ],
      ),
    );
  }

  Widget _than(String? toiId) {
    if (_dangTai) {
      return const Center(
        child: SizedBox(
          height: 22,
          width: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: Mau.vang),
        ),
      );
    }
    if (_loi != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loi!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _loi = null;
                    _dangTai = true;
                  });
                  _tai();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Mau.vang,
                  side: const BorderSide(color: Mau.vien),
                ),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }
    if (_ds.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Chưa có tin nhắn nào. Nhắn một câu để bắt đầu.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Mau.chuMo, fontSize: 13),
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _cuon,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      itemCount: _ds.length,
      itemBuilder: (_, i) {
        final m = _ds[i];
        return _BongBong(tin: m, cuaToi: m.senderId == toiId);
      },
    );
  }

  Widget _oNhap() {
    return Container(
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
                hintText: 'Nhắn gì đó…',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 44,
            width: 44,
            child: IconButton.filled(
              onPressed: _dangGui ? null : _gui,
              style: IconButton.styleFrom(
                backgroundColor: Mau.vang,
                foregroundColor: const Color(0xFF1A1206),
              ),
              icon: _dangGui
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _BongBong extends StatelessWidget {
  const _BongBong({required this.tin, required this.cuaToi});

  final TinNhan tin;
  final bool cuaToi;

  @override
  Widget build(BuildContext context) {
    final gio = Dinh.ngayGio(tin.taoLuc);
    return Align(
      alignment: cuaToi ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.76,
        ),
        decoration: BoxDecoration(
          color: cuaToi ? const Color(0xFF3A3218) : const Color(0xFF241F33),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(cuaToi ? 14 : 4),
            bottomRight: Radius.circular(cuaToi ? 4 : 14),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              cuaToi ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(tin.body,
                style: const TextStyle(fontSize: 13.5, height: 1.45)),
            // Dấu thời gian chỉ hiện khi CÓ. Rỗng nghĩa là gói đẩy thiếu
            // createdAt — thà trống còn hơn vẽ ra mốc 1970.
            if (gio.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                cuaToi && tin.daDoc ? '$gio · đã xem' : gio,
                style: const TextStyle(fontSize: 9.5, color: Mau.chuMo),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
