import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tovi_student/copy.dart';
import 'package:tovi_student/live_parts.dart';
import 'package:tovi_student/progress_page.dart';
import 'package:tovi_student/ui.dart';

Widget host(Widget child) => MaterialApp(home: Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: child)));

void main() {
  testWidgets('Bar shows Arabic labels and swaps to the filled icon when active', (tester) async {
    var picked = -1;
    await tester.pumpWidget(host(ToviBar(
      index: 1,
      onSelect: (value) => picked = value,
      tabs: const [
        ToviTab(Icons.home_outlined, 'الرئيسية', activeIcon: Icons.home_rounded),
        ToviTab(Icons.event_note_outlined, 'الجدول', activeIcon: Icons.event_note_rounded),
      ],
    )));
    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('الجدول'), findsOneWidget);
    expect(find.byIcon(Icons.event_note_rounded), findsOneWidget);
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    await tester.tap(find.text('الرئيسية'));
    expect(picked, 0);
  });

  test('Countdown formats minutes and hours', () {
    expect(countdown(const Duration(minutes: 4, seconds: 5)), '04:05');
    expect(countdown(const Duration(hours: 1, minutes: 2, seconds: 3)), '01:02:03');
    expect(countdown(const Duration(seconds: -3)), '00:00');
  });

  testWidgets('Progress card shows streak and points from the server', (tester) async {
    await tester.pumpWidget(host(ProgressCard(
      copy: const Copy(true),
      onOpen: () {},
      data: {
        'xp': 60,
        'streak': {'current': 3, 'best': 3, 'activeToday': true},
        'week': [for (var i = 7; i <= 13; i++) {'day': '2026-11-${i.toString().padLeft(2, '0')}', 'xp': i == 13 ? 30 : 0}],
      },
    )));
    expect(find.text('3'), findsOneWidget);
    expect(find.text('60'), findsOneWidget);
    expect(find.text('أحسنت، سلسلتك محفوظة اليوم.'), findsOneWidget);
  });

  testWidgets('Attendance strip reports progress toward attendance', (tester) async {
    await tester.pumpWidget(host(const AttendanceStrip(copy: Copy(true), me: {'liveSeconds': 600, 'attendanceSeconds': 1200, 'attended': false}, light: true)));
    expect(find.text('حضورك 10 من 20 دقيقة'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
  });

  testWidgets('Polls reveal results after voting and lock the choice', (tester) async {
    final votes = <int>[];
    await tester.pumpWidget(host(LivePanel(
      copy: const Copy(true),
      initial: 2,
      messages: const [],
      questions: const [],
      polls: const [
        {
          'id': 'p1',
          'question': 'أي قانون؟',
          'open': true,
          'total': 4,
          'myOption': null,
          'options': [
            {'index': 0, 'text': 'الأول', 'votes': 1},
            {'index': 1, 'text': 'الثاني', 'votes': 3},
          ],
        },
      ],
      composer: TextEditingController(),
      canChat: true,
      onSend: () async {},
      onAsk: (_) async => null,
      onVote: (_) async {},
      onAnswer: (id, option) async => votes.add(option),
    )));
    expect(find.text('75%'), findsNothing);
    await tester.tap(find.text('الثاني'));
    expect(votes, [1]);
  });
}
