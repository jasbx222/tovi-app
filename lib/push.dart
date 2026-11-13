import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'api.dart';
import 'session.dart';

/// Registers the token Firebase issues for this install.
/// A missing Firebase project leaves the inbox on the API and never sends a placeholder token.
Future<void> registerDeviceToken(Session session) async {
  const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  const appId = String.fromEnvironment('FIREBASE_APP_ID');
  const sender = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  const project = String.fromEnvironment('FIREBASE_PROJECT_ID');
  if (apiKey.isEmpty || appId.isEmpty || sender.isEmpty || project.isEmpty) return;
  try {
    await Firebase.initializeApp(options: FirebaseOptions(apiKey: apiKey, appId: appId, messagingSenderId: sender, projectId: project));
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;
    await session.api.put('/api/student/device-token', {'token': token, 'platform': 'flutter'});
  } on ApiException {
    return;
  } catch (_) {
    return;
  }
}
