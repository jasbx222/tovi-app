import 'package:material_ui/material_ui.dart';

import '../app.dart';
import '../session.dart';
import '../ui.dart';
import 'hub_kit.dart';
import 'places.dart';
import 'tiles.dart';

/// One search across courses, teachers, summaries and institutes, with filters and recent searches.
class FindPage extends StatefulWidget {
  const FindPage({super.key, required this.session, this.initial = ''});
  final Session session;
  final String initial;
  @override
  State<FindPage> createState() => _FindPageState();
}

class _FindPageState extends State<FindPage> {
  static const types = ['all', 'courses', 'teachers', 'summaries', 'institutes'];
  static const recentKey = 'tovi-recent-searches';
  late final query = TextEditingController(text: widget.initial);
  final debounce = Debounce(const Duration(milliseconds: 350));
  var tab = 0;
  var list = GlobalKey<PagedListState>();
  Map<String, dynamic>? all;
  Map<String, dynamic> totals = {};
  List<Map<String, dynamic>> grades = [];
  List<Map<String, dynamic>> subjects = [];
  String? gradeId;
  String? subjectId;
  String error = '';
  var loading = false;
  var ticket = 0;

  List<String> get recent => widget.session.prefs.getStringList(recentKey) ?? const [];

  @override
  void initState() {
    super.initState();
    run();
    Future.wait([widget.session.api.get('/api/student/grades'), widget.session.api.get('/api/student/subjects')]).then((r) {
      if (mounted) setState(() { grades = asMaps(r[0]); subjects = asMaps(r[1]); });
    }).catchError((_) {});
  }

  @override
  void dispose() { query.dispose(); debounce.dispose(); super.dispose(); }

  String filters() => '${gradeId == null ? '' : '&gradeId=$gradeId'}${subjectId == null ? '' : '&subjectId=$subjectId'}';

  Future<void> remember() async {
    final text = query.text.trim();
    if (text.length < 2) return;
    final next = [text, ...recent.where((x) => x != text)].take(8).toList();
    await widget.session.prefs.setStringList(recentKey, next);
  }

  Future<void> run() async {
    final mine = ++ticket;
    if (tab != 0) { setState(() => list = GlobalKey<PagedListState>()); return; }
    setState(() { loading = true; error = ''; });
    try {
      final data = asMap(await widget.session.api.get('/api/student/find?type=all&q=${Uri.encodeQueryComponent(query.text.trim())}${filters()}'));
      if (!mounted || mine != ticket) return;
      setState(() { all = asMap(data['results']); totals = asMap(data['totals']); loading = false; });
    } catch (reason) {
      if (mounted && mine == ticket) setState(() { error = hubError(reason, widget.session); loading = false; });
    }
  }

  Widget item(BuildContext context, String type, Map<String, dynamic> row) {
    final s = widget.session;
    return switch (type) {
      'courses' => CourseTileCard(session: s, row: row),
      'teachers' => TeacherLine(session: s, row: row, onOpen: openTeacher(context, s, row)),
      'institutes' => PlaceLine(session: s, row: row, onOpen: () => Navigator.push(context, toviRoute(InstitutePage(session: s, id: asText(row['id']), name: asText(row['name']))))),
      _ => SoftPanel(
          onTap: () => Navigator.push(context, toviRoute(SummaryPage(session: s, id: asText(row['id'])))),
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            const IconOrb(icon: Icons.description_rounded, color: ToviTokens.coral, size: 48),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(asText(row['title']), style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Row(children: [
                HubFace(url: row['teacherPhotoUrl'], name: asText(row['teacherName']), size: 18),
                const SizedBox(width: 6),
                Expanded(child: Text(asText(row['teacherName']), style: const TextStyle(color: ToviTokens.muted, fontSize: 12.5))),
              ]),
            ])),
            Icon(row['unlocked'] == true ? Icons.lock_open_rounded : Icons.lock_rounded, color: row['unlocked'] == true ? ToviTokens.mint : ToviTokens.faint, size: 20),
          ]),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.session.copy;
    final labels = [copy.pick('الكل', 'All'), copy.pick('دورات', 'Courses'), copy.pick('معلمون', 'Teachers'), copy.pick('ملخصات', 'Summaries'), copy.pick('معاهد', 'Institutes')];
    final counts = [null, for (final t in types.skip(1)) asInt(totals[t])];
    return Scaffold(
      backgroundColor: ToviTokens.page,
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 20, 6),
            child: Row(children: [
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded)),
              Expanded(
                child: TextField(
                  controller: query,
                  autofocus: widget.initial.isEmpty,
                  textInputAction: TextInputAction.search,
                  onChanged: (_) { setState(() {}); debounce(run); },
                  onSubmitted: (_) { remember(); run(); },
                  decoration: toviField('', hint: copy.pick('دورة، معلم، ملخص، معهد…', 'Course, teacher, summary, institute…'), icon: Icons.search_rounded).copyWith(
                    suffixIcon: query.text.isEmpty ? null : IconButton(onPressed: () { query.clear(); run(); }, icon: const Icon(Icons.close_rounded)),
                  ),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: HubSegments(labels: labels, index: tab, counts: counts, onChanged: (i) { setState(() => tab = i); run(); }),
          ),
          if (grades.isNotEmpty || subjects.isNotEmpty)
            SizedBox(
              height: 46,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6), children: [
                _FilterChip(label: copy.pick('المرحلة', 'Grade'), rows: grades, value: gradeId, onChanged: (v) { setState(() => gradeId = v); run(); }),
                const SizedBox(width: 8),
                _FilterChip(label: copy.pick('المادة', 'Subject'), rows: subjects, value: subjectId, onChanged: (v) { setState(() => subjectId = v); run(); }),
              ]),
            ),
          Expanded(child: tab == 0 ? overview(context) : PagedList(
            key: list,
            session: widget.session,
            grid: types[tab] == 'courses',
            load: (page) async {
              final data = asMap(await widget.session.api.get('/api/student/find?type=${types[tab]}&page=$page&pageSize=20&q=${Uri.encodeQueryComponent(query.text.trim())}${filters()}'));
              if (mounted) setState(() => totals = asMap(data['totals']));
              return {'items': asMap(data['results'])[types[tab]], 'hasMore': data['hasMore']};
            },
            empty: _nothing(copy),
            itemBuilder: (context, row, i, refresh) => item(context, types[tab], row),
          )),
        ]),
      ),
    );
  }

  Widget _nothing(dynamic copy) => HubEmpty(
        icon: Icons.travel_explore_rounded,
        title: copy.pick('ما لكينا نتائج', 'No results'),
        body: copy.pick('جرّب كلمة ثانية أو شيل الفلاتر.', 'Try another word or clear the filters.'),
      );

  Widget overview(BuildContext context) {
    final copy = widget.session.copy;
    if (loading && all == null) return const Padding(padding: EdgeInsets.all(20), child: ListSkeleton());
    if (error.isNotEmpty && all == null) return ErrorNote(text: error, onRetry: run);
    final data = all ?? const {};
    final sections = [
      ('courses', copy.pick('دورات', 'Courses')),
      ('teachers', copy.pick('معلمون', 'Teachers')),
      ('summaries', copy.pick('ملخصات', 'Summaries')),
      ('institutes', copy.pick('معاهد', 'Institutes')),
    ];
    final any = sections.any((s) => asMaps(data[s.$1]).isNotEmpty);
    return ListView(padding: const EdgeInsets.fromLTRB(20, 6, 20, 28), children: [
      if (query.text.isEmpty && recent.isNotEmpty) ...[
        Row(children: [
          Expanded(child: Text(copy.pick('عمليات بحث سابقة', 'Recent searches'), style: const TextStyle(fontWeight: FontWeight.w800, color: ToviTokens.muted))),
          TextButton(onPressed: () async { await widget.session.prefs.remove(recentKey); setState(() {}); }, child: Text(copy.pick('مسح', 'Clear'))),
        ]),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final r in recent)
            ActionChip(
              avatar: const Icon(Icons.history_rounded, size: 16, color: ToviTokens.muted),
              label: Text(r),
              backgroundColor: ToviTokens.surface,
              side: BorderSide.none,
              onPressed: () { query.text = r; run(); },
            ),
        ]),
        const SizedBox(height: 12),
      ],
      if (!any) _nothing(copy),
      for (final (key, label) in sections)
        if (asMaps(data[key]).isNotEmpty) ...[
          SectionHead(title: '$label · ${asInt(totals[key])}', action: asInt(totals[key]) > asMaps(data[key]).length ? copy.viewAll : null, onAction: () { setState(() => tab = types.indexOf(key)); run(); }),
          if (key == 'courses')
            LayoutBuilder(builder: (context, box) {
              final width = (box.maxWidth - 12) / 2;
              return Wrap(spacing: 12, runSpacing: 12, children: [for (final row in asMaps(data[key])) SizedBox(width: width, child: item(context, key, row))]);
            })
          else
            for (final row in asMaps(data[key])) Padding(padding: const EdgeInsets.only(bottom: 10), child: item(context, key, row)),
        ],
    ]);
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.rows, required this.value, required this.onChanged});
  final String label;
  final List<Map<String, dynamic>> rows;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final picked = rows.where((r) => asText(r['id']) == value).map((r) => asText(r['name'])).firstOrNull;
    return PopupMenuButton<String>(
      onSelected: (v) => onChanged(v.isEmpty ? null : v),
      itemBuilder: (context) => [
        PopupMenuItem(value: '', child: Text(label)),
        for (final r in rows) PopupMenuItem(value: asText(r['id']), child: Text(asText(r['name']))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(color: picked == null ? ToviTokens.surface : ToviTokens.violetSoft, borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(picked ?? label, style: TextStyle(fontWeight: FontWeight.w700, color: picked == null ? ToviTokens.inkSoft : ToviTokens.violet)),
          const SizedBox(width: 4),
          Icon(Icons.expand_more_rounded, size: 18, color: picked == null ? ToviTokens.muted : ToviTokens.violet),
        ]),
      ),
    );
  }
}
