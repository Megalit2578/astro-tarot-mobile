/// Câu mô tả trạng thái hoạt động của người bên kia.
///
/// Trả null khi không biết gì. Giao diện bỏ hẳn dòng ấy, không hiện "Không rõ".
String? moTaHoatDong({
  required bool? online,
  DateTime? lastSeen,
  DateTime? bayGio,
}) {
  if (online == null && lastSeen == null) return null;
  if (online == true) return 'Đang hoạt động';
  if (lastSeen == null) return null;

  final now = bayGio ?? DateTime.now();
  final giay = now.difference(lastSeen).inSeconds;
  if (giay < 60) return 'Vừa hoạt động';

  final phut = giay ~/ 60;
  if (phut < 60) return 'Hoạt động $phut phút trước';

  final gio = phut ~/ 60;
  if (gio < 24) return 'Hoạt động $gio giờ trước';

  final ngay = gio ~/ 24;
  if (ngay < 7) return 'Hoạt động $ngay ngày trước';

  return 'Hoạt động hơn một tuần trước';
}
