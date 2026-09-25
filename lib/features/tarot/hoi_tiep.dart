import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme.dart';
import '../../widgets/hop_thoai.dart';
import 'tarot_repository.dart';

/// Hỏi tiếp về một lượt vừa trải — phần trò chuyện với Tarot AI của web.
///
/// Mỗi câu hỏi là một lượt gọi mô hình, chậm và tính phí; nên khoá ô nhập
/// trong lúc chờ, và nói rõ là đang chờ, để người dùng không bấm gửi lại.
class HoiTiep extends ConsumerStatefulWidget {
  const HoiTiep({super.key, required this.readingId});
  final String readingId;

  @override
  ConsumerState<HoiTiep> createState() => _HoiTiepState();
}

class _HoiTiepState extends ConsumerState<HoiTiep> {
  final _o = TextEditingController();
  final _tin = <({bool cuaToi, String noiDung})>[];
  bool _dangCho = false;

  @override
  void dispose() {
    _o.dispose();
    super.dispose();
  }

  Future<void> _gui() async {
    final q = _o.text.trim();
    if (q.isEmpty || _dangCho) return;
    setState(() {
      _tin.add((cuaToi: true, noiDung: q));
      _dangCho = true;
    });
    _o.clear();
    try {
      final tl =
          await ref.read(tarotRepositoryProvider).hoiThem(widget.readingId, q);
      if (!mounted) return;
      setState(() => _tin.add((
            cuaToi: false,
            noiDung: tl.isEmpty ? 'Mô hình không trả lời được câu này.' : tl,
          )));
    } catch (e) {
      if (!mounted) return;
      // Trả lại câu hỏi vào ô nhập để khỏi phải gõ lại.
      setState(() => _tin.removeLast());
      _o.text = q;
      baoLoi(context, e, 'Không gửi được câu hỏi.');
    } finally {
      if (mounted) setState(() => _dangCho = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Hỏi tiếp về lượt này',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text(
          'Muốn hiểu rõ một lá, hay hỏi sâu hơn một ý trong lời giải? Hỏi ở '
          'đây — AI nhớ các lá vừa rút.',
          style: TextStyle(fontSize: 12, color: Mau.chuMo, height: 1.5),
        ),
        const SizedBox(height: 10),
        for (final t in _tin)
          Align(
            alignment: t.cuaToi ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.82),
              decoration: BoxDecoration(
                color: t.cuaToi ? Mau.vang.withValues(alpha: 0.14) : Mau.the,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Mau.vien),
              ),
              child: SelectableText(t.noiDung,
                  style: const TextStyle(fontSize: 13.5, height: 1.6)),
            ),
          ),
        if (_dangCho)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('AI đang suy nghĩ… có thể mất vài chục giây.',
                style: TextStyle(fontSize: 11.5, color: Mau.chuMo)),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('o-hoi-tiep'),
                controller: _o,
                enabled: !_dangCho,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Hỏi thêm…',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Gửi',
              onPressed: _dangCho ? null : _gui,
              style: IconButton.styleFrom(
                backgroundColor: Mau.vang,
                foregroundColor: const Color(0xFF1A1206),
              ),
              icon: const Icon(Icons.send, size: 18),
            ),
          ],
        ),
      ],
    );
  }
}
