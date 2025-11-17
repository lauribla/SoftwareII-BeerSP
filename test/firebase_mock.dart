import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';

final _testOptions = FirebaseOptions(
  apiKey: 'test',
  appId: 'test',
  messagingSenderId: 'test',
  projectId: 'test',
);

class FakeFirebaseApp extends FirebaseAppPlatform {
  FakeFirebaseApp() : super('testApp', _testOptions);

  @override
  Future<void> delete() async {}
}

class FakeFirebasePlatform extends FirebasePlatform {
  FakeFirebasePlatform() : super();

  @override
  FirebaseAppPlatform createFirebaseApp({
    required String name,
    required FirebaseOptions options,
  }) {
    return FakeFirebaseApp();
  }

  @override
  List<FirebaseAppPlatform> getApps() {
    return [FakeFirebaseApp()];
  }
}
