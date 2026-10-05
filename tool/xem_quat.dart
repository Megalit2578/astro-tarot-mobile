// Điểm vào riêng chỉ để NHÌN quạt bài, không phải một phần của app.
//
//   flutter run -t tool/xem_quat.dart
//
// Trang chủ nằm sau màn đăng nhập, nên muốn xem một widget trang trí ở đó thì
// phải đăng nhập trước. Dựng riêng một điểm vào thế này thì xem được ngay,
// trên đúng máy ảo và đúng bộ dựng hình của Flutter — chính xác hơn hẳn việc
// dựng thử bằng HTML rồi đoán là Flutter cũng ra như vậy.
//
// Không dùng `dart_defines/may.json` khi chạy file này: ảnh bài lấy từ web
// thật, mà may.json trỏ WEB_BASE_URL về 10.0.2.2.

import 'package:flutter/material.dart';

import 'package:astrotarot_mobile/theme.dart';
import 'package:astrotarot_mobile/widgets/quat_bai_tarot.dart';
import 'package:astrotarot_mobile/widgets/troi_sao.dart';
import 'package:astrotarot_mobile/features/home/daily_card.dart';

void main() => runApp(const _Xem());

class _Xem extends StatefulWidget {
  const _Xem();

  @override
  State<_Xem> createState() => _XemState();
}

class _XemState extends State<_Xem> {
  LaAnChinh? _chon;

  @override
  Widget build(BuildContext context) {
    final la = _chon;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: NenSao(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                const Text(
                  'Chào Đạt,',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 18,
                  child: Center(
                    child: la == null
                        ? const Text(
                            'Hôm nay bạn muốn hỏi điều gì?',
                            style: TextStyle(color: Mau.chuMo, fontSize: 13),
                          )
                        : Text(
                            '${la.tenVi} · ${la.tuKhoa.first}',
                            style: const TextStyle(
                              color: Mau.vang,
                              fontSize: 13,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 6),
                QuatBaiTarot(onChon: (l) => setState(() => _chon = l)),
                const SizedBox(height: 20),
                // Một thẻ giả để thấy quạt bài nối với phần dưới ra sao.
                Card(
                  child: ListTile(
                    leading: Icon(Icons.auto_awesome, color: Mau.vang),
                    title: const Text('Trải bài với Tarot AI'),
                    subtitle: const Text('Hỏi một câu, nhận lời giải'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
