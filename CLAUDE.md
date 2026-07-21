# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Claude Code가 이 저장소에서 작업할 때 매 세션마다 참조하는 파일입니다.

## 프로젝트 개요

**Pig.Fig.** — 도심 유휴공간 기반 무화과 대리재배 모바일 플랫폼.
입양자(adopter)가 무화과 묘목을 입양하면, 재배자(grower)가 도심 유휴공간에서 실제로 키워주고
입양자는 앱을 통해 생육 과정을 지켜보다가 다 자란 무화과를 수령하거나 기부할 수 있는 서비스입니다.

## 기술 스택

- **프론트엔드**: Flutter — 최초 실행 온보딩(2장), 입양자(adopter) 플로우(회원가입/로그인/홈/케어 4종/
  게임 탭/마이페이지/성장 타임라인/수령·기부 선택/기부 인증서/AI 챗봇), 재배자(grower) 플로우(대시보드/일지/
  환경점검 3탭 + 묘목 완성 신고) 구현됨. accounts(회원가입/로그인/로그아웃/`DELETE /api/accounts/me/`
  회원탈퇴), seedlings(`GET /api/seedlings/` 목록
  조회 + `PATCH /api/seedlings/{id}/complete/` 완성 신고), diary(`POST /api/diary/` 작성 +
  `GET /api/diary/{seedling_id}/` 조회, 사진은 `image_picker`로 선택해 multipart 업로드), sensor
  (`POST /api/sensor/data/` 저장 + `GET /api/sensor/anomaly/{seedling_id}/` 이상 이력 조회), chatbot
  (`POST /api/chatbot/ask/`)는 실제 백엔드와 연동됩니다. 홈 화면의 케어 게이지·마이페이지 프로필·
  수령/기부 선택은 여전히 로컬 mock이며, 재배자용 vision API 연동은 아직 미착수
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
python manage.py seed_demo              # 로컬 개발/데모용 계정·묘목·일지·센서 데이터 생성 (멱등, DB가 비어 있을 때)

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
`DELETE /api/accounts/me/`(`AccountDeleteView`, 본인만·JWT 인증 필수)는 회원탈퇴를 하드 삭제가 아니라
`is_active=False`로만 처리합니다 — `Seedling`/`Diary` 등이 유저를 FK로 물고 있어서, 특히 재배자가
탈퇴할 때 담당 묘목까지 CASCADE로 사라지면 그 묘목을 보던 입양자 쪽 일지/성장 타임라인까지 깨지기
때문입니다. `is_active=False`가 되면 `LoginView`가 쓰는 `authenticate()`(Django `ModelBackend`)도,
기존에 발급된 access 토큰을 검증하는 simplejwt의 `JWTAuthentication.get_user()`도 둘 다 기본 동작으로
이미 `is_active`를 확인해 거부하므로, 탈퇴 후 재로그인은 물론 탈퇴 시점에 들고 있던 토큰도 즉시
쓸모없어집니다 — 이 뷰에서 따로 로그인 차단 로직을 추가할 필요가 없었습니다.

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
- `gemini_diagnosis`는 `build_diagnosis_text(anomaly_fields, temperature, humidity, light)`가 만듭니다.
  `settings.GEMINI_API_KEY`가 설정돼 있으면 `_generate_gemini_diagnosis()`가 온도/습도/조도 측정값과
  `FALLBACK_RANGES`(정상 범위)를 프롬프트에 넣어 `ChatGoogleGenerativeAI`(`chatbot` 앱과 동일한
  langchain 연동 방식)로 시니어 재배자용 한국어 진단·조치 문장을 2~3문장 생성합니다. 키가 비어있거나
  Gemini 호출이 실패하면(네트워크 오류, 타임아웃 등 — `except Exception`으로 폭넓게 잡음) 기존
  `_build_static_diagnosis_text()`("이상 감지: {필드명} 수치 이상")로 조용히 폴백합니다. 이 파일의
  `LLM_MODEL`은 `gemini-2.5-flash`입니다(`gemini-1.5-flash`는 이 프로젝트의 API 키/버전에서 완전히
  폐지되어 `ListModels`에 없고 404를 반환하는 것을 실제로 확인했음 — `chatbot/rag_pipeline.py`의
  `LLM_MODEL`도 동일하게 `gemini-2.5-flash`로 맞춰져 있습니다). 테스트(`sensor/tests.py`)는
  `@override_settings(GEMINI_API_KEY='')`로 기존 케이스를
  네트워크 호출 없이 고정하고, `_generate_gemini_diagnosis`를 `patch`해 "키 있을 때 그 결과를 그대로
  쓰는지"와 "호출 실패 시 폴백하는지"를 각각 검증합니다 — `chatbot/tests.py`가 `initialize_rag`/
  `ask_question`을 mock하는 것과 동일한 패턴입니다.
- `SensorDataCreateSerializer`(`POST /api/sensor/data/` 응답용)는 원래 `id`/`seedling`/`temperature`/
  `humidity`/`light`만 내려주고 `perform_create`가 채운 `is_anomaly`/`gemini_diagnosis`/`recorded_at`는
  응답에 없었습니다 — 프론트엔드가 저장 응답에서 이상 감지 결과를 바로 보여주려면 이 값들이 필요해서
  세 필드를 읽기 전용으로 추가했습니다. 모델 필드 자체나 판정 로직은 그대로입니다.

`sensor/mock_sensor.py`는 Django에 의존하지 않는 순수 MQTT publisher로, 실제 하드웨어 없이
로컬에서 파이프라인을 테스트할 때 사용합니다.

### 데모 시드 데이터 (`seedlings/management/commands/seed_demo.py`)
`python manage.py seed_demo`는 DB가 비어 있어 프론트엔드 화면이 전부 빈 상태로 보일 때 앱 전체
흐름을 바로 확인할 수 있도록 계정 3개(`adopter@demo.com`/`adopter2@demo.com`/`grower@demo.com`,
비밀번호 모두 `demo1234`) + 묘목 3개(재배중/완료/다른 입양자 소유 재배중 각 1개, 모두 위 재배자
담당) + 묘목 #1에 일지 3건(6/20·7/2·7/18로 날짜 분산, 성장 타임라인이 시간 역순으로 보이도록) +
센서 데이터 6건(정상 5건 + 습도 급등 1건)을 만듭니다. 센서 데이터는 `SensorDataCreateView.
perform_create()`와 동일하게 `detect_anomaly()`/`build_diagnosis_text()`를 실제로 호출해
저장하므로(직접 `is_anomaly=True`를 박아넣지 않음), 이력 5건이 쌓인 뒤 마지막 습도 85% 값이
Prophet 기반 판정으로 실제 이상 감지되고(`GEMINI_API_KEY` 설정 시 `gemini_diagnosis`도 진짜
Gemini 응답으로 채워짐) "최근 이상 이력"이 재현 가능하게 나타납니다. 멱등하게 동작합니다 — 이메일이
이미 있는 계정, `(adopter, grower, status)` 조합이 이미 있는 묘목, 일지/센서 데이터가 하나라도
있는 묘목은 건너뛰므로 재실행해도 중복 생성되지 않습니다. Django 커맨드 규칙에 따라 앱 하나(
`seedlings`) 아래 두었지만 `accounts`/`diary`/`sensor` 모델을 모두 다룹니다.

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
Gemini(`LLM_MODEL = 'gemini-2.5-flash'`)로 답변을 생성하며, `timeout=LLM_TIMEOUT_SECONDS`(10초)를
둬 응답이 지연되면 타임아웃으로 실패시킵니다. 임베딩은 `EMBEDDING_MODEL = 'models/gemini-embedding-001'`을
쓰는데, 예전에 쓰던 `models/embedding-001`도 이 프로젝트의 API 키/버전에서 폐지되어 404가 나는 것을
확인해 함께 교체했습니다(임베딩 모델을 바꾸면 기존에 그 모델로 만든 벡터가 차원이 달라 호환되지
않으므로, `chatbot/vector_store/`를 지우고 새 모델로 재임베딩해 만들었습니다). 벡터스토어는
`chatbot/views.py`의 모듈 전역 `_vectorstore`에 프로세스당 한 번만 캐싱됩니다. `settings.GEMINI_API_KEY`가
비어있으면 `ChatbotAskView`는 RAG를 아예 호출하지 않고 고정 mock 응답("챗봇 서비스 준비 중입니다.")을
반환합니다 — 로컬 개발 시 API 키 없이도 앱이 동작하게 하기 위함입니다. 키가 있어도 `ask_question()`
호출이 실패하면(네트워크 오류, 타임아웃, 모델 오류 등 — `except Exception`으로 폭넓게 잡음)
`ChatbotAskView`가 500을 그대로 노출하지 않고 `ERROR_ANSWER`("죄송해요, 지금은 답변을 가져오지
못했어요. 잠시 후 다시 시도해주세요.")로 폴백합니다 — `sensor/anomaly.py`의 Gemini 폴백과 동일한
패턴입니다. `chatbot/tests.py`는 `initialize_rag`/`ask_question`을 mock해 mock 응답/정상 RAG 응답/
호출 실패 시 폴백까지 세 경로를 모두 네트워크 호출 없이 검증합니다.
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
- `GrowerDashboardScreen`은 `StatefulWidget`으로 `initState`에서 `GrowerRepository.fetchSeedlings()`
  (`GET /api/seedlings/`, 인증 토큰 필요)를 호출해 로딩/에러/빈 목록/데이터 4가지 상태를 분기합니다.
  이를 위해 `core/network/api_client.dart`에 `get()`이 추가됐습니다 — `patch()`처럼 새 HTTP 메서드라
  별도 메서드로 뒀지만, 목록 엔드포인트는 최상위가 JSON 배열이라 `post()`/`patch()`와 달리
  `Future<dynamic>`을 반환하고 호출부(`fetchSeedlings()`)에서 `as List<dynamic>`으로 캐스팅합니다.
  통계 카드 3개(담당 묘목/재배중/완료)는 응답 리스트에서 직접 계산하며, 디자인 원본의 "완성 임박"/
  "이상 감지"는 실제 `Seedling` 모델에 대응하는 필드가 없어(진행 단계·이상탐지는 diary/sensor
  API 영역이라 이번에도 미연동) "재배중"/"완료" 카운트로 대체했습니다. 카드의 "입양자 #{id}" 표기도
  같은 이유입니다 — `SeedlingSerializer`가 `adopter`를 FK id로만 내려주고 이름을 함께 주는
  엔드포인트가 없어서, 실제 값(id)만 그대로 보여줍니다. 담당 묘목 카드를 탭하면(완료된 묘목은 탭
  비활성화) `GrowerCompleteArgs`(seedlingId/seedlingName/adopterName — 이제 adopterName엔
  "입양자 #6"처럼 완성된 표시 문구 전체가 들어가므로 `grower_complete_screen.dart`는 앞에 "입양자"를
  더 붙이지 않습니다)를 route argument로 담아 `/grower/complete`로 이동하며, 이 화면의 "완성 신고하기"
  버튼이 `completeSeedling()`으로 실제 `PATCH /api/seedlings/{id}/complete/`를 호출합니다. 성공 후
  `Navigator.pop()`으로 대시보드에 돌아오면 `await`로 이어받아 곧바로 `fetchSeedlings()`를 다시
  호출해 목록·통계를 최신 상태로 갱신합니다(완성 처리 직후에도 화면이 낡은 mock처럼 안 바뀌는 문제
  방지). 탭한 seedlingId는 이제 항상 실제 `Seedling.pk`입니다(목록 자체가 실제 응답이므로).
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
  바뀌었습니다(`_tab`으로 홈/게임/마이페이지 세 화면을 스왑하는 `switch` 식). `games_screen.dart`
  (1m)는 2x2 게임 카드 그리드(돼지 풍선 터뜨리기/무화과 퀴즈/해충 잡기/물주기 타이밍, 각 카드에
  `StatusBadge`로 난이도 배지) + 하단 "보유 아이템" 바로 구성되며, 게임 자체와 아이템 시스템은
  아직 미구현이라 카드/보유 아이템 모두 로컬 mock입니다. 카드를 탭하면 `_openGame()`이 `GameType`
  기준 `switch`로 분기하는데, 지금은 모든 case가 "준비 중이에요" 스낵바로 귀결됩니다 — 게임별 실제
  화면은 팀원이 별도 브랜치에서 개발할 예정이라, 이 `switch`가 카드→게임 화면 라우팅을 위한
  스켈레톤 역할을 하고(화면이 생기면 해당 case만 `Navigator.push`로 바꾸면 됨) 실제 게임 위젯
  자리는 비워뒀습니다. 구현 중 실제로 겪은 버그: 2x2 카드를 각 `Row`+`Expanded`로 만들고 카드
  높이를 맞추려고 `CrossAxisAlignment.stretch`를 줬는데, 이 `Row`가 (`SingleChildScrollView` →
  `Column`으로 이어지는) 세로 방향이 unbounded인 컨텍스트에 직접 놓여 있으면 `stretch`가 무한대
  높이로 풀리면서 그 `Row` 이후의 형제 위젯(두 번째 카드 줄, 보유 아이템 카드)이 전부 화면 밖으로
  밀려나 안 보이는 문제가 있었습니다(디버그 assert가 release 웹 빌드에서는 제거되어 에러도 없이
  조용히 사라짐 — Playwright로 실제 렌더링을 확인하지 않았다면 놓쳤을 버그). 각 `Row`를
  `IntrinsicHeight`로 감싸 높이를 먼저 유한하게 확정시킨 뒤 `stretch`를 적용하는 방식으로
  해결했습니다. `mypage_screen.dart`
  는 프로필 카드 + 리스트 메뉴이며, 이번 범위 밖인 메뉴(성장 타임라인/AI 챗봇/알림 설정/입양 내역)는
  탭하면 스낵바만 띄우고, "수령 / 기부 선택"과 "기부 인증서"만 실제로 이동합니다. "기부 인증서"는
  마이페이지에서 곧장 진입할 때는 하드코딩된 mock 인자를 쓰고, `pickup_donate_screen.dart`에서
  기부처를 선택해 진입할 때는 실제 선택한 기부처 이름을 `DonationCertificateArgs`로 넘깁니다(둘 다
  `GrowerCompleteArgs`와 동일한 route-argument 패턴). `pickup_donate_screen.dart`는 수령/기부 두
  옵션과 기부처 3곳을 모두 로컬 `State`로만 관리하며(수령 선택 시 기부처 목록·버튼 자체가 숨겨짐),
  `Seedling.pickup_or_donate`/`donate_type` API 연동은 하지 않는 순수 정적 UI입니다. 디자인의 점선
  테두리(일지 사진 업로드 박스, 기부 인증서 카드)는 Flutter에 내장 dashed border가 없어 실선으로
  근사했습니다. `mypage_screen.dart` 하단(메뉴 리스트 밖, 별도 배치)에는 "로그아웃"(muted 텍스트)과
  "회원탈퇴"(더 작은 회색 텍스트)가 있습니다 — 로직은 `features/auth/presentation/account_actions.dart`
  의 `confirmLogout()`/`confirmDeleteAccount()`를 그대로 호출하는데, 이 두 함수는 `AlertDialog` 확인 →
  `AuthRepository.logout()`(로컬 토큰 삭제만)/`deleteAccount()`(`DELETE /api/accounts/me/` 호출 후
  토큰 삭제) → `pushNamedAndRemoveUntil('/', (route) => false)`로 로그인 화면 이동(뒤로가기로 못
  돌아오게 네비게이션 스택을 전부 비움)까지를 한 번에 처리합니다. `GrowerShell`에는 마이페이지 탭
  자체가 없어서(홈/일지/환경점검 3탭뿐) 재배자용 로그아웃 진입점은 디자인 문서(1r~1u)에도 없는
  자리인데, 해당 문서 어디에도 재배자 화면엔 프로필/설정 메뉴가 없어(앱바는 로고+벨뿐) 새로 위치를
  정해야 했습니다. `GrowerDashboardScreen`(홈 탭)의 앱바에 사람 아이콘을 하나 추가해 탭하면
  `showModalBottomSheet`로 로그아웃/회원탈퇴 두 줄이 뜨는 방식을 택했습니다 — 이를 위해
  `PigFigAppBar`에 `onProfileTap` 옵션을 추가했고(지정할 때만 벨 옆에 사람 아이콘이 나타남, 나머지
  화면은 영향 없음) 기존 `showNotificationBell`/`closeLabel` 패턴과 동일하게 opt-in 방식입니다. 두
  화면(입양자 마이페이지/재배자 대시보드)이 같은 다이얼로그 로직을 그대로 재사용하므로 코드 중복이
  없습니다.
- `features/adopter/data/seedling_repository.dart`는 `grower/data/grower_repository.dart`와 동일한
  패턴(같은 `GET /api/seedlings/`, 같은 `Seedling`/`SeedlingStatus` 모양)을 입양자 쪽에도 그대로
  적용한 별도 파일입니다 — 기능이 겹치더라도 feature 간 참조 없이 각 feature가 자기 데이터 계층을
  갖는 이 프로젝트 컨벤션을 따릅니다. 여기에 `pickPrimarySeedling()` 헬퍼가 있는데, 입양자가 여러
  묘목을 가진 경우 홈/성장 타임라인에 보여줄 "대표 묘목"을 고릅니다(재배중인 것 중 가장 최근 시작한
  것 우선, 전부 완료 상태면 가장 최근 완료된 것) — 처음에는 응답의 첫 번째 항목을 그냥 썼다가, 완료된
  #1이 재배중인 #3보다 먼저 와서 홈 화면이 "이미 다 자란" 묘목을 보여주는 문제를 발견해 이 헬퍼로
  고쳤습니다. `home_screen.dart`는 이제 `StatefulWidget`으로 `initState`에서 이 repository를 호출해
  로딩/에러/(묘목 없음→ 입양 유도 CTA)/데이터 4가지 상태를 분기하며, 물주기 등 케어 게이지 4종은
  여전히 로컬 mock이라 실제 묘목 데이터와 무관하게 동작합니다.
- `growth_timeline_screen.dart`(마이페이지의 "성장 타임라인" 메뉴에서 진입)도 `StatefulWidget`으로
  바뀌어 `seedling_repository.dart`로 대표 묘목을 고른 뒤 `features/adopter/data/diary_repository.dart`
  의 `fetchDiaries()`로 `GET /api/diary/{seedling_id}/`를 호출합니다. 실제 `Diary` 모델에는 성장
  단계·키·잎 개수 필드가 없어(그건 애초에 mock이 지어낸 값) 카드는 날짜 + `content` 본문 +
  (있으면) `yolo_status_tag` 배지로 단순화됐고, `photo` URL이 있으면 `Image.network()`로 실제 사진을,
  없으면 기존 "✨ 일러스트 변환" placeholder를 보여줍니다. 응답 순서가 보장되지 않아 클라이언트에서
  `created_at` 내림차순으로 정렬합니다.
- `grower_diary_screen.dart`는 이제 탭 진입 시 `GrowerRepository.fetchSeedlings()`로 담당 묘목
  목록을 불러와 상단에 선택 칩으로 보여줍니다(재배중인 묘목이 있으면 자동 선택) — 이전에는 이 화면이
  어떤 묘목에 대한 일지인지 알 방법이 전혀 없었기 때문에 실제 연동을 위해 꼭 필요했던 추가입니다.
  "성장 단계" 칩은 `Diary` 모델에 대응 필드가 없어 여전히 로컬 장식으로만 남습니다. "사진 추가하기"는
  `image_picker`(웹 포함 크로스플랫폼) 파일 선택기를 열어 바이트로 읽어 미리보기를 보여주고,
  "입양자에게 전달하기"는 `features/grower/data/diary_repository.dart`의 `createDiary()`로
  `POST /api/diary/`를 호출합니다 — 사진이 있으면 `multipart/form-data`(`ApiClient.postMultipart()`,
  신규 추가), 없으면 텍스트 필드만 보냅니다. 성공 시 폼을 초기화하고 스낵바를 띄웁니다.
- `grower_sensor_screen.dart`도 `grower_diary_screen.dart`와 동일한 묘목 선택 칩 패턴을 씁니다
  (`GrowerRepository.fetchSeedlings()` 재사용). "기록 저장하기"는 `features/grower/data/
  sensor_repository.dart`의 `createSensorData()`로 `POST /api/sensor/data/`를 호출하고, 응답의
  `is_anomaly`/`gemini_diagnosis`를 그대로 "⚠️ 이상 감지"(빨강)/"✅ 정상이에요"(초록) 박스에
  표시합니다 — 온도/습도/조도 세 값 중 어느 필드가 문제인지는 응답에 없어서(위 백엔드 섹션 참고)
  각 수치 행의 "정상/주의" 배지는 없앴고, 전체 판정만 보여줍니다. 저장 성공 시 같은 묘목의
  `GET /api/sensor/anomaly/{seedling_id}/`를 다시 호출해 화면 하단 "최근 이상 이력"(최대 3건,
  `recorded_at` 내림차순)도 함께 갱신합니다. 이 화면도 `GrowerShell`의 탭이라 다른 탭으로 이동했다가
  돌아오면 State가 재생성되어 입력값(스테퍼로 조정한 온도/습도/조도)이 초기값으로 리셋됩니다 — 케어
  게이지 4종과 같은 종류의 로컬 mock 한계입니다.
- `chatbot_screen.dart`(마이페이지의 "AI 챗봇" 메뉴에서 진입)는 `features/adopter/data/
  chatbot_repository.dart`를 통해 실제 `POST /api/chatbot/ask/`를 호출합니다. 이 호출도
  `grower_repository.dart`의 완성 신고처럼 인증 토큰이 필요한데, `PATCH`용으로 이미 있던
  `api_client.dart`의 `patch()`와 달리 이번엔 기존 `post()`에 선택적 `accessToken` 파라미터를
  추가하는 방식으로 확장했습니다(회원가입/로그인처럼 토큰이 필요 없는 기존 `post()` 호출은 그대로
  동작). 채팅 메시지 목록은 화면을 벗어나면 사라지는 `State` 배열이며 대화 히스토리를 서버에
  저장하지 않습니다. `GEMINI_API_KEY` 미설정 시(로컬 기본값) 백엔드가 고정 mock 응답
  ("챗봇 서비스 준비 중입니다.")을 내려주므로, 실제 질문 전송~응답 수신까지 API 키 없이도
  end-to-end로 검증할 수 있습니다.

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
- vision의 YOLOv8 추론은 아직 mock, notifications는 `FIREBASE_CREDENTIALS_PATH` 미설정 시 mock
  발송으로 대체되어 로컬에서도 키 없이 동작. `GEMINI_API_KEY`는 이제 로컬 `.env`에 실제 값이 설정돼
  있고, `sensor/anomaly.py`의 `gemini_diagnosis`는 실제 Gemini API(`gemini-2.5-flash`)로 진단 문장을
  생성하도록 연동 완료(위 "센서 데이터 파이프라인" 참고). `chatbot` 앱도 `gemini-2.5-flash`(LLM)/
  `models/gemini-embedding-001`(임베딩)로 모델명을 갱신하고 `ChatbotAskView`에 예외 처리(Gemini
  호출 실패 시 500 대신 안내 메시지로 폴백)를 추가해 실키로 실제 Gemini RAG 응답이 오는 것까지
  검증 완료(위 "RAG 챗봇 파이프라인" 참고)
- DB(MySQL) 연결 및 `migrate` 완료 (`.env`에 실제 접속 정보 필요)
- 프론트엔드: 최초 실행 온보딩(2장, `SharedPreferences` 플래그로 1회만 노출), 입양자 플로우
  (회원가입/로그인/홈/케어 4종/게임 탭/마이페이지/성장 타임라인/수령·기부 선택/기부 인증서/AI 챗봇),
  재배자 플로우(대시보드/일지/환경점검 3탭 + 묘목 완성 신고) 모두 구현됨. accounts(회원가입·로그인·
  로그아웃·회원탈퇴),
  seedlings(`GET /api/seedlings/` 목록 조회, `PATCH /api/seedlings/{id}/complete/` 완성 신고), diary
  (`POST /api/diary/` 작성, `GET /api/diary/{seedling_id}/` 조회), sensor
  (`POST /api/sensor/data/` 저장, `GET /api/sensor/anomaly/{seedling_id}/` 이력 조회),
  chatbot(`POST /api/chatbot/ask/`)는 모두 JWT 인증으로 실제 백엔드와 연동되어 동작 확인됨(서로 다른
  재배자 계정 2개로 대시보드 목록·통계·완성 신고 자동 새로고침 테스트; 재배자로 일지를 실제로 작성한
  뒤 같은 묘목의 입양자 계정으로 로그인해 성장 타임라인에 그 일지가 실제로 나타나는 end-to-end
  시나리오까지 확인; 입양자 홈 화면은 묘목 있는 계정/없는 계정 각각 확인; sensor는 정상 범위 값 저장
  → "정상이에요" 표시, 범위 밖 값 저장 → 실제 백엔드 판정 문구가 "이상 감지" 박스와 이력에 반영되는
  것까지 확인; chatbot은 `GEMINI_API_KEY` 미설정 상태에서 mock 응답으로 테스트, 이후 실키가 설정됨
  — 재검증은 하지 않음; 로그아웃/회원탈퇴는 입양자로 로그아웃한 뒤 곧바로 재배자로 로그인하는 전환
  흐름과, 데모 계정이 아닌 새 테스트 계정으로 회원탈퇴 후 같은 계정으로 재로그인이 실제로 거부되는
  것까지 확인 — 데모 계정(`adopter@demo.com` 등)은 탈퇴 검증에 쓰지 않아 seed 데이터가 그대로
  보존됨). 재배자 대시보드·입양자 홈·성장 타임라인·재배자 일지/환경 점검 작성이 모두
  실제 데이터를 쓰지만, 케어 게이지 4종·마이페이지 프로필·수령/기부 선택은 여전히 로컬 mock
  상태(라우트 이동/새 탭 진입 시 초기화)이며 서버에 저장되지 않음(vision API,
  `Seedling.pickup_or_donate` 갱신 API 미연동)
- 온보딩 3 "앱으로 케어"(claude.ai/design 문서), 게임 탭의 실제 게임 4종(카드 UI만 구현, 게임 자체와
  아이템 시스템은 팀원이 별도 브랜치에서 개발 예정), vision 연동 등은 아직 미착수