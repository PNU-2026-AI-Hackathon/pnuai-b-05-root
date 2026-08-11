import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// 웹(Chrome 등): 브라우저의 파일 다운로드를 트리거한다(앵커 태그 + Blob URL).
Future<void> saveImageBytes(Uint8List bytes, String filename) async {
  final blob = web.Blob([bytes.toJS].toJS);
  final url = web.URL.createObjectURL(blob);
  final anchor =
      web.document.createElement('a') as web.HTMLAnchorElement
        ..href = url
        ..download = filename;
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
