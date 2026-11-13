import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'session.dart';
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

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      final value = Map<String, dynamic>.from(await widget.session.api.get('/api/student/courses/${widget.id}') as Map);
      if (mounted) setState(() => data = value);
    } on ApiException catch (reason) {
      if (mounted) setState(() => error = reason.message);
    }
  }

  Future<void> act(String path) async {
    try { await widget.session.api.post(path); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OK'))); }
    on ApiException catch (reason) { setState(() => error = reason.message); }
  }

  @override
  Widget build(BuildContext context) {
    final course = data?['course'] as Map?;
    final chapters = (data?['chapters'] as List?) ?? const [];
    final lessons = (data?['lessons'] as List?) ?? const [];
    final enrolled = data?['enrolled'] == true;
    return Scaffold(
      appBar: AppBar(title: Text('${course?['title'] ?? ''}')),
      body: error.isNotEmpty && data == null
          ? Center(child: Text(error))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SoftCard(
                  color: Tovi.brandSoft,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${course?['title'] ?? ''}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, children: [
                      FilledButton(onPressed: () => act('/api/student/courses/${widget.id}/like'), child: Text(widget.session.copy.pick('إعجاب', 'Like'))),
                      OutlinedButton(onPressed: () => act('/api/student/courses/${widget.id}/save'), child: Text(widget.session.copy.pick('حفظ', 'Save'))),
                    ]),
                  ]),
                ),
                if (!enrolled) Padding(padding: const EdgeInsets.only(top: 12), child: SoftCard(color: Tovi.saffron, child: Text(widget.session.copy.pick('فعّل كود الدورة لرؤية الفيديو', 'Redeem a course code to see the video')))),
                for (final chapter in chapters) ...[
                  SectionLabel('${(chapter as Map)['title']}'),
                  for (final lesson in lessons.where((item) => (item as Map)['chapterId'] == chapter['id']))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SoftCard(
                        onTap: enrolled ? () => widget.session.api.post('/api/student/lessons/${(lesson as Map)['id']}/progress') : null,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${(lesson as Map)['title']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text('${lesson['videoReference'] ?? ''}', style: const TextStyle(color: Tovi.muted)),
                        ]),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}
