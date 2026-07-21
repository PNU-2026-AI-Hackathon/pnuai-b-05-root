---
name: api-integration
description: Pig.Fig. 프로젝트에서 Flutter 화면을 실제 Django 백엔드 API와 연동할 때 따르는 표준 절차. repository 패턴, ApiClient/TokenStorage 재사용, 로딩/에러/빈 목록 3상태 처리, end-to-end 검증(백엔드 로그까지 확인), 데모 계정 보호 규칙을 다룬다. "이 화면을 실제 API랑 연동해줘", "mock을 실제 데이터로 바꿔줘" 같은 요청에 사용한다.
---

# 프론트-백엔드 API 연동 (Pig.Fig.)

## 1. Repository 패턴

- 위치: `features/<feature>/data/<name>_repository.dart`. feature마다 자기 repository를 두며(예:
  `adopter/data/seedling_repository.dart`와 `grower/data/grower_repository.dart`가 같은
  `GET /api/seedlings/`를 각자 감쌈), feature 간 참조하지 않는다.
- 생성자는 `ApiClient`/`TokenStorage`를 선택적으로 주입받되 기본값을 새로 만든다:
  `Repository({ApiClient? apiClient, TokenStorage? tokenStorage}) : _apiClient = apiClient ?? ApiClient(), ...`
- 인증 토큰이 필요한 호출은 먼저 `TokenStorage().readAccessToken()`을 읽고, 없으면
  `ApiException('로그인이 필요해요.')`를 던지는 작은 헬퍼(`_requireAccessToken()`)로 통일한다
  (`grower_repository.dart` 참고).
- `core/network/api_client.dart`에 이미 `post()`/`get()`/`patch()`/`delete()`/`postMultipart()`가
  있다. 새 HTTP 메서드가 필요하면(드묾) 이 파일의 기존 메서드 하나를 그대로 본떠 추가한다 — 에러
  처리(`ApiException`, DRF `ValidationError` 파싱)와 응답 파싱 방식을 반드시 통일한다. 목록 응답처럼
  최상위가 JSON 배열이면 `Future<dynamic>`을 쓰고(`get()`처럼) 호출부에서 캐스팅한다.
- 모델 클래스(예: `Seedling`)는 `factory X.fromJson(Map<String, dynamic> json)`으로 파싱한다.

## 2. 화면은 3상태 필수

목록/상세를 불러오는 화면은 반드시 아래 상태를 분기한다(정확한 순서와 위젯은 `home_screen.dart`,
`grower_dashboard_screen.dart` 참고):

1. 로딩 — `_loading` bool, 첫 진입 시에만 스피너
2. 에러 — `_errorMessage`, "다시 시도" 버튼으로 재시도
3. 빈 목록/데이터 없음 — 별도의 안내 위젯(에러와 구분되는 정상적인 "그냥 없음" 상태)
4. 데이터 있음 — 실제 콘텐츠

탭 화면이면 이 문서와 별개로 `flutter-screen` 스킬의 `RevalidatableState` 절차도 함께 적용한다(탭
재진입 시 재조회).

## 3. 백엔드를 같이 수정했다면

프론트 연동 대상 API가 이번에 새로 생겼거나 바뀐 것이면, 프론트 작업 전/후로 백엔드가 실제로
동작하는지 별도로 검증한다 — `backend-api` 스킬 참고. 최소한:

```bash
cd backend
python manage.py test <앱명>
```
가 통과해야 프론트 연동 검증을 시작한다. 실패한 채로 프론트만 맞춰 넣지 않는다.

## 4. End-to-end 검증 (실제 계정 → 백엔드 로그 → 화면 반영)

mock 데이터가 아니라 실제로 연동됐다는 걸 증명하려면 세 지점을 모두 확인한다:

1. Django 개발 서버가 떠 있는지 확인(`curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/api/...`
   가 200/401/405 등 정상 응답을 주는지). Windows에서는 이전 세션의 좀비 `runserver` 프로세스가 남아
   새 라우트가 404로 뜨는 경우가 실제로 있었다 — 이상하면
   `powershell -Command "Get-CimInstance Win32_Process -Filter \"CommandLine LIKE '%runserver%'\""`로
   모두 찾아 정리하고 하나만 새로 띄운다.
2. `flutter build web` → 정적 파일 서버 → Playwright로 실제 로그인 → 해당 화면 진입 → 스크린샷.
   (`flutter run -d web-server`는 DWDS가 headless Playwright와 잘 안 맞아 이 프로젝트에서는
   `flutter build web` + `python -m http.server`로 정적 서빙하는 방식을 씀.)
3. 백엔드 서버 로그(runserver stdout)에서 실제 요청이 찍혔는지 대조한다 — 화면에 뭔가 보인다고
   끝난 게 아니라, 기대한 엔드포인트가 기대한 횟수만큼(예: 탭 재진입 시 딱 1번 더) 호출됐는지까지
   확인해야 진짜 연동 검증이다.

## 5. 데모 계정 보호

`backend/seedlings/management/commands/seed_demo.py`로 만든 계정(`adopter@demo.com`,
`adopter2@demo.com`, `grower@demo.com`, 비밀번호 모두 `demo1234`)과 그 묘목/일지/센서 데이터는
시연·개발용 고정 데이터다. 다음 같은 파괴적 검증에는 **절대 쓰지 않는다**:

- 회원탈퇴(소프트 삭제라도 `is_active=False`가 되어 데모 흐름이 깨짐)
- 되돌리기 어려운 상태 전이를 반복 검증하는 것(예: 완성 신고는 멱등하지 않음 — 이미 완료된 묘목으로
  실험하면 이후 시연에서 "완성 신고" 흐름을 다시 보여줄 수 없게 됨)

이런 검증이 필요하면 그 자리에서 임시 계정을 새로 만들어(회원가입) 쓰고, 결과를 확인한 뒤 그대로
둔다(정리 스크립트 불필요 — 기존 e2e 테스트 계정들도 정리하지 않고 누적돼 있음).

## 6. 완료 조건

`flutter-screen` 스킬의 5번 항목과 동일 — `flutter analyze`, Playwright 실검증, `CLAUDE.md` 갱신,
한국어 요약.
