import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'cards.dart';
import 'copy.dart';
import 'redeem.dart';
import 'session.dart';
import 'student_rules.dart';
import 'teacher_page.dart';
import 'ui.dart';
import 'video_page.dart';
import 'features/hub_kit.dart' show HubApi;

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
  var liked = false;
  var saved = false;

  @override
  void initState() {
    super.initState();
    load();
    loadMarks();
  }

  Future<void> loadMarks() async {
    try {
      final value = asMap(await widget.session.api.get('/api/student/courses/${widget.id}/marks'));
      if (mounted) setState(() { liked = value['liked'] == true; saved = value['saved'] == true; });
    } catch (_) {}
  }

  Future<void> toggle(bool like) async {
    final copy = widget.session.copy;
    final on = like ? liked : saved;
    final path = '/api/student/courses/${widget.id}/${like ? 'like' : 'save'}';
    setState(() => like ? liked = !on : saved = !on);
    try {
      if (on) {
        await widget.session.api.sendDelete(path);
      } else {
        await widget.session.api.post(path);
      }
      if (!mounted) return;
      final text = like
          ? (on ? copy.pick('شلت الإعجاب', 'Like removed') : copy.pick('عجبتك الدورة', 'Liked'))
          : (on ? copy.pick('شلتها من المحفوظات', 'Removed from saved') : copy.pick('انحفظت بالمحفوظات', 'Saved'));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    } on ApiException catch (reason) {
      if (mounted) setState(() { like ? liked = on : saved = on; error = studentMessage(reason.code, reason.message, copy.arabic); });
    } catch (_) {
      if (mounted) setState(() => like ? liked = on : saved = on);
    }
  }

  Future<void> load() async {
    try {
      final value = asMap(await widget.session.api.get('/api/student/courses/${widget.id}'));
      if (mounted) setState(() { data = value; error = ''; loading = false; });
    } on ApiException catch (reason) {
      if (mounted) setState(() { error = studentMessage(reason.code, reason.message, widget.session.copy.arabic); loading = false; });
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

  Future<void> play(Map<String, dynamic> lesson) async {
    if (lesson['locked'] == true) {
      await redeem();
      return;
    }
    final reference = asText(lesson['videoReference']);
    if (reference.isEmpty) {
      await markLesson(asText(lesson['id']));
      return;
    }
    await playLesson(
      context,
      widget.session,
      title: asText(lesson['title']),
      subtitle: asText(asMap(data?['course'])['title']),
      reference: reference,
      youtubeId: asText(lesson['youtubeId']),
      onWatched: () => markLesson(asText(lesson['id'])),
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.session.copy;
    final course = asMap(data?['course']);
    final card = {...course, ...asMap(data?['card'])};
    if (asText(card['id']).isEmpty) card['id'] = widget.id;
    final chapters = asMaps(data?['chapters']);
    final lessons = asMaps(data?['lessons']);
    final enrolled = data?['enrolled'] == true;
    final title = asText(card['title']);
    final free = lessons.where((l) => l['isFree'] == true).toList();
    Map<String, dynamic>? next;
    for (final lesson in lessons) {
      if (lesson['locked'] != true && lesson['completed'] != true) {
        next = lesson;
        break;
      }
    }
    next ??= lessons.where((l) => l['locked'] != true).firstOrNull;
    final teacher = asText(card['teacherName']);
    return Scaffold(
      backgroundColor: ToviTokens.page,
      body: Column(children: [
        Expanded(
          child: RefreshIndicator(
            color: ToviTokens.violet,
            onRefresh: load,
            child: CustomScrollView(slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 280,
                  child: Stack(fit: StackFit.expand, children: [
                    CourseCover(row: card, iconSize: 110),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x5917142B), Color(0x0017142B), Color(0xB317142B)], stops: [0, 0.35, 1]),
                      ),
                    ),
                    Align(
                      alignment: Alignment.topCenter,
                      child: ToviHeader(
                        title: '',
                        light: true,
                        onBack: () => Navigator.pop(context),
                        action: PopupMenuButton<String>(
                          tooltip: copy.pick('المزيد', 'More'),
                          color: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          onSelected: (value) {
                            if (value == 'like') toggle(true);
                            if (value == 'save') toggle(false);
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(value: 'like', child: Row(children: [Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: Tovi.coral, size: 20), const SizedBox(width: 10), Text(liked ? copy.pick('شيل الإعجاب', 'Unlike') : copy.like)])),
                            PopupMenuItem(value: 'save', child: Row(children: [Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: Tovi.violet, size: 20), const SizedBox(width: 10), Text(saved ? copy.pick('شيل من المحفوظات', 'Unsave') : copy.save)])),
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
                    ),
                    PositionedDirectional(
                      start: 20,
                      end: 20,
                      bottom: 34,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          for (final chip in [asText(card['grade']), asText(card['subject'])].where((t) => t.isNotEmpty)) _HeroChip(text: chip),
                          if (free.isNotEmpty) _HeroChip(text: lessonCount(copy, free.length, free: true), sun: true),
                        ]),
                        const SizedBox(height: 10),
                        Text(title.isEmpty ? '…' : title, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w700, height: 1.25)),
                      ]),
                    ),
                  ]),
                ),
              ),
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -18),
                  child: Container(
                    decoration: const BoxDecoration(color: ToviTokens.page, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                    child: loading
                        ? const SkeletonFade(child: Column(children: [Bone(height: 64, radius: 20), SizedBox(height: 12), Bone(height: 180, radius: 24)]))
                        : data == null
                            ? ErrorNote(text: error, onRetry: load)
                            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                                if (teacher.isNotEmpty)
                                  SoftPanel(
                                    onTap: () => Navigator.push(context, toviRoute(TeacherPage(session: widget.session, id: asText(card['teacherId'])))),
                                    child: Row(children: [
                                      TeacherAvatar(id: asText(card['teacherId']), name: teacher, photo: card['teacherPhotoUrl'], size: 46),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          Text(teacher, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                          Text(copy.pick('مدرّس الدورة', 'Course teacher'), style: const TextStyle(color: Tovi.muted, fontSize: 12.5)),
                                        ]),
                                      ),
                                      const Icon(Icons.chevron_left_rounded, color: ToviTokens.faint),
                                    ]),
                                  ),
                                const SizedBox(height: 14),
                                Row(children: [
                                  _Meta(icon: Icons.grid_view_rounded, text: '${chapters.length} ${copy.pick('فصول', 'chapters')}'),
                                  const SizedBox(width: 16),
                                  _Meta(icon: Icons.play_lesson_rounded, text: '${lessons.length} ${copy.lessons}'),
                                  const Spacer(),
                                  CircleButton(icon: Icons.calendar_month_rounded, tooltip: copy.timetable, onPressed: () => setState(() => tab = 1)),
                                ]),
                                const SizedBox(height: 14),
                                _Tabs(labels: [copy.lessons, copy.timetable, copy.about], index: tab, onSelect: (value) => setState(() => tab = value)),
                                const SizedBox(height: 14),
                                if (error.isNotEmpty) Text(error, style: const TextStyle(color: Tovi.danger)),
                                if (tab == 0) _lessons(copy, chapters, lessons, enrolled),
                                if (tab == 1) _aboutTime(copy),
                                if (tab == 2) _about(copy, course, enrolled),
                              ]),
                  ),
                ),
              ),
            ]),
          ),
        ),
        if (data != null)
          Container(
            decoration: const BoxDecoration(color: ToviTokens.surface, boxShadow: ToviTokens.floating),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                child: ToviButton(
                  color: Tovi.violet,
                  label: enrolled
                      ? copy.pick('متابعة الدرس', 'Continue lesson')
                      : next != null
                          ? copy.pick('شاهد درساً مجانياً', 'Watch a free lesson')
                          : copy.redeem,
                  onPressed: next != null ? () => play(next!) : (enrolled ? null : redeem),
                ),
              ),
            ),
          ),
      ]),
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
            child: SoftPanel(
              color: ToviTokens.sunSoft,
              onTap: redeem,
              child: Row(children: [
                const Icon(Icons.key_rounded, color: Color(0xFFB37A00)),
                const SizedBox(width: 10),
                Expanded(child: Text(copy.pick('الدروس المجانية مفتوحة لك. فعّل كود الدورة لفتح الباقي.', 'Free lessons are open. Redeem the course code for the rest.'), style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4))),
              ]),
            ),
          ),
        for (var c = 0; c < groups.length; c++) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 6),
            child: Text(asText(groups[c]['title']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          _lessonList(groups[c], lessons, c, enrolled),
        ],
      ],
    );
  }

  Widget _lessonList(Map<String, dynamic> chapter, List<Map<String, dynamic>> lessons, int chapterIndex, bool enrolled) {
    final copy = widget.session.copy;
    final rows = (chapter['id'] == null ? [...lessons] : [for (final lesson in lessons) if (lesson['chapterId'] == chapter['id']) lesson])
      ..sort((a, b) => asInt(a['sortOrder']).compareTo(asInt(b['sortOrder'])));
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(children: [
      for (var index = 0; index < rows.length; index++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _LessonRow(
            lesson: rows[index],
            number: '${chapterIndex + 1}.${index + 1}',
            freeLabel: enrolled ? '' : copy.pick('مجاني', 'Free'),
            onTap: () => play(rows[index]),
          ),
        ),
    ]);
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
          Expanded(child: ToviButton(label: liked ? copy.pick('عجبتني ✓', 'Liked ✓') : copy.like, color: liked ? Tovi.coral : Tovi.violet, onPressed: () => toggle(true))),
          const SizedBox(width: 10),
          Expanded(child: ToviButton(label: saved ? copy.pick('محفوظة ✓', 'Saved ✓') : copy.save, color: Tovi.blue, onPressed: () => toggle(false))),
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

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.text, this.sun = false});
  final String text;
  final bool sun;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: sun ? ToviTokens.sun : Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(color: sun ? ToviTokens.ink : Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({required this.lesson, required this.number, required this.freeLabel, required this.onTap});
  final Map<String, dynamic> lesson;
  final String number;
  final String freeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locked = lesson['locked'] == true;
    final done = lesson['completed'] == true;
    final isFree = lesson['isFree'] == true;
    return Material(
      color: ToviTokens.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: locked ? ToviTokens.sunken : done ? ToviTokens.mintSoft : ToviTokens.violetSoft, borderRadius: BorderRadius.circular(14)),
              child: Icon(locked ? Icons.lock_rounded : done ? Icons.check_rounded : Icons.play_arrow_rounded, color: locked ? ToviTokens.faint : done ? ToviTokens.mint : ToviTokens.violet),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(number, style: const TextStyle(color: Tovi.muted, fontWeight: FontWeight.w700, fontSize: 12)),
                Text(asText(lesson['title']), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: locked ? Tovi.muted : Tovi.ink)),
              ]),
            ),
            if (isFree && freeLabel.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: ToviTokens.sunSoft, borderRadius: BorderRadius.circular(999)),
                child: Text(freeLabel, style: const TextStyle(color: Color(0xFF8A5E00), fontWeight: FontWeight.w700, fontSize: 12)),
              ),
          ]),
        ),
      ),
    );
  }
}
