import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:livekit_client/livekit_client.dart' hide Session;
import 'package:material_ui/material_ui.dart' hide ConnectionState;
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'copy.dart';
import 'live_parts.dart';
import 'session.dart';
import 'student_rules.dart';
import 'ui.dart';

/// Entry to a live session: shows the countdown, the waiting room, the live
/// room and the end summary depending on the phase reported by the server.
class MeetingPage extends StatefulWidget {
  const MeetingPage({super.key, required this.session, required this.sessionId});
  final Session session;
  final String sessionId;

  @override
  State<MeetingPage> createState() => _MeetingPageState();
}

class _MeetingPageState extends State<MeetingPage> {
  Map<String, dynamic>? state;
  Map<String, dynamic>? me;
  String error = '';
  Duration skew = Duration.zero;
  Timer? ticker;
  Timer? beat;
  Timer? refresh;
  var earnedXp = 0;
  var entering = false;
  var counted = false;

  String get base => '/api/student/sessions/${widget.sessionId}';
  Copy get copy => widget.session.copy;
  String get phase => asText(state?['phase']);
  DateTime get now => DateTime.now().add(skew);

  @override
  void initState() {
    super.initState();
    load();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  @override
  void dispose() {
    ticker?.cancel();
    beat?.cancel();
    refresh?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final data = asMap(await widget.session.api.get('$base/live'));
      final server = asDate(data['serverNow']);
      if (!mounted) return;
      setState(() {
        state = data;
        me = data['me'] == null ? me : asMap(data['me']);
        if (server != null) skew = server.difference(DateTime.now());
        error = '';
      });
      schedule();
    } on ApiException catch (reason) {
      if (mounted) setState(() => error = studentMessage(reason.code, reason.message, copy.arabic));
    } catch (_) {
      if (mounted) setState(() => error = copy.pick('تعذّر تحميل الحصة. تحقق من الاتصال.', 'Could not load the session. Check your connection.'));
    }
  }

  String scheduledFor = '';

  void schedule() {
    if (scheduledFor == phase) return;
    scheduledFor = phase;
    beat?.cancel();
    refresh?.cancel();
    if (phase == 'lobby' || phase == 'live') {
      heartbeat();
      beat = Timer.periodic(const Duration(seconds: 30), (_) => heartbeat());
    }
    if (phase == 'lobby' || phase == 'upcoming') {
      refresh = Timer.periodic(const Duration(seconds: 15), (_) => load());
    }
  }

  void tick() {
    if (!mounted || state == null) return;
    final session = asMap(state!['session']);
    final starts = asDate(session['startsAt']);
    final opens = asDate(state!['opensAt']);
    if (phase == 'upcoming' && opens != null && !now.isBefore(opens)) load();
    if (phase == 'lobby' && starts != null && !now.isBefore(starts)) load();
    setState(() {});
  }

  Future<void> heartbeat() async {
    try {
      final result = asMap(await widget.session.api.post('$base/presence'));
      if (!mounted) return;
      final xp = asInt(result['xp']);
      setState(() {
        me = result;
        if (xp > 0) earnedXp += xp;
      });
      if (!counted) {
        counted = true;
        unawaited(load());
      }
      if (xp > 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(copy.pick('سُجّل حضورك · +$xp نقطة', 'Attendance recorded · +$xp XP'))));
      }
    } on ApiException catch (reason) {
      if (reason.code == 'outside_window' || reason.code == 'session_dead') load();
    } catch (_) {}
  }

  Future<void> enter() async {
    setState(() => entering = true);
    final ended = await Navigator.push<bool>(
      context,
      toviRoute(LiveRoomPage(session: widget.session, sessionId: widget.sessionId, state: state ?? const {}, me: me, onPresence: (value, xp) {
        me = value;
        earnedXp += xp;
      })),
    );
    if (!mounted) return;
    setState(() => entering = false);
    if (ended == true) await load();
  }

  @override
  Widget build(BuildContext context) {
    final data = state;
    Widget body;
    if (data == null) {
      body = error.isEmpty ? const Center(child: CircularProgressIndicator(color: Tovi.violet)) : Padding(padding: const EdgeInsets.all(24), child: ErrorNote(text: error, onRetry: load));
    } else {
      final session = asMap(data['session']);
      final starts = asDate(session['startsAt']);
      final opens = asDate(data['opensAt']);
      switch (phase) {
        case 'upcoming':
          body = LiveWaiting(copy: copy, session: session, target: opens, now: now, lobby: false, present: asInt(data['present']), hostPresent: data['hostPresent'] == true, lobbyMinutes: asInt(data['lobbyMinutes']));
        case 'lobby':
          body = LiveWaiting(copy: copy, session: session, target: starts, now: now, lobby: true, present: asInt(data['present']), hostPresent: data['hostPresent'] == true, lobbyMinutes: asInt(data['lobbyMinutes']));
        case 'live':
          body = LiveReady(copy: copy, session: session, me: me, busy: entering, onEnter: enter, present: asInt(data['present']));
        case 'cancelled':
          body = Padding(padding: const EdgeInsets.all(24), child: EmptyNote(icon: Icons.event_busy_rounded, text: copy.pick('أُلغيت هذه الحصة.', 'This session was cancelled.')));
        default:
          body = LiveEnded(session: widget.session, base: base, copy: copy, info: session, me: me, earnedXp: earnedXp, recordingEnabled: data['recordingEnabled'] == true);
      }
    }
    return Scaffold(
      backgroundColor: Tovi.page,
      body: SafeArea(
        child: Column(children: [
          ToviHeader(title: copy.meeting, safe: false, onBack: () => Navigator.pop(context)),
          Expanded(child: RefreshIndicator(color: Tovi.violet, onRefresh: load, child: body)),
        ]),
      ),
    );
  }
}

/// The LiveKit room with reactions, questions, polls, chat and attendance.
class LiveRoomPage extends StatefulWidget {
  const LiveRoomPage({super.key, required this.session, required this.sessionId, required this.state, required this.me, required this.onPresence});
  final Session session;
  final String sessionId;
  final Map<String, dynamic> state;
  final Map<String, dynamic>? me;
  final void Function(Map<String, dynamic> me, int xp) onPresence;

  @override
  State<LiveRoomPage> createState() => _LiveRoomPageState();
}

class _LiveRoomPageState extends State<LiveRoomPage> {
  Room? room;
  EventsListener<RoomEvent>? listener;
  String error = '';
  String environment = '';
  String chatPath = '';
  String title = '';
  bool raised = false;
  bool leaving = false;
  bool audioOnly = false;
  final messages = <LiveLine>[];
  final announcements = <String>[];
  final hands = <String>[];
  final floating = <FloatingReaction>[];
  final composer = TextEditingController();
  List<Map<String, dynamic>> questions = [];
  List<Map<String, dynamic>> polls = [];
  Map<String, dynamic>? me;
  Timer? clock;
  Timer? beat;
  Timer? sync;
  var elapsed = 0;
  var scheduledMinutes = 0;
  var reactionSeq = 0;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? chatFeed;

  String get base => '/api/student/sessions/${widget.sessionId}';
  Copy get copy => widget.session.copy;
  List<String> get kinds => [for (final kind in (widget.state['reactions'] as List? ?? const [])) '$kind'];

  @override
  void initState() {
    super.initState();
    me = widget.me;
    final info = asMap(widget.state['session']);
    title = firstMeta(info, const ['title', 'classroomTitle']);
    final starts = asDate(info['startsAt']);
    if (starts != null) elapsed = DateTime.now().difference(starts).inSeconds.clamp(0, 1 << 30);
    connect();
  }

  Future<void> connect() async {
    try {
      final token = asMap(await widget.session.api.post('$base/token'));
      final chat = asMap(await widget.session.api.get('$base/chat'));
      environment = asText(chat['environment']);
      chatPath = asText(chat['path']);
      if (environment == 'production' && Session.buildEnvironment != 'production') {
        throw ApiException(403, 'environment_mismatch', 'This build cannot enter a production meeting.');
      }
      scheduledMinutes = asInt(token['durationMinutes']);
      if (asText(token['title']).isNotEmpty) title = asText(token['title']);
      final next = Room(roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true));
      listener = next.createListener()
        ..on<RoomDisconnectedEvent>((event) {
          if (leaving || !mounted) return;
          if (event.reason == DisconnectReason.participantRemoved || event.reason == DisconnectReason.roomDeleted) {
            leaving = true;
            Navigator.pop(context, true);
            return;
          }
          reconnect();
        })
        ..on<TrackSubscribedEvent>((_) => applyAudioOnly())
        ..on<DataReceivedEvent>(onData);
      await next.connect(asText(token['url']), asText(token['token']));
      next.addListener(() { if (mounted) setState(() {}); });
      clock?.cancel();
      clock = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() => elapsed += 1); });
      beat?.cancel();
      beat = Timer.periodic(const Duration(seconds: 30), (_) => heartbeat());
      sync?.cancel();
      sync = Timer.periodic(const Duration(seconds: 12), (_) => pull());
      if (mounted) setState(() { room = next; error = ''; });
      unawaited(heartbeat());
      unawaited(pull());
      await openFirestore();
    } on ApiException catch (reason) {
      if (mounted) setState(() => error = studentMessage(reason.code, reason.message, copy.arabic));
    } catch (_) {
      if (mounted) setState(() => error = copy.pick('تعذّر الاتصال بالبث. حاول مرة ثانية.', 'Could not reach the live room. Try again.'));
    }
  }

  void onData(DataReceivedEvent event) {
    Object? data;
    try {
      data = jsonDecode(utf8.decode(event.data));
    } catch (_) {
      return;
    }
    if (data is! Map || !mounted) return;
    final message = asMap(data);
    final from = event.participant;
    setState(() {
      switch (message['type']) {
        case 'announcement':
          announcements.insert(0, asText(message['text']));
        case 'chat':
          if (!chatAllowed) messages.add(LiveLine(asText(from?.name).isEmpty ? copy.pick('مشارك', 'Participant') : asText(from?.name), asText(message['text']), host: from?.identity.startsWith('teacher:') == true));
        case 'hand':
          final who = asText(message['from']);
          if (message['raised'] == true) {
            if (!hands.contains(who)) hands.add(who);
          } else {
            hands.remove(who);
          }
          if (who == room?.localParticipant?.identity && message['raised'] != true) raised = false;
        case 'reaction':
          addFloating(asText(message['kind']));
        case 'poll':
        case 'questions':
          pull();
      }
    });
  }

  void addFloating(String kind) {
    if (!kinds.contains(kind)) return;
    final item = FloatingReaction(reactionSeq++, kind);
    floating.add(item);
    if (floating.length > 12) floating.removeAt(0);
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => floating.remove(item));
    });
  }

  Future<void> reconnect() async {
    await room?.dispose();
    if (!mounted) return;
    setState(() => room = null);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) await connect();
  }

  Future<void> heartbeat() async {
    try {
      final result = asMap(await widget.session.api.post('$base/presence'));
      final xp = asInt(result['xp']);
      widget.onPresence(result, xp);
      if (!mounted) return;
      setState(() => me = result);
      if (xp > 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(copy.pick('سُجّل حضورك · +$xp نقطة', 'Attendance recorded · +$xp XP'))));
      }
    } on ApiException catch (reason) {
      if (reason.code == 'outside_window' || reason.code == 'session_dead') await finish();
    } catch (_) {}
  }

  Future<void> pull() async {
    try {
      final results = await Future.wait([widget.session.api.get('$base/questions'), widget.session.api.get('$base/polls')]);
      if (!mounted) return;
      setState(() {
        questions = asMaps(results[0]);
        polls = asMaps(results[1]);
      });
    } catch (_) {}
  }

  Future<void> finish() async {
    if (leaving) return;
    leaving = true;
    await room?.disconnect();
    if (mounted) Navigator.pop(context, true);
  }

  bool get chatAllowed => environment.isNotEmpty && environment == Session.buildEnvironment && chatPath == '$environment/meetings/${widget.sessionId}/messages';

  CollectionReference<Map<String, dynamic>>? get messagesCollection {
    if (!chatAllowed || Firebase.apps.isEmpty) return null;
    return FirebaseFirestore.instance.collection('environments').doc(environment).collection('meetings').doc(widget.sessionId).collection('messages');
  }

  Future<void> openFirestore() async {
    final query = messagesCollection?.orderBy('at').limitToLast(60);
    if (query == null) return;
    await chatFeed?.cancel();
    chatFeed = query.snapshots().listen((snapshot) {
      if (!mounted) return;
      setState(() {
        messages
          ..clear()
          ..addAll(snapshot.docs.map((doc) {
            final row = doc.data();
            return LiveLine(asText(row['name']), asText(row['text']), host: row['host'] == true);
          }));
      });
    });
  }

  Future<void> send(Map<String, Object?> payload) async {
    await room?.localParticipant?.publishData(utf8.encode(jsonEncode(payload)), reliable: true);
  }

  Future<void> sendChat() async {
    final text = composer.text.trim();
    if (text.isEmpty) return;
    if (!chatAllowed && environment == 'production') return;
    final name = room?.localParticipant?.name ?? '';
    composer.clear();
    await send({'type': 'chat', 'text': text});
    final collection = messagesCollection;
    if (collection != null) {
      await collection.add({'text': text, 'name': name, 'environment': environment, 'at': DateTime.now().toUtc().toIso8601String()});
    } else if (mounted) {
      setState(() => messages.add(LiveLine(name, text, mine: true)));
    }
  }

  Future<void> react(String kind) async {
    try {
      await widget.session.api.post('$base/reactions', {'kind': kind});
      await send({'type': 'reaction', 'kind': kind});
      if (mounted) setState(() => addFloating(kind));
    } on ApiException catch (reason) {
      if (reason.status != 429 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(studentMessage(reason.code, reason.message, copy.arabic))));
      }
    } catch (_) {}
  }

  Future<String?> ask(String text) async {
    try {
      await widget.session.api.post('$base/questions', {'text': text});
      await send({'type': 'questions'});
      await pull();
      return null;
    } on ApiException catch (reason) {
      return studentMessage(reason.code, reason.message, copy.arabic);
    } catch (_) {
      return copy.pick('تعذّر الإرسال.', 'Could not send.');
    }
  }

  Future<void> vote(String questionId) async {
    try {
      await widget.session.api.post('$base/questions/$questionId/vote');
      await pull();
    } catch (_) {}
  }

  Future<void> answer(String pollId, int option) async {
    try {
      await widget.session.api.post('$base/polls/$pollId/vote', {'option': option});
      await pull();
    } on ApiException catch (reason) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(studentMessage(reason.code, reason.message, copy.arabic))));
    } catch (_) {}
  }

  Future<void> toggleAudioOnly() async {
    setState(() => audioOnly = !audioOnly);
    await applyAudioOnly();
  }

  Future<void> applyAudioOnly() async {
    final current = room;
    if (current == null) return;
    for (final person in current.remoteParticipants.values) {
      for (final publication in person.videoTrackPublications) {
        if (audioOnly) {
          await publication.disable();
        } else {
          await publication.enable();
        }
      }
    }
  }

  @override
  void dispose() {
    leaving = true;
    clock?.cancel();
    beat?.cancel();
    sync?.cancel();
    chatFeed?.cancel();
    composer.dispose();
    listener?.dispose();
    room?.dispose();
    super.dispose();
  }

  Future<void> confirmLeave() async {
    if (room == null) {
      if (mounted) Navigator.pop(context, false);
      return;
    }
    final yes = await showToviSheet<bool>(
      context,
      (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SheetHandle(),
          Text(copy.pick('مغادرة الحصة؟', 'Leave the session?'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(copy.pick('تكدر ترجع قبل ما تنتهي الحصة، ووقت حضورك ينحفظ.', 'You can come back before it ends; your time is kept.'), style: const TextStyle(color: Tovi.muted, height: 1.5)),
          const SizedBox(height: 16),
          ToviButton(label: copy.leave, color: Tovi.danger, onPressed: () => Navigator.pop(context, true)),
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(copy.pick('البقاء', 'Stay'))),
        ]),
      ),
    );
    if (yes != true || !mounted) return;
    leaving = true;
    await room?.disconnect();
    if (mounted) Navigator.pop(context, false);
  }

  void openPanel(int tab) {
    showToviSheet<void>(
      context,
      (sheet) => StatefulBuilder(
        builder: (sheet, refreshSheet) {
          return LivePanel(
            copy: copy,
            initial: tab,
            messages: messages,
            questions: questions,
            polls: polls,
            composer: composer,
            canChat: !(environment == 'production' && !chatAllowed),
            onSend: () async {
              await sendChat();
              refreshSheet(() {});
            },
            onAsk: (text) async {
              final problem = await ask(text);
              refreshSheet(() {});
              return problem;
            },
            onVote: (id) async {
              await vote(id);
              refreshSheet(() {});
            },
            onAnswer: (id, option) async {
              await answer(id, option);
              refreshSheet(() {});
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = room;
    final local = current?.localParticipant;
    final micOn = local?.isMicrophoneEnabled() ?? false;
    final cameraOn = local?.isCameraEnabled() ?? false;
    final quality = local?.connectionQuality ?? ConnectionQuality.unknown;
    final reconnecting = current?.connectionState == ConnectionState.reconnecting;
    final remotes = current?.remoteParticipants.values.toList() ?? const <RemoteParticipant>[];
    final host = remotes.where((p) => p.identity.startsWith('teacher:') || p.identity.startsWith('assistant:')).toList();
    final main = <Participant>[...remotes.where((p) => p.isScreenShareEnabled()), ...host, ...remotes];
    final stage = main.isEmpty ? null : main.first;
    final strip = <Participant>[?local, for (final p in remotes) if (p != stage) p];
    final openPoll = polls.where((p) => p['open'] == true && p['myOption'] == null).length;
    final names = {for (final p in remotes) p.identity: p.name.isEmpty ? p.identity : p.name, if (local != null) local.identity: local.name};
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) confirmLeave();
      },
      child: Scaffold(
        backgroundColor: ToviTokens.night,
        body: current == null
            ? SafeArea(
                child: Column(children: [
                  ToviHeader(title: title.isEmpty ? copy.meeting : title, light: true, onBack: () => Navigator.pop(context, false)),
                  Expanded(
                    child: Center(
                      child: error.isEmpty
                          ? Column(mainAxisSize: MainAxisSize.min, children: [
                              const CircularProgressIndicator(color: Colors.white),
                              const SizedBox(height: 14),
                              Text(copy.pick('جاري الدخول للبث…', 'Joining the live room…'), style: const TextStyle(color: Colors.white70)),
                            ])
                          : Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, height: 1.5)),
                                const SizedBox(height: 12),
                                TextButton(onPressed: connect, child: Text(copy.pick('إعادة المحاولة', 'Try again'))),
                              ]),
                            ),
                    ),
                  ),
                ]),
              )
            : Column(children: [
                SafeArea(
                  bottom: false,
                  child: LiveTopBar(
                    copy: copy,
                    title: title.isEmpty ? copy.meeting : title,
                    teacher: asText(asMap(widget.state['session'])['teacherName']),
                    elapsed: elapsed,
                    scheduledMinutes: scheduledMinutes,
                    quality: quality,
                    viewers: remotes.length + 1,
                    onLeave: confirmLeave,
                  ),
                ),
                if (reconnecting)
                  LiveNotice(icon: Icons.sync_rounded, color: ToviTokens.sun, text: copy.pick('انقطع الاتصال، نعيد ربطك…', 'Connection dropped, reconnecting…'))
                else if (quality == ConnectionQuality.poor || quality == ConnectionQuality.lost)
                  LiveNotice(
                    icon: Icons.signal_cellular_alt_1_bar_rounded,
                    color: ToviTokens.coral,
                    text: audioOnly ? copy.pick('شغّال بالصوت فقط لتوفير الاتصال.', 'Audio only to save bandwidth.') : copy.pick('اتصالك ضعيف. جرّب الصوت فقط.', 'Weak connection. Try audio only.'),
                    action: audioOnly ? copy.pick('رجّع الفيديو', 'Video on') : copy.pick('الصوت فقط', 'Audio only'),
                    onAction: toggleAudioOnly,
                  ),
                if (announcements.isNotEmpty)
                  LiveNotice(icon: Icons.campaign_rounded, color: ToviTokens.sun, text: announcements.first, onClose: () => setState(announcements.clear)),
                Expanded(
                  child: Stack(children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                        child: stage == null
                            ? LiveTile(name: copy.pick('بانتظار المعلم', 'Waiting for the teacher'), quality: ConnectionQuality.unknown, audioOnly: false, large: true, icon: Icons.hourglass_top_rounded)
                            : LiveTile.of(stage, audioOnly: audioOnly, large: true),
                      ),
                    ),
                    PositionedDirectional(
                      end: 20,
                      bottom: 20,
                      child: IgnorePointer(child: ReactionStream(items: floating)),
                    ),
                  ]),
                ),
                if (strip.isNotEmpty)
                  SizedBox(
                    height: 86,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      scrollDirection: Axis.horizontal,
                      itemCount: strip.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => SizedBox(width: 120, child: LiveTile.of(strip[i], audioOnly: audioOnly, mine: strip[i] == local)),
                    ),
                  ),
                if (hands.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(children: [
                      const Icon(Icons.back_hand_rounded, size: 16, color: ToviTokens.sun),
                      const SizedBox(width: 6),
                      Expanded(child: Text(hands.map((h) => names[h] ?? h).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12.5))),
                    ]),
                  ),
                AttendanceStrip(copy: copy, me: me),
                ReactionBar(kinds: kinds, onReact: react),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                      LiveControl(icon: micOn ? Icons.mic_rounded : Icons.mic_off_rounded, label: copy.mic, active: micOn, onTap: () => local?.setMicrophoneEnabled(!micOn)),
                      LiveControl(icon: cameraOn ? Icons.videocam_rounded : Icons.videocam_off_rounded, label: copy.camera, active: cameraOn, onTap: () => local?.setCameraEnabled(!cameraOn)),
                      LiveControl(
                        icon: raised ? Icons.back_hand_rounded : Icons.back_hand_outlined,
                        label: raised ? copy.lower : copy.raise,
                        active: raised,
                        onTap: () async {
                          setState(() => raised = !raised);
                          await send({'type': 'hand', 'from': local?.identity ?? '', 'raised': raised});
                        },
                      ),
                      LiveControl(icon: Icons.forum_outlined, label: copy.pick('تفاعل', 'Talk'), badge: openPoll, onTap: () => openPanel(openPoll > 0 ? 2 : 0)),
                      LiveControl(icon: Icons.call_end_rounded, label: copy.leave, danger: true, onTap: confirmLeave),
                    ]),
                  ),
                ),
              ]),
      ),
    );
  }
}

/// The end of a live session: attendance, points and replays.
class LiveEnded extends StatefulWidget {
  const LiveEnded({super.key, required this.session, required this.base, required this.copy, required this.info, required this.me, required this.earnedXp, required this.recordingEnabled});
  final Session session;
  final String base;
  final Copy copy;
  final Map<String, dynamic> info;
  final Map<String, dynamic>? me;
  final int earnedXp;
  final bool recordingEnabled;

  @override
  State<LiveEnded> createState() => _LiveEndedState();
}

class _LiveEndedState extends State<LiveEnded> {
  Map<String, dynamic>? recordings;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = asMap(await widget.session.api.get('${widget.base}/recordings'));
      if (mounted) setState(() => recordings = data);
    } catch (_) {
      if (mounted) setState(() => recordings = const {'enabled': false, 'items': []});
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.copy;
    final me = widget.me;
    final minutes = (asInt(me?['liveSeconds']) / 60).round();
    final needed = (asInt(me?['attendanceSeconds']) / 60).round();
    final attended = me?['attended'] == true;
    final items = asMaps(recordings?['items']);
    final enabled = recordings?['enabled'] == true;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        LiveHero(
          color: attended ? ToviTokens.mint : ToviTokens.violet,
          icon: attended ? Icons.verified_rounded : Icons.flag_rounded,
          eyebrow: copy.pick('انتهت الحصة', 'Session ended'),
          title: firstMeta(widget.info, const ['title', 'classroomTitle']),
          subtitle: asText(widget.info['teacherName']),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: StatPill(color: ToviTokens.violet, icon: Icons.timer_outlined, label: copy.pick('دقائق حضورك', 'Your minutes'), value: '$minutes')),
          const SizedBox(width: 10),
          Expanded(child: StatPill(color: attended ? ToviTokens.mint : ToviTokens.coral, icon: attended ? Icons.how_to_reg_rounded : Icons.person_off_outlined, label: copy.pick('الحضور', 'Attendance'), value: me == null ? '—' : (attended ? copy.pick('حاضر', 'Present') : copy.pick('غير مكتمل', 'Partial')))),
          const SizedBox(width: 10),
          Expanded(child: StatPill(color: const Color(0xFFC98A00), icon: Icons.bolt_rounded, label: copy.pick('نقاط', 'XP'), value: '+${widget.earnedXp}')),
        ]),
        if (me != null && !attended && needed > 0)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(copy.pick('يُحسب الحضور بعد $needed دقيقة من البث.', 'Attendance counts after $needed minutes of live time.'), style: const TextStyle(color: Tovi.muted, height: 1.5)),
          ),
        SectionHead(title: copy.pick('الإعادة', 'Replay')),
        if (recordings == null)
          const SkeletonFade(child: Bone(height: 72, radius: 18))
        else if (!enabled && items.isEmpty)
          SoftPanel(
            color: ToviTokens.sunken,
            child: Row(children: [
              const Icon(Icons.videocam_off_outlined, color: Tovi.muted),
              const SizedBox(width: 12),
              Expanded(child: Text(copy.pick('التسجيل غير مفعّل لهذه المنصة، فما راح تتوفر إعادة.', 'Recording is not enabled on this platform, so no replay is available.'), style: const TextStyle(color: Tovi.muted, height: 1.5))),
            ]),
          )
        else if (items.isEmpty)
          EmptyNote(icon: Icons.video_library_outlined, text: copy.pick('ما سجّل المعلم هاي الحصة.', 'The teacher did not record this session.'))
        else
          for (final row in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SoftPanel(
                onTap: asText(row['url']).isEmpty ? null : () => launchUrl(Uri.parse(asText(row['url']))),
                child: Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: ToviTokens.violetSoft, borderRadius: BorderRadius.circular(14)),
                    child: Icon(asText(row['url']).isEmpty ? Icons.hourglass_top_rounded : Icons.play_arrow_rounded, color: Tovi.violet),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      asText(row['url']).isEmpty ? copy.pick('التسجيل قيد التجهيز', 'Recording is processing') : copy.pick('شاهد الإعادة', 'Watch the replay'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ]),
              ),
            ),
      ],
    );
  }
}
