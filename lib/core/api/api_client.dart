import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config.dart';
import 'endpoints.dart';
import 'token_store.dart';

/// Lỗi đã dịch sang câu người dùng đọc được.
///
/// Backend trả bao thư `{success, message, data, timestamp}` và `message` đã
/// là tiếng Việt viết cho người dùng cuối. Dùng thẳng nó thay vì tự chế câu
/// mới: hai nơi viết hai kiểu thì cùng một lỗi lại hiện hai câu khác nhau tuỳ
/// đi đường web hay đường app.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.phienHong = false});

  final String message;
  final int? statusCode;

  /// Phiên thật sự chết — phải đăng nhập lại. Khác hẳn "mạng chập chờn".
  final bool phienHong;

  @override
  String toString() => message;
}

/// Tầng gọi API.
///
/// Chép lại ba bài học đã trả giá bên web, đừng bỏ cái nào:
///
/// 1. **Làm mới token phải một-luồng.** Mở một màn hình là bắn vài lời gọi
///    song song; token hết hạn thì tất cả cùng nhận 401 cùng lúc. Mỗi cái tự
///    đi làm mới là backend nhận N lượt, và vì mỗi lượt cấp refresh token mới
///    nên các lượt sau cầm token đã bị thay — đăng xuất ngẫu nhiên, rất khó
///    tái hiện.
///
/// 2. **Coi cả 403 là "có thể hết hạn".** Backend từng trả 403 thân rỗng cho
///    token quá hạn. Chỉ bắt 401 thì giao diện đứng im không hiểu vì sao.
///
/// 3. **Chỉ 401/403 từ chính `/auth/refresh` mới là phiên chết.** Lỗi 5xx hay
///    mất mạng là tạm thời; vứt refresh token vì một khoảng gián đoạn là bắt
///    người dùng đăng nhập lại dù phiên còn sống tới bảy ngày.
class ApiClient {
  ApiClient({required this.tokenStore, this.khiPhienHong}) {
    dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      // Render gói free ngủ sau khi rảnh; lượt đánh thức mất 50 giây trở lên.
      // Đặt ngắn hơn là người dùng thấy "hết thời gian chờ" ở mọi lần mở app
      // đầu tiên trong ngày.
      receiveTimeout: const Duration(seconds: 70),
      headers: {'Content-Type': 'application/json'},
      // Tự xử mã lỗi trong interceptor, đừng để Dio ném sớm.
      validateStatus: (_) => true,
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        await tokenStore.nap();
        final t = tokenStore.access;
        if (t != null && t.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $t';
        }
        handler.next(options);
      },
      onResponse: (response, handler) async {
        final code = response.statusCode ?? 0;
        final path = response.requestOptions.path;

        final dangHetHan = code == 401 || code == 403;
        // Không thử làm mới cho chính hai đường này: /auth/refresh hỏng thì
        // gọi lại nó là vòng lặp, còn /auth/login trả 401 nghĩa là sai mật
        // khẩu chứ không phải token hết hạn.
        final laDuongAuth =
            path == Endpoints.refresh || path == Endpoints.login;
        final daThuLai = response.requestOptions.extra['daThuLai'] == true;

        if (!dangHetHan || laDuongAuth || daThuLai || !tokenStore.coPhien) {
          return handler.next(response);
        }

        final moi = await _lamMoiMotLuong();
        if (!moi) return handler.next(response);

        // Thử lại đúng MỘT lần. Đánh dấu để lượt sau không rơi lại vào đây —
        // không có cờ này thì token hỏng sẽ tạo vòng lặp vô hạn.
        final opts = response.requestOptions;
        opts.extra = {...opts.extra, 'daThuLai': true};
        opts.headers['Authorization'] = 'Bearer ${tokenStore.access}';
        try {
          final lai = await dio.fetch(opts);
          return handler.resolve(lai);
        } catch (_) {
          return handler.next(response);
        }
      },
    ));
  }

  late final Dio dio;
  final TokenStore tokenStore;

  /// Gọi khi refresh token không còn dùng được — tầng trên đưa người dùng về
  /// màn đăng nhập.
  final void Function()? khiPhienHong;

  Future<bool>? _dangLamMoi;

  Future<bool> _lamMoiMotLuong() {
    // Đây chính là chốt một-luồng: ai tới sau thì chờ chung kết quả, không
    // mở thêm lượt làm mới nào nữa.
    return _dangLamMoi ??= _lamMoi().whenComplete(() => _dangLamMoi = null);
  }

  Future<bool> _lamMoi() async {
    final refresh = tokenStore.refresh;
    if (refresh == null || refresh.isEmpty) return false;

    try {
      // Dùng Dio trần: đi qua interceptor là tự gọi lại chính mình.
      final raw = Dio(BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        validateStatus: (_) => true,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 70),
      ));
      final r = await raw.post(
        Endpoints.refresh,
        // camelCase. Bản web từng gửi `refresh_token` và backend trả thẳng
        // 400 "Refresh token is required".
        data: {'refreshToken': refresh},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      final code = r.statusCode ?? 0;
      if (code == 401 || code == 403) {
        await tokenStore.xoa();
        khiPhienHong?.call();
        return false;
      }
      if (code < 200 || code >= 300) {
        // 5xx hay mạng chập chờn: phiên vẫn còn, chỉ là lúc này không làm mới
        // được. Giữ nguyên token để lần sau thử lại.
        return false;
      }

      final data = (r.data is Map) ? (r.data as Map)['data'] : null;
      final access = data is Map ? data['accessToken'] as String? : null;
      final moi = data is Map ? data['refreshToken'] as String? : null;
      if (access == null || moi == null) return false;

      await tokenStore.luu(access, moi);
      return true;
    } catch (_) {
      // Ngoại lệ mạng cũng là tạm thời, không phải phiên chết.
      return false;
    }
  }

  // ---- lối vào cho tầng trên ----

  Future<T> get<T>(String path, {Map<String, dynamic>? query}) =>
      _goi<T>(() => dio.get(path, queryParameters: query));

  Future<T> post<T>(String path, {Object? body}) =>
      _goi<T>(() => dio.post(path, data: body));

  Future<T> patch<T>(String path, {Object? body}) =>
      _goi<T>(() => dio.patch(path, data: body));

  Future<T> put<T>(String path, {Object? body}) =>
      _goi<T>(() => dio.put(path, data: body));

  Future<T> delete<T>(String path) => _goi<T>(() => dio.delete(path));

  /// Bóc bao thư `{success, message, data}` và dựng ApiException khi hỏng.
  Future<T> _goi<T>(Future<Response<dynamic>> Function() chay) async {
    late final Response<dynamic> r;
    try {
      r = await chay();
    } on DioException catch (e) {
      // Người dùng chỉ cần câu dễ hiểu, nhưng người sửa lỗi cần biết chính
      // xác Dio ném gì. Không có dòng này thì mọi sự cố mạng đều trông giống
      // nhau trên màn hình, và chỉ còn cách đoán.
      if (kDebugMode) {
        debugPrint('[api] ${e.type} ${e.requestOptions.method} '
            '${e.requestOptions.uri} -> ${e.message}');
      }
      throw ApiException(_loiMang(e));
    }

    final code = r.statusCode ?? 0;
    final body = r.data;
    final message = _thongDiep(body);

    if (code < 200 || code >= 300) {
      throw ApiException(
        message ?? 'Máy chủ trả lỗi $code.',
        statusCode: code,
        phienHong: (code == 401 || code == 403) && !tokenStore.coPhien,
      );
    }

    if (body is Map && body.containsKey('data')) return body['data'] as T;
    return body as T;
  }

  /// Backend dùng HAI dạng bao thư, phải đọc được cả hai.
  ///
  /// Phần lớn endpoint trả `{success, message, data, timestamp}`. Nhưng chốt
  /// chặn bảo mật của Spring trả dạng khác hẳn:
  /// `{data: null, error: {code, message}}`.
  ///
  /// Chỉ đọc `message` tầng ngoài thì mọi lỗi 401/403 đều rơi về câu chống
  /// chế "Máy chủ trả lỗi 401" — đúng loại câu vô dụng mà người dùng đọc xong
  /// không biết làm gì. Bắt được khi chạy thật: đăng nhập sai trên máy ảo hiện
  /// đúng câu ấy trong khi máy chủ có gửi kèm lời giải thích tử tế.
  String? _thongDiep(dynamic body) {
    if (body is! Map) return null;
    final ngoai = body['message'];
    if (ngoai is String && ngoai.isNotEmpty) return ngoai;
    final err = body['error'];
    if (err is Map && err['message'] is String) {
      final m = err['message'] as String;
      if (m.isNotEmpty) return m;
    }
    return null;
  }

  /// Dịch lỗi mạng sang câu người dùng đọc được.
  ///
  /// **Tách `connectionTimeout` khỏi `receiveTimeout`.** Ban đầu tôi gộp cả
  /// hai vào một câu "máy chủ phản hồi chậm", và nó đã dẫn tôi đi sai hướng:
  /// máy ảo hỏng DNS nên không mở nổi kết nối, mà màn hình lại nói máy chủ
  /// chậm — tôi đi kiểm tra backend một lúc trước khi nhận ra.
  ///
  /// Hai chuyện khác hẳn nhau:
  /// - Không **mở được** kết nối → lỗi ở mạng phía người dùng, hoặc DNS.
  /// - Mở được nhưng **trả lời chậm** → máy chủ đang bận, hoặc gói free đang
  ///   thức dậy.
  ///
  /// Nói sai loại là đẩy người đọc đi tìm ở nhầm chỗ.
  String _loiMang(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
        return 'Không mở được kết nối tới máy chủ. Thường là do mạng chập '
            'chờn — kiểm tra wifi hoặc dữ liệu di động rồi thử lại.';
      case DioExceptionType.receiveTimeout:
        return 'Máy chủ nhận được yêu cầu nhưng trả lời quá chậm. Gói miễn '
            'phí ngủ sau khi rảnh nên lần mở đầu tiên có thể mất gần một '
            'phút — thử lại giúp nhé.';
      case DioExceptionType.connectionError:
        return 'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.';
      case DioExceptionType.badCertificate:
        return 'Chứng chỉ bảo mật của máy chủ không hợp lệ. Nếu bạn đang dùng '
            'wifi công cộng, hãy đổi mạng khác.';
      case DioExceptionType.cancel:
        return 'Yêu cầu đã bị huỷ.';
      default:
        return 'Không gọi được máy chủ.';
    }
  }
}
