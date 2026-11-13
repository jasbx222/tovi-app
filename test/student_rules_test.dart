import 'package:flutter_test/flutter_test.dart';
import 'package:tovi_student/student_rules.dart';

void main() {
  test('Student.Code.AcceptsSixteenDigitsOnly', () {
    expect(activationCodeShape('1717171717171717'), isTrue);
    expect(activationCodeShape('1717 1717 1717 1717'), isTrue);
    expect(activationCodeShape('171717171717171'), isFalse);
    expect(activationCodeShape('17171717171717171'), isFalse);
    expect(digitsOf('ab17-17'), '1717');
  });

  test('Student.Account.PhoneAndPasswordMatchServerShape', () {
    expect(phoneShape('07710000081'), isTrue);
    expect(phoneShape('077100'), isFalse);
    expect(passwordShape('password1'), isTrue);
    expect(passwordShape('short'), isFalse);
  });

  test('Student.Code.ExplainsServerRejectionInArabic', () {
    expect(studentMessage('already_enrolled', 'x', true), contains('منضم'));
    expect(studentMessage('code_already_active', 'x', true), contains('مستخدم'));
    expect(studentMessage('code_expired', 'x', true), contains('منته'));
    expect(studentMessage('exam_ended', 'x', true), contains('انتهى'));
    expect(studentMessage('outside_window', 'x', true), contains('نافذة'));
    expect(studentMessage('invalid_login', 'x', true), contains('موقوف'));
    expect(studentMessage('unknown', 'as sent', true), 'as sent');
  });
}
