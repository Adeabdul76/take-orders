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
  static const apiKey = 'AIzaSyBN_UJ8ukvYJn0pOeamK9mM9n1NQZWIZY8';
  static const appId = '1:814490936878:android:c4460c535026c89bc921bf';
  static const messagingSenderId = '814490936878';
  static const projectId = 'ishola-cafe';

  static bool get isSet =>
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      messagingSenderId.isNotEmpty &&
      projectId.isNotEmpty;
}
