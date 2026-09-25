import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../theme.dart';
import 'call_controller.dart';

/// Dải điều khiển cuộc gọi, đặt ngay dưới thanh tiêu đề của hộp trò chuyện.
///
/// Khi có hình thì nở thành khung video; còn lại chỉ là một dải mỏng. Không
/// đẩy sang màn hình riêng: trong lúc gọi người ta vẫn hay gõ thêm một dòng —
/// tên riêng, ngày tháng — và bắt họ thoát ra thoát vào là làm mất mạch.
class CallPanel extends StatelessWidget {
  const CallPanel({super.key, required this.c});

  final CallController c;

  @override
  Widget build(BuildContext context) {
    return switch (c.trangThai) {
      TrangThaiGoi.rong => const SizedBox.shrink(),
      TrangThaiGoi.hong => _Loi(c: c),
      TrangThaiGoi.coNguoiGoi => _ChuongDen(c: c),
      _ => _DangGoi(c: c),
    };
  }
}

class _Loi extends StatelessWidget {
  const _Loi({required this.c});
  final CallController c;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
      color: const Color(0x22E5645E),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 17, color: Color(0xFFE5645E)),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              c.loi ?? 'Cuộc gọi không thành công.',
              style: const TextStyle(fontSize: 12, height: 1.5),
            ),
          ),
          TextButton(
            onPressed: c.xoaLoi,
            style: TextButton.styleFrom(foregroundColor: Mau.chuMo),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }
}

class _ChuongDen extends StatelessWidget {
  const _ChuongDen({required this.c});
  final CallController c;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: const Color(0x22D4AF37),
      child: Row(
        children: [
          Icon(c.coVideo ? Icons.videocam : Icons.call,
              size: 20, color: Mau.vang),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              '${c.tenDoiPhuong ?? 'Người kia'} đang gọi'
              '${c.coVideo ? ' video' : ''}…',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          IconButton.filled(
            onPressed: c.cupMay,
            tooltip: 'Từ chối',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFE5645E),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.call_end, size: 18),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: c.nhan,
            tooltip: 'Nhận',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF6BBF7B),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.call, size: 18),
          ),
        ],
      ),
    );
  }
}

class _DangGoi extends StatelessWidget {
  const _DangGoi({required this.c});
  final CallController c;

  String get _nhan => switch (c.trangThai) {
        TrangThaiGoi.dangGoi => 'Đang gọi…',
        TrangThaiGoi.dangNoi => 'Đang kết nối…',
        TrangThaiGoi.dangChay => 'Đang trong cuộc gọi',
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    final hienHinh = c.coVideo && c.trangThai == TrangThaiGoi.dangChay;

    return Container(
      color: const Color(0xFF15131C),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Column(
        children: [
          if (hienHinh) ...[
            SizedBox(
              height: 220,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: RTCVideoView(
                        c.remoteRenderer,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    width: 86,
                    height: 118,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: RTCVideoView(
                        c.localRenderer,
                        mirror: true,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: Text(_nhan,
                    style: const TextStyle(fontSize: 12.5, color: Mau.chuMo)),
              ),
              IconButton(
                onPressed: c.doiMic,
                tooltip: c.micBat ? 'Tắt tiếng' : 'Bật tiếng',
                icon: Icon(c.micBat ? Icons.mic : Icons.mic_off,
                    size: 19, color: c.micBat ? Mau.chu : Mau.chuMo),
              ),
              if (c.coVideo)
                IconButton(
                  onPressed: c.doiCam,
                  tooltip: c.camBat ? 'Tắt camera' : 'Bật camera',
                  icon: Icon(c.camBat ? Icons.videocam : Icons.videocam_off,
                      size: 19, color: c.camBat ? Mau.chu : Mau.chuMo),
                ),
              const SizedBox(width: 4),
              IconButton.filled(
                onPressed: c.cupMay,
                tooltip: 'Cúp máy',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFE5645E),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.call_end, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
