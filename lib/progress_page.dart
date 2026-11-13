import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'copy.dart';
import 'session.dart';
import 'student_rules.dart';
import 'ui.dart';

String badgeTitle(String key, Copy copy) => switch (key) {
      'first_lesson' => copy.pick('أول درس', 'First lesson'),
      'ten_lessons' => copy.pick('10 دروس', '10 lessons'),
      'first_exam' => copy.pick('أول اختبار', 'First exam'),
      'five_exams' => copy.pick('5 اختبارات', '5 exams'),
      'first_live' => copy.pick('أول حصة مباشرة', 'First live session'),
      'five_lives' => copy.pick('5 حصص مباشرة', '5 live sessions'),
      'streak_3' => copy.pick('3 أيام متتالية', '3-day streak'),
      'streak_7' => copy.pick('أسبوع كامل', '7-day streak'),
      'xp_100' => copy.pick('100 نقطة', '100 XP'),
      'xp_500' => copy.pick('500 نقطة', '500 XP'),
      _ => key,
    };

IconData badgeIcon(String kind) => switch (kind) {
      'lesson' => Icons.play_lesson_outlined,
      'exam' => Icons.fact_check_outlined,
      'live' => Icons.sensors_rounded,
      'streak' => Icons.local_fire_department_rounded,
      _ => Icons.bolt_rounded,
    };

String eventLabel(String kind, Copy copy) => switch (kind) {
      'lesson' => copy.pick('إكمال درس', 'Lesson completed'),
      'exam' => copy.pick('تسليم اختبار', 'Exam submitted'),
      'live' => copy.pick('حضور حصة مباشرة', 'Live attendance'),
      _ => kind,
    };

const _weekdaysAr = ['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح'];
const _weekdaysEn = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// Compact progress block for the home screen.
class ProgressCard extends StatelessWidget {
  const ProgressCard({super.key, required this.copy, required this.data, required this.onOpen});
  final Copy copy;
  final Map<String, dynamic> data;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final streak = asMap(data['streak']);
    final current = asInt(streak['current']);
    final today = streak['activeToday'] == true;
    return SoftPanel(
      onTap: onOpen,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _Metric(icon: Icons.local_fire_department_rounded, color: ToviTokens.coral, value: '$current', label: copy.pick('يوم متتالي', 'day streak')),
          const SizedBox(width: 18),
          _Metric(icon: Icons.bolt_rounded, color: const Color(0xFFE0A100), value: '${asInt(data['xp'])}', label: copy.pick('نقطة', 'XP')),
          const Spacer(),
          const Icon(Icons.chevron_left_rounded, color: Tovi.muted, textDirection: TextDirection.ltr),
        ]),
        const SizedBox(height: 14),
        WeekBars(copy: copy, week: asMaps(data['week']), height: 56),
        const SizedBox(height: 10),
        Text(
          today ? copy.pick('أحسنت، سلسلتك محفوظة اليوم.', 'Nice, your streak is safe today.') : copy.pick('كمّل درس أو احضر حصة اليوم حتى تحافظ على سلسلتك.', 'Finish a lesson or attend a session today to keep your streak.'),
          style: const TextStyle(color: Tovi.muted, fontSize: 12.5, height: 1.45),
        ),
      ]),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.color, required this.value, required this.label});
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(ToviTokens.radiusSm)),
        child: Icon(icon, color: color, size: 20),
      ),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.1)),
        Text(label, style: const TextStyle(color: Tovi.muted, fontSize: 12)),
      ]),
    ]);
  }
}

class WeekBars extends StatelessWidget {
  const WeekBars({super.key, required this.copy, required this.week, this.height = 96});
  final Copy copy;
  final List<Map<String, dynamic>> week;
  final double height;

  @override
  Widget build(BuildContext context) {
    final top = week.fold<int>(1, (max, row) => asInt(row['xp']) > max ? asInt(row['xp']) : max);
    final names = copy.arabic ? _weekdaysAr : _weekdaysEn;
    return SizedBox(
      height: height + 24,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < week.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                AnimatedContainer(
                  duration: ToviTokens.calm,
                  height: asInt(week[i]['xp']) == 0 ? 6 : 6 + (height - 6) * asInt(week[i]['xp']) / top,
                  decoration: BoxDecoration(
                    color: i == week.length - 1 ? Tovi.violet : (asInt(week[i]['xp']) == 0 ? ToviTokens.sunken : ToviTokens.violet.withValues(alpha: 0.35)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(_dayName(asText(week[i]['day']), names), style: TextStyle(fontSize: 11, color: i == week.length - 1 ? Tovi.violet : Tovi.muted, fontWeight: i == week.length - 1 ? FontWeight.w700 : FontWeight.w500)),
              ]),
            ),
          ),
      ]),
    );
  }

  String _dayName(String day, List<String> names) {
    final date = DateTime.tryParse(day);
    return date == null ? '' : names[date.weekday - 1];
  }
}

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key, required this.session});
  final Session session;

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  Map<String, dynamic>? data;
  String error = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final next = asMap(await widget.session.api.get('/api/student/progress'));
      if (mounted) setState(() { data = next; error = ''; });
    } on ApiException catch (reason) {
      if (mounted) setState(() => error = studentMessage(reason.code, reason.message, widget.session.copy.arabic));
    } catch (_) {
      if (mounted) setState(() => error = widget.session.copy.pick('تعذّر تحميل التقدّم.', 'Could not load progress.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.session.copy;
    final d = data;
    return Scaffold(
      backgroundColor: Tovi.page,
      body: SafeArea(
        child: Column(children: [
          ToviHeader(title: copy.pick('تقدّمي', 'My progress'), safe: false, onBack: () => Navigator.pop(context)),
          Expanded(
            child: RefreshIndicator(
              color: Tovi.violet,
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  if (error.isNotEmpty) ErrorNote(text: error, onRetry: load),
                  if (d == null && error.isEmpty)
                    const SkeletonFade(child: Column(children: [Bone(height: 150, radius: 24), SizedBox(height: 14), Bone(height: 160, radius: 18)]))
                  else if (d != null) ...[
                    _Summary(copy: copy, data: d),
                    SectionHead(title: copy.pick('هذا الأسبوع', 'This week')),
                    SoftPanel(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(copy.pick('${asInt(d['weekXp'])} نقطة هذا الأسبوع', '${asInt(d['weekXp'])} XP this week'), style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        WeekBars(copy: copy, week: asMaps(d['week'])),
                      ]),
                    ),
                    SectionHead(title: copy.pick('الإنجازات', 'Achievements')),
                    GridView.count(
                      crossAxisCount: MediaQuery.sizeOf(context).width > 600 ? 4 : 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.25,
                      children: [for (final row in asMaps(d['achievements'])) _Badge(copy: copy, row: row)],
                    ),
                    SectionHead(title: copy.pick('آخر النقاط', 'Recent points')),
                    if (asMaps(d['recent']).isEmpty)
                      EmptyNote(icon: Icons.bolt_rounded, text: copy.pick('كمّل درس أو اختبار أو احضر حصة حتى تبدي تجمع نقاط.', 'Finish a lesson or exam, or attend a session, to start earning XP.'))
                    else
                      SoftPanel(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Column(children: [
                          for (final row in asMaps(d['recent']))
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(children: [
                                Icon(badgeIcon(asText(row['kind'])), color: Tovi.violet, size: 20),
                                const SizedBox(width: 12),
                                Expanded(child: Text(eventLabel(asText(row['kind']), copy), style: const TextStyle(fontWeight: FontWeight.w600))),
                                Text('+${asInt(row['points'])}', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFB98500))),
                              ]),
                            ),
                        ]),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.copy, required this.data});
  final Copy copy;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final streak = asMap(data['streak']);
    final counts = asMap(data['counts']);
    Widget cell(String value, String label) => Expanded(
          child: Column(children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(color: Tovi.violet, borderRadius: BorderRadius.circular(ToviTokens.radiusLg), boxShadow: ToviTokens.floating),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(copy.pick('مجموع نقاطك', 'Total XP'), style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
              Text('${asInt(data['xp'])}', style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w700, height: 1.15)),
              Text(copy.pick('اليوم +${asInt(data['todayXp'])}', 'Today +${asInt(data['todayXp'])}'), style: const TextStyle(color: ToviTokens.sun, fontWeight: FontWeight.w700)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(ToviTokens.radiusMd)),
            child: Column(children: [
              const Icon(Icons.local_fire_department_rounded, color: ToviTokens.coral, size: 28),
              Text('${asInt(streak['current'])}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.1)),
              Text(copy.pick('يوم', 'days'), style: const TextStyle(color: Tovi.muted, fontSize: 12)),
            ]),
          ),
        ]),
        const SizedBox(height: 18),
        Container(height: 1, color: Colors.white.withValues(alpha: 0.18)),
        const SizedBox(height: 14),
        Row(children: [
          cell('${asInt(counts['lessons'])}', copy.pick('دروس', 'Lessons')),
          cell('${asInt(counts['exams'])}', copy.pick('اختبارات', 'Exams')),
          cell('${asInt(counts['lives'])}', copy.pick('حصص', 'Lives')),
          cell('${asInt(streak['best'])}', copy.pick('أطول سلسلة', 'Best streak')),
        ]),
      ]),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.copy, required this.row});
  final Copy copy;
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final unlocked = row['unlocked'] == true;
    final goal = asInt(row['goal']);
    final progress = asInt(row['progress']);
    final kind = asText(row['kind']);
    final tone = switch (kind) {
      'streak' => ToviTokens.coral,
      'xp' => const Color(0xFFE0A100),
      'live' => ToviTokens.sky,
      'exam' => ToviTokens.mint,
      _ => ToviTokens.violet,
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: unlocked ? ToviTokens.surface : ToviTokens.sunken, borderRadius: BorderRadius.circular(ToviTokens.radiusMd), boxShadow: unlocked ? ToviTokens.raised : null),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: unlocked ? tone : ToviTokens.surface, shape: BoxShape.circle),
          child: Icon(unlocked ? badgeIcon(kind) : Icons.lock_outline_rounded, size: 20, color: unlocked ? Colors.white : ToviTokens.faint),
        ),
        const Spacer(),
        Text(badgeTitle(asText(row['key']), copy), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: unlocked ? Tovi.ink : Tovi.muted)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(value: goal == 0 ? 0 : progress / goal, minHeight: 5, color: tone, backgroundColor: unlocked ? ToviTokens.sunken : ToviTokens.surface),
        ),
        const SizedBox(height: 4),
        Text('$progress / $goal', style: const TextStyle(color: Tovi.muted, fontSize: 11.5)),
      ]),
    );
  }
}
