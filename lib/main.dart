import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'session.dart';

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
        final theme = ThemeData(
          useMaterial3: true,
          fontFamily: 'IBM Plex Sans Arabic',
          scaffoldBackgroundColor: const Color(0xFFF3EFE7),
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F6B4A)).copyWith(
            primary: const Color(0xFF1B1916),
            secondary: const Color(0xFF1F6B4A),
            surface: const Color(0xFFFFFDF9),
          ),
          appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF3EFE7), foregroundColor: Color(0xFF1B1916), elevation: 0, scrolledUnderElevation: 0, centerTitle: false),
          filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B1916), foregroundColor: const Color(0xFFF7F3EC), minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
          inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
        );
        return MaterialApp(
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
