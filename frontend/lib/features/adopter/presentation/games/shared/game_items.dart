import '../models/game_item.dart';

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
