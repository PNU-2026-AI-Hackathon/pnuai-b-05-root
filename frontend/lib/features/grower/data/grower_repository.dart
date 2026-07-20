import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';

/// backend/seedlings (`PATCH /api/seedlings/{id}/complete/`) 연동.
class GrowerRepository {
  GrowerRepository({ApiClient? apiClient, TokenStorage? tokenStorage})
    : _apiClient = apiClient ?? ApiClient(),
      _tokenStorage = tokenStorage ?? TokenStorage();

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  Future<void> completeSeedling(int seedlingId) async {
    final accessToken = await _tokenStorage.readAccessToken();
    if (accessToken == null) {
      throw ApiException('로그인이 필요해요.');
    }
    await _apiClient.patch(
      '/api/seedlings/$seedlingId/complete/',
      accessToken: accessToken,
    );
  }
}
