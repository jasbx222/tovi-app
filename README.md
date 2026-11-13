# TOVI student

Flutter app for iOS and Android. It talks only to `/api/student` and `/api/auth/student`.

```bash
flutter pub get
flutter run --dart-define=API_URL=http://127.0.0.1:5088
```

Pass `TOVI_ENV=production` only for a build that may enter production meetings. Pass the `FIREBASE_*` dart defines when this install should register its real Firebase Cloud Messaging token. Firestore rules are in `firestore.rules`.
