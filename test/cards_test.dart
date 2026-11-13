import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tovi_student/cards.dart';
import 'package:tovi_student/copy.dart';

Widget host(Widget child) => MaterialApp(home: Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: Center(child: SizedBox(width: 280, height: 260, child: child)))));

void main() {
  testWidgets('Course card without a cover shows the subject art, chips, teacher and free badge', (tester) async {
    await tester.pumpWidget(host(CourseCard(
      copy: Copy(true),
      onTap: () {},
      row: const {'id': 'c1', 'title': 'فيزياء السادس', 'subject': 'فيزياء', 'grade': 'السادس العلمي', 'teacherId': 't1', 'teacherName': 'أحمد علي', 'lessons': 12, 'freeLessons': 2},
    )));
    expect(find.text('فيزياء السادس'), findsOneWidget);
    expect(find.text('السادس العلمي'), findsOneWidget);
    expect(find.text('أحمد علي'), findsOneWidget);
    expect(find.text('درسان مجانيان'), findsOneWidget);
    expect(find.text('12 درساً'), findsOneWidget);
    expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);
    expect(find.text('أع'), findsOneWidget);
  });

  testWidgets('Course card hides the free badge when no lesson is free', (tester) async {
    await tester.pumpWidget(host(CourseCard(copy: Copy(true), onTap: () {}, row: const {'id': 'c2', 'title': 'رياضيات', 'lessons': 3, 'freeLessons': 0})));
    expect(find.textContaining('مجانية'), findsNothing);
  });

  testWidgets('Follow pill switches label with the following state', (tester) async {
    var following = false;
    await tester.pumpWidget(StatefulBuilder(builder: (context, set) => host(Center(child: FollowPill(following: following, copy: Copy(true), onPressed: () => set(() => following = !following))))));
    expect(find.text('متابعة'), findsOneWidget);
    await tester.tap(find.text('متابعة'));
    await tester.pumpAndSettle();
    expect(find.text('متابَع'), findsOneWidget);
  });

  test('Counts shorten and initials use two names', () {
    expect(countLabel(950), '950');
    expect(countLabel(1200), '1.2K');
    expect(initialsOf('سارة محمد'), 'سم');
    expect(lessonCount(Copy(true), 1, free: true), 'درس مجاني');
    expect(lessonCount(Copy(true), 5), '5 دروس');
  });

  test('Cards.ToneFor.StableAndNoYellow', () {
    expect(toneFor('4314911b-a2bf-401c-bcd4-336dde343f9f'), toneFor('4314911b-a2bf-401c-bcd4-336dde343f9f'));
    expect(toneFor('4314911b-a2bf-401c-bcd4-336dde343f9f'), isNot(toneFor('57f6d816-0682-43c0-8a9b-85e221e2591c')));
    for (final seed in ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']) {
      expect(toneFor(seed).first, isNot(const Color(0xFFE59A00)));
    }
  });
}
