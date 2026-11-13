import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'session.dart';
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
  final code = TextEditingController();
  var registering = false;
  var error = '';
  var busy = false;

  @override
  void dispose() {
    phone.dispose();
    password.dispose();
    firstName.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() { busy = true; error = ''; });
    try {
      final api = widget.session.api;
      final result = registering
          ? await api.post('/api/auth/student/register', {
              'firstName': firstName.text,
              'phone': phone.text,
              'password': password.text,
              'gender': 'Unspecified',
            })
          : await api.post('/api/auth/student/login', {'phone': phone.text, 'password': password.text});
      await widget.session.signIn(result['token'] as String);
    } on ApiException catch (reason) {
      setState(() => error = reason.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> reset() async {
    setState(() { busy = true; error = ''; });
    try {
      await widget.session.api.post('/api/auth/student/otp', {'phone': phone.text});
      if (!mounted) return;
      final entered = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(widget.session.copy.pick('رمز التحقق', 'Verification code')),
          content: TextField(controller: code, keyboardType: TextInputType.number),
          actions: [TextButton(onPressed: () => Navigator.pop(context, code.text), child: Text(widget.session.copy.pick('تأكيد', 'Confirm')))],
        ),
      );
      if (entered == null || entered.isEmpty) return;
      await widget.session.api.post('/api/auth/student/otp/verify', {'phone': phone.text, 'code': entered});
      await widget.session.api.post('/api/auth/student/password-reset', {'phone': phone.text, 'code': entered, 'password': password.text});
      setState(() => error = widget.session.copy.pick('تم تغيير كلمة المرور', 'Password updated'));
    } on ApiException catch (reason) {
      setState(() => error = reason.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.session.copy;
    return Scaffold(
      backgroundColor: Tovi.paper,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Container(width: 48, height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: Tovi.ink, borderRadius: BorderRadius.circular(14)), child: const Text('T', style: TextStyle(color: Color(0xFFF6F1E7), fontWeight: FontWeight.w700, fontSize: 22))),
                  ),
                  const SizedBox(height: 16),
                  Text(copy.brand, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700, letterSpacing: -1)),
                  const SizedBox(height: 6),
                  Text(copy.pick('تعلّم دروسك وحصصك المباشرة من مكان واحد.', 'Your lessons and live classes, in one place.'), style: const TextStyle(color: Tovi.muted, height: 1.5)),
                  const SizedBox(height: 22),
                  if (registering) TextField(controller: firstName, decoration: toviField(copy.pick('الاسم', 'First name'))),
                  if (registering) const SizedBox(height: 10),
                  TextField(controller: phone, decoration: toviField(copy.phone), keyboardType: TextInputType.phone),
                  const SizedBox(height: 10),
                  TextField(controller: password, decoration: toviField(copy.password), obscureText: true),
                  if (error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error, style: const TextStyle(color: Color(0xFFA33B32)))),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: busy ? null : submit, child: Text(registering ? copy.register : copy.login)),
                  TextButton(onPressed: () => setState(() => registering = !registering), child: Text(registering ? copy.login : copy.register)),
                  TextButton(onPressed: busy ? null : reset, child: Text(copy.pick('نسيت كلمة المرور', 'Reset password'))),
                  TextButton(onPressed: widget.session.toggleLanguage, child: Text(copy.pick('English', 'العربية'))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
