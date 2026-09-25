import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/endpoints.dart';
import '../../core/api/trang.dart';
import '../../core/auth/auth_controller.dart';
import '../../theme.dart';
import '../../widgets/hop_thoai.dart';

/// Trạng thái khảo sát của chính mình.
class TinhTrangGopY {
  const TinhTrangGopY({
    required this.daGui,
    required this.tong,
    required this.mucTieu,
  });

  final bool daGui;
  final int tong;
  final int mucTieu;

  factory TinhTrangGopY.fromJson(Map<String, dynamic> j) => TinhTrangGopY(
        daGui: j['submitted'] == true,
        tong: soNguyen(j['total']) ?? 0,
        mucTieu: soNguyen(j['goal']) ?? 20,
      );
}

/// null khi không đọc được (backend cũ, mạng hỏng) — lúc đó cứ cho góp ý.
final tinhTrangGopYProvider = FutureProvider<TinhTrangGopY?>((ref) async {
  try {
    final d = await ref
        .watch(apiClientProvider)
        .get<Map<String, dynamic>>(Endpoints.feedbackStatus);
    return TinhTrangGopY.fromJson(d);
  } catch (_) {
    return null;
  }
});

/// Khảo sát ngắn (NPS), khớp nút "Góp ý" của web.
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  int? _nps;
  int? _sao;
  final _gopY = TextEditingController();
  bool _dangGui = false;

  @override
  void dispose() {
    _gopY.dispose();
    super.dispose();
  }

  Future<void> _gui() async {
    if (_nps == null) {
      baoTin(context, 'Chọn điểm từ 0 đến 10 trước.');
      return;
    }
    setState(() => _dangGui = true);
    try {
      await ref.read(apiClientProvider).post(Endpoints.feedback, body: {
        // Cùng nguồn GENERAL như nút góp ý chung của web; utmSource bên dưới
        // mới là thứ tách được phản hồi từ app khi đếm.
        'source': 'GENERAL',
        'nps': _nps,
        'rating': _sao,
        'comment': _gopY.text.trim().isEmpty ? null : _gopY.text.trim(),
        'utmSource': 'mobile_app',
      });
      ref.invalidate(tinhTrangGopYProvider);
      if (!mounted) return;
      baoTin(context, 'Cảm ơn bạn — phản hồi đã được ghi nhận.');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) baoLoi(context, e, 'Không gửi được phản hồi.');
    } finally {
      if (mounted) setState(() => _dangGui = false);
    }
  }

  Widget _o(int so, bool chon, VoidCallback bam) => InkWell(
        key: ValueKey('o-diem-$so-$chon'),
        onTap: bam,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: chon ? Mau.vang : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: chon ? Mau.vang : Mau.vien),
          ),
          child: Text('$so',
              style: TextStyle(
                  fontWeight: chon ? FontWeight.w600 : FontWeight.w400,
                  color: chon ? const Color(0xFF1A1206) : Mau.chu)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final tt = ref.watch(tinhTrangGopYProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Góp ý')),
      body: tt?.daGui == true
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Text(
                  'Bạn đã gửi phản hồi rồi — cảm ơn bạn đã giúp chúng tôi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, height: 1.6),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                const Text('ASTROTAROT có giúp bạn không?',
                    style: TextStyle(fontSize: 18)),
                const SizedBox(height: 18),
                const Text(
                  'Bạn có sẵn sàng giới thiệu ASTROTAROT cho bạn bè? '
                  '(0 = không, 10 = chắc chắn)',
                  style: TextStyle(fontSize: 13.5, height: 1.5),
                ),
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (var i = 0; i <= 10; i++)
                    _o(i, _nps == i, () => setState(() => _nps = i)),
                ]),
                const SizedBox(height: 20),
                const Text('Đánh giá trải nghiệm (tuỳ chọn)',
                    style: TextStyle(fontSize: 13.5)),
                const SizedBox(height: 10),
                Wrap(spacing: 6, children: [
                  for (var i = 1; i <= 5; i++)
                    _o(i, _sao == i, () => setState(() => _sao = i)),
                ]),
                const SizedBox(height: 20),
                TextField(
                  controller: _gopY,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                      hintText: 'Góp ý thêm (tuỳ chọn): điều gì nên cải thiện?'),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _dangGui ? null : _gui,
                  child: Text(_dangGui ? 'Đang gửi…' : 'Gửi phản hồi'),
                ),
              ],
            ),
    );
  }
}
