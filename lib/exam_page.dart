import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'session.dart';
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

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      final value = Map<String, dynamic>.from(await widget.session.api.get('/api/student/exams/${widget.id}') as Map);
      if (mounted) setState(() => paper = value);
    } on ApiException catch (reason) {
      if (mounted) setState(() => error = reason.message);
    }
  }

  Future<void> submit() async {
    final questions = (paper?['questions'] as List?) ?? const [];
    try {
      final response = await widget.session.api.post('/api/student/exams/${widget.id}/attempts', {
        'answers': [for (final question in questions) {'questionId': (question as Map)['id'], 'response': answers['${question['id']}'] ?? ''}],
      });
      final stored = await widget.session.api.get('/api/student/exams/${widget.id}/result');
      setState(() => result = '${response['totalMark']} / ${stored['totalMark']}');
    } on ApiException catch (reason) {
      setState(() => error = reason.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final questions = (paper?['questions'] as List?) ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text('${paper?['title'] ?? widget.session.copy.pick('الاختبار', 'Exam')}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (error.isNotEmpty) Text(error, style: const TextStyle(color: Color(0xFFA33B32))),
          if (result.isNotEmpty) SoftCard(color: Tovi.brandSoft, child: Text(result, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700))),
          for (final raw in questions) question(Map<String, dynamic>.from(raw as Map)),
          if (paper != null) FilledButton(onPressed: submit, child: Text(widget.session.copy.pick('تسليم', 'Submit'))),
        ],
      ),
    );
  }

  Widget question(Map<String, dynamic> question) {
    final id = '${question['id']}';
    final type = '${question['type']}';
    final options = (question['options'] as List?) ?? const [];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${question['text']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            Text('${question['mark']}', style: const TextStyle(color: Tovi.muted)),
            const SizedBox(height: 8),
            if (type == 'TrueFalse')
              DropdownButton<String>(
                value: answers[id],
                hint: Text(widget.session.copy.pick('الإجابة', 'Answer')),
                items: const [DropdownMenuItem(value: 'true', child: Text('true')), DropdownMenuItem(value: 'false', child: Text('false'))],
                onChanged: (value) => setState(() => answers[id] = value ?? ''),
              )
            else if (type == 'MultipleChoice')
              Wrap(spacing: 8, children: [
                for (final option in options)
                  ChoiceChip(
                    label: Text('${(option as Map)['text']}'),
                    selected: answers[id] == '${option['id']}',
                    onSelected: (_) => setState(() => answers[id] = '${option['id']}'),
                  ),
              ])
            else
              TextField(onChanged: (value) => answers[id] = value, decoration: toviField(widget.session.copy.pick('إجابة مفتوحة', 'Open answer'))),
          ],
        ),
      ),
    );
  }
}
