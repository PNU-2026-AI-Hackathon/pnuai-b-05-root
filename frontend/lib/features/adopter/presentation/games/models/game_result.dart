import 'game_item.dart';
import 'game_type.dart';
import 'reward_grade.dart';

/// 게임 종료 결과. 각 게임 화면이 종료 시 이 객체를 만들어
/// `Navigator.pop(context, result)`로 게임 탭에 돌려준다.
class GameResult {
  const GameResult({
    required this.score,
    required this.cleared,
    required this.gameType,
    this.itemsEarned = const [],
    this.grade,
  });

  /// 획득 점수 (예: 무화과 퀴즈는 문항당 10점, 만점 100점).
  final int score;

  /// 목표 달성 여부 (달성 시에만 아이템을 준다).
  final bool cleared;

  /// 어느 게임의 결과인지. 골드 등급 직접 선택 UI(`GameScaffold._GoldRewardDialog`)가
  /// `rewardCountFor(gameType, grade)`로 게임별 선택 개수를 알아내는 데 쓴다.
  final GameType gameType;

  /// 이번 게임에서 획득한 아이템 목록. 목표 미달성 시 항상 빈 리스트이고,
  /// 골드 등급이면 결과 다이얼로그에서 사용자가 직접 고르기 전까지도 빈 리스트다.
  final List<GameItem> itemsEarned;

  /// 획득 등급. cleared == false면 항상 null.
  final RewardGrade? grade;
}
