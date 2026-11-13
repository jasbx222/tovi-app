import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'copy.dart';
import 'session.dart';
import 'student_rules.dart';
import 'ui.dart';

Future<Map<String, dynamic>?> askRedeem(BuildContext context, Session session) async {
  final code = TextEditingController();
  final copy = session.copy;
  final entered = await showToviSheet<String>(
    context,
    (context) => _CodeSheet(controller: code, copy: copy),
  );
  final digits = entered ?? '';
  code.dispose();
  if (!context.mounted || digits.isEmpty) return null;
  try {
    return asMap(await session.api.post('/api/student/codes/redeem', {'code': digits}));
  } on ApiException catch (reason) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(studentMessage(reason.code, reason.message, copy.arabic))));
    }
    return null;
  }
}

class _CodeSheet extends StatefulWidget {
  const _CodeSheet({required this.controller, required this.copy});
  final TextEditingController controller;
  final Copy copy;

  @override
  State<_CodeSheet> createState() => _CodeSheetState();
}

class _CodeSheetState extends State<_CodeSheet> {
  var error = '';

  @override
  Widget build(BuildContext context) {
    final copy = widget.copy;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHandle(),
          Text(copy.redeem, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(copy.pick('16 رقماً لكورس أو ملخص أو اختبار أو صف.', '16 digits for a course, summary, exam, or classroom.'), style: const TextStyle(color: Tovi.muted, height: 1.4)),
          const SizedBox(height: 14),
          TextField(
            controller: widget.controller,
            keyboardType: TextInputType.number,
            maxLength: 16,
            decoration: toviField(copy.code),
          ),
          if (error.isNotEmpty) Text(error, style: const TextStyle(color: Tovi.danger)),
          const SizedBox(height: 14),
          ToviButton(
            label: copy.pick('تفعيل', 'Redeem'),
            onPressed: () {
              final digits = digitsOf(widget.controller.text);
              if (!activationCodeShape(digits)) {
                setState(() => error = copy.pick('الكود 16 رقماً.', 'The code is 16 digits.'));
                return;
              }
              Navigator.pop(context, digits);
            },
          ),
        ],
      ),
    );
  }
}
