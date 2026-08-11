/// 이미지 바이트를 이 기기에 저장한다. 웹/모바일(Android)에서 저장 방식이 완전히 달라
/// (웹은 브라우저 다운로드, 모바일은 갤러리 저장) `dart.library.*` 조건부 export로 분기한다
/// — 실패 시(권한 거부, 지원하지 않는 플랫폼 등) 예외를 던지므로 호출부가 스낵바로 안내한다.
library;

export 'src/image_downloader_stub.dart'
    if (dart.library.io) 'src/image_downloader_io.dart'
    if (dart.library.html) 'src/image_downloader_web.dart';
