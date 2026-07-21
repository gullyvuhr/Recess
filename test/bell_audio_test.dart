import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recess/src/core/bell_audio.dart';
import 'package:recess/src/core/models.dart';
import 'package:recess/src/core/notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('recess/bell_preview_test');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('every Bell Sound has one distinct, audible packaged mapping', () {
    final definitions = BellSound.values.map((sound) => sound.definition);

    expect(definitions.map((value) => value.label).toSet(), hasLength(3));
    expect(
      definitions.map((value) => value.previewAssetPath).toSet(),
      hasLength(3),
    );
    expect(
      definitions.map((value) => value.androidResourceName).toSet(),
      hasLength(3),
    );
    expect(
      definitions.map((value) => value.androidChannelId).toSet(),
      hasLength(3),
    );

    for (final sound in BellSound.values) {
      final definition = sound.definition;
      final flutterAsset = File(definition.previewAssetPath);
      final androidAsset = File(
        'android/app/src/main/res/raw/'
        '${definition.androidResourceName}.wav',
      );
      final iosAsset = File('ios/Runner/Sounds/${definition.iosFileName}');
      expect(flutterAsset.existsSync(), isTrue);
      expect(androidAsset.readAsBytesSync(), flutterAsset.readAsBytesSync());
      expect(iosAsset.readAsBytesSync(), flutterAsset.readAsBytesSync());
      final durationRange = switch (sound) {
        BellSound.schoolBell => (1.2, 1.8),
        BellSound.coachWhistle => (0.5, 1.0),
        BellSound.gentleChime => (1.5, 2.3),
      };
      _expectAudibleShortPcmWave(
        flutterAsset,
        minimumDuration: durationRange.$1,
        maximumDuration: durationRange.$2,
      );
    }
  });

  test('notification details use each selected native sound mapping', () {
    for (final sound in BellSound.values) {
      final definition = sound.definition;
      final details = NotificationService.detailsFor(sound);

      expect(details.android!.channelId, definition.androidChannelId);
      expect(details.android!.sound!.sound, definition.androidResourceName);
      expect(details.iOS!.sound, definition.iosFileName);
    }
  });

  test('preview stops existing playback before playing the selected sound',
      () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    const player = PlatformBellPreviewPlayer(channel: channel);

    await player.play(BellSound.coachWhistle);
    await player.play(BellSound.gentleChime);

    expect(calls.map((call) => call.method), ['stop', 'play', 'stop', 'play']);
    expect(
      calls.map((call) => call.arguments),
      [
        null,
        'assets/sounds/coach_whistle.wav',
        null,
        'assets/sounds/gentle_chime.wav',
      ],
    );
  });

  test('preview audio failures are ignored', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            channel,
            (_) => throw PlatformException(
                  code: 'audio-session-unavailable',
                ));
    const player = PlatformBellPreviewPlayer(channel: channel);

    await expectLater(player.play(BellSound.schoolBell), completes);
  });
}

void _expectAudibleShortPcmWave(
  File file, {
  required double minimumDuration,
  required double maximumDuration,
}) {
  final bytes = file.readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  expect(String.fromCharCodes(bytes.take(4)), 'RIFF');
  expect(String.fromCharCodes(bytes.skip(8).take(4)), 'WAVE');
  final channels = data.getUint16(22, Endian.little);
  final sampleRate = data.getUint32(24, Endian.little);
  final bitsPerSample = data.getUint16(34, Endian.little);
  final dataLength = data.getUint32(40, Endian.little);
  final duration = dataLength / (sampleRate * channels * (bitsPerSample / 8));
  expect(sampleRate, 44100);
  expect(bitsPerSample, 16);
  expect(channels, 1);
  expect(duration, inInclusiveRange(minimumDuration, maximumDuration));

  var peak = 0;
  var firstAudibleSample = -1;
  for (var offset = 44; offset + 1 < bytes.length; offset += 2) {
    final sample = data.getInt16(offset, Endian.little).abs();
    if (sample > peak) peak = sample;
    if (firstAudibleSample < 0 && sample > 500) {
      firstAudibleSample = (offset - 44) ~/ 2;
    }
  }
  expect(peak, greaterThan(10000));
  expect(peak, lessThan(32767));
  expect(firstAudibleSample, greaterThanOrEqualTo(0));
  expect(firstAudibleSample / (sampleRate * channels), lessThan(0.1));
}
