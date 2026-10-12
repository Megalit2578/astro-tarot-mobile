import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/api/trang.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/config.dart';
import '../../theme.dart';
import '../../widgets/hop_thoai.dart';

/// Năm trạng thái của một bài viết, đúng theo `BlogStatus` bên backend.
///
/// Thứ tự ở đây là thứ tự một bài đi qua, nên bộ lọc đọc theo chiều tự nhiên:
/// viết nháp → gửi duyệt → được duyệt (hoặc bị từ chối) → xuất bản.
const tenTrangThaiBai = {
  'DRAFT': 'Bản nháp',
  'PENDING': 'Chờ duyệt',
  'APPROVED': 'Đã duyệt',
  'REJECTED': 'Bị từ chối',
  'PUBLISHED': 'Đã xuất bản',
};

/// Lời giải thích ngắn hiện dưới mỗi trạng thái ở màn "Bài của tôi".
///
/// Người viết bài không thuộc máy trạng thái; không nói rõ thì một bài nằm ở
/// APPROVED trông y như đã lên trang, và tác giả ngồi chờ một việc đã xong.
const _giaiThichTrangThai = {
  'DRAFT': 'Chỉ mình bạn thấy. Gửi duyệt để quản lý xem.',
  'PENDING': 'Đang chờ quản lý duyệt. Vẫn sửa được.',
  'APPROVED': 'Đã duyệt, chờ quản lý xuất bản.',
  'REJECTED': 'Sửa theo lý do bên dưới rồi gửi lại.',
  'PUBLISHED': 'Đã lên trang Bài viết, ai cũng đọc được.',
};

String giaiThichTrangThaiBai(String t) => _giaiThichTrangThai[t] ?? '';

/// Người gửi bài còn sửa được khi bài ở ba trạng thái này.
///
/// Khớp đúng `BlogServiceImpl.update`: DRAFT, PENDING, REJECTED. Bày nút Sửa
/// trên một bài đã xuất bản là hứa một việc máy chủ sẽ từ chối.
bool suaDuocBai(String trangThai) =>
    trangThai == 'DRAFT' || trangThai == 'PENDING' || trangThai == 'REJECTED';

/// Gửi duyệt được từ DRAFT và REJECTED — khớp `submitForReview`.
bool guiDuyetDuoc(String trangThai) =>
    trangThai == 'DRAFT' || trangThai == 'REJECTED';

/// Tác giả chỉ tự xoá được bản nháp của mình — khớp `delete`.
bool tacGiaXoaDuoc(String trangThai) => trangThai == 'DRAFT';

/// Một bài viết nhìn từ phía người viết hoặc người duyệt.
///
/// Khác [BaiViet] ở `blog_screen.dart`: bản công khai chỉ cần những gì để
/// đọc, bản này cần thêm trạng thái, người duyệt và lý do từ chối.
class BaiVietQuanTri {
  const BaiVietQuanTri({
    required this.id,
    required this.tieuDe,
    required this.slug,
    required this.trangThai,
    this.tomTat,
    this.noiDung,
    this.anh,
    this.tacGia,
    this.nguoiDuyet,
    this.lyDoTuChoi,
    this.taoLuc,
    this.suaLuc,
  });

  final String id;
  final String tieuDe;
  final String slug;
  final String trangThai;
  final String? tomTat;
  final String? noiDung;
  final String? anh;
  final String? tacGia;
  final String? nguoiDuyet;
  final String? lyDoTuChoi;
  final DateTime? taoLuc;
  final DateTime? suaLuc;

  String? get anhDayDu => AppConfig.anh(anh);

  String get tenTrangThai => tenTrangThaiBai[trangThai] ?? trangThai;

  static String? _ten(dynamic v) {
    if (v is! Map) return null;
    return chuoi(v['fullName']) ?? chuoi(v['username']);
  }

  factory BaiVietQuanTri.fromJson(Map<String, dynamic> j) => BaiVietQuanTri(
        id: (j['id'] ?? '').toString(),
        tieuDe: (j['title'] ?? '') as String,
        slug: (j['slug'] ?? '') as String,
        trangThai: (j['status'] ?? 'DRAFT').toString(),
        tomTat: chuoi(j['summary']),
        noiDung: chuoi(j['content']),
        anh: chuoi(j['thumbnailUrl']),
        tacGia: _ten(j['author']),
        nguoiDuyet: _ten(j['reviewer']),
        lyDoTuChoi: chuoi(j['rejectionReason']),
        taoLuc: thoiDiem(j['createdAt']),
        suaLuc: thoiDiem(j['updatedAt']),
      );
}

Color mauTrangThaiBai(String t) => switch (t) {
      'PENDING' => MauTrangThai.cho,
      'APPROVED' => MauTrangThai.xanh,
      'REJECTED' => MauTrangThai.xau,
      'PUBLISHED' => MauTrangThai.tot,
      _ => Mau.chuMo,
    };

/// Đường dẫn bài viết, sinh từ tiêu đề tiếng Việt.
///
/// Bản sao của `slugifyVietnamese` bên web, và phải giữ giống hệt: hai bên
/// sinh slug khác nhau thì cùng một tiêu đề cho ra hai đường dẫn, mà slug là
/// khoá duy nhất — bài thứ hai sẽ bị máy chủ từ chối với một thông báo không
/// ai hiểu.
///
/// Bỏ dấu thủ công chứ không dùng chuẩn hoá Unicode: `đ` không phải là `d` có
/// dấu, nên tách dấu kiểu NFD vẫn để lại `đ` nguyên vẹn rồi bị `[^a-z0-9]`
/// xoá mất — "đường" thành "ung".
String tiengVietThanhSlug(String s) {
  var r = s.toLowerCase();
  const bang = {
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };
  for (final e in bang.entries) {
    r = r.replaceAll(RegExp('[${e.value}]'), e.key);
  }
  r = r.replaceAll(RegExp(r'[^a-z0-9\s-]'), '');
  r = r.replaceAll(RegExp(r'[\s-]+'), '-');
  r = r.replaceAll(RegExp(r'^-+|-+$'), '');
  return r.length > 255 ? r.substring(0, 255) : r;
}

/// Gọi API bài viết cho cả hai phía: người viết và người duyệt.
class BlogRepository {
  BlogRepository(this._api);
  final ApiClient _api;

  // ---- Phía người viết (quyền BLOG_CREATE) ----

  Future<Trang<BaiVietQuanTri>> cuaToi({
    String trangThai = '',
    int trang = 0,
  }) async {
    final d = await _api.get<dynamic>(Endpoints.blogsCuaToi, query: {
      'page': trang,
      'size': 20,
      if (trangThai.isNotEmpty) 'status': trangThai,
    });
    return Trang.tu(d, BaiVietQuanTri.fromJson);
  }

  Future<BaiVietQuanTri> tao({
    required String tieuDe,
    required String slug,
    required String noiDung,
    String? tomTat,
    String? anh,
  }) async {
    final d = await _api.post<Map<String, dynamic>>(
      Endpoints.blogSoan,
      body: {
        'title': tieuDe,
        'slug': slug,
        'content': noiDung,
        if (tomTat != null && tomTat.isNotEmpty) 'summary': tomTat,
        if (anh != null && anh.isNotEmpty) 'thumbnailUrl': anh,
      },
    );
    return BaiVietQuanTri.fromJson(d);
  }

  /// Sửa bài. Gửi cả những trường để trống: `UpdateBlogRequest` không có
  /// `@NotBlank`, nên bỏ hẳn khoá ra khỏi body là "không đổi trường này", còn
  /// gửi chuỗi rỗng mới là "xoá nó đi" — người dùng xoá ảnh bìa phải ra được
  /// kết quả thứ hai.
  Future<BaiVietQuanTri> sua(
    String id, {
    required String tieuDe,
    required String slug,
    required String noiDung,
    String tomTat = '',
    String anh = '',
  }) async {
    final d = await _api.put<Map<String, dynamic>>(
      Endpoints.blogSua(id),
      body: {
        'title': tieuDe,
        'slug': slug,
        'content': noiDung,
        'summary': tomTat,
        'thumbnailUrl': anh,
      },
    );
    return BaiVietQuanTri.fromJson(d);
  }

  Future<void> guiDuyet(String id) =>
      _api.patch<dynamic>(Endpoints.blogGuiDuyet(id));

  Future<void> xoaBaiCuaToi(String id) =>
      _api.delete<dynamic>(Endpoints.blogSua(id));

  // ---- Phía người duyệt (quyền BLOG_REVIEW) ----

  Future<Trang<BaiVietQuanTri>> tatCa({
    String trangThai = '',
    int trang = 0,
  }) async {
    final d = await _api.get<dynamic>(Endpoints.blogsTatCa, query: {
      'page': trang,
      'size': 20,
      if (trangThai.isNotEmpty) 'status': trangThai,
    });
    return Trang.tu(d, BaiVietQuanTri.fromJson);
  }

  Future<void> duyet(String id) => _api.patch<dynamic>(
        Endpoints.blogDuyet(id),
        body: {'action': 'APPROVED'},
      );

  Future<void> tuChoi(String id, String lyDo) => _api.patch<dynamic>(
        Endpoints.blogDuyet(id),
        body: {'action': 'REJECTED', 'rejectionReason': lyDo},
      );

  Future<void> xuatBan(String id) =>
      _api.patch<dynamic>(Endpoints.blogXuatBan(id));

  Future<void> xoaBaiBatKy(String id) =>
      _api.delete<dynamic>(Endpoints.blogXoa(id));
}

final blogRepositoryProvider = Provider<BlogRepository>(
  (ref) => BlogRepository(ref.watch(apiClientProvider)),
);
