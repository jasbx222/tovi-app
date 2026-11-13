import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tovi_student/features/hub_kit.dart';
import 'package:tovi_student/ui.dart';

Widget host(Widget child) => MaterialApp(home: Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: child)));

void main() {
  test('Initials and dates read naturally', () {
    expect(initialsOf('زهراء علي'), 'زع');
    expect(initialsOf('  '), 'ت');
    expect(shortDate(DateTime(2026, 11, 13), true), '13 تشرين الثاني');
    expect(hourOf(DateTime(2026, 1, 1, 18, 5), false), '6:05 pm');
  });

  testWidgets('Tabs show counts and report the picked tab', (tester) async {
    var picked = -1;
    await tester.pumpWidget(host(HubSegments(labels: const ['مفتوحة', 'مقدّمة'], counts: const [3, null], index: 0, onChanged: (i) => picked = i)));
    expect(find.text('3'), findsOneWidget);
    await tester.tap(find.text('مقدّمة'));
    expect(picked, 1);
  });

  testWidgets('Bar shows the unread badge only when there is something new', (tester) async {
    await tester.pumpWidget(host(ToviBar(index: 0, onSelect: (_) {}, tabs: const [
      ToviTab(Icons.home_outlined, 'الرئيسية'),
      ToviTab(Icons.notifications_none_rounded, 'الإشعارات', badge: 4),
    ])));
    expect(find.text('4'), findsOneWidget);
    await tester.pumpWidget(host(ToviBar(index: 0, onSelect: (_) {}, tabs: const [
      ToviTab(Icons.notifications_none_rounded, 'الإشعارات'),
    ])));
    expect(find.text('0'), findsNothing);
  });
}
