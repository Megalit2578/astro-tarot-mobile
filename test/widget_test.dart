import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astrotarot_mobile/core/auth/app_user.dart';

void main() {
  group('appRoleFrom', () {
    test('doi vai tro backend sang vai tro giao dien', () {
      expect(appRoleFrom('ADMIN'), AppRole.admin);
      expect(appRoleFrom('MANAGER'), AppRole.manager);
      expect(appRoleFrom('STAFF'), AppRole.staff);
      expect(appRoleFrom('USER'), AppRole.user);
    });

    test('phien cu con vai tro READER van vao duoc, khong bi khoa sach', () {
      // READER da gop vao STAFF o migration V2_15. Tra guest o day la khoa
      // sach giao dien cua phien cu, va khong ai doan ra phai dang xuat roi
      // dang nhap lai.
      expect(appRoleFrom('READER'), AppRole.staff);
    });

    test('khong ro thi la khach', () {
      expect(appRoleFrom(null), AppRole.guest);
      expect(appRoleFrom('KHONG_TON_TAI'), AppRole.guest);
    });
  });

  group('AppUser.fromJson', () {
    test('dung danh sach quyen may chu gui ve', () {
      final u = AppUser.fromJson({
        'userId': 'u1',
        'username': 'dat',
        'fullName': 'Dat Tran',
        'role': 'ADMIN',
        'permissions': ['USER_BASIC', 'USERS_MANAGE'],
      });
      expect(u.co('USERS_MANAGE'), isTrue);
      expect(u.laQuanTri, isTrue);
      expect(u.laNhanSu, isFalse);
    });

    test('thieu permissions thi lui ve quyen toi thieu, KHONG suy ra tu vai tro',
        () {
      // Suy rong ra tu vai tro la bay ca man quan tri cho nguoi co the khong
      // con quyen do nua, roi moi thao tac deu 403. Hep con hon sai.
      final u = AppUser.fromJson({
        'userId': 'u2',
        'username': 'x',
        'fullName': 'X',
        'role': 'ADMIN',
      });
      expect(u.permissions, {'USER_BASIC'});
      expect(u.laQuanTri, isFalse);
    });

    test('permissions rong cung lui ve quyen toi thieu', () {
      final u = AppUser.fromJson({
        'userId': 'u3',
        'username': 'y',
        'fullName': 'Y',
        'role': 'STAFF',
        'permissions': <String>[],
      });
      expect(u.permissions, {'USER_BASIC'});
    });
  });

  testWidgets('man hinh dung duoc widget co ban', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('ok'))));
    expect(find.text('ok'), findsOneWidget);
  });
}
