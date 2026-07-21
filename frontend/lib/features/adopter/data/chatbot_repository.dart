import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';

/// backend/chatbot (`POST /api/chatbot/ask/`) 연동.
class ChatbotRepository {
  ChatbotRepository({ApiClient? apiClient, TokenStorage? tokenStorage})
    : _apiClient = apiClient ?? ApiClient(),
      _tokenStorage = tokenStorage ?? TokenStorage();

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  Future<String> ask(String question) async {
    final accessToken = await _tokenStorage.readAccessToken();
    if (accessToken == null) {
      throw ApiException('로그인이 필요해요.');
    }
    final response = await _apiClient.post(
      '/api/chatbot/ask/',
      body: {'question': question},
      accessToken: accessToken,
    );
    return response['answer'] as String;
  }
}
