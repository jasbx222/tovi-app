import 'package:livekit_client/livekit_client.dart' hide Session;
import 'package:material_ui/material_ui.dart';

import 'copy.dart';
import 'ui.dart';

const reactionGlyphs = {'clap': '👏', 'heart': '❤️', 'idea': '💡', 'laugh': '😄', 'wow': '😮'};

class LiveLine {
  const LiveLine(this.name, this.text, {this.host = false, this.mine = false});
  final String name;
  final String text;
  final bool host;
  final bool mine;
}

class FloatingReaction {
  const FloatingReaction(this.id, this.kind);
  final int id;
  final String kind;
}

String twoDigits(int value) => value.toString().padLeft(2, '0');

String countdown(Duration left) {
  if (left.isNegative) return '00:00';
  final hours = left.inHours;
  final minutes = left.inMinutes % 60;
  final seconds = left.inSeconds % 60;
  return hours > 0 ? '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}' : '${twoDigits(minutes)}:${twoDigits(seconds)}';
}

String clockOf(DateTime when, bool arabic) {
  final hour = when.hour % 12 == 0 ? 12 : when.hour % 12;
  final suffix = when.hour < 12 ? (arabic ? 'ص' : 'AM') : (arabic ? 'م' : 'PM');
  return '$hour:${twoDigits(when.minute)} $suffix';
}

/// Solid hero block used on the live screens.
class LiveHero extends StatelessWidget {
  const LiveHero({super.key, required this.color, required this.icon, required this.eyebrow, required this.title, this.subtitle = '', this.child});
  final Color color;
  final IconData icon;
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(ToviTokens.radiusLg), boxShadow: ToviTokens.floating),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(ToviTokens.radiusSm)),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(eyebrow, style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, height: 1.3)),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.82))),
        ],
        if (child != null) ...[const SizedBox(height: 18), child!],
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text, this.color = Tovi.muted});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(color: Tovi.ink, height: 1.45))),
      ]),
    );
  }
}

/// Countdown before the waiting room opens, and the waiting room itself.
class LiveWaiting extends StatelessWidget {
  const LiveWaiting({
    super.key,
    required this.copy,
    required this.session,
    required this.target,
    required this.now,
    required this.lobby,
    required this.present,
    required this.hostPresent,
    required this.lobbyMinutes,
  });
  final Copy copy;
  final Map<String, dynamic> session;
  final DateTime? target;
  final DateTime now;
  final bool lobby;
  final int present;
  final bool hostPresent;
  final int lobbyMinutes;

  @override
  Widget build(BuildContext context) {
    final starts = asDate(session['startsAt']);
    final left = target == null ? Duration.zero : target!.difference(now);
    final title = firstMeta(session, const ['title', 'classroomTitle']);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        LiveHero(
          color: lobby ? ToviTokens.violet : ToviTokens.ink,
          icon: lobby ? Icons.meeting_room_outlined : Icons.schedule_rounded,
          eyebrow: lobby ? copy.pick('غرفة الانتظار', 'Waiting room') : copy.pick('الحصة الجاية', 'Upcoming session'),
          title: title.isEmpty ? copy.meeting : title,
          subtitle: [asText(session['teacherName']), if (asText(session['title']).isNotEmpty) asText(session['classroomTitle'])].where((t) => t.isNotEmpty).join(' · '),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(lobby ? copy.pick('يبدأ البث بعد', 'Live starts in') : copy.pick('تفتح الغرفة بعد', 'Room opens in'), style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                const SizedBox(height: 2),
                Text(countdown(left), textDirection: TextDirection.ltr, style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w700, height: 1.1, fontFeatures: [FontFeature.tabularFigures()])),
              ]),
            ),
            if (starts != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(99)),
                child: Text(clockOf(starts, copy.arabic), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        SoftPanel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (lobby) ...[
              _InfoRow(
                icon: hostPresent ? Icons.check_circle_rounded : Icons.hourglass_empty_rounded,
                color: hostPresent ? ToviTokens.mint : ToviTokens.faint,
                text: hostPresent ? copy.pick('المعلم موجود ويجهّز البث', 'The teacher is here and getting ready') : copy.pick('المعلم بعده ما دخل', 'The teacher has not joined yet'),
              ),
              _InfoRow(icon: Icons.groups_2_outlined, color: Tovi.violet, text: copy.pick('$present طالب بالانتظار', '$present students waiting')),
            ] else
              _InfoRow(icon: Icons.meeting_room_outlined, color: Tovi.violet, text: copy.pick('غرفة الانتظار تفتح قبل البداية بـ $lobbyMinutes دقائق.', 'The waiting room opens $lobbyMinutes minutes before the start.')),
            _InfoRow(icon: Icons.timer_outlined, color: Tovi.violet, text: copy.pick('المدة ${asInt(session['durationMinutes'])} دقيقة', '${asInt(session['durationMinutes'])} minutes')),
          ]),
        ),
        const SizedBox(height: 16),
        Text(copy.pick('قبل ما يبدأ', 'Before it starts'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _InfoRow(icon: Icons.headphones_outlined, text: copy.pick('استخدم سماعات حتى يكون الصوت أوضح.', 'Use headphones for clearer audio.')),
        _InfoRow(icon: Icons.wifi_rounded, text: copy.pick('إذا الإنترنت ضعيف تكدر تحوّل للصوت فقط داخل البث.', 'On a weak connection you can switch to audio only.')),
        _InfoRow(icon: Icons.how_to_reg_outlined, text: copy.pick('يُحسب حضورك إذا بقيت نص وقت الحصة أو أكثر.', 'You are marked present after half of the session.')),
      ],
    );
  }
}

/// Shown while the session is live and the student has not entered the room yet.
class LiveReady extends StatelessWidget {
  const LiveReady({super.key, required this.copy, required this.session, required this.me, required this.busy, required this.onEnter, required this.present});
  final Copy copy;
  final Map<String, dynamic> session;
  final Map<String, dynamic>? me;
  final bool busy;
  final VoidCallback onEnter;
  final int present;

  @override
  Widget build(BuildContext context) {
    final title = firstMeta(session, const ['title', 'classroomTitle']);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        LiveHero(
          color: ToviTokens.coral,
          icon: Icons.sensors_rounded,
          eyebrow: copy.pick('مباشر الآن', 'Live now'),
          title: title.isEmpty ? copy.meeting : title,
          subtitle: asText(session['teacherName']),
          child: Text(copy.pick('$present طالب داخل الحصة', '$present students in the session'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 16),
        AttendanceStrip(copy: copy, me: me, light: true),
        const SizedBox(height: 16),
        ToviButton(label: copy.pick('ادخل البث', 'Join the live'), busy: busy, color: Tovi.violet, onPressed: onEnter),
      ],
    );
  }
}

class LiveTopBar extends StatelessWidget {
  const LiveTopBar({super.key, required this.copy, required this.title, required this.teacher, required this.elapsed, required this.scheduledMinutes, required this.quality, required this.viewers, required this.onLeave});
  final Copy copy;
  final String title;
  final String teacher;
  final int elapsed;
  final int scheduledMinutes;
  final ConnectionQuality quality;
  final int viewers;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final bars = switch (quality) {
      ConnectionQuality.excellent => Icons.signal_cellular_alt_rounded,
      ConnectionQuality.good => Icons.signal_cellular_alt_2_bar_rounded,
      ConnectionQuality.poor => Icons.signal_cellular_alt_1_bar_rounded,
      ConnectionQuality.lost => Icons.signal_cellular_connected_no_internet_0_bar_rounded,
      _ => Icons.signal_cellular_alt_rounded,
    };
    final barsColor = quality == ConnectionQuality.poor || quality == ConnectionQuality.lost ? ToviTokens.coral : Colors.white70;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 8),
      child: Row(children: [
        CircleButton(icon: Icons.arrow_back_ios_new_rounded, tooltip: copy.leave, onPressed: onLeave, background: ToviTokens.nightRaised, foreground: Colors.white),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            Text('${teacher.isEmpty ? copy.meeting : teacher} · $viewers ${copy.pick('مشارك', 'in room')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ]),
        ),
        Icon(bars, size: 18, color: barsColor),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: ToviTokens.coral, borderRadius: BorderRadius.circular(99)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text('${twoDigits(elapsed ~/ 60)}:${twoDigits(elapsed % 60)}', textDirection: TextDirection.ltr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12, fontFeatures: [FontFeature.tabularFigures()])),
          ]),
        ),
      ]),
    );
  }
}

class LiveNotice extends StatelessWidget {
  const LiveNotice({super.key, required this.icon, required this.color, required this.text, this.action, this.onAction, this.onClose});
  final IconData icon;
  final Color color;
  final String text;
  final String? action;
  final VoidCallback? onAction;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 6, 8),
      decoration: BoxDecoration(color: ToviTokens.nightRaised, borderRadius: BorderRadius.circular(ToviTokens.radiusSm)),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4))),
        if (action != null) TextButton(onPressed: onAction, style: TextButton.styleFrom(foregroundColor: color), child: Text(action!)),
        if (onClose != null) IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18)),
      ]),
    );
  }
}

class LiveTile extends StatelessWidget {
  const LiveTile({super.key, required this.name, required this.quality, required this.audioOnly, this.track, this.large = false, this.speaking = false, this.muted = false, this.mine = false, this.icon});

  factory LiveTile.of(Participant person, {required bool audioOnly, bool large = false, bool mine = false}) {
    final screen = person.videoTrackPublications.where((p) => p.source == TrackSource.screenShareVideo && p.track is VideoTrack).map((p) => p.track as VideoTrack);
    final camera = person.videoTrackPublications.where((p) => p.track is VideoTrack && !p.muted).map((p) => p.track as VideoTrack);
    final track = screen.isNotEmpty ? screen.first : (camera.isNotEmpty ? camera.first : null);
    return LiveTile(
      name: person.name.isEmpty ? person.identity : person.name,
      quality: person.connectionQuality,
      audioOnly: audioOnly && !mine,
      track: track,
      large: large,
      speaking: person.isSpeaking,
      muted: !person.isMicrophoneEnabled(),
      mine: mine,
    );
  }

  final String name;
  final ConnectionQuality quality;
  final bool audioOnly;
  final VideoTrack? track;
  final bool large;
  final bool speaking;
  final bool muted;
  final bool mine;

  /// Shown instead of the initial when the tile is a placeholder, such as an empty stage.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'T' : name.trim().substring(0, 1);
    return AnimatedContainer(
      duration: ToviTokens.fast,
      decoration: BoxDecoration(
        color: ToviTokens.nightRaised,
        borderRadius: BorderRadius.circular(large ? ToviTokens.radiusLg : ToviTokens.radiusSm),
        boxShadow: speaking ? const [BoxShadow(color: Color(0x666A4CFF), blurRadius: 18)] : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(fit: StackFit.expand, children: [
        if (track != null && !audioOnly)
          VideoTrackRenderer(track!, fit: large ? VideoViewFit.contain : VideoViewFit.cover)
        else
          Center(
            child: CircleAvatar(
              radius: large ? 38 : 20,
              backgroundColor: Tovi.violet,
              child: icon != null
                  ? Icon(icon, color: Colors.white, size: large ? 32 : 18)
                  : Text(initial, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: large ? 28 : 16)),
            ),
          ),
        PositionedDirectional(
          start: 8,
          bottom: 8,
          end: 8,
          child: Row(children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (muted) const Padding(padding: EdgeInsetsDirectional.only(end: 4), child: Icon(Icons.mic_off_rounded, size: 12, color: Colors.white70)),
                  Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontSize: large ? 13 : 11, fontWeight: FontWeight.w600))),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Reactions floating up from the corner, kept short and subtle.
class ReactionStream extends StatelessWidget {
  const ReactionStream({super.key, required this.items});
  final List<FloatingReaction> items;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      width: 56,
      height: 220,
      child: Stack(children: [
        for (final item in items)
          TweenAnimationBuilder<double>(
            key: ValueKey(item.id),
            tween: Tween(begin: 0, end: 1),
            duration: still ? const Duration(milliseconds: 1) : const Duration(milliseconds: 1600),
            curve: Curves.easeOutCubic,
            builder: (context, t, child) => Positioned(
              bottom: 180 * t,
              left: 12 + 10 * (item.id % 3 - 1) * t,
              child: Opacity(opacity: (1 - t).clamp(0, 1), child: child),
            ),
            child: Text(reactionGlyphs[item.kind] ?? '', style: const TextStyle(fontSize: 28)),
          ),
      ]),
    );
  }
}

class ReactionBar extends StatelessWidget {
  const ReactionBar({super.key, required this.kinds, required this.onReact});
  final List<String> kinds;
  final ValueChanged<String> onReact;

  @override
  Widget build(BuildContext context) {
    if (kinds.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (final kind in kinds)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Material(
              color: ToviTokens.nightRaised,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => onReact(kind),
                child: SizedBox(width: 44, height: 44, child: Center(child: Text(reactionGlyphs[kind] ?? kind, style: const TextStyle(fontSize: 20)))),
              ),
            ),
          ),
      ]),
    );
  }
}

class AttendanceStrip extends StatelessWidget {
  const AttendanceStrip({super.key, required this.copy, required this.me, this.light = false});
  final Copy copy;
  final Map<String, dynamic>? me;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final data = me;
    if (data == null) return const SizedBox.shrink();
    final seconds = asInt(data['liveSeconds']);
    final needed = asInt(data['attendanceSeconds']);
    final done = data['attended'] == true;
    final value = needed == 0 ? 0.0 : (seconds / needed).clamp(0.0, 1.0);
    final ink = light ? Tovi.ink : Colors.white;
    final soft = light ? Tovi.muted : Colors.white60;
    final text = done
        ? copy.pick('حضورك مسجّل ✓', 'You are marked present ✓')
        : copy.pick('حضورك ${seconds ~/ 60} من ${needed ~/ 60} دقيقة', 'Attendance ${seconds ~/ 60} of ${needed ~/ 60} min');
    final bar = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(done ? Icons.how_to_reg_rounded : Icons.timelapse_rounded, size: 16, color: done ? ToviTokens.mint : (light ? Tovi.violet : ToviTokens.sun)),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: TextStyle(color: done ? ToviTokens.mint : ink, fontSize: 12.5, fontWeight: FontWeight.w600))),
        if (!done) Text('${(value * 100).round()}%', style: TextStyle(color: soft, fontSize: 12)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(value: value, minHeight: 6, color: done ? ToviTokens.mint : (light ? Tovi.violet : ToviTokens.sun), backgroundColor: light ? ToviTokens.sunken : ToviTokens.nightRaised),
      ),
    ]);
    if (light) return SoftPanel(child: bar);
    return Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 0), child: bar);
  }
}

class LiveControl extends StatelessWidget {
  const LiveControl({super.key, required this.icon, required this.label, required this.onTap, this.active = false, this.danger = false, this.badge = 0});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool danger;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final color = danger ? ToviTokens.danger : (active ? Tovi.violet : ToviTokens.nightRaised);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 62,
          child: Column(children: [
            Badge(
              isLabelVisible: badge > 0,
              backgroundColor: ToviTokens.sun,
              textColor: ToviTokens.ink,
              label: Text('$badge'),
              child: AnimatedContainer(
                duration: ToviTokens.fast,
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
            ),
            const SizedBox(height: 4),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ]),
        ),
      ),
    );
  }
}

/// Bottom sheet with chat, questions and polls.
class LivePanel extends StatefulWidget {
  const LivePanel({
    super.key,
    required this.copy,
    required this.initial,
    required this.messages,
    required this.questions,
    required this.polls,
    required this.composer,
    required this.canChat,
    required this.onSend,
    required this.onAsk,
    required this.onVote,
    required this.onAnswer,
  });
  final Copy copy;
  final int initial;
  final List<LiveLine> messages;
  final List<Map<String, dynamic>> questions;
  final List<Map<String, dynamic>> polls;
  final TextEditingController composer;
  final bool canChat;
  final Future<void> Function() onSend;
  final Future<String?> Function(String text) onAsk;
  final Future<void> Function(String id) onVote;
  final Future<void> Function(String id, int option) onAnswer;

  @override
  State<LivePanel> createState() => _LivePanelState();
}

class _LivePanelState extends State<LivePanel> {
  late var tab = widget.initial;
  final asking = TextEditingController();
  String problem = '';
  var sending = false;

  @override
  void dispose() {
    asking.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.copy;
    final height = MediaQuery.sizeOf(context).height * 0.72;
    final labels = [copy.pick('الدردشة', 'Chat'), copy.pick('الأسئلة', 'Questions'), copy.pick('التصويت', 'Polls')];
    return SizedBox(
      height: height,
      child: Column(children: [
        const SheetHandle(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: ToviTokens.sunken, borderRadius: BorderRadius.circular(99)),
            child: Row(children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => tab = i),
                    child: AnimatedContainer(
                      duration: ToviTokens.fast,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: tab == i ? ToviTokens.surface : Colors.transparent, borderRadius: BorderRadius.circular(99), boxShadow: tab == i ? ToviTokens.raised : null),
                      child: Text(labels[i], style: TextStyle(fontWeight: FontWeight.w700, color: tab == i ? Tovi.ink : Tovi.muted)),
                    ),
                  ),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: [chat, questions, polls][tab]()),
      ]),
    );
  }

  Widget composerRow({required TextEditingController controller, required String hint, required Future<void> Function() onSubmit, bool enabled = true}) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              maxLength: 300,
              minLines: 1,
              maxLines: 3,
              decoration: toviField('', hint: hint).copyWith(counterText: ''),
              onSubmitted: (_) => onSubmit(),
            ),
          ),
          const SizedBox(width: 6),
          IconButton.filled(
            onPressed: enabled && !sending ? onSubmit : null,
            style: IconButton.styleFrom(backgroundColor: Tovi.violet, fixedSize: const Size(48, 48)),
            icon: const Icon(Icons.send_rounded, color: Colors.white),
          ),
        ]),
      ),
    );
  }

  Widget chat() {
    final copy = widget.copy;
    return Column(children: [
      Expanded(
        child: widget.messages.isEmpty
            ? EmptyNote(icon: Icons.chat_bubble_outline_rounded, text: copy.pick('ابدأ الدردشة مع زملائك.', 'Start chatting with your classmates.'))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: widget.messages.length,
                itemBuilder: (_, i) {
                  final line = widget.messages[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (line.name.isNotEmpty)
                        Text(line.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: line.host ? Tovi.violet : Tovi.muted)),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: line.host ? ToviTokens.violetSoft : ToviTokens.sunken, borderRadius: BorderRadius.circular(14)),
                        child: Text(line.text, style: const TextStyle(height: 1.45)),
                      ),
                    ]),
                  );
                },
              ),
      ),
      composerRow(
        controller: widget.composer,
        hint: widget.canChat ? copy.pick('اكتب رسالة', 'Write a message') : copy.pick('الدردشة غير متاحة', 'Chat is unavailable'),
        enabled: widget.canChat,
        onSubmit: () async {
          await widget.onSend();
          if (mounted) setState(() {});
        },
      ),
    ]);
  }

  Widget questions() {
    final copy = widget.copy;
    final rows = [...widget.questions]..sort((a, b) {
        final answered = (a['answered'] == true ? 1 : 0) - (b['answered'] == true ? 1 : 0);
        return answered != 0 ? answered : asInt(b['votes']) - asInt(a['votes']);
      });
    return Column(children: [
      Expanded(
        child: rows.isEmpty
            ? EmptyNote(icon: Icons.help_outline_rounded, text: copy.pick('اسأل المعلم، وزملاءك يكدرون يرفعون سؤالك.', 'Ask the teacher; classmates can upvote your question.'))
            : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: rows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final row = rows[i];
                  final voted = row['voted'] == true;
                  final mine = row['mine'] == true;
                  final answered = row['answered'] == true;
                  return Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                    decoration: BoxDecoration(color: answered ? ToviTokens.mintSoft : ToviTokens.sunken, borderRadius: BorderRadius.circular(ToviTokens.radiusSm)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(asText(row['text']), style: const TextStyle(fontWeight: FontWeight.w600, height: 1.45)),
                          const SizedBox(height: 4),
                          Text(
                            [mine ? copy.pick('سؤالك', 'Yours') : asText(row['authorName']), if (answered) copy.pick('تمت الإجابة', 'Answered')].join(' · '),
                            style: TextStyle(color: answered ? ToviTokens.mint : Tovi.muted, fontSize: 12),
                          ),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: mine || answered ? null : () => widget.onVote(asText(row['id'])),
                        style: TextButton.styleFrom(foregroundColor: voted ? Tovi.violet : Tovi.muted, backgroundColor: voted ? ToviTokens.violetSoft : ToviTokens.surface, shape: const StadiumBorder()),
                        icon: Icon(voted ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined, size: 16),
                        label: Text('${asInt(row['votes'])}'),
                      ),
                    ]),
                  );
                },
              ),
      ),
      if (problem.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(problem, style: const TextStyle(color: Tovi.danger))),
      composerRow(
        controller: asking,
        hint: copy.pick('اكتب سؤالك للمعلم', 'Ask the teacher'),
        onSubmit: () async {
          final text = asking.text.trim();
          if (text.isEmpty) return;
          setState(() => sending = true);
          final result = await widget.onAsk(text);
          if (!mounted) return;
          setState(() {
            sending = false;
            problem = result ?? '';
            if (result == null) asking.clear();
          });
        },
      ),
    ]);
  }

  Widget polls() {
    final copy = widget.copy;
    final rows = widget.polls;
    if (rows.isEmpty) return EmptyNote(icon: Icons.poll_outlined, text: copy.pick('ماكو تصويت هسه. من يطرح المعلم سؤال يطلع هنا.', 'No polls yet. They appear here when the teacher starts one.'));
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final poll = rows[i];
        final open = poll['open'] == true;
        final mine = poll['myOption'];
        final total = asInt(poll['total']);
        final reveal = mine != null || !open;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: ToviTokens.surface, borderRadius: BorderRadius.circular(ToviTokens.radiusMd), boxShadow: ToviTokens.raised),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: open ? ToviTokens.sunSoft : ToviTokens.sunken, borderRadius: BorderRadius.circular(99)),
                child: Text(open ? copy.pick('مفتوح', 'Open') : copy.pick('مغلق', 'Closed'), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: open ? const Color(0xFF9A6A00) : Tovi.muted)),
              ),
              const Spacer(),
              Text(copy.pick('$total صوت', '$total votes'), style: const TextStyle(color: Tovi.muted, fontSize: 12)),
            ]),
            const SizedBox(height: 10),
            Text(asText(poll['question']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, height: 1.4)),
            const SizedBox(height: 10),
            for (final option in asMaps(poll['options']))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PollOption(
                  text: asText(option['text']),
                  share: total == 0 ? 0 : asInt(option['votes']) / total,
                  reveal: reveal,
                  chosen: mine != null && asInt(mine) == asInt(option['index']),
                  onTap: open && mine == null ? () => widget.onAnswer(asText(poll['id']), asInt(option['index'])) : null,
                ),
              ),
          ]),
        );
      },
    );
  }
}

class _PollOption extends StatelessWidget {
  const _PollOption({required this.text, required this.share, required this.reveal, required this.chosen, required this.onTap});
  final String text;
  final double share;
  final bool reveal;
  final bool chosen;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ToviTokens.sunken,
      borderRadius: BorderRadius.circular(ToviTokens.radiusSm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(children: [
          if (reveal)
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: share.clamp(0.0, 1.0),
                child: ColoredBox(color: chosen ? ToviTokens.violet.withValues(alpha: 0.22) : ToviTokens.violet.withValues(alpha: 0.10)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              if (chosen) const Padding(padding: EdgeInsetsDirectional.only(end: 8), child: Icon(Icons.check_circle_rounded, size: 18, color: Tovi.violet)),
              Expanded(child: Text(text, style: TextStyle(fontWeight: chosen ? FontWeight.w700 : FontWeight.w500))),
              if (reveal) Text('${(share * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w700, color: ToviTokens.inkSoft)),
            ]),
          ),
        ]),
      ),
    );
  }
}
