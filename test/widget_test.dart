import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tovi_student/main.dart';
import 'package:tovi_student/session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Student.Auth.ShowsArabicSignIn', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final session = Session(await SharedPreferences.getInstance());
    await tester.pumpWidget(ToviStudentApp(session: session));
    expect(find.text('توفي'), findsOneWidget);
    expect(find.text('دخول'), findsOneWidget);
  });
}
