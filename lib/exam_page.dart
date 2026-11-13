import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'session.dart';
import 'student_rules.dart';
import 'ui.dart';

class ExamPage extends StatefulWidget {
  const ExamPage({super.key, required this.session, required this.id});
  final Session session;
  final String id;

  @override
  State<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> {
  Map<String, dynamic>? paper;
  final answers = <String, String>{};
  String error = '';
  String result = '';
  var loading = true;
  var submitting = false;
  var locked = false;
  final waiting = <String>{};

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final value = asMap(await widget.session.api.get('/api/student/exams/${widget.id}'));
      var saved = '';
      var closed = false;
      final pending = <String>{};
      final prior = <String, String>{};
      try {
        final stored = asMap(await widget.session.api.get('/api/student/exams/${widget.id}/result'));
        saved = asText(stored['totalMark']);
        closed = true;
        for (final answer in asMaps(stored['answers'])) {
          final id = asText(answer['questionId']);
          prior[id] = asText(answer['response']);
          if (answer['corrected'] != true) pending.add(id);
        }
      } on ApiException catch (reason) {
        if (reason.status != 404) rethrow;
      }
      if (!mounted) return;
      setState(() {
        paper = value;
        result = saved;
        locked = closed;
        waiting
          ..clear()
          ..addAll(pending);
        answers.addAll(prior);
        error = '';
        loading = false;
      });
    } on ApiException catch (reason) {
      if (mounted) setState(() { error = studentMessage(reason.code, reason.message, widget.session.copy.arabic); loading = false; });
    }
  }

  Future<void> submit() async {
    final questions = asMaps(paper?['questions']);
    setState(() { submitting = true; error = ''; });
    try {
      final response = asMap(await widget.session.api.post('/api/student/exams/${widget.id}/attempts', {
        'answers': [for (final question in questions) {'questionId': question['id'], 'response': answers[asText(question['id'])] ?? ''}],
      }));
      if (mounted) await load();
      if (mounted && result.isNotEmpty) {
        setState(() => result = '${asText(response['totalMark'])} / $result');
      }
    } on ApiException catch (reason) {
      if (mounted) setState(() => error = studentMessage(reason.code, reason.message, widget.session.copy.arabic));
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.session.copy;
    final questions = asMaps(paper?['questions']);
    final end = asDate(paper?['endDate']);
    return Scaffold(
      backgroundColor: Tovi.surface,
      body: Column(
        children: [
          ToviHeader(title: asText(paper?['title']).isEmpty ? copy.pick('الاختبار', 'Exam') : asText(paper?['title']), onBack: () => Navigator.pop(context)),
          Expanded(
            child: loading
                ? const Padding(padding: EdgeInsets.all(20), child: SkeletonFade(child: Bone(height: 140, radius: 22)))
                : paper == null
                    ? ErrorNote(text: error, onRetry: load)
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        children: [
                          if (end != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(copy.pick('ينتهي ${_clock(end)}', 'Ends ${_clock(end)}'), style: const TextStyle(color: Tovi.muted, fontWeight: FontWeight.w700)),
                            ),
                          if (error.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(error, style: const TextStyle(color: Tovi.danger))),
                          if (result.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: SoftPanel(
                                color: Tovi.lilac,
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(copy.pick('النتيجة', 'Result'), style: const TextStyle(color: Tovi.violet, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  Text(result, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700)),
                                ]),
                              ),
                            ),
                          if (questions.isEmpty) EmptyNote(icon: Icons.quiz_rounded, text: copy.empty),
                          for (var i = 0; i < questions.length; i++) _question(questions[i], i),
                        ],
                      ),
          ),
          if (paper != null && questions.isNotEmpty && !locked)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: ToviButton(label: copy.pick('تسليم', 'Submit'), busy: submitting, onPressed: submit),
              ),
            ),
        ],
      ),
    );
  }

  Widget _question(Map<String, dynamic> question, int index) {
    final copy = widget.session.copy;
    final id = asText(question['id']);
    final type = asText(question['type']);
    final options = asMaps(question['options']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${index + 1}', style: const TextStyle(color: Tovi.violet, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(asText(question['text']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, height: 1.4)),
            Text('${asText(question['mark'])} ${copy.pick('درجة', 'marks')}', style: const TextStyle(color: Tovi.muted, fontSize: 12)),
            const SizedBox(height: 12),
            if (type == 'TrueFalse')
              Row(children: [
                Expanded(child: _choice(copy.pick('صح', 'True'), answers[id] == 'true', locked ? null : () => setState(() => answers[id] = 'true'))),
                const SizedBox(width: 8),
                Expanded(child: _choice(copy.pick('خطأ', 'False'), answers[id] == 'false', locked ? null : () => setState(() => answers[id] = 'false'))),
              ])
            else if (type == 'MultipleChoice')
              for (final option in options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _choice(asText(option['text']), answers[id] == asText(option['id']), locked ? null : () => setState(() => answers[id] = asText(option['id']))),
                )
            else if (locked)
              Text(waiting.contains(id) ? copy.pick('بانتظار تصحيح الأستاذ.', 'Waiting for the teacher.') : answers[id] ?? '', style: const TextStyle(height: 1.5))
            else
              TextField(onChanged: (value) => answers[id] = value, decoration: toviField(copy.pick('إجابة مفتوحة', 'Open answer'))),
          ],
        ),
      ),
    );
  }

  Widget _choice(String label, bool selected, VoidCallback? onTap) {
    return Material(
      color: selected ? Tovi.violet : Tovi.field,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Text(label, style: TextStyle(color: selected ? Colors.white : Tovi.ink, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

String _clock(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month ${value.year} $hour:$minute';
}
