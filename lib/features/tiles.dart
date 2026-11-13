import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../course_page.dart';
import '../session.dart';
import '../ui.dart';
import 'hub_kit.dart';

/// Course card with cover, teacher photo, subject, progress and like/save toggles.
class CourseTileCard extends StatefulWidget {
  const CourseTileCard({super.key, required this.session, required this.row, this.wide = false, this.onChanged});
  final Session session;
  final Map<String, dynamic> row;
  final bool wide;
  final ValueChanged<Map<String, dynamic>>? onChanged;

  @override
  State<CourseTileCard> createState() => _CourseTileCardState();
}

class _CourseTileCardState extends State<CourseTileCard> {
  late Map<String, dynamic> row = widget.row;

  @override
  void didUpdateWidget(CourseTileCard old) {
    super.didUpdateWidget(old);
    if (old.row != widget.row) row = widget.row;
  }

  Future<void> toggle(String kind) async {
    final on = row[kind] == true;
    final key = kind == 'liked' ? 'like' : 'save';
    setState(() => row = {...row, kind: !on, if (kind == 'liked') 'likes': asInt(row['likes']) + (on ? -1 : 1)});
    try {
      final path = '/api/student/courses/${row['id']}/$key';
      if (on) {
        await widget.session.api.sendDelete(path);
      } else {
        await widget.session.api.post(path);
      }
      widget.onChanged?.call(row);
    } on ApiException catch (reason) {
      if (!mounted) return;
      setState(() => row = {...row, kind: on});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hubError(reason, widget.session))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.session.copy;
    final title = asText(row['title']);
    final lessons = asInt(row['lessons']);
    final done = asInt(row['done']);
    final unlocked = row['unlocked'] == true;
    final teacher = asText(row['teacherName']);
    final subject = firstMeta(row, const ['subject', 'grade']);
    return Material(
      color: ToviTokens.surface,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shadowColor: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(context, toviRoute(CoursePage(session: widget.session, id: asText(row['id'])))),
        child: DecoratedBox(
          decoration: const BoxDecoration(boxShadow: ToviTokens.raised),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AspectRatio(
              aspectRatio: widget.wide ? 16 / 8 : 16 / 10,
              child: Stack(fit: StackFit.expand, children: [
                HubPhoto(url: row['coverUrl'], seed: title, radius: 0),
                const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0x8C17142B)], stops: [0.45, 1]))),
                if (subject.isNotEmpty)
                  PositionedDirectional(
                    start: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(99)),
                      child: Text(subject, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: ToviTokens.violet)),
                    ),
                  ),
                PositionedDirectional(
                  end: 6,
                  top: 6,
                  child: Row(children: [
                    _Toggle(on: row['liked'] == true, icon: Icons.favorite_rounded, off: Icons.favorite_border_rounded, color: ToviTokens.coral, tip: copy.like, onTap: () => toggle('liked')),
                    _Toggle(on: row['saved'] == true, icon: Icons.bookmark_rounded, off: Icons.bookmark_border_rounded, color: ToviTokens.violet, tip: copy.save, onTap: () => toggle('saved')),
                  ]),
                ),
                PositionedDirectional(
                  start: 10,
                  bottom: 8,
                  end: 10,
                  child: Row(children: [
                    HubFace(url: row['teacherPhotoUrl'], name: teacher, size: 26),
                    const SizedBox(width: 6),
                    Expanded(child: Text(teacher, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5))),
                  ]),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, height: 1.3, color: ToviTokens.ink)),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.play_circle_outline_rounded, size: 15, color: ToviTokens.muted),
                  const SizedBox(width: 4),
                  Text(copy.pick('$lessons درس', '$lessons lessons'), style: const TextStyle(color: ToviTokens.muted, fontSize: 12.5)),
                  const Spacer(),
                  if (unlocked)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: ToviTokens.mintSoft, borderRadius: BorderRadius.circular(99)),
                      child: Text(copy.pick('مفعّل', 'Unlocked'), style: const TextStyle(color: ToviTokens.mint, fontSize: 11.5, fontWeight: FontWeight.w800)),
                    ),
                ]),
                if (unlocked && lessons > 0) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(value: done / lessons, minHeight: 6, backgroundColor: ToviTokens.sunken, color: ToviTokens.violet),
                  ),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.on, required this.icon, required this.off, required this.color, required this.tip, required this.onTap});
  final bool on;
  final IconData icon;
  final IconData off;
  final Color color;
  final String tip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      toggled: on,
      label: tip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.94), shape: BoxShape.circle),
          child: AnimatedSwitcher(
            duration: still ? Duration.zero : ToviTokens.calm,
            transitionBuilder: (child, animation) => ScaleTransition(scale: CurvedAnimation(parent: animation, curve: Curves.elasticOut), child: child),
            child: Icon(on ? icon : off, key: ValueKey(on), size: 19, color: on ? color : ToviTokens.muted),
          ),
        ),
      ),
    );
  }
}

/// Horizontal strip of course cards.
class CourseStrip extends StatelessWidget {
  const CourseStrip({super.key, required this.session, required this.rows});
  final Session session;
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 252,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        itemCount: rows.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) => SizedBox(width: 220, child: CourseTileCard(session: session, row: rows[i])),
      ),
    );
  }
}

/// Teacher row with photo, subject and counts. Opens [onOpen] when tapped.
class TeacherLine extends StatelessWidget {
  const TeacherLine({super.key, required this.session, required this.row, this.onOpen});
  final Session session;
  final Map<String, dynamic> row;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final copy = session.copy;
    final name = asText(row['name']);
    final subject = asText(row['subject']);
    return SoftPanel(
      onTap: onOpen,
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        HubFace(url: row['photoUrl'], name: name, size: 52, ring: row['following'] == true),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
          const SizedBox(height: 2),
          Text(
            [if (subject.isNotEmpty) subject, copy.pick('${asInt(row['courses'])} دورة', '${asInt(row['courses'])} courses'), copy.pick('${asInt(row['followers'])} متابع', '${asInt(row['followers'])} followers')].join(' · '),
            style: const TextStyle(color: ToviTokens.muted, fontSize: 12.5),
          ),
        ])),
        if (row['following'] == true)
          const Icon(Icons.check_circle_rounded, color: ToviTokens.violet, size: 20)
        else
          const Icon(Icons.chevron_left_rounded, color: ToviTokens.faint),
      ]),
    );
  }
}

/// Institute row with logo and counts.
class PlaceLine extends StatelessWidget {
  const PlaceLine({super.key, required this.session, required this.row, this.onOpen});
  final Session session;
  final Map<String, dynamic> row;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final copy = session.copy;
    final name = asText(row['name']);
    return SoftPanel(
      onTap: onOpen,
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        SizedBox(width: 56, height: 56, child: HubPhoto(url: row['logoUrl'], seed: name, radius: 16, icon: Icons.apartment_rounded)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
          const SizedBox(height: 2),
          Text(
            [copy.pick('${asInt(row['teachers'])} معلم', '${asInt(row['teachers'])} teachers'), copy.pick('${asInt(row['courses'])} دورة', '${asInt(row['courses'])} courses'), if (asText(row['address']).isNotEmpty) asText(row['address'])].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: ToviTokens.muted, fontSize: 12.5),
          ),
        ])),
        const Icon(Icons.chevron_left_rounded, color: ToviTokens.faint),
      ]),
    );
  }
}

/// A rounded square with a soft tint holding an icon.
class IconOrb extends StatelessWidget {
  const IconOrb({super.key, required this.icon, required this.color, this.soft, this.size = 44});
  final IconData icon;
  final Color color;
  final Color? soft;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: soft ?? color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(size * 0.34)),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

/// Builds the teacher profile screen. Left empty until that screen exists, so teacher rows are not tappable.
Widget Function(Session session, String id)? teacherPageBuilder;

VoidCallback? openTeacher(BuildContext context, Session session, Map<String, dynamic> row) {
  final builder = teacherPageBuilder;
  if (builder == null) return null;
  return () => Navigator.push(context, toviRoute(builder(session, asText(row['id']))));
}
