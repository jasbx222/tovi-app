import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'cards.dart';
import 'copy.dart';
import 'course_page.dart';
import 'meeting_page.dart';
import 'session.dart';
import 'student_rules.dart';
import 'ui.dart';
import 'video_page.dart';

/// Follows or unfollows and returns the new card values from the server.
Future<Map<String, dynamic>?> toggleFollow(BuildContext context, Session session, Map<String, dynamic> row) async {
  final id = asText(row['id']);
  final following = row['following'] == true;
  try {
    final result = asMap(following ? await session.api.delete('/api/student/teachers/$id/follow') : await session.api.post('/api/student/teachers/$id/follow'));
    return {...row, 'following': result['following'] == true, 'followers': asInt(result['followers'])};
  } on ApiException catch (reason) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(studentMessage(reason.code, reason.message, session.copy.arabic))));
    return null;
  }
}

class TeacherPage extends StatefulWidget {
  const TeacherPage({super.key, required this.session, required this.id, this.preview});
  final Session session;
  final String id;
  final Map<String, dynamic>? preview;

  @override
  State<TeacherPage> createState() => _TeacherPageState();
}

class _TeacherPageState extends State<TeacherPage> {
  Map<String, dynamic>? data;
  Map<String, dynamic> teacher = {};
  String error = '';
  var busy = false;

  @override
  void initState() {
    super.initState();
    teacher = {...?widget.preview};
    load();
  }

  Future<void> load() async {
    try {
      final value = asMap(await widget.session.api.get('/api/student/teachers/${widget.id}'));
      if (mounted) {
        setState(() {
          data = value;
          teacher = asMap(value['teacher']);
          error = '';
        });
      }
    } on ApiException catch (reason) {
      if (mounted) setState(() => error = studentMessage(reason.code, reason.message, widget.session.copy.arabic));
    }
  }

  Future<void> follow() async {
    setState(() => busy = true);
    final next = await toggleFollow(context, widget.session, teacher);
    if (!mounted) return;
    setState(() {
      busy = false;
      if (next != null) teacher = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.session.copy;
    final name = asText(teacher['name']);
    final id = widget.id;
    final tone = toneFor(id);
    final courses = asMaps(data?['courses']);
    final free = asMaps(data?['freeLessons']);
    final upcoming = asMaps(data?['upcoming']);
    final bio = asText(data?['bio']);
    final subjects = (teacher['subjects'] is List ? (teacher['subjects'] as List).map(asText).where((s) => s.isNotEmpty).toList() : <String>[]);
    return Scaffold(
      backgroundColor: ToviTokens.page,
      body: RefreshIndicator(
        color: ToviTokens.violet,
        onRefresh: load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 190,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: tone, begin: AlignmentDirectional.topStart, end: AlignmentDirectional.bottomEnd),
                    ),
                    child: CustomPaint(painter: _HeroPainter(), size: Size.infinite),
                  ),
                  ToviHeader(title: '', light: true, onBack: () => Navigator.pop(context)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 130, 16, 0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: ToviTokens.surface, borderRadius: BorderRadius.circular(28), boxShadow: ToviTokens.floating),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                        child: Column(
                          children: [
                            // The photo sits half above the card edge.
                            SizedBox(
                              height: 62,
                              child: OverflowBox(
                                maxHeight: 104,
                                alignment: Alignment.bottomCenter,
                                child: TeacherAvatar(id: id, name: name, photo: teacher['photoUrl'], size: 104, ring: 4),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Padding(
                              padding: EdgeInsets.zero,
                              child: Column(
                                children: [
                                  Text(
                                    name.isEmpty ? '…' : name,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ToviTokens.ink),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    [if (subjects.isNotEmpty) subjects.join(' · '), if (asText(teacher['institute']).isNotEmpty) asText(teacher['institute'])].join('  •  '),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: tone[0], fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      _Stat(value: countLabel(asInt(teacher['followers'])), label: copy.pick('متابع', 'Followers')),
                                      _Stat(value: '${asInt(teacher['courses'])}', label: copy.pick('دورة', 'Courses')),
                                      _Stat(value: '${asInt(teacher['freeLessons'])}', label: copy.pick('درس مجاني', 'Free lessons')),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: FollowPill(large: true, following: teacher['following'] == true, busy: busy, copy: copy, onPressed: data == null ? null : follow),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              sliver: SliverList.list(
                children: [
                  if (error.isNotEmpty) ErrorNote(text: error, onRetry: load),
                  if (data == null && error.isEmpty) const SkeletonFade(child: Column(children: [Bone(height: 90, radius: 22), SizedBox(height: 12), Bone(height: 200, radius: 22)])),
                  if (bio.isNotEmpty) ...[
                    SectionHead(title: copy.pick('نبذة', 'About')),
                    SoftPanel(
                      child: Text(bio, style: const TextStyle(height: 1.7, fontSize: 15, color: ToviTokens.inkSoft)),
                    ),
                  ],
                  if (upcoming.isNotEmpty) ...[
                    SectionHead(title: copy.pick('البث القادم', 'Upcoming live')),
                    for (final row in upcoming)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _LiveRow(
                          row: row,
                          copy: copy,
                          onOpen: () => Navigator.push(context, toviRoute(MeetingPage(session: widget.session, sessionId: asText(row['id'])))),
                        ),
                      ),
                  ],
                  if (data != null) ...[
                    SectionHead(title: copy.pick('الدورات', 'Courses')),
                    if (courses.isEmpty)
                      EmptyNote(icon: Icons.play_lesson_rounded, text: copy.pick('لا توجد دورات بعد.', 'No courses yet.'))
                    else
                      _CourseGrid(
                        rows: courses,
                        copy: copy,
                        onOpen: (row) => Navigator.push(context, toviRoute(CoursePage(session: widget.session, id: asText(row['id'])))),
                      ),
                  ],
                  if (free.isNotEmpty) ...[
                    SectionHead(title: copy.pick('دروس مجانية', 'Free lessons')),
                    for (final row in free)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: FreeLessonRow(
                          title: asText(row['title']),
                          subtitle: asText(row['courseTitle']),
                          onPlay: () => playLesson(
                            context,
                            widget.session,
                            title: asText(row['title']),
                            subtitle: asText(row['courseTitle']),
                            reference: asText(row['videoReference']),
                            youtubeId: asText(row['youtubeId']),
                            onWatched: () => widget.session.api.post('/api/student/lessons/${asText(row['id'])}/progress').catchError((_) => null),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final soft = Paint()..color = Colors.white.withValues(alpha: 0.10);
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.2), size.height * 0.55, soft);
    canvas.drawCircle(Offset(size.width * 0.92, size.height * 0.95), size.height * 0.5, soft);
    canvas.drawCircle(Offset(size.width * 0.72, size.height * 0.32), 4, Paint()..color = ToviTokens.sun);
    canvas.drawCircle(Offset(size.width * 0.32, size.height * 0.7), 3, Paint()..color = Colors.white.withValues(alpha: 0.7));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: ToviTokens.page, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: ToviTokens.ink),
            ),
            Text(label, style: const TextStyle(color: ToviTokens.muted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _CourseGrid extends StatelessWidget {
  const _CourseGrid({required this.rows, required this.copy, required this.onOpen});
  final List<Map<String, dynamic>> rows;
  final Copy copy;
  final ValueChanged<Map<String, dynamic>> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rows.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 216),
          itemBuilder: (context, i) => CourseCard(row: rows[i], copy: copy, showTeacher: false, coverHeight: 120, onTap: () => onOpen(rows[i])),
        );
      },
    );
  }
}

class _LiveRow extends StatelessWidget {
  const _LiveRow({required this.row, required this.copy, required this.onOpen});
  final Map<String, dynamic> row;
  final Copy copy;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final start = asDate(row['startsAt'])?.toLocal();
    final phase = asText(row['phase']);
    final live = phase == 'live' || phase == 'lobby';
    final time = start == null ? '' : '${start.day}/${start.month} · ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    return SoftPanel(
      onTap: row['enrolled'] == true ? onOpen : null,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: live ? ToviTokens.coralSoft : ToviTokens.violetSoft, borderRadius: BorderRadius.circular(14)),
            child: Icon(live ? Icons.sensors_rounded : Icons.event_rounded, color: live ? ToviTokens.coral : ToviTokens.violet),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asText(row['title']),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${asText(row['classroomTitle'])}  •  $time',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: ToviTokens.muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          if (live)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: ToviTokens.coral, borderRadius: BorderRadius.circular(999)),
              child: Text(
                copy.pick('مباشر', 'Live'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            )
          else if (row['enrolled'] != true)
            const Icon(Icons.lock_outline_rounded, color: ToviTokens.faint, size: 20),
        ],
      ),
    );
  }
}

class FreeLessonRow extends StatelessWidget {
  const FreeLessonRow({super.key, required this.title, required this.subtitle, required this.onPlay});
  final String title;
  final String subtitle;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return SoftPanel(
      onTap: onPlay,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: ToviTokens.sunSoft, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.play_arrow_rounded, color: Color(0xFFB37A00), size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: ToviTokens.muted, fontSize: 12.5),
                  ),
              ],
            ),
          ),
          const Icon(Icons.chevron_left_rounded, color: ToviTokens.faint),
        ],
      ),
    );
  }
}

/// All teachers and the ones the student follows.
class TeachersPage extends StatefulWidget {
  const TeachersPage({super.key, required this.session, this.followingOnly = false});
  final Session session;
  final bool followingOnly;

  @override
  State<TeachersPage> createState() => _TeachersPageState();
}

class _TeachersPageState extends State<TeachersPage> {
  late var following = widget.followingOnly;
  List<Map<String, dynamic>> items = [];
  final busy = <String>{};
  String error = '';
  var loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final data = asMap(await widget.session.api.get(following ? '/api/student/teachers/following' : '/api/student/teachers?pageSize=50'));
      if (mounted) {
        setState(() {
          items = asMaps(data['items']);
          error = '';
          loading = false;
        });
      }
    } on ApiException catch (reason) {
      if (mounted) {
        setState(() {
          error = studentMessage(reason.code, reason.message, widget.session.copy.arabic);
          loading = false;
        });
      }
    }
  }

  Future<void> follow(int index) async {
    final row = items[index];
    final id = asText(row['id']);
    setState(() => busy.add(id));
    final next = await toggleFollow(context, widget.session, row);
    if (!mounted) return;
    setState(() {
      busy.remove(id);
      if (next == null) return;
      if (following && next['following'] != true) {
        items.removeAt(index);
      } else {
        items[index] = next;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.session.copy;
    return Scaffold(
      backgroundColor: ToviTokens.page,
      body: Column(
        children: [
          ToviHeader(title: copy.pick('المعلمون', 'Teachers'), onBack: () => Navigator.pop(context)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                backgroundColor: ToviTokens.sunken,
                selectedBackgroundColor: ToviTokens.violet,
                selectedForegroundColor: Colors.white,
                side: BorderSide.none,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
              segments: [
                ButtonSegment(value: false, label: Text(copy.pick('كل المعلمين', 'All teachers'))),
                ButtonSegment(value: true, label: Text(copy.pick('أتابعهم', 'Following'))),
              ],
              selected: {following},
              onSelectionChanged: (value) {
                setState(() => following = value.first);
                load();
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: ToviTokens.violet,
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (loading)
                    const SkeletonFade(child: Column(children: [Bone(height: 94, radius: 24), SizedBox(height: 10), Bone(height: 94, radius: 24), SizedBox(height: 10), Bone(height: 94, radius: 24)]))
                  else if (error.isNotEmpty)
                    ErrorNote(text: error, onRetry: load)
                  else if (items.isEmpty)
                    EmptyNote(icon: Icons.person_search_rounded, text: following ? copy.pick('لم تتابع أي معلم بعد.', 'You do not follow any teacher yet.') : copy.empty)
                  else
                    for (var i = 0; i < items.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TeacherTile(
                          row: items[i],
                          copy: copy,
                          busy: busy.contains(asText(items[i]['id'])),
                          onFollow: () => follow(i),
                          onOpen: () async {
                            await Navigator.push(context, toviRoute(TeacherPage(session: widget.session, id: asText(items[i]['id']), preview: items[i])));
                            if (mounted) await load();
                          },
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
