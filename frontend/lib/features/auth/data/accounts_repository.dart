import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';

/// backend/accounts (`PATCH /api/accounts/me/`) 연동 — 본인 프로필 수정.
class AccountsRepository {
  AccountsRepository({ApiClient? apiClient, TokenStorage? tokenStorage})
    : _apiClient = apiClient ?? ApiClient(),
      _tokenStorage = tokenStorage ?? TokenStorage();

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  Future<void> updateNickname(String nickname) async {
    final accessToken = await _tokenStorage.readAccessToken();
    if (accessToken == null) {
      throw ApiException('로그인이 필요해요.');
    }
    await _apiClient.patch(
      '/api/accounts/me/',
      body: {'nickname': nickname},
      accessToken: accessToken,
    );
  }
}
