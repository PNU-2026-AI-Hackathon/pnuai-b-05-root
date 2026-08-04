import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';

enum SeedlingStatus { growing, completed }

extension SeedlingStatusApi on SeedlingStatus {
  static SeedlingStatus fromApiValue(String value) =>
      value == 'completed' ? SeedlingStatus.completed : SeedlingStatus.growing;
}

/// `Seedling.pickup_or_donate`(backend `PickupOrDonate` TextChoices)와 1:1 대응.
enum PickupOrDonateChoice { pickup, donate }

extension PickupOrDonateChoiceApi on PickupOrDonateChoice {
  String get apiValue => this == PickupOrDonateChoice.pickup ? 'pickup' : 'donate';

  static PickupOrDonateChoice? fromApiValue(String? value) => switch (value) {
    'pickup' => PickupOrDonateChoice.pickup,
    'donate' => PickupOrDonateChoice.donate,
    _ => null,
  };
}

/// `Seedling.donate_type`(backend `DonateType` TextChoices)와 1:1 대응.
enum DonateType { schoolWelfare, urbanFarmingCommunity, inAppSharing }

extension DonateTypeApi on DonateType {
  String get apiValue => switch (this) {
    DonateType.schoolWelfare => 'school_welfare',
    DonateType.urbanFarmingCommunity => 'urban_farming_community',
    DonateType.inAppSharing => 'in_app_sharing',
  };

  static DonateType? fromApiValue(String? value) => switch (value) {
    'school_welfare' => DonateType.schoolWelfare,
    'urban_farming_community' => DonateType.urbanFarmingCommunity,
    'in_app_sharing' => DonateType.inAppSharing,
    _ => null,
  };
}

/// `GET /api/seedlings/` 응답 한 건. 입양자 화면(홈/성장 타임라인/수령·기부 선택)에서 쓰는
/// 필드만 파싱한다.
class Seedling {
  const Seedling({
    required this.id,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.pickupOrDonate,
    this.donateType,
  });

  final int id;
  final SeedlingStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final PickupOrDonateChoice? pickupOrDonate;
  final DonateType? donateType;

  factory Seedling.fromJson(Map<String, dynamic> json) => Seedling(
    id: json['id'] as int,
    status: SeedlingStatusApi.fromApiValue(json['status'] as String),
    startedAt: DateTime.parse(json['started_at'] as String),
    completedAt: json['completed_at'] == null
        ? null
        : DateTime.parse(json['completed_at'] as String),
    pickupOrDonate: PickupOrDonateChoiceApi.fromApiValue(
      json['pickup_or_donate'] as String?,
    ),
    donateType: DonateTypeApi.fromApiValue(json['donate_type'] as String?),
  );
}

/// 여러 묘목 중 홈/성장 타임라인에 대표로 보여줄 하나를 고른다. 재배중인 묘목이 있으면
/// 그중 가장 최근에 시작한 것을, 없으면(전부 완료) 가장 최근에 완료된 것을 우선한다 —
/// 입양자가 지금 신경 쓰고 있을 가능성이 가장 큰 묘목을 보여주기 위함이다.
Seedling? pickPrimarySeedling(List<Seedling> seedlings) {
  if (seedlings.isEmpty) return null;
  final growing =
      seedlings.where((s) => s.status == SeedlingStatus.growing).toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  if (growing.isNotEmpty) return growing.first;
  final byCompletion = [...seedlings]
    ..sort(
      (a, b) => (b.completedAt ?? b.startedAt).compareTo(
        a.completedAt ?? a.startedAt,
      ),
    );
  return byCompletion.first;
}

/// 수령/기부를 선택할 대상 묘목을 고른다 — 완료된 묘목 중 가장 최근에 완료된 것.
/// 이미 선택을 마친 묘목도 대상에 포함한다(백엔드가 재제출을 허용하므로 다시 바꿀 수 있음).
Seedling? pickSeedlingForPickupDonate(List<Seedling> seedlings) {
  final completed =
      seedlings.where((s) => s.status == SeedlingStatus.completed).toList()
        ..sort(
          (a, b) => (b.completedAt ?? b.startedAt).compareTo(
            a.completedAt ?? a.startedAt,
          ),
        );
  return completed.isEmpty ? null : completed.first;
}

/// backend/seedlings (`GET /api/seedlings/`) 연동 — 입양자용.
/// `grower/data/grower_repository.dart`의 동일한 패턴을 입양자 쪽에도 그대로 적용한다.
/// `SeedlingListCreateView.get_queryset`이 `role != GROWER`일 때 `adopter=user`로
/// 이미 필터링해 내려주므로 클라이언트에서 별도 필터링은 하지 않는다.
class SeedlingRepository {
  SeedlingRepository({ApiClient? apiClient, TokenStorage? tokenStorage})
    : _apiClient = apiClient ?? ApiClient(),
      _tokenStorage = tokenStorage ?? TokenStorage();

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  Future<List<Seedling>> fetchSeedlings() async {
    final accessToken = await _tokenStorage.readAccessToken();
    if (accessToken == null) {
      throw ApiException('로그인이 필요해요.');
    }
    final response = await _apiClient.get(
      '/api/seedlings/',
      accessToken: accessToken,
    );
    return (response as List<dynamic>)
        .map((json) => Seedling.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// 무화과 입양. 서버가 담당 재배자를 자동 배정하므로 별도 필드 없이 생성만 요청한다.
  Future<void> createSeedling() async {
    final accessToken = await _tokenStorage.readAccessToken();
    if (accessToken == null) {
      throw ApiException('로그인이 필요해요.');
    }
    await _apiClient.post(
      '/api/seedlings/',
      body: const {},
      accessToken: accessToken,
    );
  }

  /// 완성된 묘목의 수령/기부를 선택(또는 변경)한다.
  /// `choice`가 `donate`일 때는 `donateType`이 필수다.
  Future<Seedling> updatePickupOrDonate({
    required int seedlingId,
    required PickupOrDonateChoice choice,
    DonateType? donateType,
  }) async {
    final accessToken = await _tokenStorage.readAccessToken();
    if (accessToken == null) {
      throw ApiException('로그인이 필요해요.');
    }
    final response = await _apiClient.patch(
      '/api/seedlings/$seedlingId/pickup-donate/',
      body: {
        'pickup_or_donate': choice.apiValue,
        if (choice == PickupOrDonateChoice.donate) 'donate_type': donateType!.apiValue,
      },
      accessToken: accessToken,
    );
    return Seedling.fromJson(response);
  }
}
