import 'dart:typed_data';

import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';

/// 재배 활동 캘린더(`GrowerActivityCalendarScreen`)와 묘목별 일지 리스트
/// (`GrowerDiaryListScreen`)에서 쓴다 — adopter 쪽 `DiaryEntry`와 달리 photo/illustration은
/// 이 두 화면에 쓰이지 않아 넣지 않았다.
class DiaryEntry {
  const DiaryEntry({
    required this.id,
    required this.content,
    required this.createdAt,
    this.yoloStatusTag,
    this.growthStage,
    this.growthStageLabel,
  });

  final int id;
  final String content;
  final DateTime createdAt;
  final String? yoloStatusTag;

  /// 재배자가 일지 작성 시 선택한 성장 단계의 코드값(백엔드 `growth_stage`,
  /// rooting/leafing/branching/mature). 선반 뷰의 필터 버튼이 이 값을 기준으로 묘목을
  /// 걸러낸다 — [growthStageLabel](한글 라벨)은 표시용이라 필터 비교에는 코드값을 쓴다.
  final String? growthStage;

  /// 재배자가 일지 작성 시 선택한 성장 단계의 한글 라벨(백엔드 `growth_stage_label`).
  /// 이 필드 도입 이전 일지에는 값이 없어 null일 수 있다.
  final String? growthStageLabel;

  factory DiaryEntry.fromJson(Map<String, dynamic> json) => DiaryEntry(
    id: json['id'] as int,
    content: json['content'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    yoloStatusTag: json['yolo_status_tag'] as String?,
    growthStage: json['growth_stage'] as String?,
    growthStageLabel: json['growth_stage_label'] as String?,
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

  /// [photoBytes]가 주어지면 `multipart/form-data`로, 아니면 사진 없이 텍스트만 전송한다
  /// (요청 자체는 사진 유무와 무관하게 항상 `postMultipart`를 거치므로 `growthStage`도
  /// 두 경우 모두 동일하게 `fields`에 실린다). [growthStage]는 백엔드
  /// `Diary.GrowthStage` 코드값(rooting/leafing/branching/mature)이며, null이면
  /// `growth_stage` 필드 자체를 보내지 않아 서버에서 null로 저장된다. 생성된 일지의
  /// id를 반환한다 — vision 분석 요청 시 `diary_id`로 연결하기 위함이다.
  Future<int> createDiary({
    required int seedlingId,
    required String content,
    Uint8List? photoBytes,
    String? photoFileName,
    String? growthStage,
  }) async {
    final accessToken = await _tokenStorage.readAccessToken();
    if (accessToken == null) {
      throw ApiException('로그인이 필요해요.');
    }
    final response = await _apiClient.postMultipart(
      '/api/diary/',
      fields: {
        'seedling': '$seedlingId',
        'content': content,
        'growth_stage': ?growthStage,
      },
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
