import 'package:flutter/material.dart';

import '../../theme.dart';

/// Màn hình chưa dựng.
///
/// Cố ý ghi rõ nó SẼ gọi endpoint nào, thay vì để một chữ "Coming soon".
/// Khung dự án này là bản đồ công việc: mở app ra là thấy còn thiếu gì và
/// phần nào của backend đã sẵn sàng phục vụ nó. Toàn bộ endpoint liệt kê ở
/// đây đều đã tồn tại — phần còn lại chỉ là dựng giao diện.
class ChuaLam extends StatelessWidget {
  const ChuaLam({
    super.key,
    required this.ten,
    required this.moTa,
    this.endpoints = const [],
  });

  final String ten;
  final String moTa;
  final List<String> endpoints;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(ten)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Mau.the,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Mau.vien),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.construction, size: 18, color: Mau.vang),
                    const SizedBox(width: 8),
                    Text(
                      'Chưa dựng giao diện',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(color: Mau.vang),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  moTa,
                  style: const TextStyle(
                      color: Mau.chuMo, fontSize: 13, height: 1.6),
                ),
              ],
            ),
          ),
          if (endpoints.isNotEmpty) ...[
            const SizedBox(height: 22),
            const Text(
              'Backend đã sẵn sàng',
              style: TextStyle(fontSize: 12, color: Mau.chuMo),
            ),
            const SizedBox(height: 10),
            for (final e in endpoints)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F16),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x22D4AF37)),
                  ),
                  child: Text(
                    e,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                      color: Mau.vangNhat,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
