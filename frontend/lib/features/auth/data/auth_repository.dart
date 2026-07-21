import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';

enum UserRole { adopter, grower }

extension UserRoleApi on UserRole {
  String get apiValue => this == UserRole.adopter ? 'adopter' : 'grower';

  static UserRole fromApiValue(String value) =>
      value == 'grower' ? UserRole.grower : UserRole.adopter;
}

class LoginResult {
  LoginResult({required this.role});
  final UserRole role;
}

/// backend/accounts (`/api/accounts/register/`, `/api/accounts/login/`) 연동.
class AuthRepository {
  AuthRepository({ApiClient? apiClient, TokenStorage? tokenStorage})
    : _apiClient = apiClient ?? ApiClient(),
      _tokenStorage = tokenStorage ?? TokenStorage();

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post(
      '/api/accounts/login/',
      body: {'email': email, 'password': password},
    );
    await _tokenStorage.save(
      access: response['access'] as String,
      refresh: response['refresh'] as String,
      email: email,
    );
    return LoginResult(
      role: UserRoleApi.fromApiValue(response['role'] as String),
    );
  }

  Future<void> register({
    required String email,
    required String password,
    required UserRole role,
  }) async {
    await _apiClient.post(
      '/api/accounts/register/',
      body: {'email': email, 'password': password, 'role': role.apiValue},
    );
  }

  Future<void> logout() => _tokenStorage.clear();

  /// 회원탈퇴. `DELETE /api/accounts/me/` 호출 후 로컬 토큰도 함께 지운다.
  Future<void> deleteAccount() async {
    final accessToken = await _tokenStorage.readAccessToken();
    await _apiClient.delete('/api/accounts/me/', accessToken: accessToken!);
    await _tokenStorage.clear();
  }
}
