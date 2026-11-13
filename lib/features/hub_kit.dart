import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../session.dart';
import '../student_rules.dart';
import '../ui.dart';

/// Extra calls the newer student screens need on top of [ToviApi].
extension HubApi on ToviApi {
  Future<dynamic> sendDelete(String path) async {
    final request = http.Request('DELETE', Uri.parse('$base$path'));
    if (token.isNotEmpty) request.headers['Authorization'] = 'Bearer $token';
    return _read(await http.Response.fromStream(await request.send()));
  }

  Future<dynamic> uploadImage(String path, String field, List<int> bytes, String filename) async {
    final request = http.MultipartRequest('POST', Uri.parse('$base$path'));
    if (token.isNotEmpty) request.headers['Authorization'] = 'Bearer $token';
    final lower = filename.toLowerCase();
    final type = lower.endsWith('.png') ? 'png' : lower.endsWith('.webp') ? 'webp' : 'jpeg';
    request.files.add(http.MultipartFile.fromBytes(field, bytes, filename: filename, contentType: MediaType('image', type)));
    return _read(await http.Response.fromStream(await request.send()));
  }

  dynamic _read(http.Response response) {
    if (response.statusCode == 204) return null;
    final data = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 400) {
      final map = data is Map ? data : const {};
      if (response.statusCode == 401) onUnauthorized?.call();
      throw ApiException(response.statusCode, '${map['error'] ?? 'error'}', '${map['message'] ?? 'Request failed'}');
    }
    return data;
  }
}

/// Bearer token sent with Tovi file requests, because some files (like institute logos) are private.
String hubImageToken = '';

/// Turns a server file path like `/api/files/<id>` into a full URL.
String? fileUrl(Object? value) {
  final text = asText(value);
  if (text.isEmpty) return null;
  if (text.startsWith('http')) return text;
  return '${Session.base}$text';
}

String hubError(Object reason, Session session) {
  if (reason is ApiException) return studentMessage(reason.code, reason.message, session.copy.arabic);
  return session.copy.pick('تعذّر الاتصال بالخادم. تأكد من الإنترنت.', 'Could not reach the server. Check your connection.');
}

const hubGradients = <List<Color>>[
  [Color(0xFF6A4CFF), Color(0xFF9B7BFF)],
  [Color(0xFFFF6B57), Color(0xFFFFA26B)],
  [Color(0xFF3D8BFF), Color(0xFF6A4CFF)],
  [Color(0xFF14A37F), Color(0xFF3D8BFF)],
  [Color(0xFFFFC23D), Color(0xFFFF6B57)],
];

List<Color> hubGradientFor(String seed) {
  var hash = 0;
  for (final unit in seed.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return hubGradients[hash % hubGradients.length];
}

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return 'ت';
  if (parts.length == 1) return parts.first.characters.first;
  return '${parts.first.characters.first}${parts[1].characters.first}';
}

/// A network image with a branded gradient while loading and when the image is missing.
class HubPhoto extends StatelessWidget {
  const HubPhoto({super.key, required this.url, required this.seed, this.radius = 18, this.icon, this.fit = BoxFit.cover, this.label});

  final Object? url;
  final String seed;
  final double radius;
  final IconData? icon;
  final BoxFit fit;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final link = fileUrl(url);
    final colors = hubGradientFor(seed);
    final fallback = DecoratedBox(
      decoration: BoxDecoration(gradient: LinearGradient(colors: colors, begin: AlignmentDirectional.topStart, end: AlignmentDirectional.bottomEnd)),
      child: Stack(children: [
        PositionedDirectional(end: -18, top: -18, child: Container(width: 86, height: 86, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.14)))),
        PositionedDirectional(start: -10, bottom: -22, child: Container(width: 64, height: 64, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.10)))),
        Center(
          child: label != null
              ? Text(label!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20))
              : Icon(icon ?? Icons.auto_stories_rounded, color: Colors.white.withValues(alpha: 0.9), size: 30),
        ),
      ]),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: link == null
          ? fallback
          : Image.network(
              link,
              headers: hubImageToken.isNotEmpty && link.startsWith(Session.base) ? {'Authorization': 'Bearer $hubImageToken'} : null,
              fit: fit,
              width: double.infinity,
              height: double.infinity,
              frameBuilder: (context, child, frame, sync) {
                if (sync || frame != null) return child;
                return Stack(fit: StackFit.expand, children: [fallback, const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))]);
              },
              errorBuilder: (context, error, stack) => fallback,
            ),
    );
  }
}

/// A round person photo; shows the person's initials on a gradient when there is no photo.
class HubFace extends StatelessWidget {
  const HubFace({super.key, required this.url, required this.name, this.size = 44, this.ring = false});

  final Object? url;
  final String name;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final inner = SizedBox(
      width: size,
      height: size,
      child: HubPhoto(url: url, seed: name, radius: size, label: initialsOf(name)),
    );
    if (!ring) return inner;
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [ToviTokens.violet, ToviTokens.coral])),
      child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: inner),
    );
  }
}

/// A skeleton shaped like a list of rows.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.rows = 5, this.height = 84});
  final int rows;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SkeletonFade(
      child: Column(children: [
        for (var i = 0; i < rows; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              Bone(width: height - 16, height: height - 16, radius: 18),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Bone(width: 180 - i * 12.0, height: 14),
                const SizedBox(height: 10),
                const Bone(width: 110, height: 12),
              ])),
            ]),
          ),
      ]),
    );
  }
}

/// Empty state with a gradient orb and an optional action.
class HubEmpty extends StatelessWidget {
  const HubEmpty({super.key, required this.icon, required this.title, this.body, this.action, this.onAction});
  final IconData icon;
  final String title;
  final String? body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 12),
      child: Column(children: [
        Container(
          width: 96,
          height: 96,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [Color(0xFF9B7BFF), ToviTokens.violet], center: Alignment(-0.3, -0.4)),
            boxShadow: [BoxShadow(color: Color(0x406A4CFF), blurRadius: 28, offset: Offset(0, 12))],
          ),
          child: Stack(children: [
            const Positioned(right: 10, top: 12, child: CircleAvatar(radius: 6, backgroundColor: ToviTokens.sun)),
            Center(child: Icon(icon, color: Colors.white, size: 40)),
          ]),
        ),
        const SizedBox(height: 18),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ToviTokens.ink)),
        if (body != null) ...[
          const SizedBox(height: 6),
          Text(body!, textAlign: TextAlign.center, style: const TextStyle(color: ToviTokens.muted, height: 1.5)),
        ],
        if (action != null && onAction != null) ...[
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(backgroundColor: ToviTokens.violet, shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12)),
            child: Text(action!, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ]),
    );
  }
}

/// One page of a server list: `{items, page, total, hasMore}`.
typedef PageLoader = Future<dynamic> Function(int page);

/// An infinite-scroll list with pull to refresh, list skeleton, empty and error states.
class PagedList extends StatefulWidget {
  const PagedList({
    super.key,
    required this.session,
    required this.load,
    required this.itemBuilder,
    required this.empty,
    this.header,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 28),
    this.skeletonHeight = 84,
    this.grid = false,
    this.onPage,
  });

  final Session session;
  final PageLoader load;
  final Widget Function(BuildContext context, Map<String, dynamic> row, int index, VoidCallback refresh) itemBuilder;
  final Widget empty;
  final Widget? header;
  final EdgeInsets padding;
  final double skeletonHeight;
  final bool grid;
  final void Function(Map<String, dynamic> page)? onPage;

  @override
  State<PagedList> createState() => PagedListState();
}

class PagedListState extends State<PagedList> {
  final items = <Map<String, dynamic>>[];
  final scroll = ScrollController();
  var page = 0;
  var more = true;
  var busy = false;
  var first = true;
  String error = '';

  @override
  void initState() {
    super.initState();
    scroll.addListener(() {
      if (scroll.position.pixels > scroll.position.maxScrollExtent - 320) next();
    });
    next();
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    setState(() { items.clear(); page = 0; more = true; first = true; error = ''; });
    await next();
  }

  Future<void> next() async {
    if (busy || !more) return;
    busy = true;
    try {
      final data = asMap(await widget.load(page + 1));
      if (!mounted) return;
      widget.onPage?.call(data);
      final rows = asMaps(data['items']);
      setState(() {
        page += 1;
        items.addAll(rows);
        more = data['hasMore'] == true || (data['hasMore'] == null && rows.isNotEmpty && items.length < asInt(data['total']));
        error = '';
        first = false;
      });
    } catch (reason) {
      if (mounted) setState(() { error = hubError(reason, widget.session); first = false; });
    } finally {
      busy = false;
    }
  }

  void replace(int index, Map<String, dynamic> row) => setState(() => items[index] = row);
  void removeAt(int index) => setState(() => items.removeAt(index));

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      if (widget.header != null) widget.header!,
      if (first)
        ListSkeleton(height: widget.skeletonHeight)
      else if (items.isEmpty && error.isNotEmpty)
        ErrorNote(text: error, onRetry: refresh)
      else if (items.isEmpty)
        widget.empty
      else if (widget.grid)
        LayoutBuilder(builder: (context, box) {
          final columns = box.maxWidth > 640 ? 3 : 2;
          final width = (box.maxWidth - (columns - 1) * 12) / columns;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            for (var i = 0; i < items.length; i++) SizedBox(width: width, child: widget.itemBuilder(context, items[i], i, refresh)),
          ]);
        })
      else
        for (var i = 0; i < items.length; i++) Padding(padding: const EdgeInsets.only(bottom: 12), child: widget.itemBuilder(context, items[i], i, refresh)),
      if (!first && items.isNotEmpty && more)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: error.isNotEmpty
              ? TextButton(onPressed: next, child: Text(widget.session.copy.pick('تحميل المزيد', 'Load more')))
              : const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: ToviTokens.violet))),
        ),
    ];
    return RefreshIndicator(
      color: ToviTokens.violet,
      onRefresh: refresh,
      child: ListView(controller: scroll, physics: const AlwaysScrollableScrollPhysics(), padding: widget.padding, children: children),
    );
  }
}

/// Pill tabs used across the new screens.
class HubSegments extends StatelessWidget {
  const HubSegments({super.key, required this.labels, required this.index, required this.onChanged, this.counts});
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final List<int?>? counts;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (var i = 0; i < labels.length; i++)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: still ? Duration.zero : ToviTokens.calm,
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: i == index ? ToviTokens.violet : ToviTokens.surface,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: i == index ? const [BoxShadow(color: Color(0x406A4CFF), blurRadius: 14, offset: Offset(0, 6))] : ToviTokens.raised,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(labels[i], style: TextStyle(fontWeight: FontWeight.w700, color: i == index ? Colors.white : ToviTokens.inkSoft)),
                  if (counts != null && i < counts!.length && counts![i] != null && counts![i]! > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                      decoration: BoxDecoration(color: i == index ? Colors.white.withValues(alpha: 0.24) : ToviTokens.violetSoft, borderRadius: BorderRadius.circular(99)),
                      child: Text('${counts![i]}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: i == index ? Colors.white : ToviTokens.violet)),
                    ),
                  ],
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

/// A page scaffold with the Tovi header.
class HubScaffold extends StatelessWidget {
  const HubScaffold({super.key, required this.title, required this.body, this.action});
  final String title;
  final Widget body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ToviTokens.page,
      body: Column(children: [
        ToviHeader(title: title, onBack: () => Navigator.maybePop(context), action: action),
        Expanded(child: body),
      ]),
    );
  }
}

String shortDate(DateTime when, bool arabic) {
  const ar = ['كانون الثاني', 'شباط', 'آذار', 'نيسان', 'أيار', 'حزيران', 'تموز', 'آب', 'أيلول', 'تشرين الأول', 'تشرين الثاني', 'كانون الأول'];
  const en = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${when.day} ${(arabic ? ar : en)[when.month - 1]}';
}

String hourOf(DateTime when, bool arabic) {
  final hour = when.hour % 12 == 0 ? 12 : when.hour % 12;
  final suffix = when.hour < 12 ? (arabic ? 'ص' : 'am') : (arabic ? 'م' : 'pm');
  return '$hour:${when.minute.toString().padLeft(2, '0')} $suffix';
}

String agoOf(DateTime when, bool arabic) {
  final gap = DateTime.now().difference(when);
  if (gap.inMinutes < 1) return arabic ? 'الآن' : 'now';
  if (gap.inMinutes < 60) return arabic ? 'قبل ${gap.inMinutes} د' : '${gap.inMinutes}m ago';
  if (gap.inHours < 24) return arabic ? 'قبل ${gap.inHours} س' : '${gap.inHours}h ago';
  return shortDate(when, arabic);
}

/// Runs [action] after the user stops typing.
class Debounce {
  Debounce(this.wait);
  final Duration wait;
  Timer? _timer;
  void call(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(wait, action);
  }

  void dispose() => _timer?.cancel();
}
