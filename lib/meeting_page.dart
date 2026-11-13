import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:livekit_client/livekit_client.dart' hide Session;
import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'session.dart';
import 'student_rules.dart';
import 'ui.dart';

class MeetingPage extends StatefulWidget {
  const MeetingPage({super.key, required this.session, required this.sessionId});
  final Session session;
  final String sessionId;

  @override
  State<MeetingPage> createState() => _MeetingPageState();
}

class _MeetingPageState extends State<MeetingPage> {
  Room? room;
  EventsListener<RoomEvent>? listener;
  String error = '';
  String status = '';
  String environment = '';
  String chatPath = '';
  bool raised = false;
  bool leaving = false;
  final messages = <String>[];
  final announcements = <String>[];
  final hands = <String>[];
  final composer = TextEditingController();
  Timer? clock;
  var elapsed = 0;
  var scheduledMinutes = 0;

  @override
  void initState() {
    super.initState();
    connect();
  }

  Future<void> connect() async {
    try {
      final token = Map<String, dynamic>.from(await widget.session.api.post('/api/student/sessions/${widget.sessionId}/token') as Map);
      final chat = Map<String, dynamic>.from(await widget.session.api.get('/api/student/sessions/${widget.sessionId}/chat') as Map);
      environment = '${chat['environment']}';
      chatPath = '${chat['path']}';
      if (environment == 'production' && Session.buildEnvironment != 'production') {
        throw ApiException(403, 'environment_mismatch', 'This build cannot enter a production meeting.');
      }
      scheduledMinutes = token['durationMinutes'] as int? ?? 0;
      final next = Room();
      listener = next.createListener()
        ..on<RoomDisconnectedEvent>((_) {
          if (!leaving && mounted) reconnect();
        })
        ..on<DataReceivedEvent>((event) {
          final data = jsonDecode(utf8.decode(event.data));
          if (data is! Map) return;
          setState(() {
            if (data['type'] == 'announcement') announcements.insert(0, '${data['text']}');
            if (data['type'] == 'chat') messages.add('${data['text']}');
            if (data['type'] == 'hand') {
              final from = '${data['from']}';
              if (data['raised'] == true) {
                if (!hands.contains(from)) hands.add(from);
              } else {
                hands.remove(from);
              }
            }
          });
        });
      await next.connect('${token['url']}', '${token['token']}');
      next.addListener(() { if (mounted) setState(() => status = next.connectionState.name); });
      clock?.cancel();
      clock = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() => elapsed += 1); });
      if (mounted) setState(() { room = next; status = next.connectionState.name; error = ''; });
      await openFirestore();
    } on ApiException catch (reason) {
      if (mounted) setState(() => error = studentMessage(reason.code, reason.message, widget.session.copy.arabic));
    } catch (reason) {
      if (mounted) setState(() => error = '$reason');
    }
  }

  Future<void> reconnect() async {
    await room?.dispose();
    room = null;
    if (mounted) await connect();
  }

  bool get chatAllowed => environment.isNotEmpty && environment == Session.buildEnvironment && chatPath == '$environment/meetings/${widget.sessionId}/messages';

  CollectionReference<Map<String, dynamic>>? get messagesCollection {
    if (!chatAllowed || Firebase.apps.isEmpty) return null;
    return FirebaseFirestore.instance.collection('environments').doc(environment).collection('meetings').doc(widget.sessionId).collection('messages');
  }

  Future<void> openFirestore() async {
    final query = messagesCollection?.limit(40);
    if (query == null) return;
    query.snapshots().listen((snapshot) {
      if (!mounted) return;
      setState(() {
        messages
          ..clear()
          ..addAll(snapshot.docs.map((doc) => '${doc.data()['text'] ?? ''}'));
      });
    });
  }

  Future<void> send(Map<String, Object?> payload) async {
    final bytes = utf8.encode(jsonEncode(payload));
    await room?.localParticipant?.publishData(bytes, reliable: true);
  }

  Future<void> sendChat() async {
    final text = composer.text.trim();
    if (text.isEmpty) return;
    if (!chatAllowed && environment == 'production') return;
    await send({'type': 'chat', 'text': text});
    await messagesCollection?.add({
      'text': text,
      'environment': environment,
      'at': DateTime.now().toUtc().toIso8601String(),
    });
    composer.clear();
    setState(() => messages.add(text));
  }

  @override
  void dispose() {
    leaving = true;
    clock?.cancel();
    composer.dispose();
    listener?.dispose();
    room?.dispose();
    super.dispose();
  }

  var chatOpen = false;

  Future<void> confirmLeave() async {
    final current = room;
    if (current == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final copy = widget.session.copy;
    final yes = await showToviSheet<bool>(
      context,
      (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            Text(copy.pick('مغادرة الحصة؟', 'Leave the meeting?'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            ToviButton(label: copy.leave, color: Tovi.danger, onPressed: () => Navigator.pop(context, true)),
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(copy.pick('البقاء', 'Stay'))),
          ],
        ),
      ),
    );
    if (yes != true || !mounted) return;
    leaving = true;
    await current.disconnect();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.session.copy;
    final current = room;
    final people = current == null
        ? <Participant>[]
        : <Participant>[if (current.localParticipant != null) current.localParticipant!, ...current.remoteParticipants.values];
    final minutes = (elapsed ~/ 60).toString().padLeft(2, '0');
    final seconds = (elapsed % 60).toString().padLeft(2, '0');
    final sharing = current?.localParticipant?.isScreenShareEnabled() == true;
    final micOn = current?.localParticipant?.isMicrophoneEnabled() ?? false;
    final cameraOn = current?.localParticipant?.isCameraEnabled() ?? false;
    final tiles = <Widget>[
      for (final person in people) ..._tilesFor(person),
    ];
    return Scaffold(
      backgroundColor: const Color(0xFF121018),
      body: current == null
          ? SafeArea(
              child: Column(children: [
                ToviHeader(title: copy.meeting, light: true, onBack: () => Navigator.pop(context)),
                Expanded(child: Center(child: error.isEmpty ? const CircularProgressIndicator(color: Colors.white) : Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)))),
              ]),
            )
          : Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
                    child: Row(children: [
                      CircleButton(icon: Icons.arrow_back_ios_new_rounded, tooltip: copy.leave, onPressed: confirmLeave, background: const Color(0x22FFFFFF), foreground: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(copy.meeting, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                        Text(
                          '$status · ${sharing ? copy.pick('مشاركة الشاشة', 'Sharing') : copy.pick('بدون مشاركة', 'No share')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                        ),
                      ])),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0x22FFFFFF), borderRadius: BorderRadius.circular(99)),
                        child: Text('$minutes:$seconds / $scheduledMinutes', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                    ]),
                  ),
                ),
                if (announcements.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: const Color(0xFF3A2A12), borderRadius: BorderRadius.circular(14)),
                    child: Text(announcements.first, style: const TextStyle(color: Color(0xFFFFD7A8))),
                  ),
                if (hands.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text('${copy.raise}: ${hands.join(' · ')}', style: const TextStyle(color: Color(0xFFFFD7A8), fontSize: 12)),
                  ),
                Expanded(
                  child: tiles.isEmpty
                      ? Center(child: Text(copy.pick('بانتظار المشاركين', 'Waiting for people'), style: TextStyle(color: Colors.white.withValues(alpha: 0.7))))
                      : GridView.count(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 2 : 1,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: MediaQuery.sizeOf(context).width > 700 ? 1.5 : 1.35,
                          children: tiles,
                        ),
                ),
                if (chatOpen) ...[
                  SizedBox(
                    height: 140,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        for (final line in messages) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(line, style: const TextStyle(color: Colors.white))),
                        if (messages.isEmpty) Text(copy.empty, style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Row(children: [
                      Expanded(
                        child: TextField(
                          controller: composer,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: copy.pick('رسالة', 'Message'),
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                            filled: true,
                            fillColor: const Color(0xFF2A2738),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          ),
                          onSubmitted: (_) => sendChat(),
                        ),
                      ),
                      IconButton(tooltip: copy.pick('إرسال', 'Send'), onPressed: sendChat, icon: const Icon(Icons.send_rounded, color: Colors.white)),
                    ]),
                  ),
                ],
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _MeetControl(icon: micOn ? Icons.mic_rounded : Icons.mic_off_rounded, label: copy.mic, active: micOn, onTap: () => current.localParticipant?.setMicrophoneEnabled(!micOn)),
                        _MeetControl(icon: cameraOn ? Icons.videocam_rounded : Icons.videocam_off_rounded, label: copy.camera, active: cameraOn, onTap: () => current.localParticipant?.setCameraEnabled(!cameraOn)),
                        _MeetControl(
                          icon: Icons.back_hand_rounded,
                          label: raised ? copy.lower : copy.raise,
                          active: raised,
                          onTap: () async {
                            raised = !raised;
                            await send({'type': 'hand', 'from': current.localParticipant?.identity ?? '', 'raised': raised});
                            if (mounted) setState(() {});
                          },
                        ),
                        _MeetControl(icon: Icons.chat_bubble_rounded, label: copy.pick('دردشة', 'Chat'), active: chatOpen, onTap: () => setState(() => chatOpen = !chatOpen)),
                        _MeetControl(icon: Icons.call_end_rounded, label: copy.leave, danger: true, onTap: confirmLeave),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  List<Widget> _tilesFor(Participant person) {
    final videos = [for (final publication in person.videoTrackPublications) if (publication.track is VideoTrack) publication.track as VideoTrack];
    if (videos.isEmpty) return [_PersonTile(name: person.identity, quality: person.connectionQuality.name)];
    return [for (final track in videos) _PersonTile(name: person.identity, quality: person.connectionQuality.name, track: track)];
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.name, required this.quality, this.track});
  final String name;
  final String quality;
  final VideoTrack? track;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: const Color(0xFF241F33),
            child: track == null
                ? Center(child: CircleAvatar(radius: 28, backgroundColor: Tovi.violet, child: Text(name.isEmpty ? 'T' : name.substring(0, 1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 22))))
                : VideoTrackRenderer(track!),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0xCC000000)])),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text('$name · $quality', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MeetControl extends StatelessWidget {
  const _MeetControl({required this.icon, required this.label, required this.onTap, this.active = false, this.danger = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? Tovi.danger : (active ? Tovi.violet : const Color(0xFF2A2738));
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 60,
          child: Column(children: [
            Container(width: 48, height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 22)),
            const SizedBox(height: 4),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10)),
          ]),
        ),
      ),
    );
  }
}
