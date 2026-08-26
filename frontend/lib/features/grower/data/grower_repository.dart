import 'dart:typed_data';

import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';

enum SeedlingStatus { growing, completed }

extension SeedlingStatusApi on SeedlingStatus {
  static SeedlingStatus fromApiValue(String value) =>
      value == 'completed' ? SeedlingStatus.completed : SeedlingStatus.growing;
}

/// `GET /api/seedlings/` 응답 한 건. 재배자 대시보드에서 쓰는 필드만 파싱한다.
class Seedling {
  const Seedling({
    required this.id,
    required this.adopterId,
    required this.status,
    required this.startedAt,
    this.completedAt,
  });

  final int id;
  final int adopterId;
  final SeedlingStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;

  factory Seedling.fromJson(Map<String, dynamic> json) => Seedling(
    id: json['id'] as int,
    adopterId: json['adopter'] as int,
    status: SeedlingStatusApi.fromApiValue(json['status'] as String),
    startedAt: DateTime.parse(json['started_at'] as String),
    completedAt: json['completed_at'] == null
        ? null
        : DateTime.parse(json['completed_at'] as String),
  );
}

/// backend/seedlings (`GET /api/seedlings/`, `PATCH /api/seedlings/{id}/complete/`) 연동.
class GrowerRepository {
  GrowerRepository({ApiClient? apiClient, TokenStorage? tokenStorage})
    : _apiClient = apiClient ?? ApiClient(),
      _tokenStorage = tokenStorage ?? TokenStorage();

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  /// 로그인한 재배자가 담당하는 묘목 목록. `SeedlingListCreateView.get_queryset`이
  /// `request.user.role == GROWER`일 때 `grower=user`로 이미 필터링해 내려주므로
  /// 클라이언트에서 별도 필터링은 하지 않는다.
  Future<List<Seedling>> fetchSeedlings() async {
    final accessToken = await _requireAccessToken();
    final response = await _apiClient.get(
      '/api/seedlings/',
      accessToken: accessToken,
    );
    return (response as List<dynamic>)
        .map((json) => Seedling.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// 묘목 완성 신고. 재배자가 입력한 최종 키(`heightCm`, 필수)와 최종 사진
  /// (`photoBytes`, 선택)을 함께 보낸다 — `diary_repository.dart`의 `createDiary()`처럼
  /// 사진 유무와 무관하게 항상 멀티파트로 전송한다. 응답으로 갱신된 묘목을 돌려준다
  /// (완성 신고 성공 문구에서 서버가 확정한 `completed_at`을 쓰기 위함).
  Future<Seedling> completeSeedling({
    required int seedlingId,
    required int heightCm,
    Uint8List? photoBytes,
    String? photoFileName,
  }) async {
    final accessToken = await _requireAccessToken();
    final response = await _apiClient.patchMultipart(
      '/api/seedlings/$seedlingId/complete/',
      fields: {'height_cm': '$heightCm'},
      fileBytes: photoBytes,
      fileFieldName: photoBytes == null ? null : 'final_photo',
      fileName: photoFileName,
      accessToken: accessToken,
    );
    return Seedling.fromJson(response);
  }

  Future<String> _requireAccessToken() async {
    final accessToken = await _tokenStorage.readAccessToken();
    if (accessToken == null) {
      throw ApiException('로그인이 필요해요.');
    }
    return accessToken;
  }
}
