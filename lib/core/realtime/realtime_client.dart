import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../api/token_store.dart';
import '../config.dart';

typedef RealtimeHandler = void Function(Map<String, dynamic> body);

/// Kênh realtime qua STOMP trên WebSocket.
///
/// ## Vì sao có sổ đăng ký đích đến
///
/// Đường truyền này ĐỨT thường xuyên, không phải thỉnh thoảng: máy chủ chạy
/// gói free nên khởi động lại luôn, 4G chuyển trạm là rớt, và khoá màn hình
/// điện thoại cũng làm hệ điều hành cắt socket. Mỗi lần nối lại, phía máy chủ
/// quên sạch mọi đăng ký cũ.
///
/// Nếu màn hình tự gọi `subscribe` một lần lúc mở rồi thôi, thì sau lần đứt
/// ĐẦU TIÊN nó không còn nhận được gì nữa — mà giao diện vẫn hiện "đang kết
/// nối" xanh lè vì socket đúng là đã nối lại. Tin nhắn im lặng biến mất, và
/// tải lại màn hình thì lại thấy đủ. Bên web đã dính đúng lỗi này.
///
/// Nên lớp này giữ sổ: ai muốn nghe đích nào thì ghi vào sổ, và MỖI lần nối
/// lại ta đăng ký lại toàn bộ sổ. Màn hình không phải biết gì về chuyện đứt
/// nối.
class RealtimeClient {
  RealtimeClient({required this.tokenStore});

  final TokenStore tokenStore;

  StompClient? _client;
  bool _daNoi = false;

  /// đích → những người đang nghe.
  final Map<String, Set<RealtimeHandler>> _so = {};

  /// đích → hàm huỷ đăng ký của phiên socket HIỆN TẠI.
  ///
  /// Phải dọn sạch mỗi lần đứt: hàm huỷ của socket cũ gọi vào socket đã chết,
  /// giữ lại chỉ tổ rò bộ nhớ và gây nhầm lẫn.
  final Map<String, StompUnsubscribe> _dangNghe = {};

  final _trangThai = ValueNotifier<bool>(false);

  /// Cho giao diện hiện chấm "đang kết nối tức thời".
  ValueListenable<bool> get dangNoi => _trangThai;

  void noi() {
    if (_client != null) return;

    _client = StompClient(
      config: StompConfig(
        url: AppConfig.wsUrl,
        // Lấy token MỖI lần nối, không giữ một bản chụp lúc tạo client.
        // Nối lại sau nửa tiếng mà vẫn cầm access token cũ thì máy chủ từ
        // chối, và client cứ thử lại mãi với đúng cái token đã hỏng.
        beforeConnect: () async {
          await tokenStore.nap();
        },
        stompConnectHeaders: _headerAuth,
        webSocketConnectHeaders: _headerAuth,
        onConnect: _khiNoi,
        onDisconnect: (_) => _khiDut(),
        onWebSocketError: (_) => _khiDut(),
        onStompError: (_) => _khiDut(),
        reconnectDelay: const Duration(seconds: 5),
      ),
    );
    _client!.activate();
  }

  Map<String, String> get _headerAuth {
    final t = tokenStore.access;
    return (t == null || t.isEmpty) ? {} : {'Authorization': 'Bearer $t'};
  }

  void _khiNoi(StompFrame _) {
    _daNoi = true;
    _trangThai.value = true;
    // Socket mới thì mọi hàm huỷ cũ đều vô nghĩa.
    _dangNghe.clear();
    for (final dich in _so.keys) {
      _dangKy(dich);
    }
  }

  void _khiDut() {
    _daNoi = false;
    _trangThai.value = false;
    _dangNghe.clear();
  }

  void _dangKy(String dich) {
    final c = _client;
    if (c == null || !_daNoi || _dangNghe.containsKey(dich)) return;
    _dangNghe[dich] = c.subscribe(
      destination: dich,
      callback: (frame) {
        final body = frame.body;
        if (body == null || body.isEmpty) return;
        Map<String, dynamic> j;
        try {
          j = jsonDecode(body) as Map<String, dynamic>;
        } catch (_) {
          // Gói không phải JSON thì bỏ qua, đừng làm chết cả kênh.
          return;
        }
        // Chép danh sách trước khi duyệt: người nghe có thể tự huỷ ngay trong
        // lúc xử lý, và sửa tập đang duyệt là ném ngoại lệ.
        for (final h in _so[dich]?.toList() ?? const <RealtimeHandler>[]) {
          h(j);
        }
      },
    );
  }

  /// Nghe một đích. Trả về hàm huỷ — gọi trong `dispose` của màn hình.
  VoidCallback nghe(String dich, RealtimeHandler handler) {
    _so.putIfAbsent(dich, () => <RealtimeHandler>{}).add(handler);
    _dangKy(dich);

    return () {
      final bo = _so[dich];
      if (bo == null) return;
      bo.remove(handler);
      if (bo.isNotEmpty) return;

      // Không còn ai nghe đích này nữa thì mới thật sự huỷ ở máy chủ.
      _so.remove(dich);
      _dangNghe.remove(dich)?.call();
    };
  }

  /// Gửi một gói. Trả false khi chưa nối — nơi gọi tự quyết định lùi về REST.
  bool gui(String dich, Map<String, dynamic> body) {
    final c = _client;
    if (c == null || !_daNoi) return false;
    try {
      c.send(destination: dich, body: jsonEncode(body));
      return true;
    } catch (_) {
      return false;
    }
  }

  void ngat() {
    for (final huy in _dangNghe.values) {
      huy();
    }
    _dangNghe.clear();
    _so.clear();
    _client?.deactivate();
    _client = null;
    _daNoi = false;
    _trangThai.value = false;
  }
}
