import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'course_page.dart';
import 'exam_page.dart';
import 'meeting_page.dart';
import 'push.dart';
import 'session.dart';
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

  @override
  void initState() {
    super.initState();
    registerDeviceToken(widget.session);
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.session.copy;
    final pages = [
      HomePage(session: widget.session),
      SearchPage(session: widget.session),
      LearnPage(session: widget.session),
      InboxPage(session: widget.session),
      ProfilePage(session: widget.session),
    ];
    final labels = [copy.home, copy.search, copy.learn, copy.inbox, copy.profile];
    final wide = MediaQuery.sizeOf(context).width >= 840;
    return Scaffold(
      backgroundColor: Tovi.paper,
      body: SafeArea(
        child: wide
            ? Row(children: [
                Container(
                  width: 196,
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Padding(padding: const EdgeInsets.all(8), child: Text(widget.session.copy.brand, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700))),
                    for (var i = 0; i < labels.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: index == i ? Tovi.ink : Tovi.card, foregroundColor: index == i ? const Color(0xFFF6F1E7) : Tovi.ink),
                          onPressed: () => setState(() => index = i),
                          child: Text(labels[i]),
                        ),
                      ),
                  ]),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: pages[index]),
              ])
            : pages[index],
      ),
      bottomNavigationBar: wide ? null : ToviBar(index: index, labels: labels, onSelect: (value) => setState(() => index = value)),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.session});
  final Session session;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, dynamic>? data;
  String error = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final value = await widget.session.api.get('/api/student/home');
      if (mounted) setState(() { data = Map<String, dynamic>.from(value as Map); error = ''; });
    } on ApiException catch (reason) {
      if (reason.status == 401) await widget.session.signOut();
      if (mounted) setState(() => error = reason.message);
    }
  }

  Future<void> redeem() async {
    final code = TextEditingController();
    final copy = widget.session.copy;
    final entered = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(copy.redeem),
        content: TextField(controller: code, decoration: InputDecoration(labelText: copy.code)),
        actions: [TextButton(onPressed: () => Navigator.pop(context, code.text.trim()), child: Text(copy.pick('تفعيل', 'Redeem')))],
      ),
    );
    if (entered == null || entered.isEmpty) return;
    try {
      await widget.session.api.post('/api/student/codes/redeem', {'code': entered});
      await load();
    } on ApiException catch (reason) {
      if (mounted) setState(() => error = reason.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.session.copy;
    final courses = (data?['courses'] as List?) ?? const [];
    final sessions = (data?['sessions'] as List?) ?? const [];
    final ads = (data?['ads'] as List?) ?? const [];
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(copy.pick('أهلاً بك', 'Welcome back'), style: const TextStyle(color: Tovi.muted)),
          Text(copy.brand, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.8)),
          const SizedBox(height: 14),
          SoftCard(
            color: Tovi.claySoft,
            onTap: redeem,
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(copy.redeem, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                Text(copy.pick('أدخل كود الدورة أو الملخص أو الاختبار أو القاعة.', 'Enter a course, summary, exam, or classroom code.'), style: const TextStyle(color: Tovi.muted)),
              ])),
              const Icon(Icons.vpn_key_outlined, color: Tovi.clay),
            ]),
          ),
          if (error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error, style: const TextStyle(color: Color(0xFFA33B32)))),
          SectionLabel(copy.pick('دوراتي', 'My courses')),
          if (courses.isEmpty) Text(copy.empty, style: const TextStyle(color: Tovi.muted)),
          for (var i = 0; i < courses.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CourseTile(
                index: i,
                title: '${(courses[i] as Map)['title']}',
                meta: '',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CoursePage(session: widget.session, id: '${(courses[i] as Map)['id']}'))),
              ),
            ),
          SectionLabel(copy.pick('الجلسات القادمة', 'Upcoming sessions')),
          for (final row in sessions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SoftCard(
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${(row as Map)['startsAt']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${row['durationMinutes']} ${copy.pick('دقيقة', 'min')}', style: const TextStyle(color: Tovi.muted)),
                  ])),
                  FilledButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MeetingPage(session: widget.session, sessionId: '${row['id']}'))), child: Text(copy.meeting)),
                ]),
              ),
            ),
          SectionLabel(copy.pick('الإعلانات', 'Advertisements')),
          for (final row in ads)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SoftCard(
                color: Tovi.saffron,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${(row as Map)['title']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('${row['body'] ?? ''}'),
                ]),
              ),
            ),
        ],
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
  List<dynamic> items = [];
  String error = '';

  Future<void> run() async {
    try {
      final page = await widget.session.api.get('/api/student/search?q=${Uri.encodeQueryComponent(query.text)}');
      setState(() { items = (page['items'] as List?) ?? []; error = ''; });
    } on ApiException catch (reason) {
      setState(() => error = reason.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(widget.session.copy.search, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        TextField(controller: query, decoration: toviField(widget.session.copy.search), onSubmitted: (_) => run()),
        if (error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error, style: const TextStyle(color: Color(0xFFA33B32)))),
        const SizedBox(height: 12),
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: CourseTile(
              index: i,
              title: '${(items[i] as Map)['title']}',
              meta: '',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CoursePage(session: widget.session, id: '${(items[i] as Map)['id']}'))),
            ),
          ),
      ],
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
      ('/api/student/learning-domains', 'name', copy.pick('المجالات', 'Domains')),
      ('/api/student/sections', 'name', copy.pick('الأقسام', 'Sections')),
      ('/api/student/grades', 'name', copy.pick('المراحل', 'Grades')),
      ('/api/student/subjects', 'name', copy.pick('المواد', 'Subjects')),
      ('/api/student/governorates', 'name', copy.pick('المحافظات', 'Governorates')),
      ('/api/student/teachers', 'firstName', copy.pick('المعلمون', 'Teachers')),
      ('/api/student/institutes', 'instituteName', copy.pick('المعاهد', 'Institutes')),
      ('/api/student/courses', 'title', copy.pick('الدورات', 'Courses')),
      ('/api/student/summaries', 'title', copy.pick('الملخصات', 'Summaries')),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(copy.pick('اكتشف', 'Discover'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        for (var i = 0; i < links.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SoftCard(
              color: i.isEven ? Tovi.card : Tovi.saffron,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CatalogPage(session: session, path: links[i].$1, field: links[i].$2, title: links[i].$3))),
              child: Row(children: [
                Expanded(child: Text(links[i].$3, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                const Icon(Icons.chevron_left, color: Tovi.muted),
              ]),
            ),
          ),
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
  List<dynamic> items = [];
  String error = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = await widget.session.api.get(widget.path);
      setState(() => items = data is List ? data : (data['items'] as List? ?? []));
    } on ApiException catch (reason) {
      setState(() => error = reason.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: error.isNotEmpty
          ? Center(child: Text(error))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (items.isEmpty) Text(widget.session.copy.empty, style: const TextStyle(color: Tovi.muted)),
                for (var i = 0; i < items.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: CourseTile(
                      index: i,
                      title: '${(items[i] as Map)[widget.field] ?? (items[i] as Map)['title'] ?? (items[i] as Map)['name'] ?? ''}',
                      meta: '',
                      onTap: () => open(Map<String, dynamic>.from(items[i] as Map)),
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> open(Map<String, dynamic> row) async {
    final id = '${row['id']}';
    if (widget.path.endsWith('/courses')) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => CoursePage(session: widget.session, id: id)));
    } else if (widget.path.endsWith('/summaries')) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => SummaryPage(session: widget.session, id: id)));
    } else if (widget.path.endsWith('/teachers')) {
      try {
        await widget.session.api.post('/api/student/teachers/$id/follow');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.session.copy.pick('تمت المتابعة', 'Following'))));
      } on ApiException catch (reason) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(reason.message)));
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
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    try {
      final value = Map<String, dynamic>.from(await widget.session.api.get('/api/student/summaries/${widget.id}') as Map);
      if (mounted) setState(() => data = value);
    } on ApiException catch (reason) {
      if (mounted) setState(() => error = reason.message);
    }
  }
  @override
  Widget build(BuildContext context) {
    final body = data?['body'];
    return Scaffold(
      appBar: AppBar(title: Text('${data?['title'] ?? ''}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SoftCard(child: Text(error.isNotEmpty ? error : (body == null ? widget.session.copy.pick('فعّل كود الملخص لقراءة النص', 'Redeem a summary code to read it') : '$body'), style: const TextStyle(height: 1.7, fontSize: 16))),
      ),
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
  List<dynamic> items = [];
  String error = '';
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    try {
      final page = await widget.session.api.get('/api/student/notifications');
      if (mounted) setState(() => items = (page['items'] as List?) ?? []);
    } on ApiException catch (reason) {
      if (mounted) setState(() => error = reason.message);
    }
  }
  @override
  Widget build(BuildContext context) {
    if (error.isNotEmpty) return Center(child: Text(error));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(widget.session.copy.pick('الإشعارات', 'Notifications'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        if (items.isEmpty) Text(widget.session.copy.empty, style: const TextStyle(color: Tovi.muted)),
        for (final row in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SoftCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${(row as Map)['title']}', style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('${row['body'] ?? ''}', style: const TextStyle(color: Tovi.muted)),
            ])),
          ),
      ],
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

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      final me = await widget.session.api.get('/api/student/profile');
      final parameters = await widget.session.api.get('/api/student/parameters');
      String link = '';
      if (parameters is List) {
        for (final row in parameters) {
          if (row is Map && row['key'] == 'privacy_url') link = '${row['value']}';
        }
      }
      setState(() { profile = Map<String, dynamic>.from(me as Map); privacy = link; });
    } on ApiException catch (reason) { setState(() => error = reason.message); }
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.session.copy;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(copy.pick('حسابي', 'My account'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        SoftCard(
          color: Tovi.brandSoft,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${profile?['firstName'] ?? ''} ${profile?['lastName'] ?? ''}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            Text('${profile?['phone'] ?? ''}', style: const TextStyle(color: Tovi.muted)),
          ]),
        ),
        if (error.isNotEmpty) Text(error),
        const SizedBox(height: 12),
        SoftCard(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExamEntry(session: widget.session))), child: Text(copy.pick('فتح اختبار', 'Open an exam'), style: const TextStyle(fontWeight: FontWeight.w700))),
        const SizedBox(height: 8),
        SoftCard(onTap: widget.session.toggleLanguage, child: Text(copy.pick('English', 'العربية'), style: const TextStyle(fontWeight: FontWeight.w700))),
        const SizedBox(height: 8),
        SoftCard(
          onTap: privacy.isEmpty ? null : () => launchUrl(Uri.parse(privacy.startsWith('http') ? privacy : '${Session.base}$privacy')),
          child: Text(copy.privacy, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 8),
        SoftCard(onTap: widget.session.signOut, child: Text(copy.pick('خروج', 'Sign out'), style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFA33B32)))),
      ],
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.session.copy.pick('فتح اختبار', 'Open an exam'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: id, decoration: toviField(widget.session.copy.pick('معرف الاختبار', 'Exam id'))),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExamPage(session: widget.session, id: id.text.trim()))), child: Text(widget.session.copy.pick('متابعة', 'Continue'))),
        ]),
      ),
    );
  }
}
