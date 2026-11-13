import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../progress_page.dart';
import '../session.dart';
import '../teacher_page.dart';
import '../ui.dart';
import 'exams.dart';
import 'hub_kit.dart';
import 'leaderboard.dart';
import 'places.dart';
import 'saved.dart';
import 'sessions.dart';
import 'tiles.dart';
import 'unlocked.dart';

/// The profile tab: photo, grade, stats, and every account destination.
class MePage extends StatefulWidget {
  const MePage({super.key, required this.session});
  final Session session;
  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> {
  Map<String, dynamic>? me;
  String privacy = '';
  String error = '';

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      final results = await Future.wait([widget.session.api.get('/api/student/account'), widget.session.api.get('/api/student/parameters')]);
      var link = '';
      for (final row in asMaps(results[1])) {
        if (row['key'] == 'privacy_url') link = asText(row['value']);
      }
      if (mounted) setState(() { me = asMap(results[0]); privacy = link; error = ''; });
    } catch (reason) {
      if (mounted) setState(() => error = hubError(reason, widget.session));
    }
  }

  Future<void> go(Widget page) async {
    await Navigator.push(context, toviRoute(page));
    if (mounted) load();
  }

  Future<void> signOut() async {
    final copy = widget.session.copy;
    final yes = await showToviSheet<bool>(
      context,
      (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SheetHandle(),
          Text(copy.pick('تسجيل الخروج؟', 'Sign out?'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          ToviButton(label: copy.pick('خروج', 'Sign out'), color: Tovi.danger, onPressed: () => Navigator.pop(context, true)),
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(copy.pick('إلغاء', 'Cancel'))),
        ]),
      ),
    );
    if (yes == true) await widget.session.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.session.copy;
    final s = widget.session;
    final row = me ?? const {};
    final name = '${asText(row['firstName'])} ${asText(row['lastName'])}'.trim();
    final stats = asMap(row['stats']);
    final place = [asText(row['grade']), asText(row['governorate'])].where((x) => x.isNotEmpty).join(' · ');
    return RefreshIndicator(
      color: ToviTokens.violet,
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 28), children: [
        if (me == null && error.isEmpty)
          const SkeletonFade(child: Bone(height: 210, radius: 28))
        else if (me == null)
          ErrorNote(text: error, onRetry: load)
        else ...[
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(colors: [ToviTokens.violet, Color(0xFF8E6BFF)], begin: AlignmentDirectional.topStart, end: AlignmentDirectional.bottomEnd),
              boxShadow: const [BoxShadow(color: Color(0x406A4CFF), blurRadius: 26, offset: Offset(0, 12))],
            ),
            child: Column(children: [
              Row(children: [
                GestureDetector(
                  onTap: () => go(AccountEditPage(session: s, me: row)),
                  child: Stack(clipBehavior: Clip.none, children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: HubFace(url: row['photoUrl'], name: name, size: 72),
                    ),
                    PositionedDirectional(
                      end: -2,
                      bottom: -2,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: const BoxDecoration(color: ToviTokens.sun, shape: BoxShape.circle),
                        child: const Icon(Icons.edit_rounded, size: 15, color: ToviTokens.ink),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name.isEmpty ? copy.brand : name, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(asText(row['phone']), textDirection: TextDirection.ltr, style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => go(AccountEditPage(session: s, me: row)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(99)),
                      child: Text(place.isEmpty ? copy.pick('حدّد مرحلتك ومحافظتك', 'Set your grade and city') : place, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ])),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                _Stat(value: '${asInt(stats['xp'])}', label: copy.pick('نقطة', 'XP'), icon: Icons.bolt_rounded),
                _Stat(value: '${asInt(stats['streak'])}', label: copy.pick('يوم متتالي', 'Streak'), icon: Icons.local_fire_department_rounded),
                _Stat(value: '${asInt(stats['courses'])}', label: copy.pick('دورة', 'Courses'), icon: Icons.menu_book_rounded),
                _Stat(value: '${asInt(stats['following'])}', label: copy.pick('متابَع', 'Following'), icon: Icons.people_alt_rounded),
              ]),
            ]),
          ),
          const SizedBox(height: 18),
          _Group(title: copy.pick('تعلّمي', 'My learning'), rows: [
            _Entry(Icons.quiz_rounded, ToviTokens.violet, copy.pick('اختباراتي', 'My exams'), () => go(ExamsPage(session: s))),
            _Entry(Icons.lock_open_rounded, ToviTokens.mint, copy.pick('اللي فعّلته', 'What I unlocked'), () => go(UnlockedPage(session: s))),
            _Entry(Icons.bookmark_rounded, ToviTokens.coral, copy.pick('المحفوظات والإعجابات', 'Saved and liked'), () => go(SavedPage(session: s))),
            _Entry(Icons.person_pin_rounded, ToviTokens.violet, copy.pick('المعلمون اللي أتابعهم', 'Teachers I follow'), () => go(TeachersPage(session: s, followingOnly: true))),
            _Entry(Icons.video_library_rounded, ToviTokens.sky, copy.pick('حصصي والإعادات', 'Sessions and replays'), () => go(Scaffold(backgroundColor: ToviTokens.page, body: SafeArea(child: SessionsHub(session: s, standalone: true))))),
          ]),
          const SizedBox(height: 14),
          _Group(title: copy.pick('النقاط والتحدي', 'Points and challenge'), rows: [
            _Entry(Icons.insights_rounded, ToviTokens.violet, copy.pick('تقدّمي ونقاطي', 'My progress and XP'), () => go(ProgressPage(session: s))),
            _Entry(Icons.emoji_events_rounded, const Color(0xFFE0A100), copy.pick('لوحة الصدارة', 'Leaderboard'), () => go(LeaderboardPage(session: s))),
          ]),
          const SizedBox(height: 14),
          _Group(title: copy.pick('استكشف', 'Explore'), rows: [
            _Entry(Icons.apartment_rounded, ToviTokens.sky, copy.pick('المعاهد', 'Institutes'), () => go(PlacesPage(session: s))),
          ]),
          const SizedBox(height: 14),
          _Group(title: copy.pick('الحساب', 'Account'), rows: [
            _Entry(Icons.manage_accounts_rounded, ToviTokens.violet, copy.pick('تعديل الملف', 'Edit profile'), () => go(AccountEditPage(session: s, me: row))),
            _Entry(Icons.password_rounded, ToviTokens.coral, copy.pick('تغيير كلمة المرور', 'Change password'), () => go(PasswordPage(session: s))),
            _Entry(Icons.language_rounded, ToviTokens.sky, copy.pick('English', 'العربية'), s.toggleLanguage),
            _Entry(Icons.privacy_tip_rounded, ToviTokens.muted, copy.privacy, privacy.isEmpty ? null : () => launchUrl(Uri.parse(privacy.startsWith('http') ? privacy : '${Session.base}$privacy'))),
          ]),
          const SizedBox(height: 14),
          SoftPanel(
            onTap: signOut,
            child: Row(children: [
              const IconOrb(icon: Icons.logout_rounded, color: ToviTokens.danger, size: 38),
              const SizedBox(width: 12),
              Text(copy.pick('خروج', 'Sign out'), style: const TextStyle(fontWeight: FontWeight.w800, color: ToviTokens.danger)),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.icon});
  final String value;
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Icon(icon, color: ToviTokens.sun, size: 20),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 11.5)),
        ]),
      );
}

class _Entry {
  const _Entry(this.icon, this.color, this.label, this.onTap);
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.rows});
  final String title;
  final List<_Entry> rows;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8), child: Text(title, style: const TextStyle(color: ToviTokens.muted, fontWeight: FontWeight.w800, fontSize: 13))),
      SoftPanel(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: [
          for (final row in rows)
            InkWell(
              onTap: row.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Row(children: [
                  IconOrb(icon: row.icon, color: row.onTap == null ? ToviTokens.faint : row.color, size: 38),
                  const SizedBox(width: 12),
                  Expanded(child: Text(row.label, style: TextStyle(fontWeight: FontWeight.w700, color: row.onTap == null ? ToviTokens.faint : ToviTokens.ink))),
                  const Icon(Icons.chevron_left_rounded, color: ToviTokens.faint),
                ]),
              ),
            ),
        ]),
      ),
    ]);
  }
}

/// Lists used by the grade, section and governorate pickers.
class Places {
  Places(this.grades, this.sections, this.governorates);
  final List<Map<String, dynamic>> grades;
  final List<Map<String, dynamic>> sections;
  final List<Map<String, dynamic>> governorates;

  static Future<Places> load(Session session) async {
    final r = await Future.wait([
      session.api.get('/api/student/grades'),
      session.api.get('/api/student/sections'),
      session.api.get('/api/student/governorates'),
    ]);
    return Places(asMaps(r[0]), asMaps(r[1]), asMaps(r[2]));
  }
}

/// Chips for picking one value; tapping the picked chip clears it.
class ChoiceWrap extends StatelessWidget {
  const ChoiceWrap({super.key, required this.rows, required this.value, required this.onChanged, this.color = ToviTokens.violet});
  final List<Map<String, dynamic>> rows;
  final String? value;
  final ValueChanged<String?> onChanged;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final row in rows)
        GestureDetector(
          onTap: () => onChanged(asText(row['id']) == value ? null : asText(row['id'])),
          child: AnimatedContainer(
            duration: still ? Duration.zero : ToviTokens.fast,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: asText(row['id']) == value ? color : ToviTokens.sunken,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (asText(row['id']) == value) ...[const Icon(Icons.check_rounded, size: 16, color: Colors.white), const SizedBox(width: 4)],
              Text(asText(row['name']), style: TextStyle(fontWeight: FontWeight.w700, color: asText(row['id']) == value ? Colors.white : ToviTokens.inkSoft)),
            ]),
          ),
        ),
    ]);
  }
}

/// Edit name, gender, grade, section, governorate and photo.
class AccountEditPage extends StatefulWidget {
  const AccountEditPage({super.key, required this.session, required this.me, this.onboarding = false});
  final Session session;
  final Map<String, dynamic> me;
  final bool onboarding;
  @override
  State<AccountEditPage> createState() => _AccountEditPageState();
}

class _AccountEditPageState extends State<AccountEditPage> {
  late final first = TextEditingController(text: asText(widget.me['firstName']));
  late final last = TextEditingController(text: asText(widget.me['lastName']));
  late String gender = asText(widget.me['gender']).isEmpty ? 'Unspecified' : asText(widget.me['gender']);
  late String? grade = asText(widget.me['gradeId']).isEmpty ? null : asText(widget.me['gradeId']);
  late String? section = asText(widget.me['sectionId']).isEmpty ? null : asText(widget.me['sectionId']);
  late String? governorate = asText(widget.me['governorateId']).isEmpty ? null : asText(widget.me['governorateId']);
  late Object? photo = widget.me['photoUrl'];
  Places? places;
  var busy = false;
  var uploading = false;
  String error = '';
  String nameError = '';

  @override
  void initState() {
    super.initState();
    Places.load(widget.session).then((value) { if (mounted) setState(() => places = value); }).catchError((Object reason) {
      if (mounted) setState(() => error = hubError(reason, widget.session));
    });
  }

  @override
  void dispose() { first.dispose(); last.dispose(); super.dispose(); }

  Future<void> pickPhoto() async {
    final copy = widget.session.copy;
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
      if (file == null) return;
      setState(() => uploading = true);
      final bytes = await file.readAsBytes();
      final name = file.name.isEmpty ? 'photo.jpg' : file.name;
      final result = asMap(await widget.session.api.uploadImage('/api/student/account/photo', 'photo', bytes, name));
      if (!mounted) return;
      setState(() { photo = result['photoUrl']; uploading = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(copy.pick('تحدثت صورتك', 'Your photo was updated'))));
    } catch (reason) {
      if (!mounted) return;
      setState(() => uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hubError(reason, widget.session))));
    }
  }

  Future<void> save() async {
    final copy = widget.session.copy;
    if (first.text.trim().length < 2) {
      setState(() => nameError = copy.pick('اكتب اسمك الأول (حرفين على الأقل).', 'Write your first name (2 letters or more).'));
      return;
    }
    setState(() { busy = true; error = ''; nameError = ''; });
    try {
      await widget.session.api.put('/api/student/account', {
        'firstName': first.text.trim(),
        'lastName': last.text.trim(),
        'gender': gender,
        'gradeId': grade,
        'sectionId': section,
        'governorateId': governorate,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(copy.pick('انحفظت التعديلات', 'Changes saved'))));
      Navigator.pop(context, true);
    } catch (reason) {
      if (mounted) setState(() { error = hubError(reason, widget.session); busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.session.copy;
    final name = '${first.text} ${last.text}'.trim();
    final head = Text(copy.pick('خلّينا نعرفك أكثر', 'Tell us about you'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900));
    final body = ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 28), children: [
      if (widget.onboarding) ...[
        head,
        const SizedBox(height: 6),
        Text(copy.pick('اختار مرحلتك حتى نطلعلك الدورات والمعلمين المناسبين إلك.', 'Pick your grade so we show the right courses and teachers.'), style: const TextStyle(color: ToviTokens.muted, height: 1.5)),
        const SizedBox(height: 18),
      ],
      Center(
        child: GestureDetector(
          onTap: uploading ? null : pickPhoto,
          child: Stack(clipBehavior: Clip.none, children: [
            HubFace(url: photo, name: name, size: 104, ring: true),
            if (uploading) const Positioned.fill(child: Center(child: CircularProgressIndicator(color: ToviTokens.violet))),
            PositionedDirectional(
              end: 0,
              bottom: 4,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: ToviTokens.violet, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                child: const Icon(Icons.photo_camera_rounded, size: 17, color: Colors.white),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      Center(child: Text(copy.pick('اضغط لتغيير الصورة', 'Tap to change the photo'), style: const TextStyle(color: ToviTokens.muted, fontSize: 12.5))),
      const SizedBox(height: 18),
      TextField(controller: first, onChanged: (_) => setState(() => nameError = ''), decoration: toviField(copy.pick('الاسم الأول', 'First name')).copyWith(errorText: nameError.isEmpty ? null : nameError)),
      const SizedBox(height: 10),
      TextField(controller: last, onChanged: (_) => setState(() {}), decoration: toviField(copy.pick('اسم الأب أو اللقب', 'Last name'))),
      const SizedBox(height: 18),
      _Label(copy.pick('الجنس', 'Gender')),
      ChoiceWrap(
        rows: [
          {'id': 'Male', 'name': copy.pick('ذكر', 'Male')},
          {'id': 'Female', 'name': copy.pick('أنثى', 'Female')},
        ],
        value: gender,
        onChanged: (v) => setState(() => gender = v ?? 'Unspecified'),
      ),
      const SizedBox(height: 18),
      if (places == null && error.isEmpty)
        const SkeletonFade(child: Column(children: [Bone(height: 40), SizedBox(height: 10), Bone(height: 40), SizedBox(height: 10), Bone(height: 40)]))
      else if (places != null) ...[
        _Label(copy.pick('المرحلة الدراسية', 'Grade')),
        ChoiceWrap(rows: places!.grades, value: grade, onChanged: (v) => setState(() => grade = v)),
        if (places!.sections.isNotEmpty) ...[
          const SizedBox(height: 18),
          _Label(copy.pick('الفرع', 'Section')),
          ChoiceWrap(rows: places!.sections, value: section, color: ToviTokens.coral, onChanged: (v) => setState(() => section = v)),
        ],
        const SizedBox(height: 18),
        _Label(copy.pick('المحافظة', 'Governorate')),
        ChoiceWrap(rows: places!.governorates, value: governorate, color: ToviTokens.sky, onChanged: (v) => setState(() => governorate = v)),
      ],
      if (error.isNotEmpty) ...[const SizedBox(height: 14), Text(error, style: const TextStyle(color: ToviTokens.danger, fontWeight: FontWeight.w600))],
      const SizedBox(height: 24),
      ToviButton(label: widget.onboarding ? copy.pick('يلا نبدأ', "Let's start") : copy.pick('حفظ التعديلات', 'Save changes'), color: ToviTokens.violet, busy: busy, onPressed: busy ? null : save),
      if (widget.onboarding)
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(copy.pick('بعدين', 'Later'), style: const TextStyle(color: ToviTokens.muted))),
    ]);
    return HubScaffold(title: widget.onboarding ? copy.brand : copy.pick('تعديل الملف', 'Edit profile'), body: body);
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, color: ToviTokens.inkSoft)));
}

/// Change the password while signed in.
class PasswordPage extends StatefulWidget {
  const PasswordPage({super.key, required this.session});
  final Session session;
  @override
  State<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends State<PasswordPage> {
  final current = TextEditingController();
  final next = TextEditingController();
  final again = TextEditingController();
  var hide = true;
  var busy = false;
  String error = '';

  @override
  void dispose() { current.dispose(); next.dispose(); again.dispose(); super.dispose(); }

  String? get mismatch => again.text.isNotEmpty && again.text != next.text ? widget.session.copy.pick('الكلمتين مو متطابقات', 'The passwords do not match') : null;
  String? get short => next.text.isNotEmpty && next.text.length < 8 ? widget.session.copy.pick('8 خانات على الأقل', 'At least 8 characters') : null;

  Future<void> submit() async {
    final copy = widget.session.copy;
    if (current.text.isEmpty || next.text.length < 8 || next.text != again.text) {
      setState(() => error = copy.pick('عبّي الحقول بشكل صحيح.', 'Fill the fields correctly.'));
      return;
    }
    setState(() { busy = true; error = ''; });
    try {
      await widget.session.api.post('/api/student/account/password', {'current': current.text, 'next': next.text});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(copy.pick('تغيّرت كلمة المرور، وانسجلت الأجهزة الثانية خروج.', 'Password changed. Other devices were signed out.'))));
      Navigator.pop(context);
    } catch (reason) {
      final code = reason is ApiException ? reason.code : '';
      if (mounted) {
        setState(() {
          busy = false;
          error = switch (code) {
            'password_wrong' => copy.pick('كلمة المرور الحالية غلط.', 'The current password is wrong.'),
            'password_same' => copy.pick('اختار كلمة مختلفة عن الحالية.', 'Choose a password different from the current one.'),
            _ => hubError(reason, widget.session),
          };
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.session.copy;
    Widget eye() => IconButton(onPressed: () => setState(() => hide = !hide), icon: Icon(hide ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: ToviTokens.muted));
    return HubScaffold(
      title: copy.pick('تغيير كلمة المرور', 'Change password'),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 28), children: [
        const Center(child: IconOrb(icon: Icons.shield_rounded, color: ToviTokens.violet, size: 72)),
        const SizedBox(height: 18),
        TextField(controller: current, obscureText: hide, decoration: toviField(copy.pick('كلمة المرور الحالية', 'Current password')).copyWith(suffixIcon: eye())),
        const SizedBox(height: 10),
        TextField(controller: next, obscureText: hide, onChanged: (_) => setState(() {}), decoration: toviField(copy.pick('كلمة المرور الجديدة', 'New password')).copyWith(errorText: short, suffixIcon: eye())),
        const SizedBox(height: 10),
        TextField(controller: again, obscureText: hide, onChanged: (_) => setState(() {}), decoration: toviField(copy.pick('أعد كتابتها', 'Repeat it')).copyWith(errorText: mismatch)),
        if (error.isNotEmpty) ...[const SizedBox(height: 12), Text(error, style: const TextStyle(color: ToviTokens.danger, fontWeight: FontWeight.w600))],
        const SizedBox(height: 22),
        ToviButton(label: copy.pick('تغيير', 'Change'), color: ToviTokens.violet, busy: busy, onPressed: busy ? null : submit),
      ]),
    );
  }
}

/// After sign-up, ask once for grade, section and governorate if they are missing.
Future<void> maybeOnboard(BuildContext context, Session session) async {
  final key = 'tovi-onboarded-${session.token.hashCode}';
  if (session.prefs.getBool(key) == true) return;
  try {
    final me = asMap(await session.api.get('/api/student/account'));
    await session.prefs.setBool(key, true);
    if (asText(me['gradeId']).isNotEmpty || !context.mounted) return;
    await Navigator.push(context, toviRoute(AccountEditPage(session: session, me: me, onboarding: true)));
  } catch (_) {}
}
