import 'package:material_ui/material_ui.dart';

/// Shared Tovi Planet design tokens. The dashboards mirror these values in
/// `shared/src/tokens.css`, so a change here should be made there too.
class ToviTokens {
  static const violet = Color(0xFF6A4CFF);
  static const violetDeep = Color(0xFF4B32D9);
  static const violetSoft = Color(0xFFEEEAFF);
  static const sun = Color(0xFFFFC23D);
  static const sunSoft = Color(0xFFFFF4D6);
  static const coral = Color(0xFFFF6B57);
  static const coralSoft = Color(0xFFFFE9E5);
  static const mint = Color(0xFF14A37F);
  static const mintSoft = Color(0xFFE2F6EF);
  static const sky = Color(0xFF3D8BFF);
  static const skySoft = Color(0xFFE5F0FF);

  static const ink = Color(0xFF17142B);
  static const inkSoft = Color(0xFF3B3754);
  static const muted = Color(0xFF6E6A85);
  static const faint = Color(0xFFA9A5BD);
  static const page = Color(0xFFF6F5FB);
  static const surface = Color(0xFFFFFFFF);
  static const sunken = Color(0xFFF0EEF7);
  static const night = Color(0xFF14111F);
  static const nightRaised = Color(0xFF221E33);
  static const danger = Color(0xFFD9434F);

  static const radiusSm = 12.0;
  static const radiusMd = 18.0;
  static const radiusLg = 24.0;

  static const space1 = 4.0;
  static const space2 = 8.0;
  static const space3 = 12.0;
  static const space4 = 16.0;
  static const space5 = 20.0;
  static const space6 = 24.0;

  static const fast = Duration(milliseconds: 160);
  static const calm = Duration(milliseconds: 240);

  static const raised = <BoxShadow>[
    BoxShadow(color: Color(0x0F17142B), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0D17142B), blurRadius: 16, offset: Offset(0, 6)),
  ];
  static const floating = <BoxShadow>[
    BoxShadow(color: Color(0x1417142B), blurRadius: 28, offset: Offset(0, 12)),
  ];
}
