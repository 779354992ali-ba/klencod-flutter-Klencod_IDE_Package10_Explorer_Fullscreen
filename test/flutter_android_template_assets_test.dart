import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled Android Gradle wrapper jar is a valid ZIP/JAR header', () async {
    final data = await rootBundle.load(
      'assets/templates/android/gradle/wrapper/gradle-wrapper.jar',
    );
    expect(data.lengthInBytes, greaterThan(1000));
    expect(data.getUint8(0), 0x50);
    expect(data.getUint8(1), 0x4B);
  });

  test('bundled Gradle launch scripts are present', () async {
    final unix = await rootBundle.loadString('assets/templates/android/gradlew');
    final windows = await rootBundle.loadString('assets/templates/android/gradlew.bat');
    expect(unix.startsWith('#!/'), isTrue);
    expect(windows.toLowerCase(), contains('@echo off'));
  });
}
