// Giả lập kênh native của flutter_webrtc để test cuộc gọi mà không cần
// camera, micro hay mạng thật.
//
// Trả đúng hình dạng dữ liệu mà lớp Dart của flutter_webrtc đọc (xem
// src/native/*_impl.dart của gói): textureId cho renderer, streamId + tracks
// cho getUserMedia, peerConnectionId, sender có rtpParameters…

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class WebRtcGia {
  WebRtcGia(this.tester);
  final WidgetTester tester;

  final goi = <String>[];

  /// Ném lỗi này ở getUserMedia (vd. quyền bị từ chối). null = thành công.
  String? loiGetUserMedia;

  /// Đừng bao giờ trả lời getUserMedia — mô phỏng hộp xin quyền đang treo.
  bool treoGetUserMedia = false;

  bool _daDatRemote = false;

  static const _kenh = MethodChannel('FlutterWebRTC.Method');

  static const _track = {
    'id': 'a1',
    'label': 'mic',
    'kind': 'audio',
    'enabled': true,
  };
  static const _trackVideo = {
    'id': 'v1',
    'label': 'cam',
    'kind': 'video',
    'enabled': true,
  };

  void batDau() {
    final m = tester.binding.defaultBinaryMessenger;
    m.setMockMethodCallHandler(_kenh, _traLoi);
    // Các EventChannel: chỉ cần 'listen'/'cancel' trả về êm.
    for (final ten in [
      'FlutterWebRTC.Event',
      'FlutterWebRTC/Texture1',
      'FlutterWebRTC/Texture2',
      'FlutterWebRTC/peerConnectionEventpc1',
    ]) {
      m.setMockMethodCallHandler(MethodChannel(ten), (_) async => null);
    }
  }

  Future<Object?> _traLoi(MethodCall call) async {
    goi.add(call.method);
    switch (call.method) {
      case 'createVideoRenderer':
        return {'textureId': goi.where((g) => g == call.method).length};
      case 'getUserMedia':
        if (treoGetUserMedia) await Completer<void>().future;
        if (loiGetUserMedia != null) {
          // Gói bọc lỗi thành chuỗi 'Unable to getUserMedia: <message>'.
          throw PlatformException(code: 'x', message: loiGetUserMedia);
        }
        return {
          'streamId': 's1',
          'audioTracks': [_track],
          'videoTracks': [_trackVideo],
        };
      case 'createPeerConnection':
        return {'peerConnectionId': 'pc1'};
      case 'addTrack':
        return {
          'senderId': 'sd1',
          'track': _track,
          'ownsTrack': true,
          'rtpParameters': {
            'transactionId': 't',
            'rtcp': {'cname': 'c', 'reducedSize': false},
            'headerExtensions': [],
            'encodings': [],
            'codecs': [],
          },
        };
      case 'createOffer':
        return {'sdp': 'v=0 offer', 'type': 'offer'};
      case 'createAnswer':
        return {'sdp': 'v=0 answer', 'type': 'answer'};
      case 'setRemoteDescription':
        _daDatRemote = true;
        return null;
      case 'getRemoteDescription':
        return _daDatRemote ? {'sdp': 'v=0', 'type': 'offer'} : null;
      default:
        return null;
    }
  }

  /// Phát một sự kiện của peer connection (vd. đã nối / hỏng).
  Future<void> phatSuKien(Map<String, dynamic> ev) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'FlutterWebRTC/peerConnectionEventpc1',
      const StandardMethodCodec().encodeSuccessEnvelope(ev),
      (_) {},
    );
  }
}
