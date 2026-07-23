import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical Recess bell masters are original scalable assets', () {
    final svg =
        File('assets/branding/recess_bell_master.svg').readAsStringSync();
    final png = File('assets/branding/recess_bell_master_1024.png');

    expect(svg, contains('viewBox="0 0 1024 1024"'));
    expect(svg, contains('#315C4B'));
    expect(svg, contains('#F7F3E8'));
    expect(svg, contains('x="448" y="150"'));
    expect(svg, contains('cx="512" cy="820" r="48"'));
    expect(svg, isNot(contains('<image')));
    expect(svg, isNot(contains('href=')));
    expect(_pngDimensions(png), (1024, 1024));
    expect(File('tool/generate_brand_assets.py').existsSync(), isTrue);
    expect(File('tool/generate_bell_sounds.py').existsSync(), isTrue);
  });

  test('Android launcher family and splash references resolve', () {
    const legacySizes = {
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    };
    const foregroundSizes = {
      'mdpi': 108,
      'hdpi': 162,
      'xhdpi': 216,
      'xxhdpi': 324,
      'xxxhdpi': 432,
    };
    for (final entry in legacySizes.entries) {
      for (final name in ['ic_launcher.png', 'ic_launcher_round.png']) {
        final file = File(
          'android/app/src/main/res/mipmap-${entry.key}/$name',
        );
        expect(_pngDimensions(file), (entry.value, entry.value));
      }
    }
    for (final entry in foregroundSizes.entries) {
      final file = File(
        'android/app/src/main/res/mipmap-${entry.key}/'
        'ic_launcher_foreground.png',
      );
      expect(_pngDimensions(file), (entry.value, entry.value));
    }

    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:icon="@mipmap/ic_launcher"'));
    expect(manifest, contains('android:roundIcon="@mipmap/ic_launcher_round"'));
    final notifications =
        File('lib/src/core/notifications.dart').readAsStringSync();
    expect(
      notifications,
      contains("AndroidInitializationSettings('ic_launcher_monochrome')"),
    );
    expect(
      File('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml')
          .readAsStringSync(),
      contains('@mipmap/ic_launcher_foreground'),
    );
    expect(
      File('android/app/src/main/res/mipmap-anydpi-v33/ic_launcher.xml')
          .readAsStringSync(),
      contains('@drawable/ic_launcher_monochrome'),
    );
    final monochrome = File(
      'android/app/src/main/res/drawable/ic_launcher_monochrome.xml',
    ).readAsStringSync();
    expect(monochrome, contains('M496,150'));
    expect(monochrome, contains('M512,210'));
    expect(
      File('android/app/src/main/res/values-v31/styles.xml').readAsStringSync(),
      contains('@drawable/recess_splash_mark'),
    );
  });

  test('iOS AppIcon catalog and native splash are complete', () {
    final directory = Directory(
      'ios/Runner/Assets.xcassets/AppIcon.appiconset',
    );
    final contents = jsonDecode(
      File('${directory.path}/Contents.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final images = contents['images'] as List<dynamic>;
    expect(images, hasLength(19));
    for (final value in images) {
      final entry = value as Map<String, dynamic>;
      final points = double.parse((entry['size'] as String).split('x').first);
      final scale = double.parse(
        (entry['scale'] as String).replaceFirst('x', ''),
      );
      final expected = (points * scale).round();
      expect(
        _pngDimensions(File('${directory.path}/${entry['filename']}')),
        (expected, expected),
      );
    }

    final storyboard = File('ios/Runner/Base.lproj/LaunchScreen.storyboard')
        .readAsStringSync();
    expect(storyboard, contains('image="RecessBell"'));
    expect(storyboard, isNot(contains('image="LaunchImage"')));
    final splashContents = File(
      'ios/Runner/Assets.xcassets/RecessBell.imageset/Contents.json',
    ).readAsStringSync();
    expect(splashContents, contains('RecessBell@1x.png'));
    expect(splashContents, contains('RecessBell@2x.png'));
    expect(splashContents, contains('RecessBell@3x.png'));
  });

  test('application keeps light identity and supports system dark mode', () {
    final app = File('lib/src/app.dart').readAsStringSync();

    expect(app, contains('scaffoldBackgroundColor: const Color(0xfff7f3e8)'));
    expect(app, contains('brightness: Brightness.dark'));
    expect(app, contains('themeMode: ThemeMode.system'));
  });

  test('release configuration has no stale direct UI dependency', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final notifications =
        File('lib/src/core/notifications.dart').readAsStringSync();

    expect(pubspec, isNot(contains('cupertino_icons:')));
    expect(notifications, isNot(contains('repeatsDaily')));
  });
}

(int, int) _pngDimensions(File file) {
  expect(file.existsSync(), isTrue, reason: file.path);
  final data = ByteData.sublistView(file.readAsBytesSync());
  expect(data.getUint32(0), 0x89504e47, reason: file.path);
  return (data.getUint32(16), data.getUint32(20));
}
