import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';

/// `SensorData` 응답 한 건.
class SensorReading {
  const SensorReading({
    required this.id,
    required this.temperature,
    required this.humidity,
    required this.light,
    required this.recordedAt,
    required this.isAnomaly,
    this.geminiDiagnosis,
  });

  final int id;
  final double temperature;
  final double humidity;
  final double light;
  final DateTime recordedAt;
  final bool isAnomaly;
  final String? geminiDiagnosis;

  factory SensorReading.fromJson(Map<String, dynamic> json) => SensorReading(
    id: json['id'] as int,
    temperature: (json['temperature'] as num).toDouble(),
    humidity: (json['humidity'] as num).toDouble(),
    light: (json['light'] as num).toDouble(),
    recordedAt: DateTime.parse(json['recorded_at'] as String),
    isAnomaly: json['is_anomaly'] as bool,
    geminiDiagnosis: json['gemini_diagnosis'] as String?,
  );
}

/// backend/sensor (`POST /api/sensor/data/`, `GET /api/sensor/anomaly/{seedling_id}/`) 연동.
class SensorRepository {
  SensorRepository({ApiClient? apiClient, TokenStorage? tokenStorage})
    : _apiClient = apiClient ?? ApiClient(),
      _tokenStorage = tokenStorage ?? TokenStorage();

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  /// 이상 감지 여부(`is_anomaly`)와 진단 텍스트(`gemini_diagnosis`)는 서버가 판정해
  /// 응답에 실어 보낸다 — 클라이언트에서는 판정 로직을 갖지 않는다.
  Future<SensorReading> createSensorData({
    required int seedlingId,
    required double temperature,
    required double humidity,
    required double light,
  }) async {
    final accessToken = await _requireAccessToken();
    final response = await _apiClient.post(
      '/api/sensor/data/',
      body: {
        'seedling': seedlingId,
        'temperature': temperature,
        'humidity': humidity,
        'light': light,
      },
      accessToken: accessToken,
    );
    return SensorReading.fromJson(response);
  }

  /// 해당 묘목의 이상 감지 이력(`is_anomaly=True`인 기록만). 최신순으로 정렬해 반환한다.
  Future<List<SensorReading>> fetchAnomalyHistory(int seedlingId) async {
    final accessToken = await _requireAccessToken();
    final response = await _apiClient.get(
      '/api/sensor/anomaly/$seedlingId/',
      accessToken: accessToken,
    );
    final readings = (response as List<dynamic>)
        .map((json) => SensorReading.fromJson(json as Map<String, dynamic>))
        .toList();
    readings.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return readings;
  }

  Future<String> _requireAccessToken() async {
    final accessToken = await _tokenStorage.readAccessToken();
    if (accessToken == null) {
      throw ApiException('로그인이 필요해요.');
    }
    return accessToken;
  }
}
