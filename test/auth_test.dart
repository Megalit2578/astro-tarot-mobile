import 'package:astrotarot_mobile/features/auth/email_link_screen.dart';
import 'package:astrotarot_mobile/features/auth/forgot_password_screen.dart';
import 'package:astrotarot_mobile/features/auth/login_screen.dart';
import 'package:astrotarot_mobile/features/auth/register_screen.dart';
import 'package:astrotarot_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/gia.dart';

const _me = {
  'userId': 'u1',
  'username': 'an',
  'fullName': 'An',
  'role': 'USER',
  'permissions': ['USER_BASIC', 'READER_APPLY'],
};

void main() {
  group('Đăng nhập', () {
    testWidgets('kiểm dữ liệu trước khi gửi', (t) async {
      final m = MoiTruong();
      await m.dung(t, const LoginScreen(), thatAuth: true);
      await bam(t, find.widgetWithText(FilledButton, 'Đăng nhập'));
      expect(find.text('Email chưa đúng định dạng'), findsOneWidget);
      expect(find.text('Hãy nhập mật khẩu'), findsOneWidget);
      expect(m.mayChu.goi, isEmpty);
    });

    testWidgets('sai mật khẩu hiện câu máy chủ; hiện/ẩn mật khẩu', (t) async {
      final m = MoiTruong();
      m.mayChu.loi('POST /auth/login', 'Email hoặc mật khẩu không đúng');
      await m.dung(t, const LoginScreen(), thatAuth: true);
      await t.enterText(find.byType(TextFormField).first, 'a@b.vn');
      await t.enterText(find.byType(TextFormField).last, 'sai');
      await bam(t, find.byTooltip('Hiện mật khẩu'));
      expect(find.byTooltip('Ẩn mật khẩu'), findsOneWidget);
      await bam(t, find.widgetWithText(FilledButton, 'Đăng nhập'));
      expect(find.text('Email hoặc mật khẩu không đúng'), findsOneWidget);
      expect(find.text('Gửi lại thư xác minh'), findsNothing);
    });

    testWidgets('chưa xác minh thì có nút gửi lại thư', (t) async {
      final m = MoiTruong();
      m.mayChu.loi('POST /auth/login',
          'Tài khoản chưa được xác minh email. Hãy kiểm tra hộp thư.');
      m.mayChu.tra('POST /auth/resend-verification', null);
      await m.dung(t, const LoginScreen(), thatAuth: true);
      await t.enterText(find.byType(TextFormField).first, 'a@b.vn');
      await t.enterText(find.byType(TextFormField).last, 'mk');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await xong(t);
      await bam(t, find.text('Gửi lại thư xác minh'));
      expect(m.mayChu.lanCuoi('POST /auth/resend-verification')!.than,
          {'email': 'a@b.vn'});
      expect(find.text('Đã gửi lại thư xác minh tới a@b.vn.'), findsOneWidget);

      m.mayChu.loi('POST /auth/resend-verification', 'Quá nhiều lần');
      await bam(t, find.text('Gửi lại thư xác minh'));
      expect(find.text('Quá nhiều lần'), findsOneWidget);
    });

    testWidgets('đăng nhập đúng thì vào khung chính', (t) async {
      final m = MoiTruong();
      m.mayChu.tra('POST /auth/login',
          {..._me, 'accessToken': 'a', 'refreshToken': 'r'});
      m.mayChu.tra('GET /api/v1/bookings/me', {'content': []});
      m.mayChu.tra('GET /api/ai-readings', {'content': []});
      m.mayChu.tra('GET /api/v1/me/notifications/unread-count', {'count': 0});
      await m.dung(t, const AstroTarotApp(), thatAuth: true);
      expect(find.byType(LoginScreen), findsOneWidget);
      await t.enterText(find.byType(TextFormField).first, 'an@x.vn');
      await t.enterText(find.byType(TextFormField).last, 'dung');
      await bam(t, find.widgetWithText(FilledButton, 'Đăng nhập'));
      expect(find.text('Chào An,'), findsOneWidget);
      expect(m.store.refresh, 'r');
    });

    testWidgets('mở đúng các lối phụ', (t) async {
      final m = MoiTruong();
      m.mayChu.tra('GET /api/v1/readers', []);
      await m.dung(t, const LoginScreen(), thatAuth: true);
      await bam(t, find.text('Tạo tài khoản'));
      expect(find.byType(RegisterScreen), findsOneWidget);
      await t.pageBack();
      await xong(t);
      await bam(t, find.text('Quên mật khẩu'));
      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
      await t.pageBack();
      await xong(t);
      await bam(t, find.text('Tôi có liên kết trong email'));
      expect(find.byType(EmailLinkScreen), findsOneWidget);
      await t.pageBack();
      await xong(t);
      await bam(t, find.text('Xem Reader trước khi đăng nhập'));
      expect(m.mayChu.cacLan('GET /api/v1/readers'), hasLength(1));
    });

    testWidgets('mở app lần đầu: vòng quay rồi màn đăng nhập', (t) async {
      final m = MoiTruong();
      await m.dung(t, const AstroTarotApp(), thatAuth: true);
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  group('Đăng ký', () {
    testWidgets('kiểm dữ liệu', (t) async {
      final m = MoiTruong();
      await m.dung(t, const RegisterScreen(), thatAuth: true);
      await bam(t, find.widgetWithText(FilledButton, 'Tạo tài khoản'));
      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(m.mayChu.goi, isEmpty);
    });

    testWidgets('gửi thành công rồi quay lại', (t) async {
      final m = MoiTruong();
      m.mayChu.tra('POST /auth/register', {'verificationEmailSent': true});
      await m.dung(t, const RegisterScreen(), thatAuth: true, quaDuong: true);
      final o = find.byType(TextFormField);
      await t.enterText(o.at(0), 'Bình');
      await t.enterText(o.at(1), 'binh@x.vn');
      await t.enterText(o.at(2), 'matkhau123');
      await t.enterText(o.at(3), 'khac');
      await bam(t, find.widgetWithText(FilledButton, 'Tạo tài khoản'));
      expect(m.mayChu.goi, isEmpty);
      await t.enterText(o.at(3), 'matkhau123');
      await bam(t, find.widgetWithText(FilledButton, 'Tạo tài khoản'));
      expect(find.textContaining('binh@x.vn'), findsWidgets);
      await bam(t, find.text('Quay lại đăng nhập'));
      expect(find.text('MỞ MÀN'), findsOneWidget);
    });

    testWidgets('máy chủ báo lỗi', (t) async {
      final m = MoiTruong();
      m.mayChu.loi('POST /auth/register', 'Email đã được sử dụng');
      await m.dung(t, const RegisterScreen(), thatAuth: true);
      final o = find.byType(TextFormField);
      await t.enterText(o.at(0), 'Bình');
      await t.enterText(o.at(1), 'binh@x.vn');
      await t.enterText(o.at(2), 'matkhau123');
      await t.enterText(o.at(3), 'matkhau123');
      await bam(t, find.widgetWithText(FilledButton, 'Tạo tài khoản'));
      expect(find.text('Email đã được sử dụng'), findsOneWidget);
    });
  });

  group('Quên mật khẩu', () {
    testWidgets('gửi liên kết và báo đã gửi', (t) async {
      final m = MoiTruong();
      m.mayChu.tra('POST /auth/forgot-password', null);
      await m.dung(t, const ForgotPasswordScreen(),
          thatAuth: true, quaDuong: true);
      await bam(t, find.text('Gửi liên kết'));
      expect(m.mayChu.goi, isEmpty);
      await t.enterText(find.byType(TextFormField), 'a@b.vn');
      await bam(t, find.text('Gửi liên kết'));
      expect(m.mayChu.lanCuoi('POST /auth/forgot-password')!.than,
          {'email': 'a@b.vn'});
      await bam(t, find.text('Quay lại đăng nhập'));
    });

    testWidgets('lỗi máy chủ', (t) async {
      final m = MoiTruong();
      m.mayChu.loi('POST /auth/forgot-password', 'Thử lại sau');
      await m.dung(t, const ForgotPasswordScreen(), thatAuth: true);
      await t.enterText(find.byType(TextFormField), 'a@b.vn');
      await bam(t, find.text('Gửi liên kết'));
      expect(find.text('Thử lại sau'), findsOneWidget);
    });
  });

  group('Liên kết trong email', () {
    test('nhận ra loại liên kết', () {
      expect(
          LienKetEmail.doc('https://astrotarot.date/verify-email?token=abc')!
              .loai,
          LoaiLienKet.xacMinh);
      final r =
          LienKetEmail.doc('https://astrotarot.date/reset-password?token=xyz')!;
      expect(r.loai, LoaiLienKet.datLaiMatKhau);
      expect(r.token, 'xyz');
      expect(LienKetEmail.doc(''), isNull);
      expect(LienKetEmail.doc('https://astrotarot.date/verify-email'), isNull);
      expect(LienKetEmail.doc('https://astrotarot.date/khac?token=1'), isNull);
    });

    testWidgets('dán liên kết xác minh', (t) async {
      final m = MoiTruong();
      m.mayChu.tra('POST /auth/verify-email', {'email': 'a@b.vn'});
      await m.dung(t, const EmailLinkScreen(), thatAuth: true, quaDuong: true);
      await t.enterText(find.byKey(const ValueKey('o-lien-ket')), 'rác');
      await xong(t);
      expect(find.textContaining('Chưa nhận ra liên kết'), findsOneWidget);
      m.clipboard = 'https://astrotarot.date/verify-email?token=tok1';
      await bam(t, find.byTooltip('Dán'));
      expect(find.text('Đây là liên kết xác minh email.'), findsOneWidget);
      await bam(t, find.text('Xác minh'));
      expect(m.mayChu.lanCuoi('POST /auth/verify-email')!.than,
          {'token': 'tok1'});
      expect(find.textContaining('a@b.vn đã được kích hoạt'), findsOneWidget);
      await bam(t, find.text('Về đăng nhập'));
      expect(find.text('MỞ MÀN'), findsOneWidget);
    });

    testWidgets('xác minh hỏng hiện câu máy chủ', (t) async {
      final m = MoiTruong();
      m.mayChu.loi('POST /auth/verify-email', 'Liên kết đã hết hạn');
      await m.dung(t, const EmailLinkScreen(), thatAuth: true);
      await t.enterText(find.byKey(const ValueKey('o-lien-ket')),
          'https://astrotarot.date/verify-email?token=cu');
      await xong(t);
      await bam(t, find.text('Xác minh'));
      expect(find.text('Liên kết đã hết hạn'), findsOneWidget);
    });

    testWidgets('đặt lại mật khẩu bằng liên kết', (t) async {
      final m = MoiTruong();
      m.mayChu.tra('POST /auth/reset-password', null);
      await m.dung(t, const EmailLinkScreen(), thatAuth: true);
      await t.enterText(find.byKey(const ValueKey('o-lien-ket')),
          'https://astrotarot.date/reset-password?token=r1');
      await xong(t);
      await bam(t, find.text('Đặt mật khẩu mới'));
      expect(find.text('Mật khẩu phải từ 8 ký tự'), findsOneWidget);
      await t.enterText(find.byKey(const ValueKey('o-mat-khau-moi')), 'x' * 130);
      await bam(t, find.text('Đặt mật khẩu mới'));
      expect(find.text('Mật khẩu tối đa 128 ký tự'), findsOneWidget);
      await t.enterText(
          find.byKey(const ValueKey('o-mat-khau-moi')), 'matkhau123');
      await t.enterText(find.byKey(const ValueKey('o-nhap-lai')), 'khac');
      await bam(t, find.text('Đặt mật khẩu mới'));
      expect(find.text('Mật khẩu nhập lại không khớp'), findsOneWidget);
      await t.enterText(find.byKey(const ValueKey('o-nhap-lai')), 'matkhau123');
      await bam(t, find.text('Đặt mật khẩu mới'));
      expect(m.mayChu.lanCuoi('POST /auth/reset-password')!.than,
          {'token': 'r1', 'newPassword': 'matkhau123'});
      expect(find.textContaining('Đã đặt mật khẩu mới'), findsOneWidget);
    });
  });
}
