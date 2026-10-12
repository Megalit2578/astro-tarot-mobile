import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../theme.dart';
import '../../widgets/hop_thoai.dart';
import 'blog_repository.dart';

/// Viết bài mới hoặc sửa bài đã có.
///
/// Một màn cho cả hai việc: form giống hệt nhau, và tách đôi chỉ để đổi một
/// lời gọi API là hai file phải sửa song song mỗi lần backend thêm trường.
///
/// Trả về `true` qua `Navigator.pop` khi có thay đổi cần tải lại danh sách.
class SoanBaiScreen extends ConsumerStatefulWidget {
  const SoanBaiScreen({super.key, this.bai});

  /// Null nghĩa là viết mới.
  final BaiVietQuanTri? bai;

  @override
  ConsumerState<SoanBaiScreen> createState() => _SoanBaiScreenState();
}

class _SoanBaiScreenState extends ConsumerState<SoanBaiScreen> {
  final _form = GlobalKey<FormState>();
  late final _tieuDe = TextEditingController(text: widget.bai?.tieuDe ?? '');
  late final _slug = TextEditingController(text: widget.bai?.slug ?? '');
  late final _tomTat = TextEditingController(text: widget.bai?.tomTat ?? '');
  late final _noiDung = TextEditingController(text: widget.bai?.noiDung ?? '');
  late final _anh = TextEditingController(text: widget.bai?.anh ?? '');

  /// Bài mới thì slug chạy theo tiêu đề; bài cũ thì KHÔNG.
  ///
  /// Slug của một bài đã xuất bản là địa chỉ người ta đã dán đi nơi khác. Sửa
  /// một chữ trong tiêu đề mà âm thầm đổi cả địa chỉ là làm hỏng mọi liên kết
  /// ấy, nên với bài cũ người viết phải tự bấm mới đổi được.
  late bool _slugTuDong = widget.bai == null;

  bool _dangLuu = false;
  String? _loi;

  bool get _laBaiMoi => widget.bai == null;

  @override
  void dispose() {
    _tieuDe.dispose();
    _slug.dispose();
    _tomTat.dispose();
    _noiDung.dispose();
    _anh.dispose();
    super.dispose();
  }

  void _doiTieuDe(String v) {
    if (!_slugTuDong) return;
    final moi = tiengVietThanhSlug(v);
    if (moi == _slug.text) return;
    _slug.text = moi;
  }

  /// Lưu bài. [guiLuon] = lưu xong thì gửi đi duyệt ngay.
  Future<void> _luu({required bool guiLuon}) async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _dangLuu = true;
      _loi = null;
    });
    final repo = ref.read(blogRepositoryProvider);
    try {
      final tieuDe = _tieuDe.text.trim();
      final slug = _slug.text.trim();
      final noiDung = _noiDung.text.trim();
      final tomTat = _tomTat.text.trim();
      final anh = _anh.text.trim();

      final BaiVietQuanTri da;
      if (_laBaiMoi) {
        da = await repo.tao(
          tieuDe: tieuDe,
          slug: slug,
          noiDung: noiDung,
          tomTat: tomTat,
          anh: anh,
        );
      } else {
        da = await repo.sua(
          widget.bai!.id,
          tieuDe: tieuDe,
          slug: slug,
          noiDung: noiDung,
          tomTat: tomTat,
          anh: anh,
        );
      }

      // Gửi duyệt là lời gọi THỨ HAI. Nếu nó hỏng thì bài vẫn đã lưu — nên
      // báo đúng chuyện đó thay vì để người viết tưởng mất cả bài và gõ lại
      // từ đầu.
      if (guiLuon) {
        try {
          await repo.guiDuyet(da.id);
        } catch (e) {
          if (!mounted) return;
          setState(() => _dangLuu = false);
          // KHÔNG dùng `baoLoi`: nó hiện nguyên câu của máy chủ ("Hàng chờ
          // đang khoá"), mà câu ấy không hề nói bài đã lưu hay chưa — người
          // viết đọc xong là đi gõ lại một bài đang nằm an toàn trên máy chủ.
          // Câu máy chủ vẫn giữ, nhưng gắn sau tin quan trọng hơn.
          final vi = e is ApiException ? ' ${e.message}' : '';
          baoTin(
            context,
            'Đã lưu bài nhưng chưa gửi duyệt được.$vi '
            'Thử gửi lại ở danh sách.',
          );
          Navigator.of(context).pop(true);
          return;
        }
      }

      if (!mounted) return;
      baoTin(
        context,
        guiLuon ? 'Đã gửi bài đi duyệt.' : 'Đã lưu bản nháp.',
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _loi = e.message);
    } catch (_) {
      setState(() => _loi = 'Không lưu được bài viết.');
    } finally {
      if (mounted) setState(() => _dangLuu = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bai = widget.bai;
    // Gửi duyệt được từ DRAFT và REJECTED. Bài đang PENDING thì sửa được
    // nhưng không gửi lại — backend đã nhận rồi.
    final hienNutGui = _laBaiMoi || guiDuyetDuoc(bai!.trangThai);

    return Scaffold(
      appBar: AppBar(
        title: Text(_laBaiMoi ? 'Viết bài' : 'Sửa bài'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
          children: [
            if (bai != null && bai.trangThai == 'REJECTED' &&
                (bai.lyDoTuChoi?.isNotEmpty ?? false)) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: MauTrangThai.xau.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: MauTrangThai.xau.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Lý do bị từ chối',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: MauTrangThai.xau)),
                    const SizedBox(height: 6),
                    Text(bai.lyDoTuChoi!,
                        style: const TextStyle(fontSize: 13, height: 1.55)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
            TextFormField(
              key: const ValueKey('o-tieu-de'),
              controller: _tieuDe,
              textInputAction: TextInputAction.next,
              maxLength: 255,
              onChanged: _doiTieuDe,
              decoration: const InputDecoration(
                labelText: 'Tiêu đề',
                hintText: 'Ví dụ: Ba lá bài hay gặp khi hỏi về công việc',
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Chưa có tiêu đề.' : null,
            ),
            const SizedBox(height: 4),
            TextFormField(
              key: const ValueKey('o-slug'),
              controller: _slug,
              maxLength: 255,
              readOnly: _slugTuDong,
              decoration: InputDecoration(
                labelText: 'Đường dẫn',
                helperText: _slugTuDong
                    ? 'Tự sinh theo tiêu đề.'
                    : 'Chỉ chữ thường, số và dấu gạch ngang.',
                suffixIcon: TextButton(
                  onPressed: () => setState(() {
                    _slugTuDong = !_slugTuDong;
                    if (_slugTuDong) _slug.text = tiengVietThanhSlug(_tieuDe.text);
                  }),
                  child: Text(_slugTuDong ? 'Sửa tay' : 'Tự sinh',
                      style: const TextStyle(fontSize: 12)),
                ),
              ),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) {
                  // Tiêu đề toàn ký tự bị lược sạch (chỉ emoji, chỉ dấu câu)
                  // thì slug ra rỗng mà người viết không hiểu vì sao.
                  return 'Đường dẫn trống — thử đổi tiêu đề hoặc gõ tay.';
                }
                if (!RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$').hasMatch(s)) {
                  return 'Chỉ chữ thường không dấu, số và dấu gạch ngang.';
                }
                return null;
              },
            ),
            const SizedBox(height: 4),
            TextFormField(
              key: const ValueKey('o-tom-tat'),
              controller: _tomTat,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Tóm tắt',
                helperText: 'Hiện ở danh sách bài viết. Để trống cũng được.',
              ),
            ),
            const SizedBox(height: 4),
            TextFormField(
              key: const ValueKey('o-anh'),
              controller: _anh,
              maxLength: 500,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Ảnh bìa',
                hintText: 'https://…',
                helperText: 'Dán địa chỉ ảnh. Để trống thì thẻ bài không có ảnh.',
              ),
            ),
            const SizedBox(height: 4),
            TextFormField(
              key: const ValueKey('o-noi-dung'),
              controller: _noiDung,
              minLines: 10,
              maxLines: 30,
              decoration: const InputDecoration(
                labelText: 'Nội dung',
                alignLabelWithHint: true,
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Bài viết chưa có nội dung.' : null,
            ),
            if (_loi != null) ...[
              const SizedBox(height: 14),
              Text(_loi!,
                  style: const TextStyle(
                      fontSize: 12.5, color: MauTrangThai.xau, height: 1.5)),
            ],
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _dangLuu ? null : () => _luu(guiLuon: false),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              child: _dangLuu
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Lưu nháp'),
            ),
            if (hienNutGui) ...[
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _dangLuu ? null : () => _luu(guiLuon: true),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  foregroundColor: Mau.vang,
                  side: const BorderSide(color: Mau.vien),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
                ),
                child: const Text('Lưu và gửi duyệt'),
              ),
              const SizedBox(height: 10),
              const Text(
                'Gửi duyệt rồi bài vẫn sửa được, nhưng quản lý sẽ đọc bản mới '
                'nhất — nên sửa xong hãy báo họ.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: Mau.chuMo, height: 1.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
