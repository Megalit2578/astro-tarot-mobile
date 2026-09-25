/// Một tin nhắn trong buổi tư vấn.
class TinNhan {
  const TinNhan({
    required this.id,
    required this.bookingId,
    required this.senderId,
    required this.senderName,
    required this.body,
    this.taoLuc,
    this.docLuc,
  });

  final String id;
  final String bookingId;
  final String senderId;
  final String senderName;
  final String body;

  /// Có thể NULL ở gói đẩy realtime của bản backend cũ.
  ///
  /// Backend đã sửa (save → saveAndFlush) nhưng vẫn để nullable ở đây: một
  /// máy đang chạy bản cũ, hay một gói còn nằm trong hàng đợi lúc deploy, vẫn
  /// gửi null. Giao diện không được vẽ `DateTime(0)` thành "01/01 08:00" —
  /// thà không có dấu thời gian còn hơn có một cái sai.
  final DateTime? taoLuc;
  final DateTime? docLuc;

  bool get daDoc => docLuc != null;

  factory TinNhan.fromJson(Map<String, dynamic> j) => TinNhan(
        id: j['id'] as String,
        bookingId: (j['bookingId'] ?? '') as String,
        senderId: (j['senderId'] ?? '') as String,
        senderName: (j['senderName'] ?? '') as String,
        body: (j['body'] ?? '') as String,
        taoLuc: _gio(j['createdAt']),
        docLuc: _gio(j['readAt']),
      );

  static DateTime? _gio(dynamic v) {
    if (v is! String || v.isEmpty) return null;
    return DateTime.tryParse(v);
  }
}
