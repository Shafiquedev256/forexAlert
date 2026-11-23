import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

/// Keeps ringtone files inside the app's own storage so they stay available
/// after the original file is moved or deleted.
class ToneStore {
  ToneStore._();

  static Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/tones');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Copies the built-in alarm out of the asset bundle and returns its path.
  static Future<String> ensureDefault() async {
    final file = File('${(await _dir()).path}/default_alarm.wav');
    if (!await file.exists()) {
      final data = await rootBundle.load('assets/sounds/default_alarm.wav');
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
    return file.path;
  }

  /// Lets the user pick any audio file; returns the app-private copy.
  static Future<String?> pickCustom() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    final picked = result?.files.single.path;
    if (picked == null) return null;

    final original = picked.split(Platform.pathSeparator).last;
    final safe = original.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final dest = File('${(await _dir()).path}/tone_${DateTime.now().millisecondsSinceEpoch}_$safe');
    await File(picked).copy(dest.path);
    return dest.path;
  }

  static String displayName(String? path) {
    if (path == null) return 'Default alarm';
    final name = path.split(Platform.pathSeparator).last;
    return name.replaceFirst(RegExp(r'^tone_\d+_'), '');
  }
}
