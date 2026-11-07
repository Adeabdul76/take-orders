// Firebase settings for sharing the cafe between phones.
//
// Fill these in from the Firebase console:
//   Project settings > General > Your apps > Android app (my.cafe.take_orders)
// (see FIREBASE_SETUP.md). These values are NOT secret passwords: they only
// say which Firebase project to use. Access is protected by firestore.rules.
//
// While they are empty, the app still works normally on one phone, and the
// "Share with other phones" option says sharing is not set up yet.

class FirebaseConfig {
  static const apiKey = '';
  static const appId = '';
  static const messagingSenderId = '';
  static const projectId = '';

  static bool get isSet =>
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      messagingSenderId.isNotEmpty &&
      projectId.isNotEmpty;
}
