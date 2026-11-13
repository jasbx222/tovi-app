import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:livekit_client/livekit_client.dart' hide Session;
import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'session.dart';
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
      if (mounted) setState(() => error = reason.message);
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

  @override
  Widget build(BuildContext context) {
    final copy = widget.session.copy;
    final current = room;
    final List<Participant> people = current == null
              ? <Participant>[]
              : <Participant>[if (current.localParticipant != null) current.localParticipant!, ...current.remoteParticipants.values];
    final minutes = (elapsed ~/ 60).toString().padLeft(2, '0');
    final seconds = (elapsed % 60).toString().padLeft(2, '0');
    return Scaffold(
      backgroundColor: Tovi.ink,
      appBar: AppBar(
        backgroundColor: Tovi.ink,
        foregroundColor: const Color(0xFFF6F1E7),
        title: Text(copy.meeting),
      ),
      body: current == null
          ? Center(child: Text(error.isEmpty ? '…' : error, style: const TextStyle(color: Colors.white)))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(spacing: 8, children: [
                    Chip(label: Text(status)),
                    Chip(label: Text('$minutes:$seconds / $scheduledMinutes')),
                    Chip(label: Text(current.localParticipant?.isScreenShareEnabled() == true ? copy.pick('مشاركة الشاشة', 'Sharing') : copy.pick('بدون مشاركة', 'No share'))),
                  ]),
                ),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 2 : 1,
                    children: [
                      for (final person in people)
                        for (final publication in person.videoTrackPublications)
                          if (publication.track != null)
                            Column(children: [
                              Expanded(child: VideoTrackRenderer(publication.track as VideoTrack)),
                              Text(person.identity, style: const TextStyle(color: Colors.white)),
                            ]),
                    ],
                  ),
                ),
                if (announcements.isNotEmpty) Text(announcements.first, style: const TextStyle(color: Colors.white)),
                SizedBox(
                  height: 72,
                  child: ListView(scrollDirection: Axis.horizontal, children: [for (final person in people) Padding(padding: const EdgeInsets.all(8), child: Text('${person.identity} · ${person.connectionQuality.name}', style: const TextStyle(color: Colors.white70)))]),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  color: const Color(0xFF141210),
                  child: Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                    FilledButton(onPressed: () => current.localParticipant?.setMicrophoneEnabled(!(current.localParticipant?.isMicrophoneEnabled() ?? false)), child: Text(copy.mic)),
                    FilledButton(onPressed: () => current.localParticipant?.setCameraEnabled(!(current.localParticipant?.isCameraEnabled() ?? false)), child: Text(copy.camera)),
                    FilledButton(style: FilledButton.styleFrom(backgroundColor: raised ? Tovi.clay : Tovi.ink), onPressed: () async {
                      raised = !raised;
                      final identity = current.localParticipant?.identity ?? '';
                      await send({'type': 'hand', 'from': identity, 'raised': raised});
                      setState(() {});
                    }, child: Text(raised ? copy.lower : copy.raise)),
                    OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFF6F1E7)), onPressed: () async { leaving = true; await current.disconnect(); if (context.mounted) Navigator.pop(context); }, child: Text(copy.leave)),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(children: [
                    Expanded(child: TextField(controller: composer, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: copy.pick('رسالة', 'Message')))),
                    IconButton(onPressed: sendChat, icon: const Icon(Icons.send, color: Colors.white)),
                  ]),
                ),
              ],
            ),
    );
  }
}
