enum RewardGrade { bronze, silver, gold }

/// 점수를 등급으로 변환한다. 50점 미만이면 클리어 실패이므로 null을 반환한다.
/// - 브론즈: 50~69
/// - 실버: 70~89
/// - 골드: 90~100
RewardGrade? computeRewardGrade(int score) {
  if (score < 50) return null;
  if (score < 70) return RewardGrade.bronze;
  if (score < 90) return RewardGrade.silver;
  return RewardGrade.gold;
}
