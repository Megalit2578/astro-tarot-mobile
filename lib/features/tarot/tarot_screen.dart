import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../theme.dart';
import '../astrology/astrology_screen.dart';
import '../home/home_repository.dart';
import 'hoi_tiep.dart';
import 'tarot_repository.dart';

/// Trải bài Tarot bằng AI.
///
/// Một màn duy nhất: đặt câu hỏi → chọn kiểu trải → nhận lời giải. Không tách
/// thành nhiều bước: cả việc chỉ có ba lựa chọn, mà chia ba màn thì người
/// dùng phải bấm tới lui để đổi ý.
class TarotScreen extends ConsumerStatefulWidget {
  const TarotScreen({super.key});

  @override
  ConsumerState<TarotScreen> createState() => _TarotScreenState();
}

class _TarotScreenState extends ConsumerState<TarotScreen> {
  final _cauHoi = TextEditingController();
  int _soLa = 3;
  bool _coNguoc = true;
  bool _dangTrai = false;
  String? _loi;
  KetQuaTraiBai? _ketQua;

  /// Ba kiểu trải phổ biến. Tên gửi lên máy chủ, mô tả để người dùng chọn
  /// đúng cái mình cần thay vì đoán theo số lá.
  static const _kieu = [
    (so: 1, ten: 'Một lá', moTa: 'Câu trả lời ngắn cho một câu hỏi rõ ràng'),
    (so: 3, ten: 'Ba lá', moTa: 'Quá khứ · Hiện tại · Tương lai'),
    (so: 5, ten: 'Năm lá', moTa: 'Nhìn sâu hơn: nguyên nhân, trở ngại, lời khuyên'),
  ];

  @override
  void dispose() {
    _cauHoi.dispose();
    super.dispose();
  }

  Future<void> _trai() async {
    final q = _cauHoi.text.trim();
    if (q.isEmpty) {
      setState(() => _loi = 'Hãy đặt một câu hỏi trước');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _dangTrai = true;
      _loi = null;
      _ketQua = null;
    });
    try {
      final kq = await ref.read(tarotRepositoryProvider).trai(
            cauHoi: q,
            soLa: _soLa,
            kieuTrai: _kieu.firstWhere((k) => k.so == _soLa).ten,
            coNguoc: _coNguoc,
          );
      if (!mounted) return;
      setState(() => _ketQua = kq);
      // Trang chủ có khối "lần trải bài gần đây" — giờ nó đã cũ.
      ref.invalidate(lichSuTraiBaiProvider);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loi = e.message);
    } finally {
      if (mounted) setState(() => _dangTrai = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tarot AI')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const Text(
            'Đặt một câu hỏi cụ thể. "Tôi có nên nhận lời mời làm việc này '
            'không" cho lời giải rõ hơn hẳn "tương lai tôi ra sao".',
            style: TextStyle(color: Mau.chuMo, fontSize: 12.5, height: 1.6),
          ),
          // Web bắt khai ngày giờ nơi sinh trước khi trải. Ở đây không chặn —
          // trải bài vẫn chạy được — nhưng nhắc rõ, vì không có bản đồ sao
          // thì lời giải chung chung hơn hẳn.
          if (ref.watch(banDoSaoProvider).asData != null &&
              ref.watch(banDoSaoProvider).asData!.value == null) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.auto_awesome, color: Mau.vang),
                title: const Text('Khai ngày giờ nơi sinh trước',
                    style: TextStyle(fontSize: 13.5)),
                subtitle: const Text(
                  'Có bản đồ sao thì lời giải bám vào chính bạn thay vì trả '
                  'lời chung chung.',
                  style: TextStyle(fontSize: 11.5, color: Mau.chuMo),
                ),
                trailing: const Icon(Icons.chevron_right, color: Mau.chuMo),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const AstrologyScreen())),
              ),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _cauHoi,
            minLines: 3,
            maxLines: 5,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            enabled: !_dangTrai,
            decoration: const InputDecoration(
              hintText: 'Câu hỏi của bạn…',
              counterText: '',
            ),
          ),

          const SizedBox(height: 14),
          const Text('Kiểu trải',
              style: TextStyle(fontSize: 12, color: Mau.chuMo)),
          const SizedBox(height: 8),
          for (final k in _kieu)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _dangTrai ? null : () => setState(() => _soLa = k.so),
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: _soLa == k.so
                        ? Mau.vang.withValues(alpha: 0.12)
                        : Mau.the,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _soLa == k.so ? Mau.vang : Mau.vien),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _soLa == k.so
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: _soLa == k.so ? Mau.vang : Mau.chuMo,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(k.ten,
                                style: const TextStyle(fontSize: 13.5)),
                            const SizedBox(height: 2),
                            Text(k.moTa,
                                style: const TextStyle(
                                    fontSize: 11.5, color: Mau.chuMo)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          SwitchListTile(
            value: _coNguoc,
            onChanged: _dangTrai ? null : (v) => setState(() => _coNguoc = v),
            contentPadding: EdgeInsets.zero,
            activeThumbColor: Mau.vang,
            title: const Text('Cho phép bài ngược',
                style: TextStyle(fontSize: 13.5)),
            subtitle: const Text(
              'Bài ngược đổi hẳn nghĩa của lá bài. Tắt đi nếu bạn mới bắt đầu.',
              style: TextStyle(fontSize: 11.5, color: Mau.chuMo, height: 1.5),
            ),
          ),

          if (_loi != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x22E5645E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x55E5645E)),
              ),
              child: Text(_loi!, style: const TextStyle(fontSize: 13)),
            ),
          ],

          const SizedBox(height: 16),
          FilledButton(
            onPressed: _dangTrai ? null : _trai,
            child: _dangTrai
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 12),
                      Text('Đang trải bài…'),
                    ],
                  )
                : const Text('Trải bài'),
          ),
          if (_dangTrai) ...[
            const SizedBox(height: 10),
            // Nói rõ là chậm, và nói TRƯỚC. Không nói thì người dùng tưởng
            // treo, bấm lại — mà mỗi lần bấm là một lượt gọi mô hình tính phí.
            const Text(
              'Lời giải do mô hình ngôn ngữ viết nên có thể mất vài chục '
              'giây. Đừng bấm lại, cứ chờ nhé.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: Mau.chuMo, height: 1.6),
            ),
          ],

          if (_ketQua != null) ...[
            const SizedBox(height: 28),
            _KetQua(kq: _ketQua!),
            if (_ketQua!.id.isNotEmpty) ...[
              const SizedBox(height: 24),
              HoiTiep(
                  key: ValueKey(_ketQua!.id), readingId: _ketQua!.id),
            ],
          ],
        ],
      ),
    );
  }
}

class _KetQua extends StatelessWidget {
  const _KetQua({required this.kq});
  final KetQuaTraiBai kq;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          kq.cauHoi,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        if (kq.luc != null) ...[
          const SizedBox(height: 4),
          Text(Dinh.ngayGio(kq.luc),
              style: const TextStyle(fontSize: 11, color: Mau.chuMo)),
        ],

        if (kq.cacLa.isNotEmpty) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kq.cacLa.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _TheLa(la: kq.cacLa[i]),
            ),
          ),
        ],

        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Mau.the,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Mau.vien),
          ),
          child: Text(
            kq.loiGiai.isEmpty
                ? 'Mô hình không trả về lời giải nào.'
                : kq.loiGiai,
            style: const TextStyle(fontSize: 13.5, height: 1.75),
          ),
        ),

        const SizedBox(height: 14),
        // Nhắc trách nhiệm. Đây là sản phẩm bói toán bằng AI; không nói rõ là
        // để người dùng hiểu nhầm nó là lời khuyên chuyên môn.
        const Text(
          'Lời giải do AI viết, mang tính tham khảo và giải trí. Với các quyết '
          'định về sức khoẻ, pháp lý hay tài chính, hãy hỏi người có chuyên môn.',
          style: TextStyle(fontSize: 11, color: Mau.chuMo, height: 1.6),
        ),
      ],
    );
  }
}

class _TheLa extends StatelessWidget {
  const _TheLa({required this.la});
  final LaBai la;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Mau.the,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Mau.vien),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${la.viTri}',
                  style: const TextStyle(fontSize: 10, color: Mau.chuMo)),
              const Spacer(),
              if (la.nguoc)
                const Icon(Icons.swap_vert, size: 13, color: Mau.vang),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              la.ten,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, height: 1.35),
            ),
          ),
          if (la.nguoc)
            const Text('ngược',
                style: TextStyle(fontSize: 10, color: Mau.vang))
          else if (la.bo != null)
            Text(la.bo!,
                style: const TextStyle(fontSize: 10, color: Mau.chuMo)),
        ],
      ),
    );
  }
}
