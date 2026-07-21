/// 게임에서 획득할 수 있는 아이템 모델.
/// 에셋 이미지 없이 이모지 문자열(예: '🍃')로 표현한다.
class GameItem {
  const GameItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
  });

  final String id;
  final String name;
  final String emoji;
  final String description;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'description': description,
  };

  factory GameItem.fromJson(Map<String, dynamic> json) => GameItem(
    id: json['id'] as String,
    name: json['name'] as String,
    emoji: json['emoji'] as String,
    description: json['description'] as String,
  );
}
