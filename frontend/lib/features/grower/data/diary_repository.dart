import 'dart:typed_data';

import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';

/// backend/diary (`POST /api/diary/`) 연동 — 재배자용 작성.
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
}
