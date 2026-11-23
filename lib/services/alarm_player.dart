import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// Plays the alarm on the alarm audio stream and loops until [stop].
class AlarmPlayer {
  final AudioPlayer _player = AudioPlayer();
  Timer? _previewTimer;
  bool _ringing = false;

  bool get isRinging => _ringing;

  /// Starts looping. A null path plays the built-in sound.
  Future<void> start(String? filePath) async {
    if (_ringing) return;
    _ringing = true;
    try {
      await _play(filePath, loop: true);
    } catch (_) {
      _ringing = false; // the engine retries on its next tick
      rethrow;
    }
  }

  /// Short test play used by Settings and the alert form.
  Future<void> preview(String? filePath) async {
    if (_ringing) return;
    _previewTimer?.cancel();
    await _play(filePath, loop: false);
    _previewTimer = Timer(const Duration(seconds: 5), () {
      if (!_ringing) _player.stop();
    });
  }

  Future<void> _play(String? filePath, {required bool loop}) async {
    await _player.setAudioContext(AudioContext(
      android: AudioContextAndroid(
        usageType: AndroidUsageType.alarm,
        contentType: AndroidContentType.sonification,
        audioFocus: AndroidAudioFocus.gain,
        stayAwake: true,
      ),
    ));
    await _player.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.release);
    await _player.setVolume(1.0);
    await _player.play(
      filePath != null ? DeviceFileSource(filePath) : AssetSource('sounds/default_alarm.wav'),
    );
  }

  Future<void> stop() async {
    _previewTimer?.cancel();
    _ringing = false;
    await _player.stop();
  }

  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }
}
