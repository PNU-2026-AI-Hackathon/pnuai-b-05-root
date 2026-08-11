import 'dart:typed_data';

/// `dart:io`/`dart:html` 조건부 export가 필수로 요구하는 기본(unconditional) 대상 —
/// 이 두 라이브러리 중 하나는 항상 존재하므로 실행 중 실제로 선택될 일은 없다.
Future<void> saveImageBytes(Uint8List bytes, String filename) {
  throw UnsupportedError('이 플랫폼에서는 이미지 저장을 지원하지 않아요.');
}
