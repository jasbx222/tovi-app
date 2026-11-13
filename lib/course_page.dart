import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'copy.dart';
import 'redeem.dart';
import 'session.dart';
import 'student_rules.dart';
import 'ui.dart';

class CoursePage extends StatefulWidget {
  const CoursePage({super.key, required this.session, required this.id});
  final Session session;
  final String id;

  @override
  State<CoursePage> createState() => _CoursePageState();
}

class _CoursePageState extends State<CoursePage> {
  Map<String, dynamic>? data;
  String error = '';
  var loading = true;
  var tab = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final value = asMap(await widget.session.api.get('/api/student/courses/${widget.id}'));
      if (mounted) setState(() { data = value; error = ''; loading = false; });
    } on ApiException catch (reason) {
      if (mounted) setState(() { error = studentMessage(reason.code, reason.message, widget.session.copy.arabic); loading = false; });
    }
  }

  Future<void> act(String path, String done) async {
    try {
      await widget.session.api.post(path);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
    } on ApiException catch (reason) {
      if (mounted) setState(() => error = studentMessage(reason.code, reason.message, widget.session.copy.arabic));
    }
  }

  Future<void> markLesson(String id) async {
    try {
      await widget.session.api.post('/api/student/lessons/$id/progress');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.session.copy.pick('تم تسجيل التقدم', 'Progress saved'))));
      }
    } on ApiException catch (reason) {
      if (mounted) setState(() => error = studentMessage(reason.code, reason.message, widget.session.copy.arabic));
    }
  }

  Future<void> redeem() async {
    final result = await askRedeem(context, widget.session);
    if (!mounted || result == null) return;
    if (asText(result['targetType']) == 'Course' && asText(result['targetId']) == widget.id) {
      await load();
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.session.copy.pick('تم التفعيل. تجده من الرئيسية.', 'Redeemed. Open it from home.'))));
    }
  }

  Future<void> openVideo(String reference) async {
    final uri = Uri.tryParse(reference);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.session.copy;
    final course = asMap(data?['course']);
    final chapters = asMaps(data?['chapters']);
    final lessons = asMaps(data?['lessons']);
    final enrolled = data?['enrolled'] == true;
    final title = asText(course['title']);
    final firstLesson = lessons.isEmpty ? null : lessons.first;
    return Scaffold(
      backgroundColor: Tovi.canvas,
      body: Stack(
        children: [
          const Positioned(top: 0, left: 0, right: 0, height: 300, child: BoardArt()),
          ToviHeader(
            title: copy.pick('الدورة', 'Course'),
            light: true,
            onBack: () => Navigator.pop(context),
            action: PopupMenuButton<String>(
              tooltip: copy.pick('المزيد', 'More'),
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (value) {
                if (value == 'like') act('/api/student/courses/${widget.id}/like', copy.like);
                if (value == 'save') act('/api/student/courses/${widget.id}/save', copy.save);
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'like', child: Text(copy.like)),
                PopupMenuItem(value: 'save', child: Text(copy.save)),
              ],
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.more_horiz_rounded, color: Tovi.ink, size: 20),
              ),
            ),
          ),
          Positioned.fill(
            top: 236,
            child: Container(
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
              child: loading
                  ? const Padding(padding: EdgeInsets.all(20), child: SkeletonFade(child: Bone(height: 180, radius: 24)))
                  : data == null
                      ? ErrorNote(text: error, onRetry: load)
                      : Column(
                          children: [
                            Expanded(
                              child: ListView(
                                padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
                                children: [
                                  Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.25)),
                                  const SizedBox(height: 12),
                                  Row(children: [
                                    _Meta(icon: Icons.grid_view_rounded, text: '${chapters.length} ${copy.pick('فصول', 'chapters')}'),
                                    const SizedBox(width: 16),
                                    _Meta(icon: Icons.play_lesson_rounded, text: '${lessons.length} ${copy.lessons}'),
                                    const Spacer(),
                                    CircleButton(icon: Icons.calendar_month_rounded, tooltip: copy.timetable, onPressed: () => setState(() => tab = 1)),
                                  ]),
                                  const SizedBox(height: 16),
                                  _Tabs(
                                    labels: [copy.lessons, copy.timetable, copy.about],
                                    index: tab,
                                    onSelect: (value) => setState(() => tab = value),
                                  ),
                                  const SizedBox(height: 16),
                                  if (error.isNotEmpty) Text(error, style: const TextStyle(color: Tovi.danger)),
                                  if (tab == 0) _lessons(copy, chapters, lessons, enrolled),
                                  if (tab == 1) _aboutTime(copy),
                                  if (tab == 2) _about(copy, course, enrolled),
                                ],
                              ),
                            ),
                            SafeArea(
                              top: false,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                                child: ToviButton(
                                  label: enrolled ? copy.pick('متابعة الدرس', 'Continue lesson') : copy.redeem,
                                  onPressed: enrolled
                                      ? (firstLesson == null ? null : () => markLesson(asText(firstLesson['id'])))
                                      : redeem,
                                ),
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

  Widget _lessons(Copy copy, List<Map<String, dynamic>> chapters, List<Map<String, dynamic>> lessons, bool enrolled) {
    if (chapters.isEmpty && lessons.isEmpty) return EmptyNote(icon: Icons.play_lesson_rounded, text: copy.empty);
    final groups = chapters.isEmpty ? [<String, dynamic>{'id': null, 'title': copy.lessons}] : [...chapters]..sort((a, b) => asInt(a['sortOrder']).compareTo(asInt(b['sortOrder'])));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!enrolled)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SoftPanel(color: const Color(0xFFFFF1E6), child: Text(copy.pick('فعّل كود الدورة لرؤية الفيديو.', 'Redeem a course code to see the video.'))),
          ),
        for (var c = 0; c < groups.length; c++) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 6),
            child: Text(asText(groups[c]['title']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          _lessonGrid(groups[c], lessons, c, enrolled),
        ],
      ],
    );
  }

  Widget _lessonGrid(Map<String, dynamic> chapter, List<Map<String, dynamic>> lessons, int chapterIndex, bool enrolled) {
    final rows = (chapter['id'] == null ? [...lessons] : [for (final lesson in lessons) if (lesson['chapterId'] == chapter['id']) lesson])
      ..sort((a, b) => asInt(a['sortOrder']).compareTo(asInt(b['sortOrder'])));
    if (rows.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, constraints) {
      final two = constraints.maxWidth > 560;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: rows.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: two ? 2 : 1,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          mainAxisExtent: 96,
        ),
        itemBuilder: (context, index) {
          final lesson = rows[index];
          final video = asText(lesson['videoReference']);
          final link = Uri.tryParse(video);
          final playable = link != null && (link.isScheme('http') || link.isScheme('https'));
          return Material(
            color: Tovi.lilac,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                if (!enrolled) {
                  redeem();
                  return;
                }
                markLesson(asText(lesson['id']));
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${chapterIndex + 1}.${index + 1}', style: const TextStyle(color: Tovi.violet, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(asText(lesson['title']), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ])),
                  if (playable)
                    IconButton(
                      tooltip: widget.session.copy.pick('فتح الفيديو', 'Open video'),
                      onPressed: () => openVideo(video),
                      icon: const Icon(Icons.play_circle_fill_rounded, color: Tovi.violet),
                    ),
                ]),
              ),
            ),
          );
        },
      );
    });
  }

  Widget _aboutTime(Copy copy) {
    return EmptyNote(icon: Icons.event_busy_rounded, text: copy.pick('لا يوجد جدول مرتبط بهذه الدورة.', 'This course has no timetable yet.'));
  }

  Widget _about(Copy copy, Map<String, dynamic> course, bool enrolled) {
    final detail = firstMeta(course, const ['description', 'body', 'summary']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SoftPanel(
          color: enrolled ? const Color(0xFFE7F7F1) : Tovi.lilac,
          child: Text(
            enrolled ? copy.pick('الدورة مفعّلة.', 'This course is unlocked.') : copy.pick('الدورة بانتظار كود التفعيل.', 'This course is waiting for an activation code.'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        if (detail.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(detail, style: const TextStyle(fontSize: 16, height: 1.7)),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: ToviButton(label: copy.like, color: Tovi.violet, onPressed: () => act('/api/student/courses/${widget.id}/like', copy.like))),
          const SizedBox(width: 10),
          Expanded(child: ToviButton(label: copy.save, color: Tovi.blue, onPressed: () => act('/api/student/courses/${widget.id}/save', copy.save))),
        ]),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 18, color: Tovi.muted),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(color: Tovi.muted, fontWeight: FontWeight.w600)),
    ]);
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.labels, required this.index, required this.onSelect});
  final List<String> labels;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (var i = 0; i < labels.length; i++)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: ChoiceChip(
              label: Text(labels[i]),
              selected: index == i,
              showCheckmark: false,
              labelStyle: TextStyle(color: index == i ? Colors.white : Tovi.ink, fontWeight: FontWeight.w700),
              selectedColor: Tovi.violet,
              backgroundColor: Tovi.field,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              onSelected: (_) => onSelect(i),
            ),
          ),
      ]),
    );
  }
}
