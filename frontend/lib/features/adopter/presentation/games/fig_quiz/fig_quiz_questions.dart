/// 무화과 퀴즈 한 문항. 4지선다와 O/X를 함께 담기 위해 [options]를 가변 길이로 둔다
/// (O/X 문항은 options가 ['O', 'X'] 2개, 객관식은 4개).
class FigQuizQuestion {
  const FigQuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
  });

  final String question;
  final List<String> options;
  final int correctIndex;
}

/// 무화과 재배 상식 10문항. 농촌진흥청 매뉴얼 기반 챗봇(chatbot 앱)과 결이 맞는
/// 일반적인 재배 상식 수준으로 작성했다(원문 인용이 아닌 일반 지식).
const figQuizQuestions = <FigQuizQuestion>[
  FigQuizQuestion(
    question: '무화과 생육에 가장 알맞은 기온 범위는 어느 정도일까요?',
    options: ['영하 5~0도', '15~30도', '35~45도', '언제나 무관'],
    correctIndex: 1,
  ),
  FigQuizQuestion(
    question: '무화과는 씨앗보다 가지를 잘라 꽂는 삽목(꺾꽂이)으로 번식시키는 경우가 많다.',
    options: ['O', 'X'],
    correctIndex: 0,
  ),
  FigQuizQuestion(
    question: '식물이 광합성으로 만든 양분과 호흡으로 쓰는 양분이 같아지는 빛의 세기를 무엇이라 할까요?',
    options: ['광포화점', '광보상점', '증산점', '이슬점'],
    correctIndex: 1,
  ),
  FigQuizQuestion(
    question: '화분에 심은 무화과에 물을 줄 때 가장 바람직한 방법은?',
    options: [
      '매일 조금씩 흙이 늘 젖어 있게',
      '겉흙이 말랐을 때 흠뻑',
      '물을 거의 주지 않는다',
      '잎에만 자주 분무한다',
    ],
    correctIndex: 1,
  ),
  FigQuizQuestion(
    question: '무화과나무는 추위에 약한 편이라 겨울철 심한 추위에는 언 피해(동해)를 입기 쉽다.',
    options: ['O', 'X'],
    correctIndex: 0,
  ),
  FigQuizQuestion(
    question: '무화과의 원산지로 널리 알려진 지역은 어디일까요?',
    options: ['북극권', '지중해·서아시아', '남극 대륙', '고산 툰드라'],
    correctIndex: 1,
  ),
  FigQuizQuestion(
    question: '무화과의 열매처럼 보이는 부분 안쪽에는 꽃이 들어 있다(은화과).',
    options: ['O', 'X'],
    correctIndex: 0,
  ),
  FigQuizQuestion(
    question: '무화과 재배에 알맞은 토양 산도(pH)는 대체로 어느 정도일까요?',
    options: ['강산성(pH 3)', '약산성~중성(pH 6~7)', '강알칼리(pH 11)', '산도와 무관'],
    correctIndex: 1,
  ),
  FigQuizQuestion(
    question: '무화과 묘목은 하루 중 햇빛을 충분히 받는 자리에서 더 건강하게 자란다.',
    options: ['O', 'X'],
    correctIndex: 0,
  ),
  FigQuizQuestion(
    question: '무화과 가지치기(전정)는 일반적으로 언제 하는 것이 좋을까요?',
    options: [
      '한여름 무더위 때',
      '생장을 멈춘 겨울~이른 봄 휴면기',
      '장마철 습할 때',
      '수확 직전',
    ],
    correctIndex: 1,
  ),
];
