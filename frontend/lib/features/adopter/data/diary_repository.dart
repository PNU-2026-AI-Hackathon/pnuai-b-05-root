import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';

/// `GET /api/diary/{seedling_id}/` 응답 한 건. 성장 타임라인 화면에서 쓰는 필드만 파싱한다.
class DiaryEntry {
  const DiaryEntry({
    required this.id,
    required this.content,
    required this.createdAt,
    this.photoUrl,
    this.yoloStatusTag,
  });

  final int id;
  final String content;
  final DateTime createdAt;
  final String? photoUrl;
  final String? yoloStatusTag;

  factory DiaryEntry.fromJson(Map<String, dynamic> json) => DiaryEntry(
    id: json['id'] as int,
    content: json['content'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    photoUrl: json['photo'] as String?,
    yoloStatusTag: json['yolo_status_tag'] as String?,
  );
}

/// backend/diary (`GET /api/diary/{seedling_id}/`) 연동 — 입양자용 조회.
class DiaryRepository {
  DiaryRepository({ApiClient? apiClient, TokenStorage? tokenStorage})
    : _apiClient = apiClient ?? ApiClient(),
      _tokenStorage = tokenStorage ?? TokenStorage();

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  /// 최신 일지가 먼저 오도록 `created_at` 내림차순으로 정렬해 반환한다
  /// (백엔드는 별도 정렬 없이 저장 순서 그대로 내려준다).
  Future<List<DiaryEntry>> fetchDiaries(int seedlingId) async {
    final accessToken = await _tokenStorage.readAccessToken();
    if (accessToken == null) {
      throw ApiException('로그인이 필요해요.');
    }
    final response = await _apiClient.get(
      '/api/diary/$seedlingId/',
      accessToken: accessToken,
    );
    final entries = (response as List<dynamic>)
        .map((json) => DiaryEntry.fromJson(json as Map<String, dynamic>))
        .toList();
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }
}
