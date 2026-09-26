import 'package:astrotarot_mobile/features/bookings/hoat_dong.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final moc = DateTime.utc(2026, 9, 26, 10);

  test('online thì nói đang hoạt động', () {
    expect(moTaHoatDong(online: true, bayGio: moc), 'Đang hoạt động');
  });

  test('không biết gì thì im', () {
    expect(moTaHoatDong(online: null, bayGio: moc), isNull);
    expect(moTaHoatDong(online: false, bayGio: moc), isNull);
  });

  test('đếm phút, giờ, ngày, rồi quá một tuần', () {
    expect(
      moTaHoatDong(
        online: false,
        lastSeen: moc.subtract(const Duration(seconds: 20)),
        bayGio: moc,
      ),
      'Vừa hoạt động',
    );
    expect(
      moTaHoatDong(
        online: false,
        lastSeen: moc.subtract(const Duration(minutes: 5)),
        bayGio: moc,
      ),
      'Hoạt động 5 phút trước',
    );
    expect(
      moTaHoatDong(
        online: false,
        lastSeen: moc.subtract(const Duration(hours: 2)),
        bayGio: moc,
      ),
      'Hoạt động 2 giờ trước',
    );
    expect(
      moTaHoatDong(
        online: false,
        lastSeen: moc.subtract(const Duration(days: 3)),
        bayGio: moc,
      ),
      'Hoạt động 3 ngày trước',
    );
    expect(
      moTaHoatDong(
        online: false,
        lastSeen: moc.subtract(const Duration(days: 12)),
        bayGio: moc,
      ),
      'Hoạt động hơn một tuần trước',
    );
  });

  test('mốc trong tương lai thì coi như vừa xong', () {
    expect(
      moTaHoatDong(
        online: false,
        lastSeen: moc.add(const Duration(minutes: 3)),
        bayGio: moc,
      ),
      'Vừa hoạt động',
    );
  });
}
