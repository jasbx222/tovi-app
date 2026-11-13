import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'auth_parts.dart';
import 'session.dart';
import 'student_rules.dart';
import 'ui.dart';

/// Inline phone check. Iraqi mobiles are 11 digits and start with 07.
String? phoneProblem(String raw, bool arabic) {
  final digits = digitsOf(raw);
  if (digits.isEmpty) return arabic ? 'اكتب رقم الهاتف' : 'Enter your phone number';
  if (!digits.startsWith('07')) return arabic ? 'الرقم يبدأ بـ 07' : 'The number starts with 07';
  if (!phoneShape(digits)) return arabic ? 'الرقم ناقص، لازم 11 رقماً' : 'The number needs 11 digits';
  return null;
}

String? passwordProblem(String raw, bool arabic) {
  if (raw.isEmpty) return arabic ? 'اكتب كلمة المرور' : 'Enter your password';
  if (!passwordShape(raw)) return arabic ? 'كلمة المرور 8 خانات على الأقل' : 'Use at least 8 characters';
  return null;
}

String? confirmProblem(String raw, String password, bool arabic) {
  if (raw.isEmpty) return arabic ? 'أعد كتابة كلمة المرور' : 'Type the password again';
  if (raw != password) return arabic ? 'كلمتا المرور غير متطابقتين' : 'The passwords do not match';
  return null;
}

String? nameProblem(String raw, bool arabic) => raw.trim().isEmpty ? (arabic ? 'اكتب اسمك' : 'Enter your first name') : null;

/// Shows a phone as 07XX XXX XXXX.
String spacedPhone(String raw) {
  final d = digitsOf(raw);
  if (d.length != 11) return d;
  return '${d.substring(0, 4)} ${d.substring(4, 7)} ${d.substring(7)}';
}

enum AuthMode { login, register, forgot }

enum ResetStep { phone, code, password }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.session});
  final Session session;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final phone = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final code = TextEditingController();
  var gender = 'Unspecified';
  var mode = AuthMode.login;
  var registerStep = 1;
  var resetStep = ResetStep.phone;
  var showErrors = false;
  var codeWrong = false;
  var error = '';
  var notice = '';
  var busy = false;
  var resendIn = 0;
  Timer? ticker;

  Session get session => widget.session;
  bool get ar => session.copy.arabic;
  String pick(String a, String e) => session.copy.pick(a, e);

  @override
  void dispose() {
    ticker?.cancel();
    for (final c in [phone, password, confirm, firstName, lastName, code]) {
      c.dispose();
    }
    super.dispose();
  }

  void go(AuthMode next, {int step = 1, ResetStep reset = ResetStep.phone, bool keepNotice = false}) {
    FocusScope.of(context).unfocus();
    setState(() {
      mode = next;
      registerStep = step;
      resetStep = reset;
      showErrors = false;
      codeWrong = false;
      error = '';
      if (!keepNotice) notice = '';
    });
  }

  bool back() {
    if (busy) return false;
    if (mode == AuthMode.register && registerStep == 2) {
      go(AuthMode.register, step: 1);
      return false;
    }
    if (mode == AuthMode.forgot && resetStep != ResetStep.phone) {
      go(AuthMode.forgot, reset: resetStep == ResetStep.password ? ResetStep.code : ResetStep.phone);
      return false;
    }
    if (mode != AuthMode.login) {
      go(AuthMode.login);
      return false;
    }
    return true;
  }

  Future<void> run(Future<void> Function() work) async {
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = '';
      notice = '';
    });
    try {
      await work();
    } on ApiException catch (reason) {
      if (mounted) setState(() => error = studentMessage(reason.code, reason.message, ar));
    } catch (_) {
      if (mounted) setState(() => error = pick('تعذّر الاتصال بالخادم. تأكد من الإنترنت وحاول مرة ثانية.', 'Could not reach the server. Check your connection and try again.'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  bool invalid(List<String?> problems) {
    if (problems.every((p) => p == null)) return false;
    setState(() => showErrors = true);
    return true;
  }

  Future<void> login() async {
    if (invalid([phoneProblem(phone.text, ar), password.text.isEmpty ? passwordProblem('', ar) : null])) return;
    await run(() async {
      final result = await session.api.post('/api/auth/student/login', {'phone': digitsOf(phone.text), 'password': password.text});
      await session.signIn(result['token'] as String);
    });
  }

  void registerNext() {
    if (invalid([nameProblem(firstName.text, ar)])) return;
    go(AuthMode.register, step: 2);
  }

  Future<void> register() async {
    if (invalid([phoneProblem(phone.text, ar), passwordProblem(password.text, ar), confirmProblem(confirm.text, password.text, ar)])) return;
    await run(() async {
      final result = await session.api.post('/api/auth/student/register', {
        'firstName': firstName.text.trim(),
        'lastName': lastName.text.trim(),
        'phone': digitsOf(phone.text),
        'password': password.text,
        'gender': gender,
      });
      await session.signIn(result['token'] as String);
    });
  }

  void startTimer() {
    ticker?.cancel();
    setState(() => resendIn = 60);
    ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => resendIn = resendIn > 0 ? resendIn - 1 : 0);
      if (resendIn == 0) t.cancel();
    });
  }

  Future<void> sendCode({bool again = false}) async {
    if (invalid([phoneProblem(phone.text, ar)])) return;
    await run(() async {
      await session.api.post('/api/auth/student/otp', {'phone': digitsOf(phone.text)});
      if (!mounted) return;
      code.clear();
      if (!again) go(AuthMode.forgot, reset: ResetStep.code);
      startTimer();
      setState(() => notice = again ? pick('أرسلنا رمزاً جديداً.', 'We sent a new code.') : '');
    });
  }

  Future<void> verifyCode([String? value]) async {
    final entered = value ?? code.text;
    if (entered.length < 6) {
      setState(() {
        codeWrong = true;
        error = pick('اكتب الرمز كاملاً، 6 أرقام.', 'Enter all 6 digits.');
      });
      return;
    }
    await run(() async {
      await session.api.post('/api/auth/student/otp/verify', {'phone': digitsOf(phone.text), 'code': entered});
      if (!mounted) return;
      password.clear();
      confirm.clear();
      go(AuthMode.forgot, reset: ResetStep.password);
    });
    if (mounted && error.isNotEmpty) setState(() => codeWrong = true);
  }

  Future<void> savePassword() async {
    if (invalid([passwordProblem(password.text, ar), confirmProblem(confirm.text, password.text, ar)])) return;
    await run(() async {
      await session.api.post('/api/auth/student/password-reset', {'phone': digitsOf(phone.text), 'code': code.text, 'password': password.text});
      if (!mounted) return;
      password.clear();
      confirm.clear();
      code.clear();
      go(AuthMode.login, keepNotice: true);
      setState(() => notice = pick('تم تغيير كلمة المرور. سجّل دخولك بالكلمة الجديدة.', 'Password changed. Sign in with the new one.'));
    });
  }

  @override
  Widget build(BuildContext context) {
    final copy = session.copy;
    final duration = motion(context, ToviTokens.calm);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return PopScope(
      canPop: mode == AuthMode.login && !busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) back();
      },
      child: Scaffold(
        backgroundColor: Tovi.canvas,
        body: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF7A5CFF), ToviTokens.violet, ToviTokens.violetDeep]),
                ),
              ),
            ),
            const Positioned(top: 90, left: 34, child: _Spark(size: 5)),
            const Positioned(top: 150, right: 46, child: _Spark(size: 4)),
            const Positioned(top: 60, right: 120, child: _Spark(size: 3)),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      children: [
                        AnimatedOpacity(
                          duration: duration,
                          opacity: mode == AuthMode.login ? 0 : 1,
                          child: IgnorePointer(
                            ignoring: mode == AuthMode.login,
                            child: CircleButton(
                              icon: Icons.arrow_back_rounded,
                              tooltip: pick('رجوع', 'Back'),
                              onPressed: back,
                              background: Colors.white.withValues(alpha: 0.16),
                              foreground: Colors.white,
                            ),
                          ),
                        ),
                        const Spacer(),
                        CircleButton(
                          icon: Icons.language_rounded,
                          tooltip: copy.pick('English', 'العربية'),
                          onPressed: session.toggleLanguage,
                          background: Colors.white.withValues(alpha: 0.16),
                          foreground: Colors.white,
                        ),
                      ],
                    ),
                  ),
                  SizeMotion(
                    duration: duration,
                    child: keyboard
                        ? const SizedBox(height: 8, width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                            child: Column(
                              children: [
                                ToviOrb(size: mode == AuthMode.login ? 112 : 64),
                                Text(
                                  copy.brand,
                                  style: TextStyle(color: Colors.white, fontSize: mode == AuthMode.login ? 34 : 26, fontWeight: FontWeight.w700, height: 1.1),
                                ),
                                if (mode == AuthMode.login) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    pick('دروسك وحصصك المباشرة في كوكب واحد.', 'Your lessons and live classes on one planet.'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 14.5, height: 1.45),
                                  ),
                                ],
                              ],
                            ),
                          ),
                  ),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 560),
                      decoration: const BoxDecoration(
                        color: ToviTokens.surface,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(22, 26, 22, 22 + MediaQuery.paddingOf(context).bottom),
                          child: AnimatedSwitcher(
                            duration: duration,
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
                            transitionBuilder: (child, animation) => FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(animation),
                                child: child,
                              ),
                            ),
                            child: KeyedSubtree(
                              key: ValueKey('$mode-$registerStep-$resetStep'),
                              child: AutofillGroup(child: panel()),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget panel() {
    switch (mode) {
      case AuthMode.login:
        return loginPanel();
      case AuthMode.register:
        return registerStep == 1 ? registerOne() : registerTwo();
      case AuthMode.forgot:
        switch (resetStep) {
          case ResetStep.phone:
            return forgotPhone();
          case ResetStep.code:
            return forgotCode();
          case ResetStep.password:
            return forgotPassword();
        }
    }
  }

  Widget heading(String title, String sub) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: ToviTokens.ink, height: 1.25),
      ),
      const SizedBox(height: 6),
      Text(sub, style: const TextStyle(fontSize: 14, color: ToviTokens.muted, height: 1.5)),
      const SizedBox(height: 22),
    ],
  );

  Widget phoneField({TextInputAction action = TextInputAction.next, ValueChanged<String>? submit}) => ToviInput(
    controller: phone,
    label: session.copy.phone,
    icon: Icons.phone_iphone_rounded,
    hint: '07XX XXX XXXX',
    helper: pick('يبدأ بـ 07 ويتكون من 11 رقماً', 'Starts with 07, 11 digits'),
    keyboardType: TextInputType.phone,
    formatters: phoneFormatters(),
    autofillHints: const [AutofillHints.telephoneNumber],
    validator: (v) => phoneProblem(v, ar),
    showErrors: showErrors,
    textInputAction: action,
    onSubmitted: submit,
    arabic: ar,
    ltr: true,
  );

  Widget switchLine(String question, String action, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(question, style: const TextStyle(color: ToviTokens.muted, fontSize: 14)),
        TextButton(onPressed: busy ? null : onTap, child: Text(action)),
      ],
    ),
  );

  Widget loginPanel() {
    final copy = session.copy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading(pick('أهلاً بعودتك', 'Welcome back'), pick('سجّل دخولك وكمّل دروسك من وين ما وقفت.', 'Sign in and pick up your lessons where you left off.')),
        AuthBanner(text: notice, success: true),
        AuthBanner(text: error),
        phoneField(),
        const SizedBox(height: 12),
        ToviInput(
          controller: password,
          label: copy.password,
          icon: Icons.lock_rounded,
          secret: true,
          autofillHints: const [AutofillHints.password],
          validator: (v) => v.isEmpty ? passwordProblem('', ar) : null,
          showErrors: showErrors,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => login(),
          arabic: ar,
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(onPressed: busy ? null : () => go(AuthMode.forgot), child: Text(pick('نسيت كلمة المرور؟', 'Forgot password?'))),
        ),
        const SizedBox(height: 6),
        AuthButton(label: copy.login, busy: busy, onPressed: login),
        switchLine(pick('ما عندك حساب؟', 'New to Tovi?'), copy.register, () => go(AuthMode.register)),
      ],
    );
  }

  Widget registerOne() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StepProgress(step: 1, total: 2, caption: pick('الخطوة 1 من 2 · معلوماتك', 'Step 1 of 2 · About you')),
        const SizedBox(height: 18),
        heading(pick('حساب جديد', 'Create your account'), pick('خلّينا نتعرّف عليك. الاسم يظهر لأساتذتك.', 'Tell us who you are. Your teachers will see this name.')),
        ToviInput(
          controller: firstName,
          label: pick('الاسم', 'First name'),
          icon: Icons.person_rounded,
          validator: (v) => nameProblem(v, ar),
          showErrors: showErrors,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.givenName],
          arabic: ar,
        ),
        const SizedBox(height: 12),
        ToviInput(
          controller: lastName,
          label: pick('اللقب (اختياري)', 'Last name (optional)'),
          icon: Icons.badge_rounded,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.familyName],
          onSubmitted: (_) => registerNext(),
          arabic: ar,
        ),
        const SizedBox(height: 18),
        Text(
          pick('الجنس', 'Gender'),
          style: const TextStyle(fontWeight: FontWeight.w700, color: ToviTokens.inkSoft),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final (value, a, e) in [('Male', 'ذكر', 'Male'), ('Female', 'أنثى', 'Female'), ('Unspecified', 'بدون تحديد', 'Skip')]) ...[
              if (value != 'Male') const SizedBox(width: 8),
              Expanded(
                child: ChoicePill(label: pick(a, e), selected: gender == value, onTap: () => setState(() => gender = value)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 24),
        AuthButton(label: pick('التالي', 'Next'), icon: Icons.arrow_forward_rounded, onPressed: registerNext),
        switchLine(pick('عندك حساب؟', 'Have an account?'), session.copy.login, () => go(AuthMode.login)),
      ],
    );
  }

  Widget registerTwo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StepProgress(step: 2, total: 2, caption: pick('الخطوة 2 من 2 · الدخول', 'Step 2 of 2 · Sign-in details')),
        const SizedBox(height: 18),
        heading(pick('أهلاً ${firstName.text.trim()}', 'Hi ${firstName.text.trim()}'), pick('رقم هاتفك وكلمة مرور تدخل بيها كل مرة.', 'Your phone and a password you will sign in with.')),
        AuthBanner(text: error),
        phoneField(),
        const SizedBox(height: 12),
        ToviInput(
          controller: password,
          label: session.copy.password,
          icon: Icons.lock_rounded,
          secret: true,
          helper: pick('8 خانات على الأقل', 'At least 8 characters'),
          validator: (v) => passwordProblem(v, ar),
          showErrors: showErrors,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
          arabic: ar,
        ),
        const SizedBox(height: 12),
        ToviInput(
          controller: confirm,
          label: pick('تأكيد كلمة المرور', 'Confirm password'),
          icon: Icons.lock_reset_rounded,
          secret: true,
          validator: (v) => confirmProblem(v, password.text, ar),
          showErrors: showErrors,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => register(),
          arabic: ar,
        ),
        const SizedBox(height: 24),
        AuthButton(label: pick('إنشاء الحساب', 'Create account'), busy: busy, onPressed: register),
        switchLine(pick('عندك حساب؟', 'Have an account?'), session.copy.login, () => go(AuthMode.login)),
      ],
    );
  }

  Widget forgotPhone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StepProgress(step: 1, total: 3, caption: pick('الخطوة 1 من 3 · رقم الهاتف', 'Step 1 of 3 · Phone')),
        const SizedBox(height: 18),
        heading(pick('نسيت كلمة المرور؟', 'Forgot your password?'), pick('اكتب رقمك ونرسلك رمزاً من 6 أرقام برسالة نصية.', 'Enter your number and we will text you a 6-digit code.')),
        AuthBanner(text: error),
        phoneField(action: TextInputAction.done, submit: (_) => sendCode()),
        const SizedBox(height: 24),
        AuthButton(label: pick('إرسال الرمز', 'Send code'), busy: busy, onPressed: sendCode),
        switchLine(pick('تذكرتها؟', 'Remembered it?'), session.copy.login, () => go(AuthMode.login)),
      ],
    );
  }

  Widget forgotCode() {
    final minutes = resendIn ~/ 60;
    final seconds = (resendIn % 60).toString().padLeft(2, '0');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StepProgress(step: 2, total: 3, caption: pick('الخطوة 2 من 3 · رمز التحقق', 'Step 2 of 3 · Verification code')),
        const SizedBox(height: 18),
        Text(
          pick('اكتب الرمز', 'Enter the code'),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: ToviTokens.ink),
        ),
        const SizedBox(height: 6),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(pick('أرسلناه إلى ', 'We sent it to '), style: const TextStyle(fontSize: 14, color: ToviTokens.muted, height: 1.5)),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                spacedPhone(phone.text),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ToviTokens.ink),
              ),
            ),
            TextButton(
              onPressed: busy ? null : () => go(AuthMode.forgot),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 32)),
              child: Text(pick('تغيير', 'Change')),
            ),
          ],
        ),
        const SizedBox(height: 18),
        AuthBanner(text: notice, success: true),
        AuthBanner(text: error),
        OtpBoxes(controller: code, error: codeWrong, onCompleted: (value) => verifyCode(value)),
        const SizedBox(height: 14),
        Center(
          child: AnimatedSwitcher(
            duration: motion(context, ToviTokens.fast),
            child: resendIn > 0
                ? Text(
                    key: const ValueKey('wait'),
                    pick('إعادة الإرسال بعد $minutes:$seconds', 'Resend in $minutes:$seconds'),
                    style: const TextStyle(color: ToviTokens.muted, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]),
                  )
                : TextButton.icon(
                    key: const ValueKey('again'),
                    onPressed: busy ? null : () => sendCode(again: true),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(pick('إعادة إرسال الرمز', 'Resend code')),
                  ),
          ),
        ),
        const SizedBox(height: 18),
        AuthButton(label: pick('تأكيد الرمز', 'Verify code'), busy: busy, onPressed: () => verifyCode()),
      ],
    );
  }

  Widget forgotPassword() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StepProgress(step: 3, total: 3, caption: pick('الخطوة 3 من 3 · كلمة مرور جديدة', 'Step 3 of 3 · New password')),
        const SizedBox(height: 18),
        heading(pick('كلمة مرور جديدة', 'Set a new password'), pick('تم التحقق من رقمك. اختر كلمة مرور ما تنساها.', 'Your number is verified. Pick a password you will remember.')),
        AuthBanner(text: error),
        ToviInput(
          controller: password,
          label: pick('كلمة المرور الجديدة', 'New password'),
          icon: Icons.lock_rounded,
          secret: true,
          helper: pick('8 خانات على الأقل', 'At least 8 characters'),
          validator: (v) => passwordProblem(v, ar),
          showErrors: showErrors,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
          arabic: ar,
        ),
        const SizedBox(height: 12),
        ToviInput(
          controller: confirm,
          label: pick('تأكيد كلمة المرور', 'Confirm password'),
          icon: Icons.lock_reset_rounded,
          secret: true,
          validator: (v) => confirmProblem(v, password.text, ar),
          showErrors: showErrors,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => savePassword(),
          arabic: ar,
        ),
        const SizedBox(height: 24),
        AuthButton(label: pick('حفظ كلمة المرور', 'Save password'), busy: busy, onPressed: savePassword),
      ],
    );
  }
}

class _Spark extends StatelessWidget {
  const _Spark({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.55), shape: BoxShape.circle),
      ),
    );
  }
}
