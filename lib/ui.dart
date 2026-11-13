import 'package:material_ui/material_ui.dart';

class Tovi {
  static const paper = Color(0xFFF3EFE7);
  static const card = Color(0xFFFFFDF9);
  static const ink = Color(0xFF1B1916);
  static const muted = Color(0xFF6E675E);
  static const line = Color(0xFFE4DDD2);
  static const brand = Color(0xFF1F6B4A);
  static const brandSoft = Color(0xFFE5F2EB);
  static const clay = Color(0xFFC4623A);
  static const claySoft = Color(0xFFF8E8DF);
  static const saffron = Color(0xFFFBF3E2);
  static const sea = Color(0xFF2F5F73);
  static const seaSoft = Color(0xFFE7F1F5);

  static const swatches = [brand, sea, clay, Color(0xFF8A6232), Color(0xFF3E4C3A)];
}

class ToviBar extends StatelessWidget {
  const ToviBar({super.key, required this.index, required this.labels, required this.onSelect});
  final int index;
  final List<String> labels;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Tovi.card, border: Border(top: BorderSide(color: Tovi.line))),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onSelect(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: index == i ? 22 : 0,
                          height: 3,
                          decoration: BoxDecoration(color: Tovi.brand, borderRadius: BorderRadius.circular(99)),
                        ),
                        const SizedBox(height: 6),
                        Text(labels[i], style: TextStyle(fontSize: 11, fontWeight: index == i ? FontWeight.w700 : FontWeight.w500, color: index == i ? Tovi.brand : Tovi.muted)),
                      ],
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

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 10),
    child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
  );
}

class SoftCard extends StatelessWidget {
  const SoftCard({super.key, required this.child, this.color = Tovi.card, this.onTap});
  final Widget child;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18), border: Border.all(color: Tovi.line)),
      child: child,
    );
    if (onTap == null) return card;
    return InkWell(borderRadius: BorderRadius.circular(18), onTap: onTap, child: card);
  }
}

class CourseTile extends StatelessWidget {
  const CourseTile({super.key, required this.title, required this.meta, required this.onTap, this.index = 0});
  final String title;
  final String meta;
  final VoidCallback onTap;
  final int index;
  @override
  Widget build(BuildContext context) {
    final color = Tovi.swatches[index % Tovi.swatches.length];
    return SoftCard(
      onTap: onTap,
      child: Row(children: [
        Container(
          width: 54, height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
          child: Text(title.isEmpty ? 'T' : title.substring(0, 1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          if (meta.isNotEmpty) Text(meta, style: const TextStyle(color: Tovi.muted, fontSize: 13)),
        ])),
        const Icon(Icons.chevron_left, color: Tovi.muted),
      ]),
    );
  }
}

InputDecoration toviField(String label) => InputDecoration(
  labelText: label,
  filled: true,
  fillColor: Colors.white,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Tovi.line)),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Tovi.line)),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Tovi.brand, width: 1.4)),
);
