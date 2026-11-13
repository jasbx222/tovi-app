import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../meeting_page.dart';
import '../session.dart';
import '../ui.dart';
import 'hub_kit.dart';
import 'tiles.dart';

/// Upcoming sessions, past sessions with attendance, and the replay library.
class SessionsHub extends StatefulWidget {
  const SessionsHub({super.key, required this.session, this.standalone = false});
  final Session session;
  final bool standalone;
  @override
  State<SessionsHub> createState() => _SessionsHubState();
}

class _SessionsHubState extends State<SessionsHub> {
  var tab = 0;
  var list = GlobalKey<PagedListState>();

  Future<dynamic> load(int page) {
    final api = widget.session.api;
    return switch (tab) {
      0 => api.get('/api/student/sessions?when=upcoming&page=$page&pageSize=20'),
      1 => api.get('/api/student/sessions?when=past&page=$page&pageSize=20'),
      _ => api.get('/api/student/replays?page=$page&pageSize=20'),
    };
  }

  Future<void> openSession(Map<String, dynamic> row) async {
    final id = asText(row['id']);
    if (tab == 0) {
      await Navigator.push(context, toviRoute(MeetingPage(session: widget.session, sessionId: id)));
    } else {
      await Navigator.push(context, toviRoute(RecapPage(session: widget.session, sessionId: id)));
    }
    list.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.session.copy;
    final empties = [
      HubEmpty(icon: Icons.event_available_rounded, title: copy.pick('ما عندك حصص قادمة', 'No upcoming sessions'), body: copy.pick('فعّل كود صف مباشر حتى تطلع حصصه هنا.', 'Redeem a classroom code to see its sessions here.')),
      HubEmpty(icon: Icons.history_rounded, title: copy.pick('ما حضرت حصص بعد', 'No past sessions yet'), body: copy.pick('بعد كل حصة تلكى هنا حضورك ونقاطك والإعادة.', 'After each session you will find your attendance, points and replay here.')),
      HubEmpty(icon: Icons.video_library_rounded, title: copy.pick('ما في إعادات بعد', 'No replays yet'), body: copy.pick('الحصص اللي يسجلها المعلم تنضاف هنا تلقائياً.', 'Sessions your teacher records appear here automatically.')),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.standalone) ToviHeader(title: copy.pick('حصصي', 'My sessions'), onBack: () => Navigator.pop(context), safe: false)
      else Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 4), child: Text(copy.schedule, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: HubSegments(
          labels: [copy.pick('القادمة', 'Upcoming'), copy.pick('السابقة', 'Past'), copy.pick('الإعادات', 'Replays')],
          index: tab,
          onChanged: (i) => setState(() { tab = i; list = GlobalKey<PagedListState>(); }),
        ),
      ),
      Expanded(
        child: PagedList(
          key: list,
          session: widget.session,
          load: load,
          empty: empties[tab],
          itemBuilder: (context, row, i, refresh) => tab == 2
              ? ReplayCard(session: widget.session, row: row, onRecap: () => Navigator.push(context, toviRoute(RecapPage(session: widget.session, sessionId: asText(row['sessionId'])))))
              : SessionCard(session: widget.session, row: row, past: tab == 1, onTap: () => openSession(row)),
        ),
      ),
    ]);
  }
}

/// A session row with date block, teacher, phase and attendance.
class SessionCard extends StatelessWidget {
  const SessionCard({super.key, required this.session, required this.row, required this.onTap, this.past = false});
  final Session session;
  final Map<String, dynamic> row;
  final VoidCallback onTap;
  final bool past;

  @override
  Widget build(BuildContext context) {
    final copy = session.copy;
    final start = asDate(row['startsAt']);
    final phase = asText(row['phase']);
    final live = phase == 'live';
    final lobby = phase == 'lobby';
    final title = firstMeta(row, const ['title', 'classroomTitle']);
    final attended = row['attended'] == true;
    final (tag, tagColor) = switch (phase) {
      'live' => (copy.pick('مباشر الآن', 'Live now'), ToviTokens.coral),
      'lobby' => (copy.pick('افتحت الغرفة', 'Room open'), ToviTokens.sun),
      'cancelled' => (copy.pick('ملغاة', 'Cancelled'), ToviTokens.muted),
      'ended' => attended ? (copy.pick('حضرت', 'Attended'), ToviTokens.mint) : (row['joined'] == true ? (copy.pick('حضور جزئي', 'Partial'), ToviTokens.sun) : (copy.pick('فاتتك', 'Missed'), ToviTokens.coral)),
      _ => ('', ToviTokens.violet),
    };
    return SoftPanel(
      onTap: phase == 'cancelled' ? null : onTap,
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Container(
          width: 58,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: live ? const LinearGradient(colors: [ToviTokens.coral, Color(0xFFFF9A6B)]) : null,
            color: live ? null : ToviTokens.violetSoft,
          ),
          child: start == null
              ? const SizedBox()
              : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('${start.day}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: live ? Colors.white : ToviTokens.violet)),
                  Text(shortDate(start, copy.arabic).split(' ').skip(1).join(' '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: live ? Colors.white : ToviTokens.violet)),
                ]),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
          const SizedBox(height: 4),
          Row(children: [
            HubFace(url: row['teacherPhotoUrl'], name: asText(row['teacherName']), size: 20),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                [asText(row['teacherName']), if (start != null) hourOf(start, copy.arabic), copy.pick('${asInt(row['durationMinutes'])} د', '${asInt(row['durationMinutes'])} min')].where((x) => x.isNotEmpty).join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: ToviTokens.muted, fontSize: 12.5),
              ),
            ),
          ]),
          if (past && phase == 'ended') ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.timer_outlined, size: 14, color: ToviTokens.muted),
              const SizedBox(width: 3),
              Text(copy.pick('${asInt(row['minutes'])} د', '${asInt(row['minutes'])} min'), style: const TextStyle(fontSize: 12, color: ToviTokens.muted)),
              const SizedBox(width: 10),
              if (asInt(row['xp']) > 0) ...[
                const Icon(Icons.bolt_rounded, size: 14, color: Color(0xFFE0A100)),
                Text('+${asInt(row['xp'])}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFB07E00))),
                const SizedBox(width: 10),
              ],
              if (asInt(row['replays']) > 0) ...[
                const Icon(Icons.play_circle_rounded, size: 14, color: ToviTokens.violet),
                const SizedBox(width: 3),
                Text(copy.pick('إعادة', 'Replay'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: ToviTokens.violet)),
              ],
            ]),
          ],
        ])),
        if (tag.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: tagColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(99)),
            child: Text(tag, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: tagColor == ToviTokens.sun ? const Color(0xFFB07E00) : tagColor)),
          )
        else if (!past)
          Icon(lobby ? Icons.meeting_room_rounded : Icons.notifications_active_outlined, color: ToviTokens.violet),
      ]),
    );
  }
}

class ReplayCard extends StatelessWidget {
  const ReplayCard({super.key, required this.session, required this.row, required this.onRecap});
  final Session session;
  final Map<String, dynamic> row;
  final VoidCallback onRecap;

  @override
  Widget build(BuildContext context) {
    final copy = session.copy;
    final url = asText(row['url']);
    final when = asDate(row['startsAt']) ?? asDate(row['createdAt']);
    final title = asText(row['title']);
    return Material(
      color: ToviTokens.surface,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: url.isEmpty ? onRecap : () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AspectRatio(
            aspectRatio: 16 / 7,
            child: Stack(fit: StackFit.expand, children: [
              HubPhoto(url: null, seed: title, radius: 0, icon: Icons.videocam_rounded),
              Center(
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: ToviTokens.floating),
                  child: const Icon(Icons.play_arrow_rounded, color: ToviTokens.violet, size: 36),
                ),
              ),
              if (asInt(row['durationMinutes']) > 0)
                PositionedDirectional(
                  end: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xB317142B), borderRadius: BorderRadius.circular(8)),
                    child: Text(copy.pick('${asInt(row['durationMinutes'])} د', '${asInt(row['durationMinutes'])} min'), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              HubFace(url: row['teacherPhotoUrl'], name: asText(row['teacherName']), size: 34),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text([asText(row['teacherName']), if (when != null) shortDate(when, copy.arabic)].where((x) => x.isNotEmpty).join(' · '), style: const TextStyle(color: ToviTokens.muted, fontSize: 12.5)),
              ])),
              TextButton(onPressed: onRecap, child: Text(copy.pick('الملخص', 'Recap'))),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// The student's own recap of a session: attendance, XP, questions, polls and the replay.
class RecapPage extends StatefulWidget {
  const RecapPage({super.key, required this.session, required this.sessionId});
  final Session session;
  final String sessionId;
  @override
  State<RecapPage> createState() => _RecapPageState();
}

class _RecapPageState extends State<RecapPage> {
  Map<String, dynamic>? data;
  String error = '';

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      final value = asMap(await widget.session.api.get('/api/student/sessions/${widget.sessionId}/summary'));
      if (mounted) setState(() { data = value; error = ''; });
    } catch (reason) {
      if (mounted) setState(() => error = hubError(reason, widget.session));
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.session.copy;
    final info = asMap(data?['session']);
    final me = asMap(data?['me']);
    final attended = me['attended'] == true;
    final questions = asMaps(data?['questions']);
    final polls = asMaps(data?['polls']);
    final recordings = asMaps(data?['recordings']);
    final start = asDate(info['startsAt']);
    return HubScaffold(
      title: copy.pick('ملخص الحصة', 'Session recap'),
      body: data == null
          ? (error.isEmpty ? const Padding(padding: EdgeInsets.all(20), child: ListSkeleton(rows: 4, height: 100)) : ErrorNote(text: error, onRetry: load))
          : RefreshIndicator(
              color: ToviTokens.violet,
              onRefresh: load,
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 28), children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: LinearGradient(colors: attended ? const [ToviTokens.mint, Color(0xFF3D8BFF)] : const [ToviTokens.violet, Color(0xFF8E6BFF)], begin: AlignmentDirectional.topStart, end: AlignmentDirectional.bottomEnd),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      HubFace(url: info['teacherPhotoUrl'], name: asText(info['teacherName']), size: 44),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(firstMeta(info, const ['title', 'classroomTitle']), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                        Text([asText(info['teacherName']), if (start != null) '${shortDate(start, copy.arabic)} · ${hourOf(start, copy.arabic)}'].where((x) => x.isNotEmpty).join(' · '), style: const TextStyle(color: Colors.white70)),
                      ])),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      _Big(value: '${asInt(me['minutes'])}', label: copy.pick('دقيقة حضور', 'minutes')),
                      _Big(value: attended ? '✓' : '—', label: attended ? copy.pick('حضور مكتمل', 'Attended') : copy.pick('يحتاج ${asInt(me['attendanceMinutes'])} د', 'Needs ${asInt(me['attendanceMinutes'])} min')),
                      _Big(value: '+${asInt(me['xp'])}', label: copy.pick('نقطة', 'XP')),
                      _Big(value: '${asInt(data?['classmates'])}', label: copy.pick('زميل حضر', 'classmates')),
                    ]),
                  ]),
                ),
                SectionHead(title: copy.pick('الإعادة', 'Replay')),
                if (recordings.isEmpty)
                  SoftPanel(color: ToviTokens.sunken, child: Row(children: [
                    const Icon(Icons.videocam_off_outlined, color: ToviTokens.muted),
                    const SizedBox(width: 10),
                    Expanded(child: Text(copy.pick('ما توفرت إعادة لهاي الحصة.', 'No replay is available for this session.'), style: const TextStyle(color: ToviTokens.muted))),
                  ]))
                else
                  for (final r in recordings)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SoftPanel(
                        onTap: asText(r['url']).isEmpty ? null : () => launchUrl(Uri.parse(asText(r['url'])), mode: LaunchMode.externalApplication),
                        child: Row(children: [
                          const IconOrb(icon: Icons.play_arrow_rounded, color: ToviTokens.violet),
                          const SizedBox(width: 12),
                          Expanded(child: Text(copy.pick('شاهد الإعادة', 'Watch the replay'), style: const TextStyle(fontWeight: FontWeight.w800))),
                          const Icon(Icons.open_in_new_rounded, color: ToviTokens.faint, size: 18),
                        ]),
                      ),
                    ),
                SectionHead(title: copy.pick('مشاركتك', 'Your part')),
                Row(children: [
                  Expanded(child: StatPill(color: ToviTokens.violet, icon: Icons.help_rounded, label: copy.pick('أسئلتك', 'Asked'), value: '${asInt(me['asked'])}')),
                  const SizedBox(width: 10),
                  Expanded(child: StatPill(color: ToviTokens.mint, icon: Icons.mark_chat_read_rounded, label: copy.pick('انجاوبت', 'Answered'), value: '${asInt(me['answered'])}')),
                  const SizedBox(width: 10),
                  Expanded(child: StatPill(color: ToviTokens.coral, icon: Icons.poll_rounded, label: copy.pick('تصويتاتك', 'Votes'), value: '${asInt(me['pollsVoted'])}')),
                ]),
                if (questions.isNotEmpty) ...[
                  SectionHead(title: copy.pick('الأسئلة', 'Questions')),
                  for (final q in questions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SoftPanel(
                        color: q['mine'] == true ? ToviTokens.violetSoft : ToviTokens.surface,
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(q['answered'] == true ? Icons.check_circle_rounded : Icons.help_outline_rounded, color: q['answered'] == true ? ToviTokens.mint : ToviTokens.muted, size: 20),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(asText(q['text']), style: const TextStyle(fontWeight: FontWeight.w600, height: 1.45)),
                            const SizedBox(height: 2),
                            Text('${q['mine'] == true ? copy.pick('سؤالك', 'You') : asText(q['authorName'])} · ${asInt(q['votes'])} ▲', style: const TextStyle(color: ToviTokens.muted, fontSize: 12)),
                          ])),
                        ]),
                      ),
                    ),
                ],
                if (polls.isNotEmpty) ...[
                  SectionHead(title: copy.pick('التصويتات', 'Polls')),
                  for (final p in polls) Padding(padding: const EdgeInsets.only(bottom: 10), child: _PollResult(row: p, copy: copy)),
                ],
              ]),
            ),
    );
  }
}

class _Big extends StatelessWidget {
  const _Big({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          Text(label, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
        ]),
      );
}

class _PollResult extends StatelessWidget {
  const _PollResult({required this.row, required this.copy});
  final Map<String, dynamic> row;
  final dynamic copy;

  @override
  Widget build(BuildContext context) {
    final options = asMaps(row['options']);
    final total = asInt(row['total']);
    final mine = row['myOption'];
    return SoftPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(asText(row['question']), style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        for (var i = 0; i < options.length; i++) ...[
          Row(children: [
            Expanded(child: Text(asText(options[i]['text']), style: TextStyle(fontWeight: mine == i ? FontWeight.w800 : FontWeight.w500, color: mine == i ? ToviTokens.violet : ToviTokens.ink))),
            Text('${asInt(options[i]['votes'])}', style: const TextStyle(color: ToviTokens.muted, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: total == 0 ? 0 : asInt(options[i]['votes']) / total, minHeight: 8, backgroundColor: ToviTokens.sunken, color: mine == i ? ToviTokens.violet : ToviTokens.faint),
          ),
          const SizedBox(height: 8),
        ],
      ]),
    );
  }
}
