---
name: flutter-screen
description: Pig.Fig. 프로젝트에서 Flutter 화면을 새로 만들거나 수정할 때 따르는 표준 절차. 디자인 확인(DesignSync), 공용 위젯/토큰 재사용, 하단 탭 화면의 상태 보존·재조회 패턴, 완료 조건(analyze/Playwright/CLAUDE.md 갱신)을 다룬다. "화면 만들어줘", "탭 추가해줘", "이 화면 디자인대로 고쳐줘" 같은 요청에 사용한다.
---

# Flutter 화면 작업 (Pig.Fig.)

이 프로젝트의 프론트엔드 화면 작업은 매번 같은 패턴을 따른다. 작업 전 [CLAUDE.md](../../../CLAUDE.md)의
"프론트엔드 구조" 섹션을 먼저 읽는다 — 이 스킬은 그 내용을 절차로 정리한 것이지 대체하는 문서가 아니다.

## 1. 구조·명명 규칙

- `core/network` (`ApiClient`) / `core/storage` (`TokenStorage`, `OnboardingStorage`) / `core/theme`
  (`AppColors`, `AppTextStyles`, `AppTheme`) — 화면에서 직접 `TextStyle`이나 색상 하드코딩 대신 이 토큰을 쓴다.
- `features/<feature>/data/` — repository 계층. `features/<feature>/presentation/` — 화면 위젯.
- `shared/widgets/` — 여러 화면에서 재사용하는 공용 위젯.
- feature 간 데이터 계층은 참조하지 않는다. 예를 들어 `adopter`와 `grower`가 같은 모양의 데이터를 다뤄도
  (예: `Seedling`) 각자 `features/<role>/data/`에 자기 repository를 둔다(코드가 겹쳐도 이 프로젝트
  컨벤션). 반면 `features/auth/`(로그인/로그아웃/회원탈퇴)처럼 역할을 가리지 않는 진짜 공통 기능은
  cross-feature import를 허용한다(예: `mypage_screen.dart`가 `features/auth/presentation/
  account_actions.dart`를 그대로 가져다 씀).
- 상태관리 라이브러리 없음. `StatefulWidget` + `setState`만 사용한다.

## 2. 디자인 반영 — DesignSync로 직접 확인

디자인이 관련된 작업(신규 화면, 레이아웃 변경, 색상/타이포 조정)은 추측하지 말고 claude.ai/design
프로젝트("PigFig Screens.dc.html", 프로젝트명 "# Pig.Fig 무화과 양육 앱")를 DesignSync로 직접 읽는다.

1. `mcp__claude-design__list_projects`로 프로젝트 id 확인
2. `mcp__claude-design__read_file`로 `PigFig Screens.dc.html`을 필요한 라인 범위만 읽는다(파일이
   900줄대로 크므로 `offset`/`limit`로 섹션 단위 탐색 — 각 화면은 `<!-- ==== 1x 이름 ==== -->` 주석과
   `id="1x"` 앵커로 구분되어 있다. 1a=디자인 시스템, 1b~1p=입양자 화면, 1q~1u=재배자 화면)
3. 찾은 값(색상 hex, spacing, border-radius, 폰트 크기 등)을 그대로 옮긴다 — 임의로 근사하지 않는다.
4. 색상은 원본 hex를 그대로 쓰지 말고 먼저 `app_colors.dart`에 이미 정의된 토큰(`AppColors.pink500`
   등)과 대조해 있으면 토큰을 쓴다. 화면 전용 일회성 색상만 인라인 `Color(0xFF...)`로 남긴다
   (기존 코드에 이미 이런 사례가 있음, 예: `mypage_screen.dart`의 `Color(0xFFF7F5EC)`).
5. 디자인에 없는 상호작용(예: 신규 요구사항으로 생긴 화면)은 기존 화면들의 톤(라운드 카드, 그림자,
   Gaegu 디스플레이 폰트 + Noto Sans KR 본문)을 따라 새로 설계하고, 어떤 판단을 했는지 요약에 남긴다.

## 3. 공용 위젯 재사용

새로 만들기 전에 `shared/widgets/`에 이미 있는지 확인한다:

- `PigFigAppBar` — 로고+벨/닫기 버튼 공통 앱바. `showNotificationBell`(탭 화면), `closeLabel`(모달성
  화면, 닫으면 pop)을 상황에 맞게 쓴다. 둘 다 필요 없으면 옵션 추가 없이 그냥 재사용한다.
- `StatusBadge` — 배지/난이도 칩("정상", "재배중", "쉬움" 등).
- `SectionCard`, `GaugeBar`, `FigTreeIllustration`, `PigCharacter`, `PigFigButton`, `SpeechBubble`,
  `CareActionButton`, `StepIndicator`, `RoleToggle` 등.
- 두 화면에 필요한 로직(예: 로그아웃/회원탈퇴 확인 다이얼로그)은 위젯이 아니어도
  `features/auth/presentation/account_actions.dart`처럼 함수 단위로 뽑아 양쪽에서 재사용한다.

## 4. 하단 탭 화면이면 `RevalidatableState` 적용

이 화면이 `AdopterShell` 또는 `GrowerShell`의 탭으로 들어간다면(즉 `IndexedStack`으로 상태가 보존된다면),
탭을 벗어났다 돌아왔을 때 데이터가 낡아 있을 수 있는지 판단한다. 다른 탭에서의 행동으로 이 화면이 보여줄
데이터가 바뀔 수 있다면(예: 다른 탭에서 완성 신고/새 일지 작성/통계 변경) 반드시 적용한다. 매번 새로
입력하는 화면(예: 일지 작성 폼, 센서 수치 입력)은 재조회할 게 없으므로 적용하지 않는다.

절차 (`core/revalidatable_state.dart`의 `RevalidatableState<T>` 참고, 실제 예시는
`home_screen.dart`/`growth_timeline_screen.dart`/`grower_dashboard_screen.dart`/
`grower_mypage_screen.dart`):

1. `State<XScreen>` 대신 `RevalidatableState<XScreen>`을 상속한다.
2. `_hasLoadedOnce` bool 필드를 추가한다. 최초 `_load()`가 끝나면(성공/실패 무관) `true`로 설정한다.
3. `revalidate()`를 구현한다 — `_hasLoadedOnce`가 false면 `_load()`로 위임(최초 로드가 아직 안 끝난
   예외적 경우). 그 외에는 **`_loading`을 건드리지 않고** 백그라운드로 다시 fetch하고, 성공하면
   `setState`로 조용히 교체, 실패하면 아무것도 하지 않는다(기존 데이터 유지, 에러 메시지도 새로
   띄우지 않음).
4. 데이터 fetch 로직이 여러 단계(예: 대표 묘목 고른 뒤 일지 조회)라면 `_load()`와 `revalidate()`가
   중복되지 않게 `_fetchData()` 같은 private 헬퍼로 뽑아 공유한다.
5. 해당 화면을 담는 `Shell`(`AdopterShell`/`GrowerShell`)에 `GlobalKey<RevalidatableState>` 필드를
   추가하고 화면 생성자에 `key:`로 넘긴다. `_switchTab()`(또는 동등한 탭 전환 메서드)에서 **탭
   인덱스가 실제로 바뀔 때만**(같은 탭 재탭은 무시) 새로 활성화되는 탭의 키로
   `.currentState?.revalidate()`를 호출한다.

## 5. 완료 조건

작업이 끝났다고 보고하기 전에 전부 확인한다:

1. `cd frontend && flutter analyze` — 이슈 0개
2. Playwright 실검증 — `flutter build web` → 정적 서버(`python -m http.server`, 기존 서버가 있으면
   충돌 방지를 위해 재사용하거나 재기동) → 이미 만들어진 launcher.js/act.js 스크립트로 Chromium을
   재사용해 실제 로그인 후 화면을 열어 스크린샷으로 확인한다. 최소한 정상 렌더링(레이아웃 안 깨짐,
   빈/에러/데이터 상태 각각), 새로 추가한 상호작용(탭 전환, 버튼 탭) 동작을 캡처로 남긴다.
3. `CLAUDE.md` 갱신 — 새 화면/변경 사항을 관련 섹션(프론트엔드 구조, 현재 개발 상태)에 반영. 이미
   있던 서술이 이번 변경으로 더 이상 맞지 않게 됐으면(예: "탭 전환 시 초기화됩니다" 같은 문장이
   `RevalidatableState` 적용 후 거짓이 됨) 같이 고친다 — 방치하면 다음 세션이 잘못된 정보로 시작한다.
4. 작업 요약은 한국어로, 무엇을 확인했는지(스크린샷 근거, 로그 근거) 구체적으로 적는다.
