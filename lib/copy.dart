class Copy {
  const Copy(this.arabic);
  final bool arabic;

  String pick(String ar, String en) => arabic ? ar : en;

  String get brand => pick('توفي', 'TOVI');
  String get login => pick('دخول', 'Sign in');
  String get register => pick('حساب جديد', 'Create account');
  String get phone => pick('الهاتف', 'Phone');
  String get password => pick('كلمة المرور', 'Password');
  String get home => pick('الرئيسية', 'Home');
  String get search => pick('بحث', 'Search');
  String get learn => pick('التعلّم', 'Learn');
  String get inbox => pick('الإشعارات', 'Inbox');
  String get profile => pick('الملف', 'Profile');
  String get redeem => pick('تفعيل كود', 'Redeem a code');
  String get code => pick('الكود', 'Code');
  String get meeting => pick('الحصة المباشرة', 'Live meeting');
  String get raise => pick('رفع اليد', 'Raise hand');
  String get lower => pick('إنزال اليد', 'Lower hand');
  String get leave => pick('مغادرة', 'Leave');
  String get mic => pick('المايك', 'Mic');
  String get camera => pick('الكاميرا', 'Camera');
  String get empty => pick('لا توجد سجلات', 'No records');
  String get privacy => pick('الخصوصية', 'Privacy');
}
