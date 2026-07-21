import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'models.dart';

class BellSoundDefinition {
  const BellSoundDefinition({
    required this.label,
    required this.previewAssetPath,
    required this.androidResourceName,
    required this.androidChannelId,
    required this.iosFileName,
  });

  final String label;
  final String previewAssetPath;
  final String androidResourceName;
  final String androidChannelId;
  final String iosFileName;
}

extension BellSoundAsset on BellSound {
  BellSoundDefinition get definition => switch (this) {
        BellSound.schoolBell => const BellSoundDefinition(
            label: 'School Bell',
            previewAssetPath: 'assets/sounds/school_bell.wav',
            androidResourceName: 'school_bell',
            androidChannelId: 'recess_school_bell',
            iosFileName: 'school_bell.wav',
          ),
        BellSound.coachWhistle => const BellSoundDefinition(
            label: 'Coach Whistle',
            previewAssetPath: 'assets/sounds/coach_whistle.wav',
            androidResourceName: 'coach_whistle',
            androidChannelId: 'recess_coach_whistle',
            iosFileName: 'coach_whistle.wav',
          ),
        BellSound.gentleChime => const BellSoundDefinition(
            label: 'Gentle Chime',
            previewAssetPath: 'assets/sounds/gentle_chime.wav',
            androidResourceName: 'gentle_chime',
            androidChannelId: 'recess_gentle_chime',
            iosFileName: 'gentle_chime.wav',
          ),
      };
}

abstract interface class BellPreviewPlayer {
  Future<void> play(BellSound sound);

  Future<void> stop();
}

class PlatformBellPreviewPlayer implements BellPreviewPlayer {
  const PlatformBellPreviewPlayer({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('recess/bell_preview');

  final MethodChannel _channel;

  @override
  Future<void> play(BellSound sound) async {
    try {
      await _channel.invokeMethod<void>('stop');
      await _channel.invokeMethod<void>(
        'play',
        sound.definition.previewAssetPath,
      );
    } catch (error) {
      if (kDebugMode) debugPrint('Bell preview failed: $error');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (error) {
      if (kDebugMode) debugPrint('Stopping Bell preview failed: $error');
    }
  }
}
