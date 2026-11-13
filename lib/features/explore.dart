import 'package:material_ui/material_ui.dart';

import '../session.dart';
import '../teacher_page.dart';
import '../ui.dart';
import 'account.dart';
import 'hub_kit.dart';
import 'places.dart';
import 'search.dart';
import 'tiles.dart';

const _subjectIcons = <IconData>[
  Icons.calculate_rounded,
  Icons.science_rounded,
  Icons.translate_rounded,
  Icons.biotech_rounded,
  Icons.public_rounded,
  Icons.history_edu_rounded,
  Icons.computer_rounded,
  Icons.menu_book_rounded,
];

IconData subjectIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('رياض') || n.contains('math')) return Icons.calculate_rounded;
  if (n.contains('فيزي') || n.contains('phys')) return Icons.bolt_rounded;
  if (n.contains('كيمي') || n.contains('chem')) return Icons.science_rounded;
  if (n.contains('أحياء') || n.contains('احياء') || n.contains('bio')) return Icons.biotech_rounded;
  if (n.contains('انكل') || n.contains('إنكل') || n.contains('engl')) return Icons.translate_rounded;
  if (n.contains('عرب') || n.contains('arab')) return Icons.history_edu_rounded;
  if (n.contains('اسلام') || n.contains('إسلام')) return Icons.mosque_rounded;
  if (n.contains('حاسوب') || n.contains('comp')) return Icons.computer_rounded;
  return _subjectIcons[name.length % _subjectIcons.length];
}

/// The Learn tab: subjects for the student's grade, new and popular courses, teachers and institutes.
class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key, required this.session});
  final Session session;
  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  Map<String, dynamic>? data;
  String error = '';

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      final value = asMap(await widget.session.api.get('/api/student/explore'));
      if (mounted) setState(() { data = value; error = ''; });
    } catch (reason) {
      if (mounted) setState(() => error = hubError(reason, widget.session));
    }
  }

  void browse({String? subjectId, String? gradeId, String? sectionId, String? domainId, String title = '', String sort = 'new'}) {
    Navigator.push(context, toviRoute(CourseBrowsePage(session: widget.session, title: title, subjectId: subjectId, gradeId: gradeId, sectionId: sectionId, domainId: domainId, sort: sort)));
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.session.copy;
    final s = widget.session;
    final grade = asMap(data?['grade']);
    final subjects = asMaps(data?['subjects']);
    final forGrade = asMaps(data?['forGrade']);
    final fresh = asMaps(data?['fresh']);
    final popular = asMaps(data?['popular']);
    final teachers = asMaps(data?['teachers']);
    final institutes = asMaps(data?['institutes']);
    final grades = asMaps(data?['grades']);
    final sections = asMaps(data?['sections']);
    final domains = asMaps(data?['domains']);
    return RefreshIndicator(
      color: ToviTokens.violet,
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.only(bottom: 28), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
          child: Text(copy.pick('استكشف', 'Explore'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GestureDetector(
            onTap: () => Navigator.push(context, toviRoute(FindPage(session: s))),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: ToviTokens.surface, borderRadius: BorderRadius.circular(18), boxShadow: ToviTokens.raised),
              child: Row(children: [
                const Icon(Icons.search_rounded, color: ToviTokens.violet),
                const SizedBox(width: 10),
                Text(copy.pick('دورة، معلم، ملخص، معهد…', 'Course, teacher, summary, institute…'), style: const TextStyle(color: ToviTokens.muted)),
              ]),
            ),
          ),
        ),
        if (data == null && error.isEmpty)
          const Padding(padding: EdgeInsets.all(20), child: ListSkeleton(rows: 4, height: 110))
        else if (data == null)
          ErrorNote(text: error, onRetry: load)
        else ...[
          if (asText(grade['name']).isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: SoftPanel(
                color: ToviTokens.sunSoft,
                onTap: () async {
                  final me = asMap(await s.api.get('/api/student/account'));
                  if (!context.mounted) return;
                  await Navigator.push(context, toviRoute(AccountEditPage(session: s, me: me, onboarding: true)));
                  load();
                },
                child: Row(children: [
                  const IconOrb(icon: Icons.school_rounded, color: Color(0xFFB07E00)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(copy.pick('اختار مرحلتك حتى نرتبلك الدورات المناسبة', 'Pick your grade to tailor courses for you'), style: const TextStyle(fontWeight: FontWeight.w700))),
                  const Icon(Icons.chevron_left_rounded),
                ]),
              ),
            ),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: SectionHead(title: asText(grade['name']).isEmpty ? copy.pick('المواد', 'Subjects') : copy.pick('مواد ${asText(grade['name'])}', '${asText(grade['name'])} subjects'))),
          SizedBox(
            height: 118,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: subjects.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final row = subjects[i];
                final colors = hubGradientFor(asText(row['name']));
                return GestureDetector(
                  onTap: () => browse(subjectId: asText(row['id']), gradeId: asText(grade['id']).isEmpty ? null : asText(grade['id']), title: asText(row['name'])),
                  child: Container(
                    width: 104,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: LinearGradient(colors: colors, begin: AlignmentDirectional.topStart, end: AlignmentDirectional.bottomEnd),
                      boxShadow: [BoxShadow(color: colors.first.withValues(alpha: 0.32), blurRadius: 14, offset: const Offset(0, 6))],
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(subjectIcon(asText(row['name'])), color: Colors.white, size: 28),
                      const Spacer(),
                      Text(asText(row['name']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      Text(copy.pick('${asInt(row['courses'])} دورة', '${asInt(row['courses'])} courses'), style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5)),
                    ]),
                  ),
                );
              },
            ),
          ),
          if (forGrade.isNotEmpty) ...[
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: SectionHead(title: copy.pick('لمرحلتك', 'For your grade'), action: copy.viewAll, onAction: () => browse(gradeId: asText(grade['id']), title: asText(grade['name'])))),
            CourseStrip(session: s, rows: forGrade),
          ],
          if (popular.isNotEmpty) ...[
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: SectionHead(title: copy.pick('الأكثر إعجاباً', 'Most liked'), action: copy.viewAll, onAction: () => browse(sort: 'popular', title: copy.pick('الأكثر إعجاباً', 'Most liked')))),
            CourseStrip(session: s, rows: popular),
          ],
          if (fresh.isNotEmpty) ...[
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: SectionHead(title: copy.pick('نزلت جديد', 'New courses'), action: copy.viewAll, onAction: () => browse(title: copy.pick('كل الدورات', 'All courses')))),
            CourseStrip(session: s, rows: fresh),
          ],
          if (teachers.isNotEmpty) ...[
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: SectionHead(title: copy.pick('معلمون مميزون', 'Top teachers'), action: copy.viewAll, onAction: () => Navigator.push(context, toviRoute(TeachersPage(session: s))))),
            SizedBox(
              height: 132,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: teachers.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final row = teachers[i];
                  return GestureDetector(
                    onTap: openTeacher(context, s, row),
                    child: SizedBox(
                      width: 92,
                      child: Column(children: [
                        HubFace(url: row['photoUrl'], name: asText(row['name']), size: 72, ring: true),
                        const SizedBox(height: 6),
                        Text(asText(row['name']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                        Text(asText(row['subject']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ToviTokens.muted, fontSize: 11.5)),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ],
          if (domains.isNotEmpty || sections.isNotEmpty || grades.isNotEmpty) ...[
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: SectionHead(title: copy.pick('تصفح حسب', 'Browse by'))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final r in domains) _Pill(icon: Icons.category_rounded, color: ToviTokens.violet, label: asText(r['name']), onTap: () => browse(domainId: asText(r['id']), title: asText(r['name']))),
                for (final r in sections) _Pill(icon: Icons.account_tree_rounded, color: ToviTokens.coral, label: asText(r['name']), onTap: () => browse(sectionId: asText(r['id']), title: asText(r['name']))),
                for (final r in grades) _Pill(icon: Icons.school_rounded, color: ToviTokens.sky, label: asText(r['name']), onTap: () => browse(gradeId: asText(r['id']), title: asText(r['name']))),
              ]),
            ),
          ],
          if (institutes.isNotEmpty) ...[
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: SectionHead(title: copy.pick('المعاهد', 'Institutes'), action: copy.viewAll, onAction: () => Navigator.push(context, toviRoute(PlacesPage(session: s))))),
            for (final row in institutes.take(3))
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: PlaceLine(session: s, row: row, onOpen: () => Navigator.push(context, toviRoute(InstitutePage(session: s, id: asText(row['id']), name: asText(row['name']))))),
              ),
          ],
        ],
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.color, required this.label, required this.onTap});
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: ToviTokens.surface,
        borderRadius: BorderRadius.circular(99),
        child: InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}

/// A filtered grid of courses with sort options and infinite scroll.
class CourseBrowsePage extends StatefulWidget {
  const CourseBrowsePage({super.key, required this.session, this.title = '', this.subjectId, this.gradeId, this.sectionId, this.domainId, this.sort = 'new'});
  final Session session;
  final String title;
  final String? subjectId;
  final String? gradeId;
  final String? sectionId;
  final String? domainId;
  final String sort;
  @override
  State<CourseBrowsePage> createState() => _CourseBrowsePageState();
}

class _CourseBrowsePageState extends State<CourseBrowsePage> {
  late var sort = widget.sort;
  var list = GlobalKey<PagedListState>();

  String query(int page) {
    final parts = <String>[
      'page=$page', 'pageSize=20', 'sort=$sort',
      if (widget.subjectId != null) 'subjectId=${widget.subjectId}',
      if (widget.gradeId != null) 'gradeId=${widget.gradeId}',
      if (widget.sectionId != null) 'sectionId=${widget.sectionId}',
      if (widget.domainId != null) 'domainId=${widget.domainId}',
    ];
    return parts.join('&');
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.session.copy;
    const sorts = ['new', 'popular', 'title'];
    return HubScaffold(
      title: widget.title.isEmpty ? copy.pick('الدورات', 'Courses') : widget.title,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: HubSegments(
            labels: [copy.pick('الأحدث', 'Newest'), copy.pick('الأكثر إعجاباً', 'Most liked'), copy.pick('أبجدي', 'A–Z')],
            index: sorts.indexOf(sort),
            onChanged: (i) => setState(() { sort = sorts[i]; list = GlobalKey<PagedListState>(); }),
          ),
        ),
        Expanded(
          child: PagedList(
            key: list,
            session: widget.session,
            grid: true,
            skeletonHeight: 120,
            load: (page) => widget.session.api.get('/api/student/explore/courses?${query(page)}'),
            empty: HubEmpty(icon: Icons.menu_book_rounded, title: copy.pick('ما في دورات هنا بعد', 'No courses here yet'), body: copy.pick('ارجع بعدين، المعلمين دا يضيفون دورات جديدة.', 'Check back soon, teachers keep adding courses.')),
            itemBuilder: (context, row, i, refresh) => CourseTileCard(session: widget.session, row: row),
          ),
        ),
      ]),
    );
  }
}
