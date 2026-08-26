import '../../../core/network/api_client.dart';
import '../../../core/storage/care_inventory_storage.dart';
import '../../../core/storage/inventory_storage.dart';
import '../../../core/storage/token_storage.dart';

enum UserRole { adopter, grower }

extension UserRoleApi on UserRole {
  String get apiValue => this == UserRole.adopter ? 'adopter' : 'grower';

  static UserRole fromApiValue(String value) =>
      value == 'grower' ? UserRole.grower : UserRole.adopter;
}

class LoginResult {
  LoginResult({required this.role, required this.userId});
  final UserRole role;
  final String userId;
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
    final userId = response['id'].toString();
    await _tokenStorage.save(
      access: response['access'] as String,
      refresh: response['refresh'] as String,
      email: email,
      userId: userId,
      nickname: response['nickname'] as String?,
    );
    // 최초 로그인 시에만 물주기/영양제를 각 2개씩 지급한다(멱등, 재로그인 시 재지급 안 됨).
    await CareInventoryStorage(userId: userId).grantInitialIfNeeded();
    return LoginResult(
      role: UserRoleApi.fromApiValue(response['role'] as String),
      userId: userId,
    );
  }

  Future<void> register({
    required String email,
    required String password,
    required UserRole role,
    String nickname = '',
  }) async {
    await _apiClient.post(
      '/api/accounts/register/',
      body: {
        'email': email,
        'password': password,
        'role': role.apiValue,
        'nickname': nickname,
      },
    );
  }

  Future<void> logout() => _tokenStorage.clear();

  /// 회원탈퇴. `DELETE /api/accounts/me/` 호출 성공 후 이 계정의 로컬 보유 아이템
  /// ([InventoryStorage])과 토큰([TokenStorage])을 함께 지운다. 계정이 사라지므로
  /// 남겨둘 이유가 없어 로그아웃(계정 유지)과 달리 인벤토리까지 삭제한다.
  Future<void> deleteAccount() async {
    final accessToken = await _tokenStorage.readAccessToken();
    await _apiClient.delete('/api/accounts/me/', accessToken: accessToken!);
    final userId = await _tokenStorage.readUserId();
    if (userId != null) await InventoryStorage(userId: userId).clear();
    await _tokenStorage.clear();
  }
}
