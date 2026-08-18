import 'dart:math';

import '../models/game_item.dart';
import '../models/game_type.dart';
import '../models/reward_grade.dart';

/// 게임 보상으로 지급되는 공용 아이템 풀.
/// 여러 게임(무화과 퀴즈, 물주기 타이밍 등)이 목표 달성 시 이 목록에서
/// 랜덤으로 하나를 골라 지급한다. 게임별로 따로 정의하지 않고 여기서 공유한다.
const rewardItems = <GameItem>[
  GameItem(
    id: 'fig_leaf_fan',
    name: '무화과잎 부채',
    emoji: '🍃',
    description: '무더운 여름날 무화과나무 곁에서 부쳐 주는 시원한 잎 부채.',
  ),
  GameItem(
    id: 'senior_watering_can',
    name: '시니어의 물뿌리개',
    emoji: '💧',
    description: '시니어 재배자의 정성이 담긴 든든한 물뿌리개.',
  ),
  GameItem(
    id: 'warm_sunlight',
    name: '햇살 한 줌',
    emoji: '☀️',
    description: '묘목을 무럭무럭 자라게 하는 따뜻한 햇살 한 줌.',
  ),
];

/// 게임·등급별 지급 개수.
/// 브론즈는 모든 게임이 1개로 동일하고, 실버는 돼지 풍선 터뜨리기만 1개이고
/// 나머지(무화과 퀴즈/해충 잡기/물주기 타이밍)는 2개다 — "브론즈는 공통, 실버만
/// 게임마다 다르다"는 표 형태라 게임별 로컬 상수 4곳에 중복 정의하는 대신 이
/// 공용 함수 하나로 모았다. 골드는 돼지 풍선 터뜨리기/무화과 퀴즈/해충 잡기가 2개,
/// 물주기 타이밍만 3개다. 브론즈/실버는 [pickRewardItems]가 이 개수만큼 무작위로
/// 뽑지만, 골드는 이 개수를 결과 다이얼로그의 직접 선택 UI가 "사용자가 골라야 하는
/// 목표 개수"로 그대로 가져다 쓴다(각 게임 화면은 골드일 때 [pickRewardItems]를
/// 호출하지 않고 `itemsEarned`를 빈 리스트로 남겨둔다).
int rewardCountFor(GameType type, RewardGrade grade) {
  switch (grade) {
    case RewardGrade.bronze:
      return 1;
    case RewardGrade.silver:
      return type == GameType.balloonPop ? 1 : 2;
    case RewardGrade.gold:
      return type == GameType.wateringTiming ? 3 : 2;
  }
}

/// [grade]에 맞는 개수만큼 [rewardItems]에서 무작위로 뽑아 돌려준다.
/// grade가 null(클리어 실패)이면 빈 리스트를 돌려준다. 같은 아이템이 중복으로
/// 뽑힐 수 있다(랜덤 지급이므로 허용). 골드 등급은 사용자가 직접 고르므로(위
/// [rewardCountFor] 참고) 각 게임 화면이 골드에 대해서는 이 함수를 호출하지 않는다.
List<GameItem> pickRewardItems(GameType type, RewardGrade? grade, Random random) {
  if (grade == null) return const [];
  final count = rewardCountFor(type, grade);
  return List.generate(count, (_) => rewardItems[random.nextInt(rewardItems.length)]);
}
