import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'session.dart';
import 'student_rules.dart';
import 'ui.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.session});
  final Session session;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final phone = TextEditingController();
  final password = TextEditingController();
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final code = TextEditingController();
  var gender = 'Unspecified';
  var registering = false;
  var error = '';
  var notice = '';
  var busy = false;

  @override
  void dispose() {
    phone.dispose();
    password.dispose();
    firstName.dispose();
    lastName.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final copy = widget.session.copy;
    if (!phoneShape(phone.text)) {
      setState(() => error = studentMessage('phone_invalid', '', copy.arabic));
      return;
    }
    if (!passwordShape(password.text)) {
      setState(() => error = studentMessage('password_short', '', copy.arabic));
      return;
    }
    setState(() { busy = true; error = ''; notice = ''; });
    try {
      final api = widget.session.api;
      final result = registering
          ? await api.post('/api/auth/student/register', {
              'firstName': firstName.text,
              'lastName': lastName.text,
              'phone': phone.text,
              'password': password.text,
              'gender': gender,
            })
          : await api.post('/api/auth/student/login', {'phone': phone.text, 'password': password.text});
      await widget.session.signIn(result['token'] as String);
    } on ApiException catch (reason) {
      setState(() => error = studentMessage(reason.code, reason.message, copy.arabic));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> reset() async {
    setState(() { busy = true; error = ''; notice = ''; });
    try {
      await widget.session.api.post('/api/auth/student/otp', {'phone': phone.text});
      if (!mounted) return;
      final entered = await showToviSheet<String>(
        context,
        (context) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHandle(),
              Text(widget.session.copy.pick('رمز التحقق', 'Verification code'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(controller: code, keyboardType: TextInputType.number, maxLength: 8, decoration: toviField(widget.session.copy.pick('الرمز', 'Code'))),
              const SizedBox(height: 14),
              ToviButton(label: widget.session.copy.pick('تأكيد', 'Confirm'), onPressed: () => Navigator.pop(context, code.text)),
              TextButton(
                onPressed: () async {
                  try {
                    await widget.session.api.post('/api/auth/student/otp', {'phone': phone.text});
                  } on ApiException catch (reason) {
                    if (mounted) setState(() => error = studentMessage(reason.code, reason.message, widget.session.copy.arabic));
                  }
                },
                child: Text(widget.session.copy.pick('إعادة الإرسال', 'Resend')),
              ),
            ],
          ),
        ),
      );
      if (entered == null || entered.isEmpty) return;
      await widget.session.api.post('/api/auth/student/otp/verify', {'phone': phone.text, 'code': entered});
      await widget.session.api.post('/api/auth/student/password-reset', {'phone': phone.text, 'code': entered, 'password': password.text});
      setState(() => notice = widget.session.copy.pick('تم تغيير كلمة المرور. ادخل بالحقل الجديد.', 'Password updated. Sign in with the new one.'));
    } on ApiException catch (reason) {
      setState(() => error = studentMessage(reason.code, reason.message, widget.session.copy.arabic));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.session.copy;
    return Scaffold(
      backgroundColor: Tovi.canvas,
      body: Stack(
        children: [
          const Positioned(top: -70, right: -50, child: _Blob(size: 220)),
          const Positioned(left: -80, bottom: 180, child: _Blob(size: 180)),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 220,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: CircleButton(
                                    icon: Icons.language_rounded,
                                    tooltip: copy.pick('English', 'العربية'),
                                    onPressed: widget.session.toggleLanguage,
                                    background: Colors.white,
                                    foreground: Tovi.violet,
                                  ),
                                ),
                                const Spacer(),
                                const ToviMark(size: 56, onViolet: true),
                                const SizedBox(height: 14),
                                Text(copy.brand, style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w700, height: 1)),
                                const SizedBox(height: 8),
                                Text(
                                  copy.pick('دروسك وحصصك المباشرة في مكان واحد.', 'Your lessons and live classes, in one place.'),
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.86), fontSize: 15, height: 1.45),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxWidth: 520),
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(registering ? copy.register : copy.login, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 14),
                              if (registering) ...[
                                TextField(controller: firstName, textInputAction: TextInputAction.next, decoration: toviField(copy.pick('الاسم', 'First name'))),
                                const SizedBox(height: 10),
                                TextField(controller: lastName, textInputAction: TextInputAction.next, decoration: toviField(copy.pick('اللقب', 'Last name'))),
                                const SizedBox(height: 10),
                                DropdownButtonFormField<String>(
                                  initialValue: gender,
                                  decoration: toviField(copy.pick('الجنس', 'Gender')),
                                  items: [
                                    DropdownMenuItem(value: 'Unspecified', child: Text(copy.pick('غير محدد', 'Unspecified'))),
                                    DropdownMenuItem(value: 'Male', child: Text(copy.pick('ذكر', 'Male'))),
                                    DropdownMenuItem(value: 'Female', child: Text(copy.pick('أنثى', 'Female'))),
                                  ],
                                  onChanged: (value) => setState(() => gender = value ?? 'Unspecified'),
                                ),
                                const SizedBox(height: 10),
                              ],
                              TextField(controller: phone, keyboardType: TextInputType.phone, textInputAction: TextInputAction.next, decoration: toviField(copy.phone, icon: Icons.phone_rounded)),
                              const SizedBox(height: 10),
                              TextField(controller: password, obscureText: true, decoration: toviField(copy.password, icon: Icons.lock_rounded)),
                              if (error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error, style: const TextStyle(color: Tovi.danger, height: 1.4))),
                              if (notice.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(notice, style: const TextStyle(color: Tovi.ok, height: 1.4))),
                              const SizedBox(height: 16),
                              ToviButton(label: registering ? copy.register : copy.login, busy: busy, onPressed: submit),
                              const SizedBox(height: 4),
                              TextButton(onPressed: busy ? null : () => setState(() { registering = !registering; error = ''; notice = ''; }), child: Text(registering ? copy.login : copy.register)),
                              TextButton(onPressed: busy ? null : reset, child: Text(copy.pick('نسيت كلمة المرور', 'Reset password'))),
                            ],
                          ),
                        ),
                        ),
                      ],
                    ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
      ),
    );
  }
}
