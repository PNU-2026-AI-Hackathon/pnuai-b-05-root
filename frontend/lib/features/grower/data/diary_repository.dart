import 'dart:typed_data';

import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';

/// 재배 활동 캘린더(`GrowerActivityCalendarScreen`)에서 날짜별로 묶어 보여줄 때 필요한
/// 최소 필드만 담는다 — adopter 쪽 `DiaryEntry`와 달리 photo/illustration/yolo 태그는
/// 이 화면에 쓰이지 않아 넣지 않았다.
class DiaryEntry {
  const DiaryEntry({
    required this.id,
    required this.content,
    required this.createdAt,
  });

  final int id;
  final String content;
  final DateTime createdAt;

  factory DiaryEntry.fromJson(Map<String, dynamic> json) => DiaryEntry(
    id: json['id'] as int,
    content: json['content'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

/// backend/diary (`POST /api/diary/` 작성, `GET /api/diary/{seedling_id}/` 조회) 연동
/// — 재배자용.
class DiaryRepository {
  DiaryRepository({ApiClient? apiClient, TokenStorage? tokenStorage})
    : _apiClient = apiClient ?? ApiClient(),
      _tokenStorage = tokenStorage ?? TokenStorage();

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  /// [photoBytes]가 주어지면 `multipart/form-data`로, 아니면 사진 없이 텍스트만 전송한다.
  /// 생성된 일지의 id를 반환한다 — vision 분석 요청 시 `diary_id`로 연결하기 위함이다.
  Future<int> createDiary({
    required int seedlingId,
    required String content,
    Uint8List? photoBytes,
    String? photoFileName,
  }) async {
    final accessToken = await _tokenStorage.readAccessToken();
    if (accessToken == null) {
      throw ApiException('로그인이 필요해요.');
    }
    final response = await _apiClient.postMultipart(
      '/api/diary/',
      fields: {'seedling': '$seedlingId', 'content': content},
      fileBytes: photoBytes,
      fileFieldName: photoBytes == null ? null : 'photo',
      fileName: photoFileName,
      accessToken: accessToken,
    );
    return response['id'] as int;
  }

  /// 특정 묘목의 일지 목록을 조회한다. 재배 활동 캘린더가 담당 묘목 전체를 순회하며
  /// 병렬로 호출한다.
  Future<List<DiaryEntry>> fetchDiaries(int seedlingId) async {
    final accessToken = await _tokenStorage.readAccessToken();
    if (accessToken == null) {
      throw ApiException('로그인이 필요해요.');
    }
    final response = await _apiClient.get(
      '/api/diary/$seedlingId/',
      accessToken: accessToken,
    );
    return (response as List<dynamic>)
        .map((json) => DiaryEntry.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
