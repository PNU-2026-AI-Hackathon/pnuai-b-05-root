import 'game_item.dart';

/// 게임 종료 결과. 각 게임 화면이 종료 시 이 객체를 만들어
/// `Navigator.pop(context, result)`로 게임 탭에 돌려준다.
class GameResult {
  const GameResult({
    required this.score,
    required this.cleared,
    this.itemEarned,
  });

  /// 획득 점수 (예: 무화과 퀴즈는 문항당 10점, 만점 100점).
  final int score;

  /// 목표 달성 여부 (달성 시에만 아이템을 준다).
  final bool cleared;

  /// 이번 게임에서 획득한 아이템. 목표 미달성 시 null.
  final GameItem? itemEarned;
}
