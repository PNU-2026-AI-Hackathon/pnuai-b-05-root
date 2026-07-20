# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Claude Code가 이 저장소에서 작업할 때 매 세션마다 참조하는 파일입니다.

## 프로젝트 개요

**Pig.Fig.** — 도심 유휴공간 기반 무화과 대리재배 모바일 플랫폼.
입양자(adopter)가 무화과 묘목을 입양하면, 재배자(grower)가 도심 유휴공간에서 실제로 키워주고
입양자는 앱을 통해 생육 과정을 지켜보다가 다 자란 무화과를 수령하거나 기부할 수 있는 서비스입니다.

## 기술 스택

- **프론트엔드**: Flutter — 최초 실행 온보딩(2장), 입양자(adopter) 플로우(회원가입/로그인/홈/케어 4종/
  마이페이지/수령·기부 선택/기부 인증서), 재배자(grower) 플로우(대시보드/일지/환경점검 3탭 + 묘목 완성
  신고) 구현됨. accounts(회원가입/로그인)와 seedlings 완성 신고(`PATCH /api/seedlings/{id}/complete/`)는
  실제 백엔드와 연동되며, 케어 게이지·일지·센서 값·마이페이지·수령/기부 선택은 여전히 로컬 mock. 재배자용
  sensor/diary/vision API 연동은 아직 미착수
- **백엔드**: Django 6.0.7 + Django REST Framework 3.17.1 (djangorestframework-simplejwt로 JWT 인증)
- **DB**: MySQL 8.0
- **비전 분석**: YOLOv8 — `vision/yolo_inference.py`에 구조는 있으나 현재 mock 추론(랜덤 값 반환)
- **시계열 예측**: Prophet — 센서 이상 감지에 이미 사용 중 (`sensor/anomaly.py`)
- **챗봇**: LangChain RAG + Gemini API — 구현 완료, `GEMINI_API_KEY` 미설정 시 mock 응답
- **IoT 연동**: MQTT (paho-mqtt) — 센서 데이터 수집 (`sensor/mqtt_client.py`)
- **푸시 알림**: FCM (Firebase Cloud Messaging) — 구현 완료, `FIREBASE_CREDENTIALS_PATH` 미설정 시 mock 발송(print만)

## 자주 쓰는 명령어

모든 명령은 `backend/` 디렉터리에서 실행합니다.

```bash
# 최초 세팅
venv\Scripts\activate           # 가상환경 활성화 (Windows)
pip install -r requirements.txt
cp .env.example .env            # DB 접속정보·API 키 등 실제 값 입력 필요

# DB
python manage.py migrate
python manage.py makemigrations <app명>   # 모델 변경 후 마이그레이션 생성

# 서버 실행
python manage.py runserver

# 검증 (PR 올리기 전 필수, CONTRIBUTING.md 참고)
python manage.py check
python manage.py test
python manage.py test sensor                                          # 앱 단위 테스트
python manage.py test sensor.tests.SensorDataCreateViewTests.test_out_of_range_sensor_data_flagged_as_anomaly   # 단일 테스트

# 센서 파이프라인 로컬 실행 (실제 하드웨어 없이 테스트)
python sensor/mqtt_client.py            # MQTT 구독 → SensorData 저장 (standalone, Django 앱 레지스트리 직접 초기화)
python sensor/mock_sensor.py <seedling_id> [--interval 10]   # 가짜 온습도/조도 값 발행
```

프론트엔드 명령은 `frontend/` 디렉터리에서 실행합니다.

```bash
flutter pub get              # 의존성 설치
flutter analyze              # 정적 분석 (PR 올리기 전 필수)
flutter test                 # 위젯 테스트 전체 실행
flutter run -d chrome        # 크롬에서 실행 (에뮬레이터 없이 가장 빠르게 확인 가능)
flutter run -d windows       # 윈도우 데스크톱 앱으로 실행

# 백엔드가 로컬(8000번 포트)이 아닌 곳에서 실행 중이거나 Android 에뮬레이터에서 테스트할 때
flutter run -d chrome --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

## 백엔드 앱 구성 및 구현 상태

`backend/` 아래 다음 7개 Django 앱으로 구성되며, **7개 모두 구현되어 있습니다**.

- `accounts` — 사용자(입양자/재배자) 인증 및 계정 관리 (구현됨)
- `seedlings` — 묘목 입양/재배 상태 관리 + 완성 신고 (구현됨)
- `diary` — 재배 일지 (사진, 생육 기록) — 구현됨
- `sensor` — IoT 센서 데이터(온습도, 조도) 수집 + Prophet 이상 감지 (구현됨)
- `vision` — YOLOv8 기반 이미지 분석 (현재는 mock 추론) (구현됨)
- `chatbot` — LangChain RAG + Gemini 기반 챗봇 (구현됨)
- `notifications` — FCM 푸시 알림 (현재 기본 환경은 mock 모드) (구현됨)

## 아키텍처

### 커스텀 유저 모델
`AUTH_USER_MODEL = accounts.User` (`accounts/models.py`). `username` 없이 `email`이 로그인 ID이며,
`role` 필드(`adopter`/`grower` TextChoices)로 역할을 구분합니다. 별도 Profile 모델은 없습니다.

### 권한 검사 패턴 (여러 파일에 걸쳐 있어 한눈에 파악하기 어려움)
이 프로젝트는 DRF의 오브젝트 레벨 permission class를 쓰지 않습니다. 대신 각 view의
`perform_create`/`get_queryset` 안에서 `request.user.role`과 FK(`seedling.adopter_id`,
`seedling.grower_id`)를 직접 비교해 `PermissionDenied`를 raise하는 방식입니다.
예시 (`sensor/views.py`):
- `SensorDataCreateView` — `role == GROWER`이고 `seedling.grower_id == request.user.pk`인 경우에만 생성 허용
- `SensorAnomalyListView` — 해당 묘목의 adopter 또는 grower만 조회 허용

`diary`, `vision` 등 새 앱의 view를 구현할 때도 `Seedling.adopter`/`Seedling.grower`를 기준으로
동일한 명시적 체크 패턴을 따라야 합니다 (AGENTS.md의 API 작업 순서: models → serializers → views → urls).

### 센서 데이터 파이프라인 (MQTT/REST → Prophet 이상 감지 → DB)
센서 데이터가 시스템에 들어오는 경로는 두 가지이며, 둘 다 동일한 이상 감지 로직으로 수렴합니다.
1. 재배자 앱이 `/api/sensor/data/`로 POST (`SensorDataCreateView`, 인증·권한 검사 있음)
2. `sensor/mqtt_client.py`가 `pigfig/sensor/{seedling_id}` 토픽을 구독해 메시지 수신 시 바로 저장
   (standalone 스크립트라 `django.setup()`을 직접 호출하며, 사용자 인증/권한 검사를 거치지 않음)

두 경로 모두 `sensor/anomaly.py`의 `detect_anomaly()`를 호출합니다.
- 묘목당 과거 `SensorData`가 5개 미만이면 `FALLBACK_RANGES` 기준 단순 임계값 비교
- 5개 이상이면 Prophet으로 필드별(온도/습도/조도) 다음 값을 예측하고, 실측값과의 오차가
  `PROPHET_THRESHOLDS`를 넘으면 이상치로 판정
- `gemini_diagnosis`는 현재 `build_diagnosis_text()`가 만드는 정적 템플릿 문자열이며, 실제 Gemini API
  연동은 `chatbot` 앱 구현 이후로 미뤄져 있음

`sensor/mock_sensor.py`는 Django에 의존하지 않는 순수 MQTT publisher로, 실제 하드웨어 없이
로컬에서 파이프라인을 테스트할 때 사용합니다.

### 비전 분석 (mock → 실제 YOLOv8로 교체 예정)
`vision/yolo_inference.py`의 `analyze_image(image_path)`는 아직 무화과 학습 데이터가 없어
현재는 랜덤 mock 값(result_tag/confidence/location_info)을 반환합니다. `_get_model()`이
`ultralytics.YOLO`를 lazy하게 로드하도록 구조만 잡아뒀고, 실제 추론 코드는 붙어있지 않습니다
(테스트에서 가중치 다운로드가 트리거되지 않도록 의도적으로 그렇게 되어 있음). `VisionAnalyzeView`는
재배자만 호출 가능하며, `diary_id`를 함께 보내면 해당 `Diary.yolo_status_tag`도 갱신합니다
(diary 소유권 검사 포함).

### RAG 챗봇 파이프라인
`chatbot/rag_pipeline.py`는 농촌진흥청 매뉴얼 기반 지식 문서 10개를 코드에 직접 하드코딩해두고
(PDF 등 외부 파일 의존 없음), `initialize_rag()`가 이를 ChromaDB로 임베딩해
`chatbot/vector_store/`에 저장(이미 저장되어 있으면 재임베딩 없이 로드)합니다. `ask_question()`은
Gemini(`gemini-1.5-flash`)로 답변을 생성합니다. 벡터스토어는 `chatbot/views.py`의 모듈 전역
`_vectorstore`에 프로세스당 한 번만 캐싱됩니다. `settings.GEMINI_API_KEY`가 비어있으면
`ChatbotAskView`는 RAG를 아예 호출하지 않고 고정 mock 응답("챗봇 서비스 준비 중입니다.")을
반환합니다 — 로컬 개발 시 API 키 없이도 앱이 동작하게 하기 위함입니다.
`langchain` 1.x부터 API가 크게 바뀌어 `RetrievalQA`는 `langchain_classic.chains`에,
`RecursiveCharacterTextSplitter`는 `langchain_text_splitters`에 있습니다(`langchain.chains`/
`langchain.text_splitter` 아님).

### FCM 푸시 알림 (mock 모드 기본)
`notifications/fcm.py`의 `send_push_notification(token, title, body)`는 `settings.FIREBASE_CREDENTIALS_PATH`가
비어있으면(로컬 개발 기본값) 실제 전송 없이 print만 하는 mock 모드로 동작합니다. 값이 있으면
`firebase_admin`을 lazy 초기화해 실제 FCM 메시지를 보냅니다. `send_notification_to_user(user, title, body)`는
해당 유저의 `FCMToken`을 전부 조회해 순회 발송하며, `seedlings/views.py`의 `SeedlingCompleteView`
(`PATCH /api/seedlings/{id}/complete/`, 담당 재배자만 가능)가 묘목 완성 처리 후 이 함수를 호출해
입양자에게 알림을 보냅니다 — 앱 간 참조가 `seedlings` → `notifications.fcm`로 향하는 유일한 지점입니다.
`FCMToken.token`은 unique 필드이므로 등록 시 `(user, token)`이 아니라 `token` 하나로 중복을 판단합니다.

### URL 라우팅
루트 `config/urls.py`가 앱마다 `/api/<앱명>/` prefix로 각 앱의 `urls.py`를 include합니다
(예: `/api/sensor/` → `sensor/urls.py`). 새 앱도 이 컨벤션을 따릅니다.

### 프론트엔드 구조 (`frontend/lib/`)
feature-first 구조이며 상태관리 라이브러리(Provider/Riverpod/Bloc) 없이 `StatefulWidget` +
`setState`만 사용합니다.
- `core/network/api_client.dart` — 백엔드 공통 HTTP 클라이언트. `baseUrl`은 기본값
  `http://localhost:8000`이며, `--dart-define=API_BASE_URL=...`로 오버라이드합니다(Android 에뮬레이터는
  `10.0.2.2` 필요). DRF `ValidationError` 응답(필드명→메시지 배열 또는 `non_field_errors`)을 파싱해
  `ApiException`으로 던지는 로직이 여기 있습니다 — 새 API 연동 시 이 클라이언트를 재사용합니다.
- `core/storage/token_storage.dart` — `shared_preferences`로 JWT access/refresh 토큰을 저장.
  같은 패턴으로 `core/storage/onboarding_storage.dart`가 온보딩 노출 여부(`bool`)를 저장한다 — 로컬
  플래그 하나짜리 상태도 위젯에 `SharedPreferences`를 직접 넣지 않고 `core/storage/`에 작은 래퍼
  클래스로 분리하는 것이 컨벤션이다.
- `core/theme/` — `AppColors`(색상 토큰)와 `AppTheme`/`AppTextStyles`(Gaegu 폰트=display,
  Noto Sans KR=본문, `google_fonts` 패키지) 디자인 시스템. 새 화면은 직접 `TextStyle`을 만들지 않고
  이 토큰을 사용합니다.
- `features/<feature>/data/` — repository 계층(예: `auth/data/auth_repository.dart`가
  `/api/accounts/register|login/`을 감쌉니다). `features/<feature>/presentation/` — 화면 위젯.
- `shared/widgets/` — 여러 화면에서 재사용하는 공용 위젯(게이지 바, 공용 앱바, 버튼 등).
- 라우팅은 `main.dart`의 `MaterialApp.routes`에 이름 있는 라우트로 전부 등록합니다(중첩 라우터 없음).
  로그인 성공 시 역할이 `adopter`면 `pushReplacementNamed('/adopter')`, `grower`면 아직 미구현이라
  스낵바만 띄웁니다(`login_screen.dart`).
- 케어 화면(`features/adopter/presentation/care/*.dart`) 4종은 각각 다른 제스처로 게이지 값을 올립니다:
  물주기=`onLongPressStart`/`onLongPressEnd`로 타이머 반복 증가, 영양제=`Draggable`/`DragTarget`,
  햇빛=`Slider`, 가지치기=`onLongPressStart` 트리거 `AnimationController.forward()`가 완료되면 1회성으로
  완료 처리. 네 화면 모두 화면을 벗어나면(라우트 pop) 상태가 초기화되는 로컬 mock 상태이며 백엔드에
  저장되지 않습니다.
- `features/grower/presentation/grower_shell.dart`는 `adopter_shell.dart`와 달리 진짜로 탭을 전환하는
  `StatefulWidget`입니다(`_index`로 `GrowerDashboardScreen`/`GrowerDiaryScreen`/`GrowerSensorScreen`을
  스왑). 각 탭 화면은 `adopter`의 `HomeScreen`처럼 자기 자신도 `Scaffold`+`PigFigAppBar`를 갖고 있어
  `GrowerShell`의 `Scaffold.body`로 들어가는 중첩 Scaffold 구조입니다 — 새 탭을 추가할 때도 이 패턴을
  따릅니다. 대시보드/일지/환경점검 모두 mock 데이터이며 sensor/diary API를 호출하지 않습니다.
  `login_screen.dart`는 로그인 응답의 `role`이 `grower`면 `pushReplacementNamed('/grower')`로 이동합니다
  (이전엔 "재배자 화면은 준비 중이에요" 스낵바만 띄웠으나 grower 플로우 구현 후 실제 이동으로 변경).
- `GrowerDashboardScreen`의 담당 묘목 카드를 탭하면 `GrowerCompleteArgs`(seedlingId/seedlingName/
  adopterName)를 route argument로 담아 `/grower/complete`(`grower_complete_screen.dart`)로 이동합니다
  (`RegisterScreen`이 role을 `ModalRoute.of(context)!.settings.arguments`로 읽는 것과 동일한 패턴).
  이 화면의 "완성 신고하기" 버튼은 `features/grower/data/grower_repository.dart`의
  `completeSeedling()`을 통해 실제 `PATCH /api/seedlings/{id}/complete/`를 호출하는, 프론트엔드에서
  최초로 인증 토큰이 필요한 API 연동입니다. 이를 위해 `core/network/api_client.dart`에 `patch()`가
  추가됐고(`post()`와 동일한 에러 파싱 로직 + `Authorization: Bearer <token>` 헤더), 토큰은
  `TokenStorage.readAccessToken()`으로 읽습니다. 성공 시 스낵바 후 `Navigator.pop()`으로 대시보드에
  돌아갑니다(패턴은 `RegisterScreen._submit`과 동일). 대시보드의 담당 묘목 목록 자체는 여전히 mock이라
  탭한 seedlingId가 실제 DB의 `Seedling.pk`와 우연히 일치할 때만 성공하며, 목록을 실제 API로 채우는
  작업은 아직 남아 있습니다.
- `main()`이 `Future<void>`로 바뀌어 `runApp()` 전에 `OnboardingStorage().hasSeenOnboarding()`을
  `await`하고, 그 결과로 `PigFigApp(initialRoute: ...)`을 결정합니다(`/onboarding` 또는 `/`) — 위젯
  트리 안에서 라우팅을 늦게 리다이렉트하는 대신 첫 프레임부터 올바른 화면으로 시작합니다. `PigFigApp`의
  `initialRoute`는 기본값이 `/`라서 `widget_test.dart`처럼 `PigFigApp()`을 인자 없이 pump하는 기존
  테스트는 영향받지 않습니다. `features/onboarding/presentation/onboarding_screen.dart`는 `PageView` 2장
  (서비스 소개/시니어 재배자)이며, 마지막 페이지에서만 "시작하기" 버튼이 보이고 "건너뛰기" 링크는
  `Visibility(maintainSize: true)`로 자리만 차지한 채 숨겨집니다(디자인 문서의 세 번째 온보딩 프레임이
  "건너뛰기" 자리에 투명 placeholder를 두는 것과 동일한 방식). claude.ai/design 문서에는 온보딩 3
  "앱으로 케어"도 있지만 이번 범위에서 의도적으로 제외했습니다.
- `adopter_shell.dart`도 `grower_shell.dart`처럼 실제 탭 전환이 필요해지면서 `StatefulWidget`으로
  바뀌었습니다(`_tab`으로 홈/마이페이지를 스왑, "게임"은 여전히 범위 밖이라 스낵바만). `mypage_screen.dart`
  는 프로필 카드 + 리스트 메뉴이며, 이번 범위 밖인 메뉴(성장 타임라인/AI 챗봇/알림 설정/입양 내역)는
  탭하면 스낵바만 띄우고, "수령 / 기부 선택"과 "기부 인증서"만 실제로 이동합니다. "기부 인증서"는
  마이페이지에서 곧장 진입할 때는 하드코딩된 mock 인자를 쓰고, `pickup_donate_screen.dart`에서
  기부처를 선택해 진입할 때는 실제 선택한 기부처 이름을 `DonationCertificateArgs`로 넘깁니다(둘 다
  `GrowerCompleteArgs`와 동일한 route-argument 패턴). `pickup_donate_screen.dart`는 수령/기부 두
  옵션과 기부처 3곳을 모두 로컬 `State`로만 관리하며(수령 선택 시 기부처 목록·버튼 자체가 숨겨짐),
  `Seedling.pickup_or_donate`/`donate_type` API 연동은 하지 않는 순수 정적 UI입니다. 디자인의 점선
  테두리(일지 사진 업로드 박스, 기부 인증서 카드)는 Flutter에 내장 dashed border가 없어 실선으로
  근사했습니다.

## 개발 규칙 (AGENTS.md 요약 — 전체 규칙은 [AGENTS.md](AGENTS.md) 참고)

- 코드 주석은 **한국어**로 작성합니다.
- REST API는 `/api/앱명/` prefix를 따릅니다.
- 환경변수(SECRET_KEY, DB 정보, API 키 등)는 반드시 `.env`에서 로드하며, 코드에 하드코딩하지 않습니다.
  `.env`는 직접 수정하지 않고, 필요한 키는 `.env.example`에 추가한 뒤 실제 값 입력은 사용자에게 요청합니다.
- 새 API는 반드시 `models.py` → `serializers.py` → `views.py` → `urls.py` 순서로 작업합니다.
- 마이그레이션 파일은 `makemigrations`로만 생성하고 직접 편집하지 않습니다.
- `views.py`는 테스트(최소 happy path) 없이 완성 상태로 두지 않습니다.
- API 응답은 항상 DRF `Response`를 사용합니다 (`django.http.JsonResponse` 금지).
- Git 워크플로(브랜치 네이밍, 커밋 메시지, PR 규칙)는 [CONTRIBUTING.md](CONTRIBUTING.md) 참고.
  요약: `main` 직접 push 금지, `feat/`·`fix/`·`refactor/`·`docs/`·`chore/` 브랜치 prefix,
  push 전 `manage.py check`와 `manage.py test` 통과 필수.
- 작업 완료 후 요약은 **한국어**로 작성합니다.

## 현재 개발 상태

- 백엔드: 7개 앱(accounts/seedlings/diary/sensor/vision/chatbot/notifications) 모두 구현 완료
- vision의 YOLOv8 추론은 아직 mock, chatbot은 `GEMINI_API_KEY`, notifications는 `FIREBASE_CREDENTIALS_PATH`
  미설정 시 각각 mock 응답/mock 발송으로 대체되어 로컬에서도 키 없이 동작
- DB(MySQL) 연결 및 `migrate` 완료 (`.env`에 실제 접속 정보 필요)
- 프론트엔드: 최초 실행 온보딩(2장, `SharedPreferences` 플래그로 1회만 노출), 입양자 플로우
  (회원가입/로그인/홈/케어 4종/마이페이지/수령·기부 선택/기부 인증서), 재배자 플로우(대시보드/일지/
  환경점검 3탭 + 묘목 완성 신고) 모두 구현됨. accounts(회원가입·로그인)와 seedlings 완성 신고
  (`PATCH /api/seedlings/{id}/complete/`, JWT 인증)는 실제 백엔드와 연동되어 동작 확인됨(수동으로
  `grower` 배정된 `Seedling` row를 만들어 대시보드 mock id와 실제 pk를 맞춘 뒤 end-to-end 테스트).
  케어 게이지·재배자 일지·센서 값·대시보드 담당 묘목 목록·마이페이지 프로필/수령·기부 선택은 여전히
  로컬 mock 상태(라우트 이동/새 탭 진입 시 초기화)이며 서버에 저장되지 않음(diary/sensor/vision API,
  묘목 목록 조회 API, `Seedling.pickup_or_donate` 갱신 API 미연동)
- 온보딩 3 "앱으로 케어"(claude.ai/design 문서), 성장 타임라인, AI 챗봇, 게임 탭, 비전 연동 등은 아직
  미착수