import 'dart:typed_data';

import 'package:gal/gal.dart';

/// Android/iOS/데스크톱: 갤러리(사진 앱)에 직접 저장한다.
Future<void> saveImageBytes(Uint8List bytes, String filename) async {
  if (!await Gal.hasAccess()) {
    final granted = await Gal.requestAccess();
    if (!granted) {
      throw Exception('갤러리 접근 권한이 필요해요.');
    }
  }
  await Gal.putImageBytes(bytes, name: filename, album: 'Pig.Fig.');
}
