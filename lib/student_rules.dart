String digitsOf(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

bool activationCodeShape(String raw) => digitsOf(raw).length == 16;

bool phoneShape(String raw) => digitsOf(raw).length >= 11;

bool passwordShape(String raw) => raw.length >= 8;

String studentMessage(String code, String fallback, bool arabic) {
  String both(String ar, String en) => arabic ? ar : en;
  switch (code) {
    case 'already_enrolled':
      return both('أنت منضم إلى هذا المحتوى. الكود لم يُستخدم.', 'You are already joined. The code was not used.');
    case 'code_already_active':
      return both('هذا الكود مستخدم.', 'This code is already used.');
    case 'code_expired':
      return both('هذا الكود منتهٍ.', 'This code is expired.');
    case 'code_canceled':
      return both('هذا الكود ملغى.', 'This code is canceled.');
    case 'code_missing':
      return both('هذا الكود غير موجود.', 'This code does not exist.');
    case 'not_enrolled':
      return both('فعّل الكود قبل فتح المحتوى.', 'Redeem a code before opening this.');
    case 'exam_ended':
      return both('انتهى وقت الاختبار.', 'This exam is past its end.');
    case 'exam_closed':
      return both('هذا الاختبار مكتمل.', 'This exam is completed.');
    case 'attempt_exists':
      return both('سُلّم الاختبار ولا تُعدَّل الإجابة.', 'This exam was submitted. The answers stay as sent.');
    case 'outside_window':
      return both('الصف خارج نافذة الوقت.', 'The session is outside its time window.');
    case 'session_dead':
      return both('انتهت الجلسة.', 'The session has ended.');
    case 'invalid_login':
      return both('الجوال أو كلمة المرور خطأ، أو الحساب موقوف.', 'The phone or password is wrong, or the account is disabled.');
    case 'phone_invalid':
      return both('الجوال أقل من 11 رقماً.', 'Phone must contain at least 11 digits.');
    case 'password_short':
      return both('كلمة المرور أقصر من 8 خانات.', 'Password must be at least 8 characters.');
    case 'phone_taken':
      return both('هذا الجوال مسجّل.', 'This phone is already registered.');
    case 'otp_invalid':
      return both('الرمز غير صحيح أو منتهٍ.', 'The code is invalid or expired.');
    case 'sms_unconfigured':
      return both('إرسال الرسالة غير مهيأ، فلم يُرسل الرمز.', 'SMS is not configured, so the code was not sent.');
    default:
      return fallback;
  }
}
