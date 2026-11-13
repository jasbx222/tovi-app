import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'session.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = Session(await SharedPreferences.getInstance());
  runApp(ToviStudentApp(session: session));
}

class ToviStudentApp extends StatelessWidget {
  const ToviStudentApp({super.key, required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        const ink = Tovi.ink;
        final theme = ThemeData(
          useMaterial3: true,
          fontFamily: 'IBM Plex Sans Arabic',
          scaffoldBackgroundColor: Tovi.surface,
          splashFactory: InkRipple.splashFactory,
          colorScheme: const ColorScheme.light(
            primary: Tovi.violet,
            onPrimary: Colors.white,
            secondary: Tovi.apricot,
            surface: Tovi.surface,
            error: Tovi.danger,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Tovi.surface,
            foregroundColor: ink,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            centerTitle: true,
          ),
          dialogTheme: const DialogThemeData(
            backgroundColor: Tovi.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
          ),
          snackBarTheme: SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            backgroundColor: ink,
            contentTextStyle: const TextStyle(fontFamily: 'IBM Plex Sans Arabic', color: Colors.white),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: ink,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              textStyle: const TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: Tovi.violet, textStyle: const TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontWeight: FontWeight.w700))),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Tovi.field,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          ),
        );
        return MaterialApp(
          key: ValueKey(session.signedIn),
          debugShowCheckedModeBanner: false,
          title: 'توفي',
          theme: theme,
          locale: Locale(session.arabic ? 'ar' : 'en'),
          builder: (context, child) => Directionality(
            textDirection: session.arabic ? TextDirection.rtl : TextDirection.ltr,
            child: child ?? const SizedBox.shrink(),
          ),
          home: session.signedIn ? HomeShell(session: session) : AuthScreen(session: session),
        );
      },
    );
  }
}
