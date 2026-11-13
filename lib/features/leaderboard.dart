import 'package:material_ui/material_ui.dart';

import '../session.dart';
import '../ui.dart';
import 'hub_kit.dart';

/// Weekly and all-time points ranking, for everyone or the student's grade.
class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key, required this.session});
  final Session session;
  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  var week = true;
  var grade = false;
  Map<String, dynamic>? data;
  String error = '';

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { data = null; error = ''; });
    try {
      final value = asMap(await widget.session.api.get('/api/student/leaderboard?period=${week ? 'week' : 'all'}&scope=${grade ? 'grade' : 'all'}'));
      if (mounted) setState(() => data = value);
    } catch (reason) {
      if (mounted) setState(() => error = hubError(reason, widget.session));
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.session.copy;
    final items = asMaps(data?['items']);
    final me = asMap(data?['me']);
    final podium = items.take(3).toList();
    final rest = items.skip(3).toList();
    return HubScaffold(
      title: copy.pick('لوحة الصدارة', 'Leaderboard'),
      body: RefreshIndicator(
        color: ToviTokens.violet,
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 28), children: [
          HubSegments(labels: [copy.pick('هذا الأسبوع', 'This week'), copy.pick('كل الوقت', 'All time')], index: week ? 0 : 1, onChanged: (i) { week = i == 0; load(); }),
          const SizedBox(height: 8),
          HubSegments(labels: [copy.pick('كل الطلاب', 'Everyone'), copy.pick('مرحلتي', 'My grade')], index: grade ? 1 : 0, onChanged: (i) { grade = i == 1; load(); }),
          const SizedBox(height: 16),
          if (data == null && error.isEmpty)
            const ListSkeleton(rows: 6, height: 70)
          else if (data == null)
            ErrorNote(text: error, onRetry: load)
          else ...[
            if (grade && data?['scope'] != 'grade')
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(copy.pick('حدّد مرحلتك من الملف حتى تتنافس ويا زملائك.', 'Set your grade in your profile to compete with classmates.'), style: const TextStyle(color: ToviTokens.muted)),
              ),
            if (items.isEmpty)
              HubEmpty(icon: Icons.emoji_events_rounded, title: copy.pick('محد جمع نقاط بعد', 'No points yet'), body: copy.pick('خلّص درس أو اختبار أو احضر حصة وكون أول واحد.', 'Finish a lesson, an exam or a live session to be first.'))
            else ...[
              _Podium(rows: podium),
              const SizedBox(height: 14),
              for (final row in rest) Padding(padding: const EdgeInsets.only(bottom: 8), child: _RankRow(row: row, copy: copy)),
            ],
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: ToviTokens.night, borderRadius: BorderRadius.circular(22)),
              child: Row(children: [
                HubFace(url: me['photoUrl'], name: asText(me['name']), size: 44),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(copy.pick('ترتيبك', 'Your rank'), style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                  Text(me['rank'] == null ? copy.pick('اجمع أول نقاطك', 'Earn your first points') : '#${asInt(me['rank'])} ${copy.pick('من', 'of')} ${asInt(data?['players'])}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                ])),
                const Icon(Icons.bolt_rounded, color: ToviTokens.sun),
                Text('${asInt(me['xp'])}', style: const TextStyle(color: ToviTokens.sun, fontWeight: FontWeight.w900, fontSize: 18)),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? at(int i) => i < rows.length ? rows[i] : null;
    final order = [at(1), at(0), at(2)];
    const heights = [92.0, 124.0, 72.0];
    const colors = [Color(0xFFB8B5C9), ToviTokens.sun, Color(0xFFE59A62)];
    return SizedBox(
      height: 250,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < 3; i++)
          Expanded(
            child: order[i] == null
                ? const SizedBox()
                : TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : Duration(milliseconds: 500 + i * 160),
                    curve: Curves.easeOutBack,
                    builder: (context, t, child) => Transform.translate(offset: Offset(0, (1 - t) * 40), child: Opacity(opacity: t.clamp(0, 1), child: child)),
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      if (i == 1) const Icon(Icons.workspace_premium_rounded, color: ToviTokens.sun, size: 30),
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(shape: BoxShape.circle, color: colors[i]),
                        child: HubFace(url: order[i]!['photoUrl'], name: asText(order[i]!['name']), size: i == 1 ? 64 : 52),
                      ),
                      const SizedBox(height: 6),
                      Text(asText(order[i]!['name']), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, color: order[i]!['me'] == true ? ToviTokens.violet : ToviTokens.ink)),
                      Text('${asInt(order[i]!['xp'])} XP', style: const TextStyle(color: ToviTokens.muted, fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Container(
                        height: heights[i],
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        alignment: Alignment.topCenter,
                        padding: const EdgeInsets.only(top: 10),
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [colors[i], colors[i].withValues(alpha: 0.55)]),
                        ),
                        child: Text('${asInt(order[i]!['rank'])}', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                      ),
                    ]),
                  ),
          ),
      ]),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.row, required this.copy});
  final Map<String, dynamic> row;
  final dynamic copy;

  @override
  Widget build(BuildContext context) {
    final mine = row['me'] == true;
    return SoftPanel(
      color: mine ? ToviTokens.violetSoft : ToviTokens.surface,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        SizedBox(width: 30, child: Text('${asInt(row['rank'])}', style: const TextStyle(fontWeight: FontWeight.w900, color: ToviTokens.muted, fontSize: 16))),
        HubFace(url: row['photoUrl'], name: asText(row['name']), size: 38),
        const SizedBox(width: 10),
        Expanded(child: Text(asText(row['name']), style: TextStyle(fontWeight: FontWeight.w700, color: mine ? ToviTokens.violet : ToviTokens.ink))),
        const Icon(Icons.bolt_rounded, size: 18, color: Color(0xFFE0A100)),
        Text('${asInt(row['xp'])}', style: const TextStyle(fontWeight: FontWeight.w800)),
      ]),
    );
  }
}
