import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web; // ✅ fixed
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCvBBVnsBHHW11lpcdizPJXANguLK-m_lM',
    appId: '1:184048274985:web:478ddda6cc1512076cd638',
    messagingSenderId: '184048274985',
    projectId: 'student-management-syste-2ea31',
    authDomain: 'student-management-syste-2ea31.firebaseapp.com',
    storageBucket: 'student-management-syste-2ea31.firebasestorage.app',
    measurementId: 'G-78LTJRFX97',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDZf0mhxKq8Mntw4dIBRJnPfLXh_IPLtrI',
    appId: '1:184048274985:android:7f85f76ff210d49a6cd638',
    messagingSenderId: '184048274985',
    projectId: 'student-management-syste-2ea31',
    storageBucket: 'student-management-syste-2ea31.firebasestorage.app',
  );
}

