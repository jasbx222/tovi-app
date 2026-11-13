import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'copy.dart';
import 'course_page.dart';
import 'exam_page.dart';
import 'features/account.dart';
import 'features/explore.dart';
import 'features/hub_kit.dart' show hubImageToken;
import 'features/inbox.dart';
import 'features/search.dart';
import 'features/sessions.dart';
import 'live_parts.dart';
import 'meeting_page.dart';
import 'progress_page.dart';
import 'push.dart';
import 'redeem.dart';
import 'session.dart';
import 'student_rules.dart';
import 'ui.dart';

export 'auth.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.session});
  final Session session;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  var index = 0;
  late final unread = UnreadCounter(widget.session)..start();

  @override
  void initState() {
    super.initState();
    registerDeviceToken(widget.session);
    hubImageToken = widget.session.token;
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) maybeOnboard(context, widget.session); });
  }

  @override
  void dispose() {
    unread.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(session: widget.session, onOpenSchedule: () => setState(() => index = 1), onOpenInbox: () => setState(() => index = 3)),
      SessionsHub(session: widget.session),
      ExplorePage(session: widget.session),
      NoticesPage(session: widget.session, counter: unread),
      MePage(session: widget.session),
    ];
    return ValueListenableBuilder<int>(valueListenable: unread, builder: (context, count, _) => _frame(context, pages, count));
  }

  Widget _frame(BuildContext context, List<Widget> pages, int count) {
    final copy = widget.session.copy;
    final tabs = [
      ToviTab(Icons.home_outlined, copy.home, activeIcon: Icons.home_rounded),
      ToviTab(Icons.event_note_outlined, copy.schedule, activeIcon: Icons.event_note_rounded),
      ToviTab(Icons.auto_stories_outlined, copy.learn, activeIcon: Icons.auto_stories_rounded),
      ToviTab(Icons.notifications_none_rounded, copy.inbox, activeIcon: Icons.notifications_rounded, badge: count),
      ToviTab(Icons.person_outline_rounded, copy.profile, activeIcon: Icons.person_rounded),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 840;
    return Scaffold(
      backgroundColor: Tovi.page,
      body: SafeArea(
        bottom: false,
        child: wide
            ? Row(
                children: [
                  _Rail(index: index, tabs: tabs, brand: copy.brand, onSelect: (value) => setState(() => index = value)),
                  Expanded(child: pages[index]),
                ],
              )
            : pages[index],
      ),
      bottomNavigationBar: wide ? null : ToviBar(index: index, tabs: tabs, onSelect: (value) => setState(() => index = value)),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.index, required this.tabs, required this.brand, required this.onSelect});
  final int index;
  final List<ToviTab> tabs;
  final String brand;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      margin: const EdgeInsets.fromLTRB(16, 12, 0, 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Tovi.surface, borderRadius: BorderRadius.circular(28), boxShadow: Tovi.shadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 18),
            child: Row(children: [
              const ToviMark(size: 40),
              const SizedBox(width: 10),
              Text(brand, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            ]),
          ),
          for (var i = 0; i < tabs.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: index == i ? Tovi.lilac : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onSelect(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Row(children: [
                      Icon(index == i ? tabs[i].activeIcon : tabs[i].icon, color: index == i ? Tovi.violet : Tovi.muted, size: 22),
                      const SizedBox(width: 10),
                      Text(tabs[i].label, style: TextStyle(fontWeight: FontWeight.w700, color: index == i ? Tovi.violet : Tovi.ink)),
                    ]),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.session, required this.onOpenSchedule, required this.onOpenInbox});
  final Session session;
  final VoidCallback onOpenSchedule;
  final VoidCallback onOpenInbox;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, dynamic>? data;
  String name = '';
  String notes = '—';
  String error = '';
  List<Map<String, dynamic>> domains = [];
  Map<String, dynamic>? progress;
  var loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final results = await Future.wait([
      _guard(widget.session.api.get('/api/student/home')),
      _guard(widget.session.api.get('/api/student/profile')),
      _guard(widget.session.api.get('/api/student/inbox/unread')),
      _guard(widget.session.api.get('/api/student/learning-domains')),
      _guard(widget.session.api.get('/api/student/progress')),
    ]);
    if (!mounted) return;
    final home = results[0];
    if (home is ApiException) {
      if (home.status == 401) await widget.session.signOut(tellServer: false);
      setState(() { error = studentMessage(home.code, home.message, widget.session.copy.arabic); loading = false; });
      return;
    }
    final profile = results[1];
    final inbox = results[2];
    var nextName = '';
    if (profile is Map) {
      final row = asMap(profile);
      nextName = '${asText(row['firstName'])} ${asText(row['lastName'])}'.trim();
    }
    var nextNotes = '—';
    if (inbox is Map) nextNotes = '${asInt(asMap(inbox)['unread'])}';
    setState(() {
      data = asMap(home);
      name = nextName;
      notes = nextNotes;
      domains = results[3] is List ? asMaps(results[3]) : [];
      progress = results[4] is Map ? asMap(results[4]) : null;
      error = '';
      loading = false;
    });
  }

  Future<void> redeem() async {
    final result = await askRedeem(context, widget.session);
    if (!mounted || result == null) return;
    await load();
    if (!mounted) return;
    final type = asText(result['targetType']);
    final id = asText(result['targetId']);
    if (type == 'Course') {
      await Navigator.push(context, toviRoute(CoursePage(session: widget.session, id: id)));
    } else if (type == 'Summary') {
      await Navigator.push(context, toviRoute(SummaryPage(session: widget.session, id: id)));
    } else if (type == 'Exam') {
      await Navigator.push(context, toviRoute(ExamPage(session: widget.session, id: id)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.session.copy;
    final courses = asMaps(data?['courses']);
    final sessions = asMaps(data?['sessions']);
    final ads = asMaps(data?['ads']);
    final shown = name.isEmpty ? copy.brand : name;
    return RefreshIndicator(
      color: Tovi.violet,
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          _HomeHead(
            name: shown,
            role: copy.student,
            inboxTip: copy.inbox,
            notes: notes == '—' || notes == '0' ? null : notes,
            onSearch: () => Navigator.push(context, toviRoute(FindPage(session: widget.session))),
            onInbox: widget.onOpenInbox,
          ),
          const SizedBox(height: 16),
          _RedeemStrip(title: copy.redeem, hint: copy.pick('16 رقماً لكورس أو ملخص أو اختبار أو صف.', '16 digits for a course, summary, exam, or classroom.'), onTap: redeem),
          if (error.isNotEmpty) ErrorNote(text: error, onRetry: load),
          if (loading)
            const _HomeSkeleton()
          else ...[
            if (_nextSession(sessions) != null) ...[
              const SizedBox(height: 18),
              _NextLive(
                row: _nextSession(sessions)!,
                copy: copy,
                onOpen: () => Navigator.push(context, toviRoute(MeetingPage(session: widget.session, sessionId: asText(_nextSession(sessions)!['id'])))),
              ),
            ],
            if (progress != null) ...[
              SectionHead(title: copy.pick('تقدّمك', 'Your progress')),
              ProgressCard(copy: copy, data: progress!, onOpen: () async {
                await Navigator.push(context, toviRoute(ProgressPage(session: widget.session)));
                if (mounted) await load();
              }),
            ],
            SectionHead(title: copy.pick('نشاطك', 'Your activity')),
            Row(children: [
              Expanded(child: StatPill(color: Tovi.blue, icon: Icons.menu_book_rounded, label: copy.pick('الدورات', 'Courses'), value: '${courses.length}')),
              const SizedBox(width: 10),
              Expanded(child: StatPill(color: Tovi.coral, icon: Icons.event_rounded, label: copy.pick('الجلسات', 'Sessions'), value: '${sessions.length}')),
              const SizedBox(width: 10),
              Expanded(child: StatPill(color: Tovi.violet, icon: Icons.notifications_none_rounded, label: copy.inbox, value: notes)),
            ]),
            if (domains.isNotEmpty) ...[
              SectionHead(title: copy.pick('المجالات', 'Domains')),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final row in domains)
                  ActionChip(
                    label: Text(asText(row['name'])),
                    backgroundColor: Tovi.surface,
                    side: BorderSide.none,
                    elevation: 0,
                    onPressed: () => Navigator.push(context, toviRoute(CatalogPage(session: widget.session, path: '/api/student/learning-domains', field: 'name', title: copy.pick('المجالات', 'Domains')))),
                  ),
              ]),
            ],
            SectionHead(
              title: copy.pick('دوراتي', 'My courses'),
              action: courses.isEmpty ? null : copy.viewAll,
              onAction: () => Navigator.push(context, toviRoute(CatalogPage(session: widget.session, path: '/api/student/courses', field: 'title', title: copy.pick('الدورات', 'Courses')))),
            ),
            if (courses.isEmpty)
              EmptyNote(icon: Icons.menu_book_rounded, text: copy.empty)
            else
              SizedBox(
                height: 176,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: courses.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final row = courses[i];
                    final viewport = MediaQuery.sizeOf(context).width - 40;
                    final width = courses.length == 1 ? viewport : (viewport - 12) / 2;
                    return SizedBox(
                      width: width,
                      child: CoursePoster(
                        title: asText(row['title']),
                        meta: firstMeta(row, const ['teacherName', 'instructor', 'author']),
                        color: Tovi.courses[i % Tovi.courses.length],
                        onTap: () => Navigator.push(context, toviRoute(CoursePage(session: widget.session, id: asText(row['id'])))),
                      ),
                    );
                  },
                ),
              ),
            if (sessions.isNotEmpty) ...[
              SectionHead(title: copy.pick('جلساتك القادمة', 'Upcoming sessions'), action: copy.schedule, onAction: widget.onOpenSchedule),
              for (final row in sessions.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SessionRow(
                    row: row,
                    copy: copy,
                    onJoin: () => Navigator.push(context, toviRoute(MeetingPage(session: widget.session, sessionId: asText(row['id'])))),
                  ),
                ),
            ],
            if (ads.isNotEmpty) ...[
              SectionHead(title: copy.pick('الإعلانات', 'Advertisements')),
              for (final row in ads)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SoftPanel(
                    color: Tovi.lilac,
                    onTap: asText(row['linkUrl']).isEmpty ? null : () => launchUrl(Uri.parse(asText(row['linkUrl']))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(copy.pick('إعلان', 'Notice'), style: const TextStyle(color: Tovi.violet, fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(asText(row['title']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      if (asText(row['body']).isNotEmpty) Text(asText(row['body']), style: const TextStyle(color: Tovi.muted, height: 1.45)),
                    ]),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

Map<String, dynamic>? _nextSession(List<Map<String, dynamic>> sessions) {
  final now = DateTime.now();
  Map<String, dynamic>? best;
  DateTime? bestStart;
  for (final row in sessions) {
    final start = asDate(row['startsAt']);
    if (start == null || asText(row['status']) == 'Cancelled') continue;
    final end = start.add(Duration(minutes: asInt(row['durationMinutes'])));
    if (end.isBefore(now)) continue;
    if (bestStart == null || start.isBefore(bestStart)) {
      best = row;
      bestStart = start;
    }
  }
  return best;
}

class _NextLive extends StatelessWidget {
  const _NextLive({required this.row, required this.copy, required this.onOpen});
  final Map<String, dynamic> row;
  final Copy copy;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final start = asDate(row['startsAt']) ?? DateTime.now();
    final now = DateTime.now();
    final live = !now.isBefore(start);
    final soon = start.difference(now).inMinutes < 10;
    final title = firstMeta(row, const ['title', 'classroomTitle']);
    final sameDay = start.year == now.year && start.month == now.month && start.day == now.day;
    final when = live
        ? copy.pick('مباشر الآن', 'Live now')
        : '${sameDay ? copy.pick('اليوم', 'Today') : copy.pick('${start.day}/${start.month}', '${start.month}/${start.day}')} · ${clockOf(start, copy.arabic)}';
    return Material(
      color: live ? ToviTokens.coral : Tovi.violet,
      borderRadius: BorderRadius.circular(ToviTokens.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(99)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(live ? Icons.sensors_rounded : Icons.schedule_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(when, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                ),
                const SizedBox(height: 12),
                Text(title.isEmpty ? copy.meeting : title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700, height: 1.3)),
                const SizedBox(height: 4),
                Text(
                  [asText(row['teacherName']), '${asInt(row['durationMinutes'])} ${copy.pick('دقيقة', 'min')}'].where((t) => t.isNotEmpty).join(' · '),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                ),
              ]),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
              child: Text(
                live ? copy.pick('ادخل', 'Join') : (soon ? copy.pick('الانتظار', 'Lobby') : copy.pick('التفاصيل', 'Details')),
                style: TextStyle(color: live ? ToviTokens.coral : Tovi.violet, fontWeight: FontWeight.w700),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _HomeHead extends StatelessWidget {
  const _HomeHead({required this.name, required this.role, required this.onSearch, required this.onInbox, this.notes, required this.inboxTip});
  final String name;
  final String role;
  final String inboxTip;
  final String? notes;
  final VoidCallback onSearch;
  final VoidCallback onInbox;

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? 'T' : name.substring(0, 1);
    return Row(children: [
      CircleAvatar(radius: 24, backgroundColor: Tovi.violet, child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        Text(role, style: const TextStyle(color: Tovi.muted, fontSize: 13)),
      ])),
      CircleButton(icon: Icons.search_rounded, tooltip: MaterialLocalizations.of(context).searchFieldLabel, onPressed: onSearch, background: Tovi.surface),
      const SizedBox(width: 8),
      CircleButton(icon: Icons.notifications_none_rounded, tooltip: inboxTip, badge: notes, onPressed: onInbox, background: Tovi.surface),
    ]);
  }
}

class _RedeemStrip extends StatelessWidget {
  const _RedeemStrip({required this.title, required this.hint, required this.onTap});
  final String title;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ToviTokens.sunSoft,
      borderRadius: BorderRadius.circular(ToviTokens.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(width: 40, height: 40, alignment: Alignment.center, decoration: const BoxDecoration(color: Tovi.sun, shape: BoxShape.circle), child: const Icon(Icons.vpn_key_rounded, color: Tovi.ink, size: 18)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(hint, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Tovi.muted, fontSize: 12, height: 1.35)),
            ])),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF9A6A00)),
          ]),
        ),
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();
  @override
  Widget build(BuildContext context) {
    return const SkeletonFade(child: Column(children: [
      SizedBox(height: 18),
      Bone(height: 150, radius: 24),
      SizedBox(height: 18),
      Row(children: [Expanded(child: Bone(height: 112, radius: 18)), SizedBox(width: 10), Expanded(child: Bone(height: 112, radius: 18)), SizedBox(width: 10), Expanded(child: Bone(height: 112, radius: 18))]),
    ]));
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.row, required this.copy, required this.onJoin});
  final Map<String, dynamic> row;
  final Copy copy;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final when = asDate(row['startsAt']);
    final minutes = asInt(row['durationMinutes']);
    final title = firstMeta(row, const ['title', 'classroomTitle', 'name', 'courseTitle']);
    final headline = title.isEmpty ? (when == null ? asText(row['startsAt']) : _clock(when, copy.arabic)) : title;
    final now = DateTime.now();
    final cancelled = asText(row['status']) == 'Cancelled';
    final live = when != null && !now.isBefore(when) && now.isBefore(when.add(Duration(minutes: minutes)));
    final ended = when != null && !now.isBefore(when.add(Duration(minutes: minutes)));
    final lobby = when != null && !live && !ended && when.difference(now).inMinutes < 10;
    final (label, tone, soft) = cancelled
        ? (copy.pick('ملغاة', 'Cancelled'), Tovi.muted, ToviTokens.sunken)
        : live
            ? (copy.pick('مباشر', 'Live'), ToviTokens.coral, ToviTokens.coralSoft)
            : lobby
                ? (copy.pick('غرفة الانتظار', 'Lobby'), Tovi.violet, ToviTokens.violetSoft)
                : ended
                    ? (copy.pick('انتهت', 'Ended'), Tovi.muted, ToviTokens.sunken)
                    : (copy.pick('قادمة', 'Upcoming'), ToviTokens.mint, ToviTokens.mintSoft);
    final detail = [
      if (when != null) _clock(when, copy.arabic),
      '$minutes ${copy.pick('دقيقة', 'min')}',
      if (asText(row['teacherName']).isNotEmpty) asText(row['teacherName']),
    ].join(' · ');
    return SoftPanel(
      onTap: onJoin,
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(ToviTokens.radiusSm)),
          child: Icon(live ? Icons.sensors_rounded : (ended ? Icons.history_rounded : Icons.videocam_outlined), color: tone, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(headline, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Tovi.ink, fontWeight: FontWeight.w700, fontSize: 15.5)),
          const SizedBox(height: 3),
          Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Tovi.muted, fontSize: 12.5)),
        ])),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(99)),
          child: Text(label, style: TextStyle(color: tone, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key, required this.session});
  final Session session;
  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  List<Map<String, dynamic>> sessions = [];
  String error = '';
  var loading = true;
  late DateTime selected = _dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final value = await widget.session.api.get('/api/student/home');
      if (!mounted) return;
      setState(() { sessions = asMaps(asMap(value)['sessions']); error = ''; loading = false; });
    } on ApiException catch (reason) {
      if (reason.status == 401) await widget.session.signOut(tellServer: false);
      if (mounted) setState(() { error = studentMessage(reason.code, reason.message, widget.session.copy.arabic); loading = false; });
    }
  }

  Future<void> pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selected,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: Theme.of(context).colorScheme.copyWith(primary: Tovi.violet)),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked != null) setState(() => selected = _dateOnly(picked));
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.session.copy;
    final start = selected.subtract(Duration(days: selected.weekday % 7));
    final days = [for (var i = 0; i < 7; i++) start.add(Duration(days: i))];
    final dated = [for (final row in sessions) if (asDate(row['startsAt']) != null) row];
    final undated = [for (final row in sessions) if (asDate(row['startsAt']) == null) row];
    final todayRows = [for (final row in dated) if (_sameDay(asDate(row['startsAt'])!, selected)) row]..sort((a, b) => asDate(a['startsAt'])!.compareTo(asDate(b['startsAt'])!));
    final weekMinutes = dated.where((row) => _sameWeek(asDate(row['startsAt'])!, start)).fold<int>(0, (sum, row) => sum + asInt(row['durationMinutes']));
    final dayMinutes = todayRows.fold<int>(0, (sum, row) => sum + asInt(row['durationMinutes']));
    final upcoming = dated.where((row) => asDate(row['startsAt'])!.isAfter(DateTime.now())).toList()
      ..sort((a, b) => asDate(a['startsAt'])!.compareTo(asDate(b['startsAt'])!));
    final next = upcoming.isNotEmpty ? upcoming.first : (todayRows.isNotEmpty ? todayRows.first : (sessions.isNotEmpty ? sessions.first : null));
    return RefreshIndicator(
      color: Tovi.violet,
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          ToviHeader(title: copy.schedule, safe: false, action: CircleButton(icon: Icons.calendar_month_rounded, tooltip: copy.schedule, onPressed: pickDay)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [for (final day in days) _DayChip(day: day, selected: _sameDay(day, selected), arabic: copy.arabic, onTap: () => setState(() => selected = day))],
          ),
          const SizedBox(height: 16),
          SoftPanel(
            onTap: todayRows.isEmpty ? null : () => _join(todayRows.first),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(copy.pick('جلسات اليوم', 'Today'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  todayRows.isEmpty
                      ? copy.pick('لا جلسات في هذا اليوم.', 'No sessions on this day.')
                      : '$dayMinutes ${copy.pick('د', 'min')}${weekMinutes > 0 ? ' / $weekMinutes' : ''}',
                  style: const TextStyle(color: Tovi.muted),
                ),
              ])),
              if (todayRows.isNotEmpty)
                Container(width: 36, height: 36, alignment: Alignment.center, decoration: const BoxDecoration(color: Tovi.lilac, shape: BoxShape.circle), child: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Tovi.violet)),
            ]),
          ),
          if (weekMinutes > 0 && dayMinutes > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: (dayMinutes / weekMinutes).clamp(0, 1).toDouble(),
                backgroundColor: ToviTokens.sunken,
                color: Tovi.violet,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text(copy.pick('جدولي', 'My schedule'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (loading) const SkeletonFade(child: Bone(height: 88, radius: 22))
          else if (error.isNotEmpty) ErrorNote(text: error, onRetry: load)
          else if (todayRows.isEmpty && undated.isEmpty) EmptyNote(icon: Icons.event_busy_rounded, text: copy.empty)
          else ...[
            for (var i = 0; i < todayRows.length; i++) ...[
              if (i > 0) _gap(todayRows[i - 1], todayRows[i], copy),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 72, child: Text(_clock(asDate(todayRows[i]['startsAt'])!, copy.arabic), style: const TextStyle(color: Tovi.muted, fontWeight: FontWeight.w700))),
                Expanded(child: _SessionRow(row: todayRows[i], copy: copy, onJoin: () => _join(todayRows[i]))),
              ]),
              const SizedBox(height: 10),
            ],
            if (undated.isNotEmpty) ...[
              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(copy.pick('بدون وقت محدد', 'No set time'), style: const TextStyle(color: Tovi.muted))),
              for (final row in undated) Padding(padding: const EdgeInsets.only(bottom: 10), child: _SessionRow(row: row, copy: copy, onJoin: () => _join(row))),
            ],
          ],
          if (next != null) ...[
            const SizedBox(height: 8),
            Material(
              color: Tovi.violet,
              borderRadius: BorderRadius.circular(ToviTokens.radiusMd),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _join(next),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(copy.nextUp, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(_nextLabel(next, copy), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                    ])),
                    Container(width: 36, height: 36, alignment: Alignment.center, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Tovi.violet)),
                  ]),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _gap(Map<String, dynamic> previous, Map<String, dynamic> next, Copy copy) {
    final start = asDate(previous['startsAt'])!;
    final end = start.add(Duration(minutes: asInt(previous['durationMinutes'])));
    final following = asDate(next['startsAt'])!;
    if (!following.isAfter(end.add(const Duration(minutes: 15)))) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        copy.pick('لا جلسات من ${_clock(end, true)} إلى ${_clock(following, true)}', 'No sessions from ${_clock(end, false)} to ${_clock(following, false)}'),
        textAlign: TextAlign.center,
        style: const TextStyle(color: Tovi.muted, fontSize: 13),
      ),
    );
  }

  void _join(Map<String, dynamic> row) {
    Navigator.push(context, toviRoute(MeetingPage(session: widget.session, sessionId: asText(row['id']))));
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.day, required this.selected, required this.arabic, required this.onTap});
  final DateTime day;
  final bool selected;
  final bool arabic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const ar = ['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح'];
    const en = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final letter = (arabic ? ar : en)[day.weekday - 1];
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: ToviTokens.fast,
          width: 44,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Tovi.violet : Tovi.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: selected ? ToviTokens.floating : ToviTokens.raised,
          ),
          child: Column(children: [
            Text(letter, style: TextStyle(color: selected ? Colors.white70 : Tovi.muted, fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 4),
            Text('${day.day}', style: TextStyle(color: selected ? Colors.white : Tovi.ink, fontWeight: FontWeight.w700, fontSize: 16)),
          ]),
        ),
      ),
    );
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.session});
  final Session session;
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final query = TextEditingController();
  List<Map<String, dynamic>> items = [];
  String error = '';
  var loading = false;
  var searched = false;

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  Future<void> run() async {
    setState(() => loading = true);
    try {
      final page = await widget.session.api.get('/api/student/search?q=${Uri.encodeQueryComponent(query.text)}');
      if (!mounted) return;
      setState(() { items = asMaps(asMap(page)['items']); error = ''; loading = false; searched = true; });
    } on ApiException catch (reason) {
      if (mounted) setState(() { error = studentMessage(reason.code, reason.message, widget.session.copy.arabic); loading = false; searched = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.session.copy;
    return Scaffold(
      backgroundColor: Tovi.surface,
      body: Column(children: [
        ToviHeader(title: copy.search, onBack: () => Navigator.pop(context)),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: TextField(controller: query, textInputAction: TextInputAction.search, decoration: toviField('', hint: copy.search, icon: Icons.search_rounded), onSubmitted: (_) => run()),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              if (loading) const SkeletonFade(child: Bone(height: 168, radius: 26))
              else if (error.isNotEmpty) ErrorNote(text: error, onRetry: run)
              else if (!searched) EmptyNote(icon: Icons.search_rounded, text: copy.pick('اكتب اسم دورة.', 'Type a course name.'))
              else if (items.isEmpty) EmptyNote(icon: Icons.search_off_rounded, text: copy.empty)
              else
                for (var i = 0; i < items.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      height: 168,
                      child: CoursePoster(
                        title: asText(items[i]['title']),
                        meta: firstMeta(items[i], const ['teacherName', 'instructor']),
                        color: Tovi.courses[i % Tovi.courses.length],
                        onTap: () => Navigator.push(context, toviRoute(CoursePage(session: widget.session, id: asText(items[i]['id'])))),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ]),
    );
  }
}

class LearnPage extends StatelessWidget {
  const LearnPage({super.key, required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) {
    final copy = session.copy;
    final links = [
      ('/api/student/learning-domains', 'name', copy.pick('المجالات', 'Domains'), Icons.category_rounded),
      ('/api/student/sections', 'name', copy.pick('الأقسام', 'Sections'), Icons.account_tree_rounded),
      ('/api/student/grades', 'name', copy.pick('المراحل', 'Grades'), Icons.school_rounded),
      ('/api/student/subjects', 'name', copy.pick('المواد', 'Subjects'), Icons.menu_book_rounded),
      ('/api/student/governorates', 'name', copy.pick('المحافظات', 'Governorates'), Icons.location_on_rounded),
      ('/api/student/teachers', 'firstName', copy.pick('المعلمون', 'Teachers'), Icons.person_rounded),
      ('/api/student/institutes', 'instituteName', copy.pick('المعاهد', 'Institutes'), Icons.apartment_rounded),
      ('/api/student/courses', 'title', copy.pick('الدورات', 'Courses'), Icons.play_lesson_rounded),
      ('/api/student/summaries', 'title', copy.pick('الملخصات', 'Summaries'), Icons.description_rounded),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text(copy.pick('اكتشف', 'Discover'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(copy.pick('المجالات والدورات والملخصات.', 'Domains, courses, and summaries.'), style: const TextStyle(color: Tovi.muted)),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth >= 720 ? 3 : 2;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: links.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.35),
            itemBuilder: (context, i) {
              final link = links[i];
              final tone = Tovi.courses[i % Tovi.courses.length];
              return SoftPanel(
                onTap: () => Navigator.push(context, toviRoute(CatalogPage(session: session, path: link.$1, field: link.$2, title: link.$3))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: tone.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(ToviTokens.radiusSm)),
                    child: Icon(link.$4, color: tone, size: 24),
                  ),
                  const Spacer(),
                  Text(link.$3, style: const TextStyle(color: Tovi.ink, fontWeight: FontWeight.w700, fontSize: 16)),
                ]),
              );
            },
          );
        }),
      ],
    );
  }
}

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key, required this.session, required this.path, required this.field, required this.title});
  final Session session;
  final String path;
  final String field;
  final String title;
  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> grades = [];
  List<Map<String, dynamic>> subjects = [];
  String? gradeId;
  String? subjectId;
  String error = '';
  var loading = true;

  bool get courses => widget.path.endsWith('/courses');

  @override
  void initState() {
    super.initState();
    load();
    if (courses) loadFilters();
  }

  Future<void> loadFilters() async {
    final loadedGrades = await _guard(widget.session.api.get('/api/student/grades'));
    final loadedSubjects = await _guard(widget.session.api.get('/api/student/subjects'));
    if (!mounted) return;
    setState(() {
      grades = loadedGrades is List ? asMaps(loadedGrades) : [];
      subjects = loadedSubjects is List ? asMaps(loadedSubjects) : [];
    });
  }

  Future<void> load() async {
    try {
      final data = await widget.session.api.get(_path());
      if (!mounted) return;
      setState(() { items = data is List ? asMaps(data) : asMaps(asMap(data)['items']); error = ''; loading = false; });
    } on ApiException catch (reason) {
      if (mounted) setState(() { error = studentMessage(reason.code, reason.message, widget.session.copy.arabic); loading = false; });
    }
  }

  String _path() {
    if (!courses) return widget.path;
    final query = <String>[
      if (gradeId != null) 'gradeId=$gradeId',
      if (subjectId != null) 'subjectId=$subjectId',
    ];
    if (query.isEmpty) return widget.path;
    return '${widget.path}?${query.join('&')}';
  }

  bool get _poster => widget.path.endsWith('/courses') || widget.path.endsWith('/summaries');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tovi.surface,
      body: Column(children: [
        ToviHeader(title: widget.title, onBack: () => Navigator.pop(context)),
        Expanded(
          child: loading
              ? const Padding(padding: EdgeInsets.all(20), child: SkeletonFade(child: Bone(height: 168, radius: 26)))
              : error.isNotEmpty
                  ? ErrorNote(text: error, onRetry: load)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        if (courses) ...[
                          _FilterMenu(
                            label: widget.session.copy.pick('المرحلة', 'Grade'),
                            value: gradeId,
                            rows: grades,
                            onChanged: (value) { setState(() => gradeId = value); load(); },
                          ),
                          const SizedBox(height: 8),
                          _FilterMenu(
                            label: widget.session.copy.pick('المادة', 'Subject'),
                            value: subjectId,
                            rows: subjects,
                            onChanged: (value) { setState(() => subjectId = value); load(); },
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (items.isEmpty) EmptyNote(icon: Icons.inbox_rounded, text: widget.session.copy.empty),
                        if (_poster)
                          for (var i = 0; i < items.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: SizedBox(height: 168, child: CoursePoster(title: _label(items[i]), color: Tovi.courses[i % Tovi.courses.length], onTap: () => open(items[i]))),
                            )
                        else
                          for (var i = 0; i < items.length; i++)
                            Padding(padding: const EdgeInsets.only(bottom: 10), child: _catalogRow(items[i], i)),
                      ],
                    ),
        ),
      ]),
    );
  }

  Widget _catalogRow(Map<String, dynamic> row, int index) {
    final teacher = widget.path.endsWith('/teachers');
    return SoftPanel(
      onTap: teacher ? () => open(row) : null,
      child: Row(children: [
        CircleAvatar(backgroundColor: Tovi.courses[index % Tovi.courses.length], child: Text(_label(row).isEmpty ? 'T' : _label(row).substring(0, 1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
        const SizedBox(width: 12),
        Expanded(child: Text(_label(row), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
        if (teacher) Text(widget.session.copy.pick('متابعة', 'Follow'), style: const TextStyle(color: Tovi.violet, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  String _label(Map<String, dynamic> row) {
    final named = asText(row[widget.field]);
    if (named.isNotEmpty) return named;
    final fallback = firstMeta(row, const ['title', 'name', 'instituteName', 'firstName']);
    if (widget.path.endsWith('/teachers')) {
      final last = asText(row['lastName']);
      return '$fallback $last'.trim();
    }
    return fallback;
  }

  Future<void> open(Map<String, dynamic> row) async {
    final id = asText(row['id']);
    if (widget.path.endsWith('/courses')) {
      await Navigator.push(context, toviRoute(CoursePage(session: widget.session, id: id)));
    } else if (widget.path.endsWith('/summaries')) {
      await Navigator.push(context, toviRoute(SummaryPage(session: widget.session, id: id)));
    } else if (widget.path.endsWith('/teachers')) {
      try {
        await widget.session.api.post('/api/student/teachers/$id/follow');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.session.copy.pick('تمت المتابعة', 'Following'))));
      } on ApiException catch (reason) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(studentMessage(reason.code, reason.message, widget.session.copy.arabic))));
      }
    }
  }
}

class SummaryPage extends StatefulWidget {
  const SummaryPage({super.key, required this.session, required this.id});
  final Session session;
  final String id;
  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  Map<String, dynamic>? data;
  String error = '';
  var loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      final value = asMap(await widget.session.api.get('/api/student/summaries/${widget.id}'));
      if (mounted) setState(() { data = value; error = ''; loading = false; });
    } on ApiException catch (reason) {
      if (mounted) setState(() { error = studentMessage(reason.code, reason.message, widget.session.copy.arabic); loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.session.copy;
    final body = asText(data?['body']);
    return Scaffold(
      backgroundColor: Tovi.surface,
      body: Column(children: [
        ToviHeader(title: asText(data?['title']).isEmpty ? copy.pick('الملخص', 'Summary') : asText(data?['title']), onBack: () => Navigator.pop(context)),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              if (loading) const SkeletonFade(child: Bone(height: 180, radius: 24))
              else if (error.isNotEmpty) ErrorNote(text: error, onRetry: load)
              else if (body.isEmpty) EmptyNote(icon: Icons.lock_rounded, text: copy.pick('فعّل كود الملخص لقراءة النص.', 'Redeem a summary code to read it.'))
              else SoftPanel(child: Text(body, style: const TextStyle(fontSize: 17, height: 1.8))),
            ],
          ),
        ),
      ]),
    );
  }
}

class InboxPage extends StatefulWidget {
  const InboxPage({super.key, required this.session});
  final Session session;
  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  List<Map<String, dynamic>> items = [];
  String error = '';
  var loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      final page = await widget.session.api.get('/api/student/notifications');
      if (mounted) setState(() { items = asMaps(asMap(page)['items']); error = ''; loading = false; });
    } on ApiException catch (reason) {
      if (mounted) setState(() { error = studentMessage(reason.code, reason.message, widget.session.copy.arabic); loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.session.copy;
    return RefreshIndicator(
      color: Tovi.violet,
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text(copy.inbox, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          if (loading) const SkeletonFade(child: Bone(height: 88, radius: 22))
          else if (error.isNotEmpty) ErrorNote(text: error, onRetry: load)
          else if (items.isEmpty) EmptyNote(icon: Icons.notifications_none_rounded, text: copy.empty)
          else
            for (final row in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SoftPanel(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: ToviTokens.violetSoft, borderRadius: BorderRadius.circular(ToviTokens.radiusSm)),
                    child: const Icon(Icons.notifications_rounded, color: Tovi.violet, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(asText(row['title']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                    if (asText(row['body']).isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(asText(row['body']), style: const TextStyle(color: Tovi.muted, height: 1.45)),
                    ],
                    if (asDate(row['createdAt']) != null) ...[
                      const SizedBox(height: 6),
                      Text('${asDate(row['createdAt'])!.day}/${asDate(row['createdAt'])!.month} · ${clockOf(asDate(row['createdAt'])!, copy.arabic)}', style: const TextStyle(color: ToviTokens.faint, fontSize: 12)),
                    ],
                  ])),
                ])),
              ),
        ],
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.session});
  final Session session;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? profile;
  String privacy = '';
  String error = '';
  var loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      final me = await widget.session.api.get('/api/student/profile');
      final parameters = await widget.session.api.get('/api/student/parameters');
      var link = '';
      if (parameters is List) {
        for (final row in parameters) {
          final map = asMap(row);
          if (map['key'] == 'privacy_url') link = asText(map['value']);
        }
      }
      if (mounted) setState(() { profile = asMap(me); privacy = link; error = ''; loading = false; });
    } on ApiException catch (reason) {
      if (mounted) setState(() { error = studentMessage(reason.code, reason.message, widget.session.copy.arabic); loading = false; });
    }
  }

  Future<void> confirmSignOut() async {
    final copy = widget.session.copy;
    final yes = await showToviSheet<bool>(
      context,
      (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SheetHandle(),
          Text(copy.pick('تسجيل الخروج؟', 'Sign out?'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          ToviButton(label: copy.pick('خروج', 'Sign out'), color: Tovi.danger, onPressed: () => Navigator.pop(context, true)),
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(copy.pick('إلغاء', 'Cancel'))),
        ]),
      ),
    );
    if (yes == true) await widget.session.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.session.copy;
    final full = '${asText(profile?['firstName'])} ${asText(profile?['lastName'])}'.trim();
    return RefreshIndicator(
      color: Tovi.violet,
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text(copy.pick('حسابي', 'My account'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          if (loading) const SkeletonFade(child: Bone(height: 96, radius: 24))
          else ...[
            if (error.isNotEmpty) ErrorNote(text: error, onRetry: load),
            SoftPanel(color: Tovi.violet, padding: const EdgeInsets.all(18), child: Row(children: [
              CircleAvatar(radius: 30, backgroundColor: Colors.white, child: Text(full.isEmpty ? 'T' : full.substring(0, 1), style: const TextStyle(color: Tovi.violet, fontWeight: FontWeight.w700, fontSize: 22))),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(full.isEmpty ? copy.brand : full, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                Text(asText(profile?['phone']), textDirection: TextDirection.ltr, style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
              ])),
            ])),
            const SizedBox(height: 14),
            SoftPanel(padding: EdgeInsets.zero, child: Column(children: [
              _ProfileAction(icon: Icons.insights_rounded, label: copy.pick('تقدّمي ونقاطي', 'My progress and XP'), onTap: () => Navigator.push(context, toviRoute(ProgressPage(session: widget.session)))),
              const Divider(height: 1, color: Tovi.line),
              _ProfileAction(icon: Icons.quiz_rounded, label: copy.pick('فتح اختبار', 'Open an exam'), onTap: () => Navigator.push(context, toviRoute(ExamEntry(session: widget.session)))),
              const Divider(height: 1, color: Tovi.line),
              _ProfileAction(icon: Icons.language_rounded, label: copy.pick('English', 'العربية'), onTap: widget.session.toggleLanguage),
              const Divider(height: 1, color: Tovi.line),
              _ProfileAction(
                icon: Icons.privacy_tip_rounded,
                label: copy.privacy,
                onTap: privacy.isEmpty ? null : () => launchUrl(Uri.parse(privacy.startsWith('http') ? privacy : '${Session.base}$privacy')),
              ),
            ])),
            const SizedBox(height: 14),
            SoftPanel(onTap: confirmSignOut, child: Row(children: [
              const Icon(Icons.logout_rounded, color: Tovi.danger),
              const SizedBox(width: 12),
              Text(copy.pick('خروج', 'Sign out'), style: const TextStyle(fontWeight: FontWeight.w700, color: Tovi.danger)),
            ])),
          ],
        ],
      ),
    );
  }
}

class _FilterMenu extends StatelessWidget {
  const _FilterMenu({required this.label, required this.value, required this.rows, required this.onChanged});
  final String label;
  final String? value;
  final List<Map<String, dynamic>> rows;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: value,
      decoration: toviField(label),
      items: [
        DropdownMenuItem<String?>(value: null, child: Text(label)),
        for (final row in rows) DropdownMenuItem<String?>(value: asText(row['id']), child: Text(asText(row['name']))),
      ],
      onChanged: onChanged,
    );
  }
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: onTap == null ? ToviTokens.sunken : ToviTokens.violetSoft, borderRadius: BorderRadius.circular(ToviTokens.radiusSm)),
            child: Icon(icon, size: 20, color: onTap == null ? Tovi.muted : Tovi.violet),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: onTap == null ? Tovi.muted : Tovi.ink))),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Tovi.muted),
        ]),
      ),
    );
  }
}

class ExamEntry extends StatefulWidget {
  const ExamEntry({super.key, required this.session});
  final Session session;
  @override
  State<ExamEntry> createState() => _ExamEntryState();
}

class _ExamEntryState extends State<ExamEntry> {
  final id = TextEditingController();
  @override
  void dispose() { id.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final copy = widget.session.copy;
    return Scaffold(
      backgroundColor: Tovi.surface,
      body: Column(children: [
        ToviHeader(title: copy.pick('فتح اختبار', 'Open an exam'), onBack: () => Navigator.pop(context)),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            TextField(controller: id, decoration: toviField(copy.pick('معرف الاختبار', 'Exam id'))),
            const SizedBox(height: 14),
            ToviButton(label: copy.pick('متابعة', 'Continue'), onPressed: () => Navigator.push(context, toviRoute(ExamPage(session: widget.session, id: id.text.trim())))),
          ]),
        ),
      ]),
    );
  }
}

Future<Object?> _guard(Future<dynamic> call) async {
  try { return await call; } on ApiException catch (reason) { return reason; }
}

DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

bool _sameWeek(DateTime value, DateTime start) {
  final day = _dateOnly(value);
  return !day.isBefore(start) && day.isBefore(start.add(const Duration(days: 7)));
}

String _clock(DateTime value, bool arabic) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final suffix = value.hour < 12 ? (arabic ? 'ص' : 'am') : (arabic ? 'م' : 'pm');
  return '$hour:$minute $suffix';
}

String _nextLabel(Map<String, dynamic> row, Copy copy) {
  final title = firstMeta(row, const ['title', 'name', 'courseTitle']);
  final when = asDate(row['startsAt']);
  if (title.isNotEmpty && when != null) return '$title · ${_clock(when, copy.arabic)}';
  if (title.isNotEmpty) return title;
  if (when != null) return _clock(when, copy.arabic);
  return asText(row['startsAt']);
}
