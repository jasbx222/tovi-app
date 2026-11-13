import 'package:material_ui/material_ui.dart';

class Tovi {
  static const canvas = Color(0xFF6C5CE7);
  static const canvasDeep = Color(0xFF5846D6);
  static const ink = Color(0xFF1B1730);
  static const muted = Color(0xFF6F6A86);
  static const line = Color(0xFFEEEAF6);
  static const surface = Color(0xFFFFFFFF);
  static const lilac = Color(0xFFF3F0FF);
  static const field = Color(0xFFF4F2FB);
  static const blue = Color(0xFF3E7BFA);
  static const apricot = Color(0xFFFF8A3C);
  static const violet = Color(0xFF6C5CE7);
  static const night = Color(0xFF171422);
  static const danger = Color(0xFFD94B5A);
  static const ok = Color(0xFF0E8F6B);

  static const courses = <Color>[
    Color(0xFFFF9B45),
    Color(0xFF7D8CFF),
    Color(0xFF6C5CE7),
    Color(0xFF2F9E8F),
    Color(0xFFE06A6A),
  ];

  static const shadow = <BoxShadow>[
    BoxShadow(color: Color(0x121B1730), blurRadius: 24, offset: Offset(0, 10)),
  ];
}

class ToviMark extends StatelessWidget {
  const ToviMark({super.key, this.size = 48, this.onViolet = false});

  final double size;
  final bool onViolet;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: onViolet ? Colors.white : Tovi.violet,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Text(
        'T',
        style: TextStyle(
          color: onViolet ? Tovi.violet : Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.46,
          height: 1,
        ),
      ),
    );
  }
}

class CircleButton extends StatelessWidget {
  const CircleButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.background,
    this.foreground,
    this.badge,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? background;
  final Color? foreground;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: background ?? Tovi.field,
        foregroundColor: foreground ?? Tovi.ink,
        fixedSize: const Size(44, 44),
        minimumSize: const Size(44, 44),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const CircleBorder(),
      ),
      icon: Icon(icon, size: 20),
    );
    if (badge == null || badge!.isEmpty) return button;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        PositionedDirectional(
          top: -2,
          end: -2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(color: Tovi.apricot, borderRadius: BorderRadius.circular(99)),
            child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

class ToviHeader extends StatelessWidget {
  const ToviHeader({super.key, required this.title, this.onBack, this.action, this.light = false, this.safe = true});

  final String title;
  final VoidCallback? onBack;
  final Widget? action;
  final bool light;
  final bool safe;

  @override
  Widget build(BuildContext context) {
    final color = light ? Colors.white : Tovi.ink;
    final bar = SizedBox(
      height: 60,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            if (onBack != null)
              CircleButton(
                icon: Icons.arrow_back_ios_new_rounded,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: onBack,
                background: light ? Colors.white : Tovi.field,
                foreground: Tovi.ink,
              )
            else
              const SizedBox(width: 44),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            action ?? const SizedBox(width: 44),
          ],
        ),
      ),
    );
    if (!safe) return bar;
    return SafeArea(bottom: false, child: bar);
  }
}

class ToviTab {
  const ToviTab(this.icon, this.label);
  final IconData icon;
  final String label;
}

class ToviBar extends StatelessWidget {
  const ToviBar({super.key, required this.index, required this.tabs, required this.onSelect});

  final int index;
  final List<ToviTab> tabs;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Tovi.surface,
        boxShadow: [BoxShadow(color: Color(0x141B1730), blurRadius: 18, offset: Offset(0, -6))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: index == i,
                    label: tabs[i].label,
                    child: InkWell(
                      onTap: () => onSelect(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 180),
                            width: index == i ? 18 : 0,
                            height: 3,
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(color: Tovi.violet, borderRadius: BorderRadius.circular(99)),
                          ),
                          Icon(tabs[i].icon, size: 24, color: index == i ? Tovi.violet : const Color(0xFFB7B3C9)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ToviButton extends StatelessWidget {
  const ToviButton({super.key, required this.label, required this.onPressed, this.busy = false, this.color = Tovi.ink});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: 0.45),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'IBM Plex Sans Arabic'),
        ),
        child: busy
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
            : Text(label),
      ),
    );
  }
}

class StatPill extends StatelessWidget {
  const StatPill({super.key, required this.color, required this.icon, required this.label, required this.value});

  final Color color;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(22)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 8),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, height: 1.1)),
        ],
      ),
    );
  }
}

class SectionHead extends StatelessWidget {
  const SectionHead({super.key, required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 12),
      child: Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Tovi.ink))),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: Tovi.violet, padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(44, 36)),
              child: Text(action!, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

class CoursePoster extends StatelessWidget {
  const CoursePoster({super.key, required this.title, required this.color, required this.onTap, this.meta = ''});

  final String title;
  final String meta;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, height: 1.3)),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(meta, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.86), fontSize: 12, height: 1.35)),
              ],
              const Spacer(),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: Icon(Icons.arrow_forward_ios_rounded, size: 13, color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SoftPanel extends StatelessWidget {
  const SoftPanel({super.key, required this.child, this.color = Tovi.surface, this.onTap, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final Color color;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: color == Tovi.surface ? Tovi.shadow : null),
      child: Material(
        color: color,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? Padding(padding: padding, child: child)
            : InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

class EmptyNote extends StatelessWidget {
  const EmptyNote({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Tovi.lilac, shape: BoxShape.circle),
            child: Icon(icon, color: Tovi.violet, size: 28),
          ),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Tovi.muted, fontSize: 15, height: 1.5)),
        ],
      ),
    );
  }
}

class ErrorNote extends StatelessWidget {
  const ErrorNote({super.key, required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: Tovi.danger, size: 36),
          const SizedBox(height: 10),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Tovi.danger, height: 1.45)),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: Text(Directionality.of(context) == TextDirection.rtl ? 'إعادة المحاولة' : 'Try again')),
          ],
        ],
      ),
    );
  }
}

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        margin: const EdgeInsets.only(top: 10, bottom: 16),
        decoration: BoxDecoration(color: const Color(0xFFE4E0F2), borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
}

class SessionChart extends StatelessWidget {
  const SessionChart({super.key, required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      width: double.infinity,
      child: CustomPaint(painter: _SessionChartPainter(values), child: const SizedBox.expand()),
    );
  }
}

class _SessionChartPainter extends CustomPainter {
  _SessionChartPainter(this.values);
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || size.width < 8) return;
    final maxValue = values.fold<double>(1, (max, value) => value > max ? value : max);
    final step = values.length == 1 ? 0.0 : (size.width - 28) / (values.length - 1);
    final points = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(14 + step * i, size.height - 16 - (values[i] / maxValue) * (size.height - 36)),
    ];
    final grid = Paint()..color = Colors.white.withValues(alpha: 0.08)..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final y = 12 + (size.height - 28) * i / 2;
      canvas.drawLine(Offset(8, y), Offset(size.width - 8, y), grid);
    }
    if (points.length > 1) {
      final line = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, line);
    }
    final dot = Paint()..color = const Color(0xFFC4B5FD);
    for (final point in points) {
      canvas.drawCircle(point, 5, dot);
      canvas.drawCircle(point, 2.2, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _SessionChartPainter oldDelegate) => oldDelegate.values != values;
}

class BoardArt extends StatelessWidget {
  const BoardArt({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _BoardArtPainter(), child: const SizedBox.expand());
  }
}

class _BoardArtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final blob = Paint()..color = Colors.white.withValues(alpha: 0.08);
    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.12), 70, blob);
    canvas.drawCircle(Offset(size.width * 0.08, size.height * 0.85), 54, blob);
    canvas.save();
    canvas.translate(size.width * 0.46, size.height * 0.52);
    canvas.rotate(-0.1);
    canvas.translate(-size.width * 0.46, -size.height * 0.52);
    final board = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.22, size.height * 0.16, size.width * 0.42, size.height * 0.62),
      const Radius.circular(18),
    );
    canvas.drawRRect(board, Paint()..color = const Color(0xFF7D70F2));
    final line = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final left = size.width * 0.30;
    final top = size.height * 0.34;
    canvas.drawLine(Offset(left, top), Offset(left + size.width * 0.18, top + size.height * 0.18), line);
    canvas.drawLine(Offset(left + size.width * 0.18, top + size.height * 0.18), Offset(left + size.width * 0.06, top + size.height * 0.30), line);
    canvas.restore();
    canvas.drawCircle(Offset(size.width * 0.74, size.height * 0.32), 18, Paint()..color = const Color(0xFFFFB15A));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SkeletonFade extends StatefulWidget {
  const SkeletonFade({super.key, required this.child});
  final Widget child;

  @override
  State<SkeletonFade> createState() => _SkeletonFadeState();
}

class _SkeletonFadeState extends State<SkeletonFade> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return FadeTransition(opacity: Tween<double>(begin: 0.45, end: 1).animate(_controller), child: widget.child);
  }
}

class Bone extends StatelessWidget {
  const Bone({super.key, this.width, this.height = 16, this.radius = 12});
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: const Color(0xFFE7E3F4), borderRadius: BorderRadius.circular(radius)),
    );
  }
}

InputDecoration toviField(String label, {String? hint, IconData? icon}) {
  final border = OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none);
  return InputDecoration(
    labelText: label.isEmpty ? null : label,
    hintText: hint,
    prefixIcon: icon == null ? null : Icon(icon, size: 20),
    filled: true,
    fillColor: Tovi.field,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: border,
    enabledBorder: border,
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Tovi.violet, width: 1.6)),
  );
}

Future<T?> showToviSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Tovi.surface,
    barrierColor: const Color(0x801B1730),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (sheetContext) {
      final inset = MediaQuery.viewInsetsOf(sheetContext).bottom;
      return Padding(padding: EdgeInsets.only(bottom: inset), child: builder(sheetContext));
    },
  );
}

String asText(Object? value) => value == null ? '' : '$value'.trim();

int asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(asText(value)) ?? 0;
}

DateTime? asDate(Object? value) {
  final text = asText(value);
  if (text.isEmpty) return null;
  return DateTime.tryParse(text)?.toLocal();
}

Map<String, dynamic> asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return {};
}

List<Map<String, dynamic>> asMaps(Object? value) {
  if (value is! List) return [];
  return [for (final item in value) if (item is Map) Map<String, dynamic>.from(item)];
}

String firstMeta(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final text = asText(row[key]);
    if (text.isNotEmpty) return text;
  }
  return '';
}

Route<T> toviRoute<T>(Widget page) => MaterialPageRoute<T>(builder: (_) => page);
