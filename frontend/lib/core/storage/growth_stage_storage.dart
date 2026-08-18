import 'package:shared_preferences/shared_preferences.dart';

/// 입양자가 마지막으로 확인한 무화과 성장 단계(코드: rooting/leafing/branching/mature)를
/// 기기에 저장한다. 홈 화면이 다음 조회 때 이 값과 최신 단계를 비교해 "진행됨"을
/// 감지하고, 감지 즉시 최신 값으로 덮어써 스스로 리셋되게 한다([CareStorage]와 동일하게
/// **계정(userId) 단위**로 분리 저장 — [TokenStorage.readUserId]로 얻은 값을 그대로
/// 넘겨 생성한다).
class GrowthStageStorage {
  GrowthStageStorage({required this.userId});

  final String userId;

  static const _keyPrefix = 'pigfig.growth_stage_last_seen.';

  /// 마지막으로 저장된 성장 단계 코드. 저장된 적 없으면(신규 계정, 또는 기능 도입 이전부터
  /// 쓰던 계정) null — 호출부는 이 경우 "히스토리 없음"으로 취급해 진행 여부를 판단하지
  /// 않고 곧장 idle 상태로 표시해야 한다.
  Future<String?> getLastSeenStage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_keyPrefix$userId');
  }

  /// 현재 단계를 "마지막으로 확인한 단계"로 기록한다. 호출부(`_fetchGrowthStageState`)가
  /// 매 조회마다 무조건 호출해, 이 저장소 자체가 "다음 조회에서 같은 진행을 다시
  /// 감지하지 않음"을 자연스럽게 보장하게 한다(별도의 consumed 콜백 불필요).
  Future<void> setLastSeenStage(String stage) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keyPrefix$userId', stage);
  }
}
