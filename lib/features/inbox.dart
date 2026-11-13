import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../app.dart';
import '../course_page.dart';
import '../exam_page.dart';
import '../meeting_page.dart';
import '../session.dart';
import '../ui.dart';
import 'hub_kit.dart';
import 'places.dart';
import 'tiles.dart';

/// Unread notification count shared by the tab bar and the home header.
class UnreadCounter extends ValueNotifier<int> {
  UnreadCounter(this.session) : super(0);
  final Session session;
  Timer? _timer;

  void start() {
    refresh();
    _timer ??= Timer.periodic(const Duration(seconds: 60), (_) => refresh());
  }

  Future<void> refresh() async {
    if (!session.signedIn) return;
    try {
      value = asInt(asMap(await session.api.get('/api/student/inbox/unread'))['unread']);
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Notifications grouped by day with read state, mark-all and deep links.
class NoticesPage extends StatefulWidget {
  const NoticesPage({super.key, required this.session, required this.counter});
  final Session session;
  final UnreadCounter counter;
  @override
  State<NoticesPage> createState() => _NoticesPageState();
}

class _NoticesPageState extends State<NoticesPage> {
  var unreadOnly = false;
  var list = GlobalKey<PagedListState>();

  Future<void> markAll() async {
    try {
      await widget.session.api.post('/api/student/inbox/read-all');
      widget.counter.value = 0;
      list.currentState?.refresh();
    } catch (reason) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hubError(reason, widget.session))));
    }
  }

  Future<void> open(Map<String, dynamic> row, int index) async {
    if (row['read'] != true) {
      list.currentState?.replace(index, {...row, 'read': true});
      try {
        final result = asMap(await widget.session.api.post('/api/student/inbox/${row['id']}/read'));
        widget.counter.value = asInt(result['unread']);
      } catch (_) {}
    }
    if (!mounted) return;
    final id = asText(row['targetId']);
    final s = widget.session;
    final Widget? page = switch (asText(row['targetType'])) {
      'session' => MeetingPage(session: s, sessionId: id),
      'course' => CoursePage(session: s, id: id),
      'exam' => ExamPage(session: s, id: id),
      'summary' => SummaryPage(session: s, id: id),
      'institute' => InstitutePage(session: s, id: id),
      'teacher' => teacherPageBuilder?.call(s, id),
      _ => null,
    };
    if (page != null) await Navigator.push(context, toviRoute(page));
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.session.copy;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
        child: Row(children: [
          Expanded(child: Text(copy.inbox, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
          ValueListenableBuilder<int>(
            valueListenable: widget.counter,
            builder: (context, unread, _) => unread == 0
                ? const SizedBox()
                : TextButton.icon(onPressed: markAll, icon: const Icon(Icons.done_all_rounded, size: 18), label: Text(copy.pick('قراءة الكل', 'Mark all read'))),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        child: ValueListenableBuilder<int>(
          valueListenable: widget.counter,
          builder: (context, unread, _) => HubSegments(
            labels: [copy.pick('الكل', 'All'), copy.pick('غير مقروءة', 'Unread')],
            counts: [null, unread],
            index: unreadOnly ? 1 : 0,
            onChanged: (i) => setState(() { unreadOnly = i == 1; list = GlobalKey<PagedListState>(); }),
          ),
        ),
      ),
      Expanded(
        child: PagedList(
          key: list,
          session: widget.session,
          load: (page) => widget.session.api.get('/api/student/inbox?page=$page&pageSize=20${unreadOnly ? '&unread=true' : ''}'),
          onPage: (data) => widget.counter.value = asInt(data['unread']),
          empty: HubEmpty(
            icon: Icons.notifications_rounded,
            title: unreadOnly ? copy.pick('كلشي مقروء', 'All caught up') : copy.pick('ما عندك إشعارات', 'No notifications yet'),
            body: copy.pick('هنا تطلعلك تذكيرات الحصص وأخبار معلميك.', 'Session reminders and news from your teachers show up here.'),
          ),
          itemBuilder: (context, row, i, refresh) {
            final rows = list.currentState?.items ?? const <Map<String, dynamic>>[];
            final when = asDate(row['createdAt']);
            final prev = i > 0 && i - 1 < rows.length ? asDate(rows[i - 1]['createdAt']) : null;
            final newDay = when != null && (prev == null || prev.day != when.day || prev.month != when.month || prev.year != when.year);
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (newDay)
                Padding(
                  padding: EdgeInsets.only(bottom: 8, top: i == 0 ? 0 : 6),
                  child: Text(_dayLabel(when, copy.arabic), style: const TextStyle(color: ToviTokens.muted, fontWeight: FontWeight.w800, fontSize: 13)),
                ),
              _NoticeRow(session: widget.session, row: row, onTap: () => open(row, i)),
            ]);
          },
        ),
      ),
    ]);
  }
}

String _dayLabel(DateTime when, bool arabic) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(when.year, when.month, when.day);
  final gap = today.difference(day).inDays;
  if (gap == 0) return arabic ? 'اليوم' : 'Today';
  if (gap == 1) return arabic ? 'أمس' : 'Yesterday';
  return shortDate(when, arabic);
}

class _NoticeRow extends StatelessWidget {
  const _NoticeRow({required this.session, required this.row, required this.onTap});
  final Session session;
  final Map<String, dynamic> row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final copy = session.copy;
    final read = row['read'] == true;
    final target = asText(row['targetType']);
    final (icon, color) = switch (asText(row['type'])) {
      'Warning' => (Icons.warning_amber_rounded, ToviTokens.coral),
      'Ads' => (Icons.campaign_rounded, const Color(0xFFE0A100)),
      _ => switch (target) {
          'session' => (Icons.videocam_rounded, ToviTokens.violet),
          'exam' => (Icons.quiz_rounded, ToviTokens.sky),
          'course' => (Icons.menu_book_rounded, ToviTokens.mint),
          _ => (Icons.notifications_rounded, ToviTokens.violet),
        },
    };
    final when = asDate(row['createdAt']);
    return SoftPanel(
      onTap: onTap,
      color: read ? ToviTokens.surface : const Color(0xFFF3F0FF),
      padding: const EdgeInsets.all(14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(clipBehavior: Clip.none, children: [
          IconOrb(icon: icon, color: color, size: 44),
          if (!read) const PositionedDirectional(end: -2, top: -2, child: CircleAvatar(radius: 6, backgroundColor: ToviTokens.coral)),
        ]),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(asText(row['title']), style: TextStyle(fontWeight: read ? FontWeight.w600 : FontWeight.w800, fontSize: 15))),
            if (when != null) Text(agoOf(when, copy.arabic), style: const TextStyle(color: ToviTokens.faint, fontSize: 12)),
          ]),
          if (asText(row['body']).isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(asText(row['body']), style: const TextStyle(color: ToviTokens.muted, height: 1.45)),
          ],
          if (target.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              switch (target) {
                'session' => copy.pick('افتح الحصة ←', 'Open the session →'),
                'exam' => copy.pick('افتح الاختبار ←', 'Open the exam →'),
                'course' => copy.pick('افتح الدورة ←', 'Open the course →'),
                _ => copy.pick('افتح ←', 'Open →'),
              },
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12.5),
            ),
          ],
        ])),
      ]),
    );
  }
}
