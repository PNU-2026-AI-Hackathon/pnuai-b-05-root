// 완성 시각(`Seedling.completed_at`)을 기준으로 계절 배지 문구를 계산한다.
//
// 순수 함수라 단독 테스트가 쉽고, 기부 인증서(`donation_certificate_screen.dart`)와
// 재배자 완성 신고 성공 문구(`grower_complete_screen.dart`) 양쪽이 공유한다.
// 백엔드는 `completed_at`만 내려주고(ISO8601 + tz) 계절 계산은 하지 않는다 —
// 문구·이모지는 UI 카피라 여기서만 관리한다.

/// 계절 배지 한 조각. `label`은 "한여름"처럼 명사, `emoji`는 그 옆에 붙이는 이모지.
typedef SeasonBadge = ({String label, String emoji});

/// [completedAt](UTC일 수 있음)을 로컬 시각으로 바꾼 뒤 월(month) 기준으로 계절을 정한다.
/// 3~5월 봄 / 6월 초여름 / 7~8월 한여름 / 9~11월 가을 / 12~2월 겨울.
SeasonBadge seasonBadgeFor(DateTime completedAt) {
  switch (completedAt.toLocal().month) {
    case 3:
    case 4:
    case 5:
      return (label: '봄', emoji: '🌸');
    case 6:
      return (label: '초여름', emoji: '🌿');
    case 7:
    case 8:
      return (label: '한여름', emoji: '☀️');
    case 9:
    case 10:
    case 11:
      return (label: '가을', emoji: '🍁');
    default: // 12, 1, 2
      return (label: '겨울', emoji: '⛄');
  }
}

/// "한여름에 완성됐어요 ☀️" 형태의 한 줄 문구.
String seasonCompletionPhrase(DateTime completedAt) {
  final badge = seasonBadgeFor(completedAt);
  return '${badge.label}에 완성됐어요 ${badge.emoji}';
}
