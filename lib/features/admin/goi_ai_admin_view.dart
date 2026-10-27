import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../theme.dart';
import '../../widgets/trang_thai.dart';
import 'admin_repository.dart';

/// Một gói AI bán cho người dùng.
class GoiAi {
  const GoiAi({
    required this.id,
    required this.ten,
    required this.hanMucNgay,
    required this.gia,
    required this.soNgay,
    required this.dangBan,
    required this.moTa,
  });

  final String id;
  final String ten;
  final int hanMucNgay;
  final int gia;
  final int soNgay;
  final bool dangBan;
  final String? moTa;

  /// Gói miễn phí được đặt thời hạn 36500 ngày (100 năm) để nghĩa là "mãi
  /// mãi". In thẳng con số ấy ra thì người đọc phải tự nhẩm 36500 chia 365 —
  /// và dễ tưởng là lỗi nhập liệu.
  String get moTaThoiHan =>
      soNgay >= 3650 ? 'không giới hạn' : '$soNgay ngày';

  factory GoiAi.fromJson(Map<String, dynamic> j) => GoiAi(
    id: (j['id'] ?? '').toString(),
    ten: (j['name'] ?? '') as String,
    hanMucNgay: (j['dailyQuota'] as num?)?.toInt() ?? 0,
    gia: (j['price'] as num?)?.toInt() ?? 0,
    soNgay: (j['durationDays'] as num?)?.toInt() ?? 0,
    // Máy chủ trả `isActive`; Jackson có thể đặt tên `active` tuỳ cấu hình,
    // nên nhận cả hai thay vì đoán một.
    dangBan: (j['isActive'] ?? j['active']) == true,
    moTa: j['description'] as String?,
  );
}

String _tien(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return '$b ₫';
}

final goiAiAdminProvider = FutureProvider<List<GoiAi>>(
  (ref) => ref.read(adminRepositoryProvider).goiAi(),
);

/// Gói AI: xem, sửa hạn mức và giá, bật hoặc ngừng bán.
///
/// ## Vì sao không có nút xoá
///
/// Backend không có endpoint xoá gói — và đúng như vậy: người đã mua một gói
/// thì bản ghi mua hàng của họ trỏ tới gói ấy. Xoá đi là làm hỏng lịch sử của
/// người đã trả tiền. Ngừng bán là cách đúng, và đó là thứ công tắc này làm.
class GoiAiAdminView extends ConsumerWidget {
  const GoiAiAdminView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = ref.watch(goiAiAdminProvider);

    return ds.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Mau.vang)),
      error: (e, _) => KhoiLoi(
        thongDiep: e is ApiException
            ? e.message
            : 'Không tải được danh sách gói AI.',
        thuLai: () => ref.invalidate(goiAiAdminProvider),
      ),
      data: (list) => list.isEmpty
          ? const KhoiTrong(
              icon: Icons.workspace_premium_outlined,
              tieuDe: 'Chưa có gói AI nào',
              moTa: 'Gói AI được tạo từ trang quản trị trên web.',
            )
          : RefreshIndicator(
              color: Mau.vang,
              backgroundColor: Mau.the,
              onRefresh: () async => ref.invalidate(goiAiAdminProvider),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: list.length,
                itemBuilder: (_, i) => _TheGoi(g: list[i]),
              ),
            ),
    );
  }
}

class _TheGoi extends ConsumerStatefulWidget {
  const _TheGoi({required this.g});
  final GoiAi g;

  @override
  ConsumerState<_TheGoi> createState() => _TheGoiState();
}

class _TheGoiState extends ConsumerState<_TheGoi> {
  bool _dangGui = false;

  GoiAi get g => widget.g;

  Future<void> _doiTrangThai(bool bat) async {
    setState(() => _dangGui = true);
    try {
      await ref.read(adminRepositoryProvider).suaGoiAi(g.id, {
        'isActive': bat,
      });
      ref.invalidate(goiAiAdminProvider);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _dangGui = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Mau.the,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: g.dangBan ? Mau.vang.withValues(alpha: 0.4) : Mau.vien,
        ),
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
                    color: Mau.chu,
                  ),
                ),
              ),
              Text(
                _tien(g.gia),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Mau.vang,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${g.hanMucNgay} lượt/ngày · ${g.moTaThoiHan}',
            style: const TextStyle(fontSize: 12, color: Mau.chuMo),
          ),
          if (g.moTa != null && g.moTa!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              g.moTa!,
              style: const TextStyle(fontSize: 12, color: Mau.chuMo),
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  g.dangBan ? 'Đang bán' : 'Đã ngừng bán',
                  style: TextStyle(
                    fontSize: 12,
                    color: g.dangBan ? Mau.vang : Mau.chuMo,
                  ),
                ),
              ),
              if (_dangGui)
                const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Mau.vang,
                  ),
                )
              else
                Switch(
                  value: g.dangBan,
                  onChanged: _doiTrangThai,
                  activeThumbColor: Mau.vang,
                ),
              TextButton(
                onPressed: _dangGui ? null : () => _moSua(context),
                style: TextButton.styleFrom(foregroundColor: Mau.vang),
                child: const Text('Sửa', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _moSua(BuildContext context) async {
    final xong = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Mau.the,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _FormGoi(g: g),
    );
    if (xong == true) ref.invalidate(goiAiAdminProvider);
  }
}

class _FormGoi extends ConsumerStatefulWidget {
  const _FormGoi({required this.g});
  final GoiAi g;

  @override
  ConsumerState<_FormGoi> createState() => _FormGoiState();
}

class _FormGoiState extends ConsumerState<_FormGoi> {
  final _khoa = GlobalKey<FormState>();
  late final TextEditingController _hanMuc;
  late final TextEditingController _gia;
  late final TextEditingController _moTa;
  bool _dangLuu = false;
  String? _loi;

  @override
  void initState() {
    super.initState();
    _hanMuc = TextEditingController(text: '${widget.g.hanMucNgay}');
    _gia = TextEditingController(text: '${widget.g.gia}');
    _moTa = TextEditingController(text: widget.g.moTa ?? '');
  }

  @override
  void dispose() {
    _hanMuc.dispose();
    _gia.dispose();
    _moTa.dispose();
    super.dispose();
  }

  Future<void> _luu() async {
    if (!_khoa.currentState!.validate()) return;
    setState(() {
      _dangLuu = true;
      _loi = null;
    });
    try {
      await ref.read(adminRepositoryProvider).suaGoiAi(widget.g.id, {
        'dailyQuota': int.parse(_hanMuc.text.trim()),
        'price': int.parse(_gia.text.trim()),
        'description': _moTa.text.trim().isEmpty ? null : _moTa.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() {
        _dangLuu = false;
        _loi = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _khoa,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sửa ${widget.g.ten}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Mau.chu,
                ),
              ),
              // Số ngày và loại gói KHÔNG sửa được ở đây: backend không nhận
              // chúng trong UpdatePlanRequest, và đổi thời hạn của một gói
              // người ta đã mua là đổi thứ họ đã trả tiền để có.
              const SizedBox(height: 4),
              Text(
                'Thời hạn ${widget.g.moTaThoiHan} — đổi thời hạn phải tạo gói mới.',
                style: const TextStyle(fontSize: 11, color: Mau.chuMo),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _hanMuc,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Lượt mỗi ngày'),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  return (n == null || n <= 0) ? 'Nhập số lớn hơn 0' : null;
                },
              ),
              TextFormField(
                controller: _gia,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Giá (₫)'),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  return (n == null || n < 0) ? 'Nhập số không âm' : null;
                },
              ),
              TextFormField(
                controller: _moTa,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Mô tả'),
              ),
              if (_loi != null) ...[
                const SizedBox(height: 8),
                Text(
                  _loi!,
                  style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _dangLuu ? null : _luu,
                  style: FilledButton.styleFrom(
                    backgroundColor: Mau.vang,
                    foregroundColor: Mau.nen,
                  ),
                  child: _dangLuu
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Lưu'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
