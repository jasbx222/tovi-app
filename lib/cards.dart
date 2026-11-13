import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'copy.dart';
import 'session.dart';
import 'ui.dart';

/// Turns a `/api/files/...` path from the API into a full image address.
String? mediaUrl(Object? path) {
  final value = asText(path);
  if (value.isEmpty) return null;
  if (value.startsWith('http://') || value.startsWith('https://')) return value;
  return '${Session.base}$value';
}

/// Every course and teacher gets a stable gradient pair from its id, so the
/// same card always looks the same without a stored colour.
List<Color> toneFor(String seed) {
  const pairs = <List<Color>>[
    [Color(0xFF6A4CFF), Color(0xFF9B7BFF)],
    [Color(0xFF3D6BFF), Color(0xFF6AA8FF)],
    [Color(0xFFFF6B57), Color(0xFFFF9E6B)],
    [Color(0xFF14A37F), Color(0xFF4FCFA8)],
    [Color(0xFF8A3FD1), Color(0xFFD36BFF)],
    [Color(0xFFE59A00), Color(0xFFFFC23D)],
  ];
  var hash = 0;
  for (final unit in seed.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return pairs[hash % pairs.length];
}

IconData subjectIcon(String subject) {
  final s = subject.toLowerCase();
  bool has(List<String> words) => words.any(s.contains);
  if (has(['رياض', 'math', 'جبر', 'هندس'])) return Icons.calculate_rounded;
  if (has(['فيزي', 'phys'])) return Icons.bolt_rounded;
  if (has(['كيمي', 'chem'])) return Icons.science_rounded;
  if (has(['أحياء', 'احياء', 'bio'])) return Icons.eco_rounded;
  if (has(['إنكليز', 'انكليز', 'english', 'لغة'])) return Icons.translate_rounded;
  if (has(['عرب', 'arab', 'أدب'])) return Icons.menu_book_rounded;
  if (has(['إسلام', 'اسلام', 'islam', 'قرآن'])) return Icons.auto_stories_rounded;
  if (has(['حاسوب', 'برمج', 'comput', 'code'])) return Icons.code_rounded;
  if (has(['تاريخ', 'جغراف', 'اجتماع', 'hist', 'geo'])) return Icons.public_rounded;
  return Icons.school_rounded;
}

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return 'T';
  if (parts.length == 1) return parts.first.characters.first;
  return '${parts[0].characters.first}${parts[1].characters.first}';
}

class NetImage extends StatelessWidget {
  const NetImage({super.key, required this.url, required this.fallback, this.fit = BoxFit.cover});
  final String? url;
  final Widget fallback;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (url == null) return fallback;
    return Image.network(
      url!,
      fit: fit,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, sync) =>
          sync ? child : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: ToviTokens.calm, curve: Curves.easeOut, child: frame == null ? fallback : child),
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

/// Round photo with a soft gradient ring; without a photo it shows the
/// teacher's initials on a Tovi gradient.
class TeacherAvatar extends StatelessWidget {
  const TeacherAvatar({super.key, required this.id, required this.name, this.photo, this.size = 64, this.ring = 3});
  final String id;
  final String name;
  final String? photo;
  final double size;
  final double ring;

  @override
  Widget build(BuildContext context) {
    final tone = toneFor(id);
    final initials = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: tone, begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Text(
        initialsOf(name),
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: size * 0.34, height: 1),
      ),
    );
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(ring),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(colors: [tone[0], tone[1], ToviTokens.sun, tone[0]]),
        boxShadow: [BoxShadow(color: tone[0].withValues(alpha: 0.22), blurRadius: size * 0.25, offset: Offset(0, size * 0.08))],
      ),
      child: Container(
        padding: EdgeInsets.all(ring > 0 ? 2 : 0),
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: ClipOval(
          child: NetImage(url: mediaUrl(photo), fallback: initials),
        ),
      ),
    );
  }
}

/// Follow pill that morphs between "follow" and "following".
class FollowPill extends StatelessWidget {
  const FollowPill({super.key, required this.following, required this.copy, required this.onPressed, this.busy = false, this.large = false});
  final bool following;
  final bool busy;
  final bool large;
  final Copy copy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final height = large ? 46.0 : 36.0;
    return AnimatedContainer(
      duration: ToviTokens.calm,
      curve: Curves.easeOutCubic,
      height: height,
      decoration: BoxDecoration(
        color: following ? ToviTokens.violetSoft : ToviTokens.violet,
        borderRadius: BorderRadius.circular(height / 2),
        boxShadow: following ? const [] : [BoxShadow(color: ToviTokens.violet.withValues(alpha: 0.28), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(height / 2),
          onTap: busy ? null : onPressed,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: large ? 22 : 14),
            child: AnimatedSwitcher(
              duration: ToviTokens.calm,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(animation), child: child),
              ),
              child: busy
                  ? SizedBox(
                      key: const ValueKey('busy'),
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: following ? ToviTokens.violet : Colors.white),
                    )
                  : Row(
                      key: ValueKey(following),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(following ? Icons.check_rounded : Icons.add_rounded, size: large ? 20 : 17, color: following ? ToviTokens.violet : Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          following ? copy.pick('متابَع', 'Following') : copy.pick('متابعة', 'Follow'),
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: large ? 15 : 13, color: following ? ToviTokens.violet : Colors.white),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Arabic counted nouns: 1 درس، 2 درسان، 3-10 دروس، 11+ درساً.
String lessonCount(Copy copy, int n, {bool free = false}) {
  if (!copy.arabic) return free ? '$n free ${n == 1 ? 'lesson' : 'lessons'}' : '$n ${n == 1 ? 'lesson' : 'lessons'}';
  if (n == 1) return free ? 'درس مجاني' : 'درس واحد';
  if (n == 2) return free ? 'درسان مجانيان' : 'درسان';
  if (n >= 3 && n <= 10) return free ? '$n دروس مجانية' : '$n دروس';
  return free ? '$n درساً مجانياً' : '$n درساً';
}

String countLabel(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
  return '$value';
}

/// Teacher card for the home carousel.
class TeacherCard extends StatelessWidget {
  const TeacherCard({super.key, required this.row, required this.copy, required this.onOpen, required this.onFollow, this.busy = false});
  final Map<String, dynamic> row;
  final Copy copy;
  final VoidCallback onOpen;
  final VoidCallback onFollow;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final id = asText(row['id']);
    final name = asText(row['name']);
    final subject = asText(row['subject']);
    final tone = toneFor(id);
    return Material(
      color: ToviTokens.surface,
      borderRadius: BorderRadius.circular(ToviTokens.radiusLg),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: onOpen,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0, 0.42, 0.42],
              colors: [tone[0].withValues(alpha: 0.14), tone[1].withValues(alpha: 0.06), ToviTokens.surface],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
            child: Column(
              children: [
                TeacherAvatar(id: id, name: name, photo: row['photoUrl'], size: 76),
                const SizedBox(height: 10),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: ToviTokens.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  subject.isEmpty ? copy.pick('معلّم', 'Teacher') : subject,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: tone[0], fontWeight: FontWeight.w700, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Tiny(icon: Icons.people_alt_rounded, text: countLabel(asInt(row['followers']))),
                    const SizedBox(width: 10),
                    _Tiny(icon: Icons.play_lesson_rounded, text: '${asInt(row['courses'])}'),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: Center(
                    child: FollowPill(following: row['following'] == true, busy: busy, copy: copy, onPressed: onFollow),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tiny extends StatelessWidget {
  const _Tiny({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: ToviTokens.muted),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(color: ToviTokens.muted, fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ],
    );
  }
}

/// Teacher row for the teachers and followed lists.
class TeacherTile extends StatelessWidget {
  const TeacherTile({super.key, required this.row, required this.copy, required this.onOpen, required this.onFollow, this.busy = false});
  final Map<String, dynamic> row;
  final Copy copy;
  final VoidCallback onOpen;
  final VoidCallback onFollow;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final id = asText(row['id']);
    final name = asText(row['name']);
    final subject = asText(row['subject']);
    final institute = asText(row['institute']);
    final tone = toneFor(id);
    return Material(
      color: ToviTokens.surface,
      borderRadius: BorderRadius.circular(ToviTokens.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              TeacherAvatar(id: id, name: name, photo: row['photoUrl'], size: 66),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: ToviTokens.ink),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (subject.isNotEmpty) _Chip(text: subject, color: tone[0]),
                        if (institute.isNotEmpty) _Chip(text: institute, color: ToviTokens.muted),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _Tiny(icon: Icons.people_alt_rounded, text: '${countLabel(asInt(row['followers']))} ${copy.pick('متابع', 'followers')}'),
                        const SizedBox(width: 10),
                        _Tiny(icon: Icons.play_lesson_rounded, text: '${asInt(row['courses'])} ${copy.pick('دورة', 'courses')}'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FollowPill(following: row['following'] == true, busy: busy, copy: copy, onPressed: onFollow),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color, this.light = false});
  final String text;
  final Color color;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: light ? Colors.white.withValues(alpha: 0.22) : color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999)),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: light ? Colors.white : color, fontWeight: FontWeight.w700, fontSize: 11.5),
      ),
    );
  }
}

/// Cover art for a course: the uploaded image, or a Tovi gradient with the
/// subject icon when there is none.
class CourseCover extends StatelessWidget {
  const CourseCover({super.key, required this.row, this.iconSize = 64});
  final Map<String, dynamic> row;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final tone = toneFor(asText(row['id']));
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: tone, begin: AlignmentDirectional.topStart, end: AlignmentDirectional.bottomEnd),
      ),
      child: CustomPaint(
        painter: _CoverPainter(),
        child: Align(
          alignment: const AlignmentDirectional(0.55, -0.2),
          child: Transform.rotate(
            angle: -math.pi / 14,
            child: Icon(subjectIcon(asText(row['subject'])), size: iconSize, color: Colors.white.withValues(alpha: 0.9)),
          ),
        ),
      ),
    );
    return NetImage(url: mediaUrl(row['coverUrl']), fallback: fallback);
  }
}

class _CoverPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final soft = Paint()..color = Colors.white.withValues(alpha: 0.10);
    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.36), size.height * 0.46, soft);
    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.36), size.height * 0.30, soft);
    canvas.drawCircle(Offset(size.width * 0.08, size.height * 0.10), size.height * 0.22, Paint()..color = Colors.white.withValues(alpha: 0.08));
    canvas.drawCircle(Offset(size.width * 0.58, size.height * 0.14), 4, Paint()..color = ToviTokens.sun);
    canvas.drawCircle(Offset(size.width * 0.30, size.height * 0.42), 2.5, Paint()..color = Colors.white.withValues(alpha: 0.7));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Course card: cover with a soft overlay, chips, title, teacher and counts.
class CourseCard extends StatelessWidget {
  const CourseCard({super.key, required this.row, required this.copy, required this.onTap, this.showTeacher = true, this.coverHeight = 124});
  final Map<String, dynamic> row;
  final Copy copy;
  final VoidCallback onTap;
  final bool showTeacher;
  final double coverHeight;

  @override
  Widget build(BuildContext context) {
    final title = asText(row['title']);
    final grade = asText(row['grade']);
    final subject = asText(row['subject']);
    final teacher = asText(row['teacherName']);
    final lessons = asInt(row['lessons']);
    final free = asInt(row['freeLessons']);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(ToviTokens.radiusLg), boxShadow: ToviTokens.raised),
      child: Material(
        color: ToviTokens.surface,
        borderRadius: BorderRadius.circular(ToviTokens.radiusLg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: coverHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CourseCover(row: row, iconSize: coverHeight * 0.42),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0x00000000), Color(0x8C17142B)], stops: [0, 0.45, 1]),
                      ),
                    ),
                    PositionedDirectional(
                      start: 10,
                      end: 10,
                      bottom: 10,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (grade.isNotEmpty) _Chip(text: grade, color: Colors.white, light: true),
                          if (subject.isNotEmpty) _Chip(text: subject, color: Colors.white, light: true),
                        ],
                      ),
                    ),
                    if (free > 0)
                      PositionedDirectional(
                        top: 10,
                        start: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: ToviTokens.sun,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 3))],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.lock_open_rounded, size: 13, color: ToviTokens.ink),
                              const SizedBox(width: 4),
                              Text(
                                lessonCount(copy, free, free: true),
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: ToviTokens.ink),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, height: 1.3, color: ToviTokens.ink),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (showTeacher && teacher.isNotEmpty) ...[
                          TeacherAvatar(id: asText(row['teacherId']), name: teacher, photo: row['teacherPhotoUrl'], size: 24, ring: 0),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              teacher,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: ToviTokens.inkSoft, fontWeight: FontWeight.w600, fontSize: 12.5),
                            ),
                          ),
                        ] else
                          const Spacer(),
                        _Tiny(icon: Icons.play_circle_outline_rounded, text: lessonCount(copy, lessons)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
