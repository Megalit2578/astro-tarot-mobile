import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/auth/auth_controller.dart';

/// Một lá bài đã rút.
class LaBai {
  const LaBai({
    required this.ten,
    required this.viTri,
    required this.nguoc,
    this.anh,
    this.bo,
    this.yNghia,
  });

  final String ten;
  final int viTri;
  final bool nguoc;
  final String? anh;
  final String? bo;
  final String? yNghia;

  factory LaBai.fromJson(Map<String, dynamic> j) => LaBai(
        ten: (j['cardName'] ?? '') as String,
        viTri: (j['position'] as num?)?.toInt() ?? 0,
        // Bài ngược đổi hẳn nghĩa, nên phải hiện rõ. Backend đặt tên trường
        // này khác nhau tuỳ chỗ nên nhận cả hai.
        nguoc: j['isReversed'] == true || j['reversed'] == true,
        anh: j['imageUrl'] as String?,
        bo: j['arcanaType'] as String?,
        yNghia: (j['meaning'] ?? j['positionMeaning']) as String?,
      );
}

/// Kết quả một lượt trải bài.
class KetQuaTraiBai {
  const KetQuaTraiBai({
    required this.id,
    required this.cauHoi,
    required this.cacLa,
    required this.loiGiai,
    this.kieuTrai,
    this.luc,
  });

  final String id;
  final String cauHoi;
  final List<LaBai> cacLa;
  final String loiGiai;
  final String? kieuTrai;
  final DateTime? luc;

  factory KetQuaTraiBai.fromJson(Map<String, dynamic> j) {
    final cards = j['drawnCards'];
    return KetQuaTraiBai(
      id: (j['readingId'] ?? j['id'] ?? '').toString(),
      cauHoi: (j['userQuestion'] ?? j['mainQuestion'] ?? '') as String,
      cacLa: cards is List
          ? cards.whereType<Map<String, dynamic>>().map(LaBai.fromJson).toList()
          : const [],
      loiGiai: (j['aiInterpretation'] ?? '') as String,
      kieuTrai: j['spreadName'] as String?,
      luc: DateTime.tryParse((j['readingTimestamp'] ?? '').toString()),
    );
  }
}

class TarotRepository {
  TarotRepository(this._api);
  final ApiClient _api;

  /// Trải bài.
  ///
  /// Lượt này gọi mô hình ngôn ngữ nên chậm — hàng chục giây là bình thường.
  /// Giao diện phải nói rõ điều đó, nếu không người dùng bấm lại nhiều lần và
  /// mỗi lần bấm là một lượt tính phí.
  Future<KetQuaTraiBai> trai({
    required String cauHoi,
    required int soLa,
    String? kieuTrai,
    bool coNguoc = true,
  }) async {
    final d = await _api.post<Map<String, dynamic>>(
      Endpoints.aiReadings,
      body: {
        'question': cauHoi.trim(),
        'numberOfCards': soLa,
        'includeReversed': coNguoc,
        'spreadName': ?kieuTrai,
      },
    );
    return KetQuaTraiBai.fromJson(d);
  }

  Future<void> hoiThem(String readingId, String cauHoi) => _api.post(
        '${Endpoints.aiReadings}/$readingId/chat',
        body: {
          'message': cauHoi.trim(),
          'readingId': readingId,
          'stream': false,
        },
      );

  Future<List<Map<String, dynamic>>> tinNhanAi(String readingId) async {
    final d =
        await _api.get<dynamic>('${Endpoints.aiReadings}/$readingId/chat/messages');
    final l = d is Map ? (d['content'] ?? d['messages']) : d;
    if (l is! List) return const [];
    return l.whereType<Map<String, dynamic>>().toList();
  }
}

final tarotRepositoryProvider =
    Provider((ref) => TarotRepository(ref.watch(apiClientProvider)));
