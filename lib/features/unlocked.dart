import 'package:material_ui/material_ui.dart';

import '../app.dart';
import '../course_page.dart';
import '../exam_page.dart';
import '../redeem.dart';
import '../session.dart';
import '../ui.dart';
import 'hub_kit.dart';
import 'tiles.dart';

/// Everything the student unlocked with a code: courses, summaries, exams and classrooms.
class UnlockedPage extends StatefulWidget {
  const UnlockedPage({super.key, required this.session});
  final Session session;
  @override
  State<UnlockedPage> createState() => _UnlockedPageState();
}

class _UnlockedPageState extends State<UnlockedPage> {
  static const types = ['', 'Course', 'Summary', 'Exam', 'VirtualClassroom'];
  var tab = 0;
  var list = GlobalKey<PagedListState>();
  Map<String, dynamic> counts = {};

  Future<void> open(Map<String, dynamic> row) async {
    final id = asText(row['targetId']);
    final page = switch (asText(row['type'])) {
      'Course' => CoursePage(session: widget.session, id: id),
      'Summary' => SummaryPage(session: widget.session, id: id),
      'Exam' => ExamPage(session: widget.session, id: id),
      _ => null,
    };
    if (page != null) await Navigator.push(context, toviRoute(page));
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.session.copy;
    final total = counts.values.fold<int>(0, (a, b) => a + asInt(b));
    return HubScaffold(
      title: copy.pick('اللي فعّلته', 'What I unlocked'),
      action: IconButton(
        tooltip: copy.redeem,
        onPressed: () async { await askRedeem(context, widget.session); list.currentState?.refresh(); },
        icon: const Icon(Icons.add_circle_rounded, color: ToviTokens.violet, size: 28),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: HubSegments(
            labels: [copy.pick('الكل', 'All'), copy.pick('دورات', 'Courses'), copy.pick('ملخصات', 'Summaries'), copy.pick('اختبارات', 'Exams'), copy.pick('صفوف', 'Classrooms')],
            index: tab,
            counts: [total, for (final t in types.skip(1)) asInt(counts[t])],
            onChanged: (i) => setState(() { tab = i; list = GlobalKey<PagedListState>(); }),
          ),
        ),
        Expanded(
          child: PagedList(
            key: list,
            session: widget.session,
            load: (page) => widget.session.api.get('/api/student/unlocked?page=$page&pageSize=20${types[tab].isEmpty ? '' : '&type=${types[tab]}'}'),
            onPage: (data) { if (data['counts'] is Map) setState(() => counts = asMap(data['counts'])); },
            empty: HubEmpty(
              icon: Icons.key_rounded,
              title: copy.pick('ما فعّلت شي بعد', 'Nothing unlocked yet'),
              body: copy.pick('فعّل كود من معلمك حتى تفتح دورة أو ملخص أو اختبار أو صف.', 'Redeem a code from your teacher to open a course, summary, exam or classroom.'),
              action: copy.redeem,
              onAction: () async { await askRedeem(context, widget.session); list.currentState?.refresh(); },
            ),
            itemBuilder: (context, row, i, refresh) => _UnlockRow(session: widget.session, row: row, onTap: () => open(row)),
          ),
        ),
      ]),
    );
  }
}

class _UnlockRow extends StatelessWidget {
  const _UnlockRow({required this.session, required this.row, required this.onTap});
  final Session session;
  final Map<String, dynamic> row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final copy = session.copy;
    final type = asText(row['type']);
    final (icon, color, label) = switch (type) {
      'Course' => (Icons.menu_book_rounded, ToviTokens.violet, copy.pick('دورة', 'Course')),
      'Summary' => (Icons.description_rounded, ToviTokens.coral, copy.pick('ملخص', 'Summary')),
      'Exam' => (Icons.quiz_rounded, ToviTokens.sky, copy.pick('اختبار', 'Exam')),
      _ => (Icons.videocam_rounded, ToviTokens.mint, copy.pick('صف مباشر', 'Live classroom')),
    };
    final when = asDate(row['unlockedAt']);
    final lessons = asInt(row['lessons']);
    final done = asInt(row['done']);
    return SoftPanel(
      onTap: type == 'VirtualClassroom' ? null : onTap,
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        SizedBox(
          width: 58,
          height: 58,
          child: type == 'Course' ? HubPhoto(url: row['coverUrl'], seed: asText(row['title']), radius: 16) : IconOrb(icon: icon, color: color, size: 58),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(asText(row['title']), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 4),
          Text(
            [label, if (when != null) copy.pick('فُعّل ${shortDate(when, true)}', 'Unlocked ${shortDate(when, false)}'), if (asText(row['code']).isNotEmpty) asText(row['code'])].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: ToviTokens.muted, fontSize: 12.5),
          ),
          if (type == 'Course' && lessons > 0) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: done / lessons, minHeight: 6, backgroundColor: ToviTokens.sunken, color: ToviTokens.violet))),
              const SizedBox(width: 8),
              Text('$done/$lessons', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: ToviTokens.violet)),
            ]),
          ],
        ])),
      ]),
    );
  }
}
