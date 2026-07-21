import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// API 서버로 보낸 요청이 실패했을 때 던지는 예외.
/// [message]는 서버가 내려준 에러 메시지(한국어) 또는 네트워크 오류 설명이다.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// 백엔드(Django REST Framework) 공통 HTTP 클라이언트.
///
/// 개발 서버 기본 주소는 데스크톱/웹/iOS 시뮬레이터 기준 localhost다.
/// Android 에뮬레이터에서 실행할 때는 `--dart-define=API_BASE_URL=http://10.0.2.2:8000`
/// 로 오버라이드한다.
class ApiClient {
  ApiClient({String? baseUrl})
    : baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://localhost:8000',
          );

  final String baseUrl;

  Future<Map<String, dynamic>> post(
    String path, {
    required Map<String, dynamic> body,
    String? accessToken,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    late final http.Response response;
    try {
      response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (accessToken != null) 'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(body),
      );
    } on Exception {
      throw ApiException('서버에 연결할 수 없어요. 네트워크 상태를 확인해주세요.');
    }

    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    throw ApiException(
      _extractErrorMessage(decoded),
      statusCode: response.statusCode,
    );
  }

  /// JWT access 토큰이 필요한 인증된 GET 요청. 목록 엔드포인트는 최상위가 JSON 배열이라
  /// `Map`이 아닌 `dynamic`을 반환한다 — 호출부에서 `as List<dynamic>` 등으로 캐스팅한다.
  Future<dynamic> get(String path, {String? accessToken}) async {
    final uri = Uri.parse('$baseUrl$path');
    late final http.Response response;
    try {
      response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (accessToken != null) 'Authorization': 'Bearer $accessToken',
        },
      );
    } on Exception {
      throw ApiException('서버에 연결할 수 없어요. 네트워크 상태를 확인해주세요.');
    }

    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    throw ApiException(
      decoded is Map<String, dynamic>
          ? _extractErrorMessage(decoded)
          : '요청 처리 중 오류가 발생했어요.',
      statusCode: response.statusCode,
    );
  }

  /// JWT access 토큰이 필요한 인증된 PATCH 요청.
  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    required String accessToken,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    late final http.Response response;
    try {
      response = await http.patch(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: body == null ? null : jsonEncode(body),
      );
    } on Exception {
      throw ApiException('서버에 연결할 수 없어요. 네트워크 상태를 확인해주세요.');
    }

    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    throw ApiException(
      _extractErrorMessage(decoded),
      statusCode: response.statusCode,
    );
  }

  /// 인증된 `multipart/form-data` POST 요청. 파일 필드(`fileFieldName`)가 주어지면
  /// 바이트로 첨부한다 — 웹에서도 동일하게 동작하도록 파일 경로가 아닌 바이트를 받는다.
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required Map<String, String> fields,
    Uint8List? fileBytes,
    String? fileFieldName,
    String? fileName,
    required String accessToken,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..fields.addAll(fields);
    if (fileBytes != null && fileFieldName != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          fileFieldName,
          fileBytes,
          filename: fileName ?? 'upload.jpg',
        ),
      );
    }

    late final http.Response response;
    try {
      final streamed = await request.send();
      response = await http.Response.fromStream(streamed);
    } on Exception {
      throw ApiException('서버에 연결할 수 없어요. 네트워크 상태를 확인해주세요.');
    }

    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    throw ApiException(
      _extractErrorMessage(decoded),
      statusCode: response.statusCode,
    );
  }

  String _extractErrorMessage(Map<String, dynamic> decoded) {
    // DRF ValidationError는 필드명 -> [메시지] 또는 non_field_errors 형태로 내려온다.
    for (final value in decoded.values) {
      if (value is List && value.isNotEmpty) {
        return value.first.toString();
      }
      if (value is String) {
        return value;
      }
    }
    return '요청 처리 중 오류가 발생했어요.';
  }
}
