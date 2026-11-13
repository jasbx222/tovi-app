import 'package:material_ui/material_ui.dart';

import '../exam_page.dart';
import '../redeem.dart';
import '../session.dart';
import '../ui.dart';
import 'hub_kit.dart';
import 'tiles.dart';

/// All exams the student can see: open now, submitted, and locked behind a code.
class ExamsPage extends StatefulWidget {
  const ExamsPage({super.key, required this.session});
  final Session session;
  @override
  State<ExamsPage> createState() => _ExamsPageState();
}

class _ExamsPageState extends State<ExamsPage> {
  static const states = ['open', 'submitted', 'locked'];
  var tab = 0;
  var list = GlobalKey<PagedListState>();
  Map<String, dynamic> counts = {};

  void switchTo(int next) => setState(() { tab = next; list = GlobalKey<PagedListState>(); });

  Future<dynamic> load(int page) async {
    return widget.session.api.get('/api/student/exams?page=$page&pageSize=20&state=${states[tab]}');
  }

  Future<void> open(Map<String, dynamic> row) async {
    final id = asText(row['id']);
    switch (asText(row['state'])) {
      case 'open':
        await Navigator.push(context, toviRoute(ExamPage(session: widget.session, id: id)));
      case 'done':
      case 'pending':
        await Navigator.push(context, toviRoute(ExamReviewPage(session: widget.session, id: id, title: asText(row['title']))));
      case 'locked':
        final result = await askRedeem(context, widget.session);
        if (result == null || !mounted) return;
      default:
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.session.copy.pick('انتهى وقت هذا الاختبار.', 'This exam has closed.'))));
        return;
    }
    list.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.session.copy;
    return HubScaffold(
      title: copy.pick('اختباراتي', 'My exams'),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: HubSegments(
            labels: [copy.pick('متاحة', 'Open'), copy.pick('مسلّمة', 'Submitted'), copy.pick('مقفلة', 'Locked')],
            index: tab,
            counts: [asInt(counts['open']), asInt(counts['done']), asInt(counts['locked'])],
            onChanged: switchTo,
          ),
        ),
        Expanded(
          child: PagedList(
            key: list,
            session: widget.session,
            load: load,
            onPage: (data) { if (data['counts'] is Map) setState(() => counts = asMap(data['counts'])); },
            empty: HubEmpty(
              icon: Icons.quiz_rounded,
              title: [copy.pick('ما عندك اختبار متاح هسه', 'No open exams right now'), copy.pick('ما سلّمت أي اختبار بعد', 'No submitted exams yet'), copy.pick('ما في اختبارات مقفلة', 'No locked exams')][tab],
              body: copy.pick('الاختبارات تطلع هنا من دوراتك أو بعد تفعيل كود اختبار.', 'Exams appear here from your courses or after you redeem an exam code.'),
              action: copy.redeem,
              onAction: () async { await askRedeem(context, widget.session); list.currentState?.refresh(); },
            ),
            itemBuilder: (context, row, i, refresh) => ExamCard(session: widget.session, row: row, onTap: () => open(row)),
          ),
        ),
      ]),
    );
  }
}

class ExamCard extends StatelessWidget {
  const ExamCard({super.key, required this.session, required this.row, required this.onTap});
  final Session session;
  final Map<String, dynamic> row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final copy = session.copy;
    final state = asText(row['state']);
    final end = asDate(row['endDate']);
    final (color, icon, label) = switch (state) {
      'open' => (ToviTokens.violet, Icons.edit_note_rounded, copy.pick('ابدأ', 'Start')),
      'done' => (ToviTokens.mint, Icons.verified_rounded, copy.pick('النتيجة', 'Result')),
      'pending' => (ToviTokens.sun, Icons.hourglass_top_rounded, copy.pick('بانتظار التصحيح', 'Being marked')),
      'locked' => (ToviTokens.muted, Icons.lock_rounded, copy.pick('فعّل', 'Unlock')),
      _ => (ToviTokens.coral, Icons.event_busy_rounded, copy.pick('مغلق', 'Closed')),
    };
    final score = row['score'];
    return SoftPanel(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        IconOrb(icon: icon, color: color, size: 50),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(asText(row['title']), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
          const SizedBox(height: 4),
          Text(
            [
              if (asText(row['courseTitle']).isNotEmpty) asText(row['courseTitle']),
              copy.pick('${asInt(row['questions'])} سؤال', '${asInt(row['questions'])} questions'),
              if (end != null && state == 'open') copy.pick('حتى ${shortDate(end, true)}', 'until ${shortDate(end, false)}'),
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: ToviTokens.muted, fontSize: 12.5),
          ),
        ])),
        const SizedBox(width: 8),
        if (score != null && state == 'done')
          Column(children: [
            Text('${asInt(score)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: ToviTokens.mint)),
            Text('/ ${asInt(row['mark'])}', style: const TextStyle(color: ToviTokens.muted, fontSize: 12)),
          ])
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
            child: Text(label, style: TextStyle(color: color == ToviTokens.sun ? const Color(0xFFB07E00) : color, fontWeight: FontWeight.w800, fontSize: 12.5)),
          ),
      ]),
    );
  }
}

/// Each question with the student's answer, the right answer, and marking status.
class ExamReviewPage extends StatefulWidget {
  const ExamReviewPage({super.key, required this.session, required this.id, this.title = ''});
  final Session session;
  final String id;
  final String title;
  @override
  State<ExamReviewPage> createState() => _ExamReviewPageState();
}

class _ExamReviewPageState extends State<ExamReviewPage> {
  Map<String, dynamic>? data;
  String error = '';

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() => error = '');
    try {
      final value = asMap(await widget.session.api.get('/api/student/exams/${widget.id}/review'));
      if (mounted) setState(() => data = value);
    } catch (reason) {
      if (mounted) setState(() => error = hubError(reason, widget.session));
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.session.copy;
    final exam = asMap(data?['exam']);
    final items = asMaps(data?['items']);
    final total = asInt(data?['totalMark']);
    final mark = asInt(exam['mark']);
    final ratio = mark == 0 ? 0.0 : (total / mark).clamp(0.0, 1.0);
    return HubScaffold(
      title: asText(exam['title']).isEmpty ? (widget.title.isEmpty ? copy.pick('مراجعة الاختبار', 'Exam review') : widget.title) : asText(exam['title']),
      body: data == null
          ? (error.isEmpty ? const Padding(padding: EdgeInsets.all(20), child: ListSkeleton(rows: 4, height: 110)) : ErrorNote(text: error, onRetry: load))
          : RefreshIndicator(
              color: ToviTokens.violet,
              onRefresh: load,
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 28), children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: const LinearGradient(colors: [ToviTokens.violet, Color(0xFF8E6BFF)], begin: AlignmentDirectional.topStart, end: AlignmentDirectional.bottomEnd),
                    boxShadow: const [BoxShadow(color: Color(0x406A4CFF), blurRadius: 26, offset: Offset(0, 12))],
                  ),
                  child: Row(children: [
                    SizedBox(
                      width: 88,
                      height: 88,
                      child: Stack(fit: StackFit.expand, children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: ratio),
                          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 900),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) => CircularProgressIndicator(value: value, strokeWidth: 9, backgroundColor: Colors.white24, color: ToviTokens.sun, strokeCap: StrokeCap.round),
                        ),
                        Center(child: Text('$total/$mark', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18))),
                      ]),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(copy.pick('نتيجتك', 'Your score'), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 6, children: [
                        _Chip(text: copy.pick('${asInt(data?['right'])} صح', '${asInt(data?['right'])} right'), color: ToviTokens.mint),
                        _Chip(text: copy.pick('${asInt(data?['wrong'])} خطأ', '${asInt(data?['wrong'])} wrong'), color: ToviTokens.coral),
                        if (asInt(data?['pending']) > 0) _Chip(text: copy.pick('${asInt(data?['pending'])} بانتظار التصحيح', '${asInt(data?['pending'])} being marked'), color: ToviTokens.sun),
                      ]),
                    ])),
                  ]),
                ),
                const SizedBox(height: 16),
                for (final row in items) Padding(padding: const EdgeInsets.only(bottom: 12), child: _ReviewItem(copy: copy, row: row)),
              ]),
            ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: TextStyle(color: color == ToviTokens.sun ? const Color(0xFFB07E00) : color, fontWeight: FontWeight.w800, fontSize: 12)),
      );
}

class _ReviewItem extends StatelessWidget {
  const _ReviewItem({required this.copy, required this.row});
  final dynamic copy;
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final correct = row['correct'];
    final pending = row['pending'] == true;
    final color = pending ? ToviTokens.sun : correct == true ? ToviTokens.mint : ToviTokens.coral;
    final type = asText(row['type']);
    final response = asText(row['response']);
    final options = asMaps(row['options']);
    return SoftPanel(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: Text('${asInt(row['number'])}', style: TextStyle(fontWeight: FontWeight.w900, color: color == ToviTokens.sun ? const Color(0xFFB07E00) : color)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(asText(row['text']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, height: 1.45))),
          const SizedBox(width: 8),
          Text(pending ? '— / ${asInt(row['mark'])}' : '${asInt(row['awarded'])} / ${asInt(row['mark'])}', style: TextStyle(fontWeight: FontWeight.w800, color: color == ToviTokens.sun ? const Color(0xFFB07E00) : color)),
        ]),
        const SizedBox(height: 10),
        if (type == 'MultipleChoice')
          for (final option in options)
            _OptionLine(text: asText(option['text']), chosen: option['chosen'] == true, right: option['isCorrect'] == true)
        else if (type == 'TrueFalse') ...[
          _OptionLine(text: copy.pick('صح', 'True'), chosen: response.toLowerCase() == 'true', right: row['correctBool'] == true),
          _OptionLine(text: copy.pick('خطأ', 'False'), chosen: response.toLowerCase() == 'false', right: row['correctBool'] == false),
        ] else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: ToviTokens.sunken, borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(copy.pick('جوابك', 'Your answer'), style: const TextStyle(color: ToviTokens.muted, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(response.isEmpty ? '—' : response, style: const TextStyle(height: 1.5)),
              if (pending) ...[
                const SizedBox(height: 8),
                Text(copy.pick('المعلم راح يصحح هذا الجواب.', 'Your teacher will mark this answer.'), style: const TextStyle(color: Color(0xFFB07E00), fontSize: 12.5, fontWeight: FontWeight.w700)),
              ],
            ]),
          ),
      ]),
    );
  }
}

class _OptionLine extends StatelessWidget {
  const _OptionLine({required this.text, required this.chosen, required this.right});
  final String text;
  final bool chosen;
  final bool right;

  @override
  Widget build(BuildContext context) {
    final color = right ? ToviTokens.mint : chosen ? ToviTokens.coral : ToviTokens.muted;
    final fill = right ? ToviTokens.mintSoft : chosen ? ToviTokens.coralSoft : ToviTokens.sunken;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(right ? Icons.check_circle_rounded : chosen ? Icons.cancel_rounded : Icons.radio_button_unchecked_rounded, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(fontWeight: chosen || right ? FontWeight.w700 : FontWeight.w500, color: ToviTokens.ink))),
      ]),
    );
  }
}
