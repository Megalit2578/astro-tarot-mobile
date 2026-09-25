import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/realtime/realtime_client.dart';

enum TrangThaiGoi { rong, dangGoi, coNguoiGoi, dangNoi, dangChay, hong }

/// Gọi thoại/video điểm-tới-điểm giữa khách và Reader.
///
/// Tiếng và hình đi THẲNG giữa hai máy; máy chủ chỉ chuyển tiếp mấy gói bắt
/// tay qua STOMP. Nhờ vậy hộp 512MB trên Render không phải nút thắt.
///
/// **Dự án đang chạy chỉ STUN, không TURN.** Hai máy cùng nằm sau NAT đối
/// xứng — rất phổ biến với 4G ở Việt Nam do nhà mạng dùng CGNAT — sẽ không
/// nối được. Wifi nhà hay mạng trường thì phần lớn chạy. [coTurn] cho giao
/// diện cảnh báo trước thay vì để người dùng ngồi nhìn "đang kết nối".
class CallController extends ChangeNotifier {
  CallController({
    required this.bookingId,
    required this.api,
    required this.realtime,
  }) {
    _huyNghe = realtime.nghe(Endpoints.queueCall, _nhanTinHieu);
    _napIce();
  }

  static const _hanKetNoi = Duration(seconds: 30);

  final String bookingId;
  final ApiClient api;
  final RealtimeClient realtime;

  TrangThaiGoi trangThai = TrangThaiGoi.rong;
  String? tenDoiPhuong;
  String? loi;
  bool coVideo = false;
  bool coTurn = true;
  bool micBat = true;
  bool camBat = true;

  MediaStream? luongCuaToi;
  MediaStream? luongDoiPhuong;
  final localRenderer = RTCVideoRenderer();
  final remoteRenderer = RTCVideoRenderer();

  RTCPeerConnection? _pc;
  List<Map<String, dynamic>> _iceServers = const [];
  /// Ứng viên ICE tới TRƯỚC khi có remote description — phải xếp hàng.
  final List<RTCIceCandidate> _iceCho = [];
  String? _offerDen;
  Timer? _dongHo;
  VoidCallback? _huyNghe;
  bool _daHuy = false;

  Future<void> khoiTaoRenderer() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  Future<void> _napIce() async {
    try {
      final d = await api.get<Map<String, dynamic>>(Endpoints.iceConfig);
      final ds = d['iceServers'];
      if (ds is List) {
        _iceServers = ds.whereType<Map>().map((e) {
          return e.map((k, v) => MapEntry(k.toString(), v));
        }).toList();
      }
      coTurn = d['hasTurn'] == true;
    } catch (_) {
      // Không lấy được thì vẫn thử với STUN công cộng, còn hơn không gọi được.
      _iceServers = const [
        {
          'urls': ['stun:stun.l.google.com:19302']
        }
      ];
      coTurn = false;
    }
    _bao();
  }

  void _bao() {
    if (!_daHuy) notifyListeners();
  }

  void _gui(Map<String, dynamic> tin) {
    realtime.gui(Endpoints.stompCall(bookingId), tin);
  }

  // ---- đồng hồ bỏ cuộc ----

  /// Đặt đồng hồ NGAY khi bắt đầu, trước cả getUserMedia.
  ///
  /// Bên web từng đặt nó SAU khi đã gửi OFFER, nên mọi thứ treo trước đó
  /// không có gì canh — và thứ hay treo nhất chính là hộp xin quyền
  /// micro/camera mà người dùng chưa bấm: getUserMedia không resolve, không
  /// reject, đứng im vô hạn. Bắt được trên production: màn hình ghi "Đang
  /// gọi…" suốt hơn mười phút.
  void _datDongHo() {
    _dongHo?.cancel();
    _dongHo = Timer(_hanKetNoi, () {
      // Báo phía kia biết ta bỏ cuộc, nếu không máy họ reo mãi.
      _gui({'type': 'HANGUP'});

      // Chưa có luồng nào nghĩa là getUserMedia còn đang treo — gần như luôn
      // là quyền chưa cấp. Nói đúng việc cần làm, đừng đổ cho người kia không
      // bắt máy khi cuộc gọi còn chưa đi khỏi máy này.
      if (luongCuaToi == null) {
        _hong('Ứng dụng đang chờ bạn cho phép dùng micro/camera. '
            'Cấp quyền rồi gọi lại nhé.');
        return;
      }
      _hong(coTurn
          ? 'Người kia không bắt máy.'
          : 'Không nối được cuộc gọi. Nếu đang dùng 4G, thử chuyển sang wifi.');
    });
  }

  // ---- vòng đời ----

  Future<RTCPeerConnection> _dungPeer(bool video) async {
    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': video ? {'facingMode': 'user'} : false,
    });
    luongCuaToi = stream;
    localRenderer.srcObject = stream;
    _bao();

    final pc = await createPeerConnection({'iceServers': _iceServers});
    for (final t in stream.getTracks()) {
      await pc.addTrack(t, stream);
    }

    pc.onTrack = (e) {
      if (e.streams.isEmpty) return;
      luongDoiPhuong = e.streams.first;
      remoteRenderer.srcObject = luongDoiPhuong;
      _bao();
    };

    pc.onIceCandidate = (c) {
      _gui({'type': 'ICE', 'payload': jsonEncode(c.toMap())});
    };

    pc.onConnectionState = (s) {
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _dongHo?.cancel();
        trangThai = TrangThaiGoi.dangChay;
        _bao();
      } else if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        // Đây chính là cảnh thiếu TURN gây ra. Nói thẳng nguyên nhân thay vì
        // "đã xảy ra lỗi", để người dùng biết đổi sang wifi là xong.
        _hong(coTurn
            ? 'Mất kết nối với người kia.'
            : 'Không nối được cuộc gọi. Hai máy đang ở hai mạng không tự '
                'thấy nhau — thử chuyển sang wifi thay vì 4G.');
      }
    };

    _pc = pc;
    return pc;
  }

  Future<void> goi({required bool video}) async {
    if (trangThai == TrangThaiGoi.dangGoi ||
        trangThai == TrangThaiGoi.coNguoiGoi ||
        trangThai == TrangThaiGoi.dangNoi ||
        trangThai == TrangThaiGoi.dangChay) {
      return;
    }
    loi = null;
    coVideo = video;
    trangThai = TrangThaiGoi.dangGoi;
    _bao();
    _datDongHo(); // TRƯỚC getUserMedia — xem chú thích ở _datDongHo.

    try {
      final pc = await _dungPeer(video);
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      _gui({
        'type': 'OFFER',
        'payload': jsonEncode(offer.toMap()),
        'video': video,
      });
      _datDongHo(); // nạp lại 30 giây cho giai đoạn đổ chuông thật
    } catch (e) {
      _hong(_loiThietBi(e));
    }
  }

  Future<void> nhan() async {
    if (trangThai != TrangThaiGoi.coNguoiGoi || _offerDen == null) return;
    trangThai = TrangThaiGoi.dangNoi;
    _bao();
    _datDongHo();

    try {
      final pc = await _dungPeer(coVideo);
      final m = jsonDecode(_offerDen!) as Map<String, dynamic>;
      await pc.setRemoteDescription(
        RTCSessionDescription(m['sdp'] as String?, m['type'] as String?),
      );
      await _xaIce(pc);
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      _gui({'type': 'ANSWER', 'payload': jsonEncode(answer.toMap())});
      _datDongHo();
    } catch (e) {
      _hong(_loiThietBi(e));
    }
  }

  void cupMay() {
    _gui({'type': 'HANGUP'});
    _don();
    loi = null;
    trangThai = TrangThaiGoi.rong;
    _bao();
  }

  void xoaLoi() {
    loi = null;
    trangThai = TrangThaiGoi.rong;
    _bao();
  }

  void doiMic() {
    final t = luongCuaToi?.getAudioTracks();
    if (t == null || t.isEmpty) return;
    micBat = !micBat;
    t.first.enabled = micBat;
    _bao();
  }

  void doiCam() {
    final t = luongCuaToi?.getVideoTracks();
    if (t == null || t.isEmpty) return;
    camBat = !camBat;
    t.first.enabled = camBat;
    _bao();
  }

  // ---- tín hiệu tới ----

  Future<void> _nhanTinHieu(Map<String, dynamic> tin) async {
    // Hàng đợi là của cả người dùng chứ không riêng buổi này: họ có thể mở
    // hai buổi ở hai màn. Không lọc thì chuông của buổi A reo ở màn buổi B.
    final bid = tin['bookingId'];
    if (bid is String && bid != bookingId) return;

    switch (tin['type']) {
      case 'OFFER':
        // "Bận" là ĐANG trong một cuộc, không phải "khác rỗng".
        //
        // Bên web từng viết `state !== "idle"`, mà "failed" cũng khác "idle" —
        // nên sau một cuộc gọi hỏng, máy lặng lẽ từ chối MỌI cuộc gọi tới cho
        // tới khi người dùng bấm tắt dải báo lỗi. Người gọi thì thấy "Người
        // kia đang bận" trong khi phía kia chẳng bận gì.
        final dangTrongCuoc = trangThai == TrangThaiGoi.dangGoi ||
            trangThai == TrangThaiGoi.coNguoiGoi ||
            trangThai == TrangThaiGoi.dangNoi ||
            trangThai == TrangThaiGoi.dangChay;
        if (dangTrongCuoc) {
          _gui({'type': 'BUSY'});
          return;
        }
        // Tới đây là rỗng hoặc hỏng. Chuông mới thì dẹp lỗi cũ.
        loi = null;
        _offerDen = tin['payload'] as String?;
        tenDoiPhuong = tin['fromName'] as String? ?? 'Người kia';
        coVideo = tin['video'] == true;
        trangThai = TrangThaiGoi.coNguoiGoi;
        _bao();
        _gui({'type': 'RINGING'});

      case 'ANSWER':
        final pc = _pc;
        final p = tin['payload'];
        if (pc == null || p is! String) return;
        final m = jsonDecode(p) as Map<String, dynamic>;
        await pc.setRemoteDescription(
          RTCSessionDescription(m['sdp'] as String?, m['type'] as String?),
        );
        await _xaIce(pc);
        trangThai = TrangThaiGoi.dangNoi;
        _bao();

      case 'ICE':
        final p = tin['payload'];
        if (p is! String) return;
        final m = jsonDecode(p) as Map<String, dynamic>;
        final c = RTCIceCandidate(
          m['candidate'] as String?,
          m['sdpMid'] as String?,
          (m['sdpMLineIndex'] as num?)?.toInt(),
        );
        final pc = _pc;
        // ICE thường tới TRƯỚC khi ta kịp đặt remote description vì hai gói đi
        // độc lập. Thêm lúc đó là ném lỗi và ứng viên mất luôn — mất đủ nhiều
        // thì không tìm ra đường nối, và cuộc gọi hỏng không một lời báo.
        if (pc != null && await pc.getRemoteDescription() != null) {
          try {
            await pc.addCandidate(c);
          } catch (_) {
            // Một ứng viên hỏng không làm chết cả cuộc gọi.
          }
        } else {
          _iceCho.add(c);
        }

      case 'BUSY':
        _hong('Người kia đang bận.');

      case 'HANGUP':
        _don();
        loi = null;
        trangThai = TrangThaiGoi.rong;
        _bao();
    }
  }

  Future<void> _xaIce(RTCPeerConnection pc) async {
    final ds = List<RTCIceCandidate>.from(_iceCho);
    _iceCho.clear();
    for (final c in ds) {
      try {
        await pc.addCandidate(c);
      } catch (_) {}
    }
  }

  // ---- dọn dẹp ----

  /// Gọi ở MỌI đường kết thúc.
  ///
  /// Quên một đường thôi là đèn camera vẫn sáng sau khi cúp máy — người dùng
  /// tưởng bị quay lén, và đó là loại lỗi không ai tha thứ.
  void _don() {
    _dongHo?.cancel();
    _dongHo = null;
    for (final t in luongCuaToi?.getTracks() ?? const <MediaStreamTrack>[]) {
      t.stop();
    }
    luongCuaToi?.dispose();
    luongCuaToi = null;
    luongDoiPhuong = null;
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
    _pc?.close();
    _pc = null;
    _iceCho.clear();
    _offerDen = null;
    tenDoiPhuong = null;
    micBat = true;
    camBat = true;
  }

  void _hong(String thongDiep) {
    _don();
    loi = thongDiep;
    trangThai = TrangThaiGoi.hong;
    _bao();
  }

  @override
  void dispose() {
    _daHuy = true;
    _huyNghe?.call();
    _don();
    localRenderer.dispose();
    remoteRenderer.dispose();
    super.dispose();
  }

  /// Lỗi quyền là lỗi người dùng sửa được — nói cho họ cách sửa.
  String _loiThietBi(Object e) {
    final s = e.toString();
    if (s.contains('NotAllowed') || s.contains('Permission')) {
      return 'Bạn chưa cho phép dùng micro/camera. Mở Cài đặt → Ứng dụng → '
          'AstroTarot → Quyền để bật.';
    }
    if (s.contains('NotFound')) {
      return 'Không tìm thấy micro hoặc camera trên máy này.';
    }
    if (s.contains('NotReadable') || s.contains('in use')) {
      return 'Micro/camera đang bị ứng dụng khác chiếm. Đóng ứng dụng đó rồi '
          'thử lại.';
    }
    return 'Không bắt đầu được cuộc gọi.';
  }
}
