import 'dart:math' as math;

import 'package:flutter/services.dart' show FilteringTextInputFormatter, LengthLimitingTextInputFormatter, TextEditingValue, TextInputFormatter, TextSelection;
import 'package:material_ui/material_ui.dart';

import 'ui.dart';

/// True when the platform asks for reduced motion.
bool calmMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

Duration motion(BuildContext context, Duration value) => calmMotion(context) ? Duration.zero : value;

/// AnimatedSize that steps straight to the new size under reduced motion.
class SizeMotion extends StatelessWidget {
  const SizeMotion({super.key, required this.duration, required this.child, this.alignment = Alignment.center});
  final Duration duration;
  final Widget child;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    if (duration == Duration.zero) return child;
    return AnimatedSize(duration: duration, curve: Curves.easeOutCubic, alignment: alignment, child: child);
  }
}

/// The Tovi planet: a soft violet sphere with a tilted ring and a small sun moon.
/// It floats and the moon orbits slowly; with reduced motion it stays still.
class ToviOrb extends StatefulWidget {
  const ToviOrb({super.key, this.size = 128});
  final double size;

  @override
  State<ToviOrb> createState() => _ToviOrbState();
}

class _ToviOrbState extends State<ToviOrb> with SingleTickerProviderStateMixin {
  late final AnimationController clock = AnimationController(vsync: this, duration: const Duration(seconds: 14));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (calmMotion(context)) {
      clock.stop();
      clock.value = 0.18;
    } else if (!clock.isAnimating) {
      clock.repeat();
    }
  }

  @override
  void dispose() {
    clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: clock,
        builder: (context, _) {
          final t = clock.value;
          final float = calmMotion(context) ? 0.0 : math.sin(t * math.pi * 4) * 4;
          return Transform.translate(
            offset: Offset(0, float),
            child: CustomPaint(size: Size.square(widget.size * 1.5), painter: _OrbPainter(t)),
          );
        },
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 3;
    final angle = t * math.pi * 2;
    final ring = Rect.fromCenter(center: c, width: r * 2.9, height: r * 0.9);
    final tilt = -0.32;

    // Glow behind the planet.
    canvas.drawCircle(
      c,
      r * 1.35,
      Paint()..shader = RadialGradient(colors: [Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: r * 1.35)),
    );

    void ringHalf(bool back) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(tilt);
      canvas.translate(-c.dx, -c.dy);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.11
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: back ? 0.30 : 0.75);
      canvas.drawArc(ring, back ? math.pi : 0, math.pi, false, paint);
      canvas.restore();
    }

    Offset moonAt() {
      final local = Offset(c.dx + math.cos(angle) * ring.width / 2, c.dy + math.sin(angle) * ring.height / 2);
      final d = local - c;
      return c + Offset(d.dx * math.cos(tilt) - d.dy * math.sin(tilt), d.dx * math.sin(tilt) + d.dy * math.cos(tilt));
    }

    final moonInFront = math.sin(angle) > 0;
    void moon() {
      final m = moonAt();
      final mr = r * 0.2;
      canvas.drawCircle(m, mr * 1.9, Paint()..color = ToviTokens.sun.withValues(alpha: 0.18));
      canvas.drawCircle(
        m,
        mr,
        Paint()..shader = RadialGradient(center: const Alignment(-0.4, -0.4), colors: const [Color(0xFFFFE08A), ToviTokens.sun]).createShader(Rect.fromCircle(center: m, radius: mr)),
      );
    }

    ringHalf(true);
    if (!moonInFront) moon();

    // Planet body.
    final body = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()..shader = const RadialGradient(center: Alignment(-0.35, -0.45), radius: 1.0, colors: [Color(0xFFB9A8FF), Color(0xFF7D62FF), ToviTokens.violetDeep]).createShader(body),
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(body));
    final band = Paint()..color = Colors.white.withValues(alpha: 0.10);
    canvas.drawOval(Rect.fromCenter(center: c.translate(0, r * 0.32), width: r * 2.4, height: r * 0.34), band);
    canvas.drawOval(Rect.fromCenter(center: c.translate(0, -r * 0.18), width: r * 2.4, height: r * 0.18), band);
    canvas.drawCircle(c.translate(-r * 0.38, -r * 0.42), r * 0.3, Paint()..color = Colors.white.withValues(alpha: 0.16));
    canvas.restore();

    ringHalf(false);
    if (moonInFront) moon();
  }

  @override
  bool shouldRepaint(_OrbPainter old) => old.t != t;
}

/// Filled text field with a floating label, inline error and optional show/hide.
/// No outline: focus and error are shown with the fill and the label colour.
class ToviInput extends StatefulWidget {
  const ToviInput({
    super.key,
    required this.controller,
    required this.label,
    this.icon,
    this.hint,
    this.helper,
    this.validator,
    this.showErrors = false,
    this.secret = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.formatters,
    this.autofillHints,
    this.arabic = true,
    this.ltr = false,
  });

  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final String? hint;
  final String? helper;
  final String? Function(String value)? validator;
  final bool showErrors;
  final bool secret;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? formatters;
  final Iterable<String>? autofillHints;
  final bool arabic;
  final bool ltr;

  @override
  State<ToviInput> createState() => _ToviInputState();
}

class _ToviInputState extends State<ToviInput> {
  final focus = FocusNode();
  var touched = false;
  var hidden = true;

  @override
  void initState() {
    super.initState();
    focus.addListener(() {
      if (!focus.hasFocus && widget.controller.text.isNotEmpty) touched = true;
      if (mounted) setState(() {});
    });
    widget.controller.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(ToviInput old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final problem = widget.validator?.call(widget.controller.text);
    final error = (touched || widget.showErrors) ? problem : null;
    final focused = focus.hasFocus;
    final fill = error != null
        ? const Color(0xFFFDEDEF)
        : focused
        ? ToviTokens.violetSoft
        : ToviTokens.sunken;
    final tone = error != null ? ToviTokens.danger : (focused ? ToviTokens.violet : ToviTokens.muted);
    final valid = problem == null && widget.controller.text.isNotEmpty && widget.validator != null && !widget.secret;
    final duration = motion(context, ToviTokens.fast);
    final note = error ?? widget.helper;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: duration,
          curve: Curves.easeOut,
          decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(ToviTokens.radiusMd)),
          child: TextField(
            controller: widget.controller,
            focusNode: focus,
            obscureText: widget.secret && hidden,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            onSubmitted: widget.onSubmitted,
            inputFormatters: widget.formatters,
            autofillHints: widget.autofillHints,
            textDirection: widget.ltr ? TextDirection.ltr : null,
            textAlign: widget.ltr && widget.arabic ? TextAlign.right : TextAlign.start,
            cursorColor: ToviTokens.violet,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ToviTokens.ink, letterSpacing: 0.2),
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: focused ? widget.hint : null,
              hintTextDirection: widget.ltr ? TextDirection.ltr : null,
              hintStyle: const TextStyle(color: ToviTokens.faint, fontWeight: FontWeight.w500),
              floatingLabelBehavior: FloatingLabelBehavior.auto,
              labelStyle: TextStyle(color: tone == ToviTokens.violet ? ToviTokens.muted : tone, fontWeight: FontWeight.w500),
              floatingLabelStyle: TextStyle(color: tone, fontWeight: FontWeight.w700),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 18, 16, 14),
              prefixIcon: widget.icon == null ? null : Icon(widget.icon, size: 21, color: tone),
              suffixIcon: widget.secret
                  ? IconButton(
                      tooltip: hidden ? (widget.arabic ? 'إظهار كلمة المرور' : 'Show password') : (widget.arabic ? 'إخفاء كلمة المرور' : 'Hide password'),
                      onPressed: () => setState(() => hidden = !hidden),
                      icon: AnimatedSwitcher(
                        duration: duration,
                        child: Icon(hidden ? Icons.visibility_rounded : Icons.visibility_off_rounded, key: ValueKey(hidden), size: 21, color: ToviTokens.muted),
                      ),
                    )
                  : valid
                  ? const Icon(Icons.check_circle_rounded, size: 20, color: ToviTokens.mint)
                  : null,
            ),
          ),
        ),
        SizeMotion(
          duration: duration,
          alignment: AlignmentDirectional.topStart,
          child: note == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(6, 6, 6, 0),
                  child: Row(
                    children: [
                      if (error != null) ...[const Icon(Icons.error_rounded, size: 15, color: ToviTokens.danger), const SizedBox(width: 5)],
                      Expanded(
                        child: Text(
                          note,
                          style: TextStyle(fontSize: 12.5, height: 1.35, color: error != null ? ToviTokens.danger : ToviTokens.muted, fontWeight: error != null ? FontWeight.w600 : FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

List<TextInputFormatter> phoneFormatters() => [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)];

/// Violet primary button with a loading state that keeps its size.
class AuthButton extends StatelessWidget {
  const AuthButton({super.key, required this.label, required this.onPressed, this.busy = false, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final duration = motion(context, ToviTokens.fast);
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        height: 56,
        child: FilledButton(
          onPressed: busy ? () {} : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: busy ? ToviTokens.violetDeep : ToviTokens.violet,
            disabledBackgroundColor: ToviTokens.violet.withValues(alpha: 0.4),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ToviTokens.radiusMd)),
            textStyle: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, fontFamily: 'IBM Plex Sans Arabic'),
          ),
          child: AnimatedSwitcher(
            duration: duration,
            child: busy
                ? const SizedBox(
                    key: ValueKey('busy'),
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  )
                : Row(
                    key: const ValueKey('label'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label),
                      if (icon != null) ...[const SizedBox(width: 8), Icon(icon, size: 20)],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Soft error or success message with an icon. Empty text renders nothing.
class AuthBanner extends StatelessWidget {
  const AuthBanner({super.key, required this.text, this.success = false});
  final String text;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final duration = motion(context, ToviTokens.calm);
    return SizeMotion(
      duration: duration,
      child: AnimatedSwitcher(
        duration: duration,
        child: text.isEmpty
            ? const SizedBox(width: double.infinity)
            : Padding(
                key: ValueKey(text),
                padding: const EdgeInsets.only(bottom: 14),
                child: Semantics(
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
                    decoration: BoxDecoration(color: success ? ToviTokens.mintSoft : const Color(0xFFFDEDEF), borderRadius: BorderRadius.circular(ToviTokens.radiusSm)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(success ? Icons.check_circle_rounded : Icons.error_rounded, size: 20, color: success ? ToviTokens.mint : ToviTokens.danger),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            text,
                            style: TextStyle(height: 1.45, fontSize: 13.5, fontWeight: FontWeight.w600, color: success ? const Color(0xFF0B6E55) : const Color(0xFFA9283A)),
                          ),
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

/// Step progress: filled segments plus a "step n of m" caption.
class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.step, required this.total, required this.caption});
  final int step;
  final int total;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final duration = motion(context, ToviTokens.calm);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 6,
                    child: Stack(
                      children: [
                        const Positioned.fill(child: ColoredBox(color: ToviTokens.sunken)),
                        AnimatedFractionallySizedBox(
                          duration: duration,
                          curve: Curves.easeOutCubic,
                          alignment: AlignmentDirectional.centerStart,
                          widthFactor: i < step ? 1 : 0,
                          child: const ColoredBox(color: ToviTokens.violet, child: SizedBox.expand()),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          caption,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: ToviTokens.muted),
        ),
      ],
    );
  }
}

/// Keeps only digits and at most [length] of them. When a paste pushes the
/// value past [length], the newest digits win, so pasting a full code into a
/// half-typed one replaces it.
class OtpFormatter extends TextInputFormatter {
  OtpFormatter(this.length);
  final int length;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > length) digits = digits.substring(digits.length - length);
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}

/// Six digit boxes backed by one hidden field, so typing auto-advances,
/// backspace walks back and a pasted code fills every box at once.
class OtpBoxes extends StatefulWidget {
  const OtpBoxes({super.key, required this.controller, this.length = 6, this.onCompleted, this.onChanged, this.error = false, this.autofocus = true});
  final TextEditingController controller;
  final int length;
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onChanged;
  final bool error;
  final bool autofocus;

  @override
  State<OtpBoxes> createState() => _OtpBoxesState();
}

class _OtpBoxesState extends State<OtpBoxes> {
  final focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    focus.addListener(_changed);
    if (widget.autofocus) {
      // Wait for the step transition to settle; focusing mid-transition is dropped on web.
      Future<void>.delayed(const Duration(milliseconds: 320), () {
        if (mounted && !focus.hasFocus) focus.requestFocus();
      });
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final duration = motion(context, ToviTokens.fast);
    return Semantics(
      textField: true,
      label: 'OTP',
      value: text,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => focus.requestFocus(),
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: widget.controller,
                  focusNode: focus,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  showCursor: false,
                  enableInteractiveSelection: true,
                  inputFormatters: [OtpFormatter(widget.length)],
                  decoration: const InputDecoration(border: InputBorder.none, counterText: ''),
                  onChanged: (value) {
                    widget.onChanged?.call(value);
                    if (value.length == widget.length) widget.onCompleted?.call(value);
                  },
                ),
              ),
            ),
            IgnorePointer(
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  children: [
                    for (var i = 0; i < widget.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: AnimatedContainer(
                          duration: duration,
                          height: 58,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: widget.error
                                ? const Color(0xFFFDEDEF)
                                : (focus.hasFocus && i == math.min(text.length, widget.length - 1))
                                ? ToviTokens.violetSoft
                                : i < text.length
                                ? ToviTokens.surface
                                : ToviTokens.sunken,
                            borderRadius: BorderRadius.circular(ToviTokens.radiusSm),
                            boxShadow: i < text.length && !widget.error ? ToviTokens.raised : null,
                          ),
                          child: i < text.length
                              ? Text(
                                  text[i],
                                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: widget.error ? ToviTokens.danger : ToviTokens.ink),
                                )
                              : (focus.hasFocus && i == text.length)
                              ? _Caret(calm: calmMotion(context))
                              : null,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Caret extends StatefulWidget {
  const _Caret({required this.calm});
  final bool calm;

  @override
  State<_Caret> createState() => _CaretState();
}

class _CaretState extends State<_Caret> with SingleTickerProviderStateMixin {
  late final AnimationController blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));

  @override
  void initState() {
    super.initState();
    if (widget.calm) {
      blink.value = 1;
    } else {
      blink.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: blink,
      child: Container(
        width: 2,
        height: 24,
        decoration: BoxDecoration(color: ToviTokens.violet, borderRadius: BorderRadius.circular(1)),
      ),
    );
  }
}

/// Pill choice used for gender. Selected is solid violet, others are sunken.
class ChoicePill extends StatelessWidget {
  const ChoicePill({super.key, required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ToviTokens.radiusSm),
          child: AnimatedContainer(
            duration: motion(context, ToviTokens.fast),
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: selected ? ToviTokens.violet : ToviTokens.sunken, borderRadius: BorderRadius.circular(ToviTokens.radiusSm)),
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w700, color: selected ? Colors.white : ToviTokens.inkSoft),
            ),
          ),
        ),
      ),
    );
  }
}
