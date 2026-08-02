import '../network/api_client.dart';

/// backend/notifications (`POST /api/notifications/register-token/`) 연동.
class FcmTokenRepository {
  FcmTokenRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<void> registerToken({
    required String token,
    required String accessToken,
  }) {
    return _apiClient.post(
      '/api/notifications/register-token/',
      body: {'token': token},
      accessToken: accessToken,
    );
  }
}
