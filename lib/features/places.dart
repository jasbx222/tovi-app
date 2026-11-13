import 'package:material_ui/material_ui.dart';

import '../meeting_page.dart';
import '../session.dart';
import '../ui.dart';
import 'hub_kit.dart';
import 'sessions.dart';
import 'tiles.dart';

/// All institutes with logos and counts.
class PlacesPage extends StatelessWidget {
  const PlacesPage({super.key, required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) {
    final copy = session.copy;
    return HubScaffold(
      title: copy.pick('المعاهد', 'Institutes'),
      body: PagedList(
        session: session,
        load: (page) => session.api.get('/api/student/places?page=$page&pageSize=20'),
        empty: HubEmpty(icon: Icons.apartment_rounded, title: copy.pick('ما في معاهد بعد', 'No institutes yet')),
        itemBuilder: (context, row, i, refresh) => PlaceLine(
          session: session,
          row: row,
          onOpen: () => Navigator.push(context, toviRoute(InstitutePage(session: session, id: asText(row['id']), name: asText(row['name'])))),
        ),
      ),
    );
  }
}

/// One institute: logo, about, teachers, courses and upcoming sessions.
class InstitutePage extends StatefulWidget {
  const InstitutePage({super.key, required this.session, required this.id, this.name = ''});
  final Session session;
  final String id;
  final String name;
  @override
  State<InstitutePage> createState() => _InstitutePageState();
}

class _InstitutePageState extends State<InstitutePage> {
  Map<String, dynamic>? data;
  String error = '';

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      final value = asMap(await widget.session.api.get('/api/student/institutes/${widget.id}'));
      if (mounted) setState(() { data = value; error = ''; });
    } catch (reason) {
      if (mounted) setState(() => error = hubError(reason, widget.session));
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.session.copy;
    final place = asMap(data?['institute']);
    final name = asText(place['name']).isEmpty ? widget.name : asText(place['name']);
    final teachers = asMaps(data?['teachers']);
    final courses = asMaps(data?['courses']);
    final upcoming = asMaps(data?['upcoming']);
    return Scaffold(
      backgroundColor: ToviTokens.page,
      body: data == null
          ? SafeArea(child: Column(children: [
              ToviHeader(title: name, onBack: () => Navigator.pop(context)),
              Expanded(child: error.isEmpty ? const Padding(padding: EdgeInsets.all(20), child: ListSkeleton()) : ErrorNote(text: error, onRetry: load)),
            ]))
          : RefreshIndicator(
              color: ToviTokens.violet,
              onRefresh: load,
              child: CustomScrollView(slivers: [
                SliverToBoxAdapter(
                  child: Stack(children: [
                    Container(
                      height: 210,
                      decoration: BoxDecoration(gradient: LinearGradient(colors: hubGradientFor(name), begin: AlignmentDirectional.topStart, end: AlignmentDirectional.bottomEnd)),
                      child: Stack(children: [
                        PositionedDirectional(end: -40, top: -30, child: Container(width: 180, height: 180, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.12)))),
                        PositionedDirectional(start: -30, bottom: -50, child: Container(width: 140, height: 140, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.10)))),
                      ]),
                    ),
                    SafeArea(child: ToviHeader(title: '', light: true, onBack: () => Navigator.pop(context))),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 150, 20, 0),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), boxShadow: ToviTokens.floating),
                          child: SizedBox(width: 92, height: 92, child: HubPhoto(url: place['logoUrl'], seed: name, radius: 22, icon: Icons.apartment_rounded)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                              Text([asText(place['governorate']), asText(place['address'])].where((x) => x.isNotEmpty).join(' · '), style: const TextStyle(color: ToviTokens.muted)),
                            ]),
                          ),
                        ),
                      ]),
                    ),
                  ]),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  sliver: SliverList.list(children: [
                    Row(children: [
                      Expanded(child: StatPill(color: ToviTokens.violet, icon: Icons.person_rounded, label: copy.pick('معلم', 'Teachers'), value: '${asInt(place['teachers'])}')),
                      const SizedBox(width: 10),
                      Expanded(child: StatPill(color: ToviTokens.coral, icon: Icons.menu_book_rounded, label: copy.pick('دورة', 'Courses'), value: '${asInt(place['courses'])}')),
                      const SizedBox(width: 10),
                      Expanded(child: StatPill(color: ToviTokens.sky, icon: Icons.videocam_rounded, label: copy.pick('حصة قادمة', 'Upcoming'), value: '${upcoming.length}')),
                    ]),
                    if (asText(place['description']).isNotEmpty) ...[
                      const SizedBox(height: 14),
                      SoftPanel(child: Text(asText(place['description']), style: const TextStyle(height: 1.6))),
                    ],
                    if (upcoming.isNotEmpty) ...[
                      SectionHead(title: copy.pick('حصص قادمة', 'Upcoming sessions')),
                      for (final row in upcoming)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: SessionCard(session: widget.session, row: row, onTap: () => Navigator.push(context, toviRoute(MeetingPage(session: widget.session, sessionId: asText(row['id']))))),
                        ),
                    ],
                    if (teachers.isNotEmpty) ...[
                      SectionHead(title: copy.pick('المعلمون', 'Teachers')),
                      for (final row in teachers) Padding(padding: const EdgeInsets.only(bottom: 10), child: TeacherLine(session: widget.session, row: row, onOpen: openTeacher(context, widget.session, row))),
                    ],
                    SectionHead(title: copy.pick('الدورات', 'Courses')),
                  ]),
                ),
                if (courses.isEmpty)
                  SliverToBoxAdapter(child: HubEmpty(icon: Icons.menu_book_rounded, title: copy.pick('ما نزلت دورات بعد', 'No courses yet')))
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    sliver: SliverGrid.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 260, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 236),
                      itemCount: courses.length,
                      itemBuilder: (context, i) => CourseTileCard(session: widget.session, row: courses[i]),
                    ),
                  ),
              ]),
            ),
    );
  }
}
