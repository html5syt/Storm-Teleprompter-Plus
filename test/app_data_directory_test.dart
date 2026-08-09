import 'package:flutter_test/flutter_test.dart';
import 'package:storm_teleprompter_plus/services/system/app_data_directory.dart';

void main() {
  test('only Windows and Linux use the portable desktop data directory', () {
    expect(
      usesPortableDesktopDataDirectory(
        isWindows: true,
        isLinux: false,
        isMacOS: false,
      ),
      isTrue,
    );
    expect(
      usesPortableDesktopDataDirectory(
        isWindows: false,
        isLinux: true,
        isMacOS: false,
      ),
      isTrue,
    );
    expect(
      usesPortableDesktopDataDirectory(
        isWindows: false,
        isLinux: false,
        isMacOS: true,
      ),
      isFalse,
    );
  });

  test(
    'non-desktop platforms use the platform application support directory',
    () {
      expect(
        usesPortableDesktopDataDirectory(
          isWindows: false,
          isLinux: false,
          isMacOS: false,
        ),
        isFalse,
      );
    },
  );
}
