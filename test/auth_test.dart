import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tovi_student/auth.dart';
import 'package:tovi_student/auth_parts.dart';
import 'package:tovi_student/main.dart';
import 'package:tovi_student/session.dart';

Future<void> openApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final session = Session(await SharedPreferences.getInstance());
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(disableAnimations: true, size: Size(390, 844)),
      child: ToviStudentApp(session: session),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Auth.PhoneProblem', () {
    expect(phoneProblem('', true), 'اكتب رقم الهاتف');
    expect(phoneProblem('0812345678', true), 'الرقم يبدأ بـ 07');
    expect(phoneProblem('0771234', true), contains('11'));
    expect(phoneProblem('07712345678', true), isNull);
    expect(phoneProblem('0771 234 5678', false), isNull);
  });

  test('Auth.PasswordAndConfirm', () {
    expect(passwordProblem('short', true), contains('8'));
    expect(passwordProblem('longenough', true), isNull);
    expect(confirmProblem('abcdefgh', 'abcdefgi', true), 'كلمتا المرور غير متطابقتين');
    expect(confirmProblem('abcdefgh', 'abcdefgh', true), isNull);
    expect(nameProblem('  ', true), isNotNull);
  });

  test('Auth.SpacedPhone', () {
    expect(spacedPhone('07712345678'), '0771 234 5678');
    expect(spacedPhone('0771'), '0771');
  });

  testWidgets('Auth.Login.ShowsInlineErrorsOnSubmit', (tester) async {
    await openApp(tester);
    expect(find.text('أهلاً بعودتك'), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'دخول'));
    await tester.tap(find.widgetWithText(FilledButton, 'دخول'));
    await tester.pump();
    expect(find.text('اكتب رقم الهاتف'), findsOneWidget);
    expect(find.text('اكتب كلمة المرور'), findsOneWidget);
  });

  testWidgets('Auth.Password.TogglesVisibility', (tester) async {
    await openApp(tester);
    TextField pass() => tester.widgetList<TextField>(find.byType(TextField)).last;
    expect(pass().obscureText, isTrue);
    await tester.tap(find.byIcon(Icons.visibility_rounded));
    await tester.pump();
    expect(pass().obscureText, isFalse);
  });

  testWidgets('Auth.Register.TwoSteps', (tester) async {
    await openApp(tester);
    await tester.ensureVisible(find.widgetWithText(TextButton, 'حساب جديد'));
    await tester.tap(find.widgetWithText(TextButton, 'حساب جديد'));
    await tester.pumpAndSettle();
    expect(find.text('الخطوة 1 من 2 · معلوماتك'), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'التالي'));
    await tester.tap(find.widgetWithText(FilledButton, 'التالي'));
    await tester.pump();
    expect(find.text('اكتب اسمك'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'زينب');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'التالي'));
    await tester.tap(find.widgetWithText(FilledButton, 'التالي'));
    await tester.pumpAndSettle();
    expect(find.text('الخطوة 2 من 2 · الدخول'), findsOneWidget);
    expect(find.text('أهلاً زينب'), findsOneWidget);
  });

  testWidgets('Auth.Otp.PasteFillsBoxesAndCompletes', (tester) async {
    final controller = TextEditingController();
    String? done;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OtpBoxes(controller: controller, onCompleted: (v) => done = v),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), 'Code: 123-456');
    await tester.pump();
    expect(controller.text, '123456');
    for (final digit in ['1', '2', '3', '4', '5', '6']) {
      expect(find.text(digit), findsOneWidget);
    }
    expect(done, '123456');
  });

  test('Auth.Otp.PasteReplacesHalfTypedCode', () {
    final f = OtpFormatter(6);
    expect(f.formatEditUpdate(const TextEditingValue(text: '482'), const TextEditingValue(text: '482731904')).text, '731904');
    expect(f.formatEditUpdate(TextEditingValue.empty, const TextEditingValue(text: 'Code: 12-34 56')).text, '123456');
    expect(f.formatEditUpdate(const TextEditingValue(text: '12'), const TextEditingValue(text: '123')).text, '123');
  });
}
