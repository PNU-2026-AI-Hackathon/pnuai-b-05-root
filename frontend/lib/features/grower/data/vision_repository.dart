import 'dart:typed_data';

import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';

/// `VisionAnalysis` 응답 한 건 (`VisionAnalysisResultSerializer`와 1:1 매핑).
class VisionAnalysisResult {
  const VisionAnalysisResult({
    required this.resultTag,
    required this.confidence,
    required this.analyzedAt,
    this.locationInfo,
  });

  final String resultTag;
  final double confidence;
  final String? locationInfo;
  final DateTime analyzedAt;

  factory VisionAnalysisResult.fromJson(Map<String, dynamic> json) =>
      VisionAnalysisResult(
        resultTag: json['result_tag'] as String,
        confidence: (json['confidence'] as num).toDouble(),
        locationInfo: json['location_info'] as String?,
        analyzedAt: DateTime.parse(json['analyzed_at'] as String),
      );
}

/// backend/vision (`POST /api/vision/analyze/`) 연동 — 재배자용 이미지 분석 요청.
class VisionRepository {
  VisionRepository({ApiClient? apiClient, TokenStorage? tokenStorage})
    : _apiClient = apiClient ?? ApiClient(),
      _tokenStorage = tokenStorage ?? TokenStorage();

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  /// [diaryId]를 함께 보내면 서버가 해당 `Diary.yolo_status_tag`도 같이 갱신한다.
  Future<VisionAnalysisResult> analyzeImage({
    required Uint8List imageBytes,
    required String imageFileName,
    int? diaryId,
  }) async {
    final accessToken = await _tokenStorage.readAccessToken();
    if (accessToken == null) {
      throw ApiException('로그인이 필요해요.');
    }
    final response = await _apiClient.postMultipart(
      '/api/vision/analyze/',
      fields: {if (diaryId != null) 'diary_id': '$diaryId'},
      fileBytes: imageBytes,
      fileFieldName: 'image',
      fileName: imageFileName,
      accessToken: accessToken,
    );
    return VisionAnalysisResult.fromJson(response);
  }
}
