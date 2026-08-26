# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Claude Code가 이 저장소에서 작업할 때 매 세션마다 참조하는 파일입니다.

## 프로젝트 개요

**Pig.Fig.** — 도심 유휴공간 기반 무화과 대리재배 모바일 플랫폼.
입양자(adopter)가 무화과 묘목을 입양하면, 재배자(grower)가 도심 유휴공간에서 실제로 키워주고
입양자는 앱을 통해 생육 과정을 지켜보다가 다 자란 무화과를 수령하거나 기부할 수 있는 서비스입니다.

## 함께 참조할 문서

AGENTS.md는 새 API 작업 전 아래 두 문서를 먼저 참조하도록 규정합니다 — 모델 필드명/타입이나
엔드포인트 목록이 이 CLAUDE.md에 없다면 여기서 확인합니다.

- [DB_SCHEMA.md](DB_SCHEMA.md) — 앱별 모델(User/Seedling/Diary/SensorData/VisionAnalysis/FCMToken)
  필드 설계. 실제 소스는 각 앱의 `models.py`이며, 모델 변경 시 이 문서도 함께 갱신합니다.
- [DESIGN.md](DESIGN.md) — 입양자/재배자 서비스 플로우와 엔드포인트 목록(Method+설명 표).
- [CONTRIBUTING.md](CONTRIBUTING.md) — 브랜치·커밋·PR 규칙 전문(아래 "개발 규칙"은 요약본).
- [AGENTS.md](AGENTS.md) — 이 저장소 전용 행동 규칙 원문(아래 "개발 규칙"은 요약본).

## 기술 스택

- **프론트엔드**: Flutter — 스플래시(1.2초, `/splash`) → 로그인 화면 진입, 입양자(adopter) 플로우
  (회원가입(닉네임 입력 포함)/로그인/홈·게임·타임라인·마이페이지 4탭 — 이 순서/무화과 입양(결제)/
  케어 3종/수령·기부 선택/기부 인증서/AI 챗봇), 재배자(grower) 플로우(홈·일지·환경점검·마이 4탭 +
  묘목 완성 신고) 구현됨. 입양자는 로그인에 성공할 때마다(최초 1회가 아니라 매번) 온보딩(3장)을 거쳐
  홈으로 진입합니다. accounts(회원가입/로그인/로그아웃/`GET`·`PATCH`·`DELETE /api/accounts/me/`로
  프로필 조회·닉네임 수정·회원탈퇴, Android는 로그인 성공 시 FCM 토큰도 함께 등록), seedlings
  (`GET /api/seedlings/` 목록 조회 + `POST /api/seedlings/` 입양(결제 후 생성, 재배자 자동 배정) +
  `PATCH /api/seedlings/{id}/complete/` 완성 신고), diary(`POST /api/diary/` 작성 +
  `GET /api/diary/{seedling_id}/` 조회 + `DELETE /api/diary/entry/{id}/` 재배자 본인 일지 삭제 —
  완료된 묘목의 일지는 삭제 불가, 사진은 `image_picker`로 선택해 multipart 업로드), sensor
  (`POST /api/sensor/data/` 저장 + `GET /api/sensor/anomaly/{seedling_id}/` 이상 이력 조회), vision
  (`POST /api/vision/analyze/`, 재배자가 일지 사진 업로드 시 백그라운드로 자동 호출), chatbot
  (`POST /api/chatbot/ask/`)는 실제 백엔드와 연동됩니다. 게임 탭 4종(돼지 풍선 터뜨리기/무화과 퀴즈/
  해충 잡기/물주기 타이밍)은 모두 실제로 플레이 가능하며, 획득 아이템은 `InventoryStorage`
  (`SharedPreferences`, 로그인한 사용자 id별로 키를 분리해 계정 간 아이템이 섞이지 않음)에 로컬
  저장됩니다. `PATCH /api/seedlings/{id}/pickup-donate/`(완성 묘목
  수령/기부 선택, 아래 "완성 묘목 수령/기부 선택" 참고)도 `pickup_donate_screen.dart`가 실제로
  연동합니다. 입양자/재배자 마이페이지 모두 2x2 `ServiceCard` 그리드로 개편됐고, 프로필의
  닉네임·이메일·담당/입양 묘목 수는 실제 서버 데이터(닉네임 수정은 `PATCH /api/accounts/me/`로 실제
  저장)입니다 — 홈 화면의 케어 게이지 3종만 여전히 로컬(서버 미연동)입니다
- **백엔드**: Django 6.0.7 + Django REST Framework 3.17.1 (djangorestframework-simplejwt로 JWT 인증)
- **DB**: MySQL 8.0
- **비전 분석**: YOLOv8-cls — `vision/yolo_inference.py`에서 `backend/vision/weights/best.pt`
  (healthy/infected 이진 분류, val top1 96.1%, 2.9MB로 저장소에 커밋됨)로 실제 추론. 가중치가 없으면
  mock으로 폴백. 프론트엔드도 연동 완료 — 재배자가 일지에 사진을 올리면 저장 직후 같은 사진으로
  자동 분석 요청까지 이어집니다(위 "프론트엔드" 항목 참고)
- **시계열 예측**: Prophet — 센서 이상 감지에 이미 사용 중 (`sensor/anomaly.py`)
- **챗봇**: LangChain RAG + Gemini API — 구현 완료, `GEMINI_API_KEY` 미설정 시 mock 응답
- **IoT 연동**: MQTT (paho-mqtt) — 센서 데이터 수집 (`sensor/mqtt_client.py`)
- **푸시 알림**: FCM (Firebase Cloud Messaging) — 구현 완료, `FIREBASE_CREDENTIALS_PATH` 미설정 시 mock 발송(print만).
  Android 클라이언트는 `google-services.json`/`firebase_messaging`으로 연동돼 로그인 성공 시 기기
  토큰을 실제로 백엔드에 등록합니다(web/windows 등 다른 플랫폼은 미지원, 아래 "FCM 푸시 알림" 참고)

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
- `vision` — YOLOv8-cls 기반 이미지 분석, 실제 추론(가중치 없으면 mock 폴백) (구현됨)
- `chatbot` — LangChain RAG + Gemini 기반 챗봇 (구현됨)
- `notifications` — FCM 푸시 알림 (현재 기본 환경은 mock 모드) (구현됨)

## 아키텍처

### 커스텀 유저 모델
`AUTH_USER_MODEL = accounts.User` (`accounts/models.py`). `username` 없이 `email`이 로그인 ID이며,
`role` 필드(`adopter`/`grower` TextChoices)로 역할을 구분합니다. `nickname`(`CharField`, `blank=True`,
`default=''`) 필드도 있어 마이페이지 프로필 표시·수정에 씁니다. 별도 Profile 모델은 없습니다.
`/api/accounts/me/`(`AccountView`, 본인만·JWT 인증 필수)는 GET(프로필 조회)/PATCH(닉네임 수정,
`ProfileSerializer` partial)/DELETE(회원탈퇴)를 한 뷰에서 지원합니다. DELETE는 하드 삭제가 아니라
`is_active=False`로만 처리합니다 — `Seedling`/`Diary` 등이 유저를 FK로 물고 있어서, 특히 재배자가
탈퇴할 때 담당 묘목까지 CASCADE로 사라지면 그 묘목을 보던 입양자 쪽 일지/성장 타임라인까지 깨지기
때문입니다. `is_active=False`가 되면 `LoginView`가 쓰는 `authenticate()`(Django `ModelBackend`)도,
기존에 발급된 access 토큰을 검증하는 simplejwt의 `JWTAuthentication.get_user()`도 둘 다 기본 동작으로
이미 `is_active`를 확인해 거부하므로, 탈퇴 후 재로그인은 물론 탈퇴 시점에 들고 있던 토큰도 즉시
쓸모없어집니다 — 이 뷰에서 따로 로그인 차단 로직을 추가할 필요가 없었습니다. `LoginView` 응답에는
`access`/`refresh`/`role`과 함께 `id`/`email`/`nickname`도 내려줘, 프론트가 프로필 조회 API를 따로
부르지 않고도 `TokenStorage`에 캐싱해 쓸 수 있게 합니다.

### 권한 검사 패턴 (여러 파일에 걸쳐 있어 한눈에 파악하기 어려움)
이 프로젝트는 DRF의 오브젝트 레벨 permission class를 쓰지 않습니다. 대신 각 view의
`perform_create`/`get_queryset` 안에서 `request.user.role`과 FK(`seedling.adopter_id`,
`seedling.grower_id`)를 직접 비교해 `PermissionDenied`를 raise하는 방식입니다.
예시 (`sensor/views.py`):
- `SensorDataCreateView` — `role == GROWER`이고 `seedling.grower_id == request.user.pk`인 경우에만 생성 허용
- `SensorAnomalyListView` — 해당 묘목의 adopter 또는 grower만 조회 허용

`diary`, `vision` 등 새 앱의 view를 구현할 때도 `Seedling.adopter`/`Seedling.grower`를 기준으로
동일한 명시적 체크 패턴을 따라야 합니다 (AGENTS.md의 API 작업 순서: models → serializers → views → urls).

`diary/views.py`의 `DiaryDestroyView`(`DELETE /api/diary/entry/{id}/`)도 같은 방식입니다 —
`DestroyAPIView` 제네릭을 쓰되 `perform_destroy(instance)` 안에서 `DiaryCreateView.perform_create()`와
대칭으로 `user.role != GROWER` 또는 `instance.grower_id != user.pk`면 `PermissionDenied`, 추가로
`instance.seedling.status == COMPLETED`면 `ValidationError`(400)로 막습니다 — 완료된 묘목의 일지는
입양자의 성장 타임라인에 확정 아카이브로 노출됐을 수 있어(회원탈퇴가 하드 삭제 대신 소프트 삭제를
쓰는 것과 같은 취지) 삭제를 허용하지 않습니다(`SeedlingPickupDonateView`의 status 가드와 동일한
형태, 조건만 반대). URL을 `entry/<int:pk>/` 아래에 둔 이유: `/api/diary/<int:seedling_id>/`(목록
조회)와 `path()` 패턴이 겹치는데 Django는 이를 HTTP 메서드로 구분하지 못하고, 여기 정수는 seedling
id가 아니라 일지 id라 같은 URL에 얹으면 의미가 헷갈리기 때문입니다.

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

### 일지 사진 → 일러스트 변환 (Gemini 이미지 생성)
재배자가 일지 작성 시 사진(`Diary.photo`)을 함께 올리면, `diary/gemini_illustration.py`의
`convert_to_illustration(photo_path)`가 Gemini 이미지 생성 모델로 "아동 그림책(picture book)
스타일의 귀여운 일러스트"로 변환을 시도하고, 성공하면 `DiaryCreateView.perform_create()`가 그 결과를
`Diary.illustration`에 저장합니다(원본 `photo`는 그대로 유지). 텍스트 모델
`gemini-2.5-flash`로는 이미지를 생성할 수 없고, `langchain_google_genai`도 이미지 생성 전용
클래스가 없어서(`ChatGoogleGenerativeAI`/`GoogleGenerativeAIEmbeddings`뿐) 이 파이프라인만
`langchain`을 거치지 않고 `google-genai` SDK(`google.genai.Client`)를 직접 씁니다 —
`requirements.txt`에도 `google-genai`를 명시적으로 추가했습니다(`langchain-google-genai`의
전이 의존성으로 이미 설치돼 있었지만, 직접 import하는 코드가 있으면 명시적으로 선언해야
안전합니다). 실제 사용 모델은 `LLM_MODEL = 'gemini-2.5-flash-image'`로, 호출 전
`client.models.list()`로 이 프로젝트 API 키에서 실제로 사용 가능한지 확인했습니다(사용 가능
목록에 있었음 — 참고로 `imagen-4.0-*` 계열도 있었지만 `generateContent`가 아니라 `predict`
API를 쓰는 별도 인터페이스라 이번엔 지시받은 대로 `gemini-2.5-flash-image`를 그대로 사용).
`_generate_illustration()`은 사진 bytes를 `types.Part.from_bytes()`로 프롬프트와 함께 보내고
응답의 `candidates[0].content.parts`를 순회해 `inline_data`가 있는 첫 part의 bytes를 반환합니다.
`convert_to_illustration()`은 `settings.GEMINI_API_KEY`가 비어있으면 호출 자체를 생략하고,
호출이 실패하면(쿼터 초과, 네트워크 오류 등) `except Exception`으로 넓게 잡아 `None`을
반환합니다 — `sensor/anomaly.py`/`vision/yolo_inference.py`와 동일한 게이트 체크 → try/except
→ 폴백 구조이며, 두 경우 모두 원본 사진만 저장된 채로 일지 작성 자체는 정상 처리됩니다.
`diary/tests.py`는 `diary.views.convert_to_illustration`(뷰 테스트: 권한/저장 로직만 검증)와
`diary.gemini_illustration._generate_illustration`(모듈 테스트: 키 없음/성공/실패 세 경로)을
각각 mock해 검증하며, 이미지 생성은 호출당 과금·쿼터가 있어 실제 네트워크를 타는 테스트는
의도적으로 만들지 않았습니다(sensor/vision과 동일한 원칙).

`ILLUSTRATION_PROMPT`는 처음엔 "따뜻하고 감성적인 동화풍 일러스트로 변환"이라고만 지시했는데,
실제로 생성된 결과물(초기 예시가 `media/diary/illustrations/diary_9_illustration.png`로 남아
있음)이 색감만 살짝 보정된 사진에 가깝고 동화풍 일러스트로 보이지 않는 문제가 있었습니다. 그래서
프롬프트에 (1) `photorealistic`/`realistic photo`처럼 보이면 안 된다는 명시적 금지 문구, (2) 아동
그림책(picture book illustration) 스타일·flat color·부드러운 선·파스텔톤·단순화된 형태 등 원하는
스타일을 구체적인 키워드로 나열하는 문장, (3) 잎 개수·크기·줄기 굵기·성장 정도 등 식물의 실제 상태는
그대로 유지하라는 기존 지시를 그대로 유지하는 세 부분으로 프롬프트를 강화했습니다. **실제로 겪은
문제**: 이 프로젝트 API 키는 초기에는 무료 티어라 이미지 생성 모델 쿼터가 0으로 설정돼 있었고
(`429 RESOURCE_EXHAUSTED ... limit: 0, model: gemini-2.5-flash-preview-image`), 이후 결제가
연결된 뒤에도 이번엔 프로젝트 단위 월간 지출 한도(monthly spending cap)를 이미 소진한 상태라
(`429 RESOURCE_EXHAUSTED ... Your project has exceeded its monthly spending cap`) 강화된
프롬프트로 실제 재검증(재배자 계정으로 사진 포함 일지 작성)을 시도해도 여전히 `illustration`이
채워지지 않고 원본 사진만 저장되는 것까지 확인했습니다 — 이 두 오류는 서로 다른 상태입니다(전자는
결제 자체가 안 걸려 있던 상태, 후자는 결제는 걸려 있으나 한도를 다 쓴 상태). 텍스트 모델
(`gemini-2.5-flash`)로 직접 호출해봐도 동일한 지출 한도 오류가 나는 것으로 보아 이 차단은
이미지 생성 모델에 국한되지 않고 **프로젝트 전체(이 API 키를 쓰는 모든 Gemini 호출)에 걸려
있었습니다**. **2026-08-26 업데이트**: 이 한도가 풀렸거나(월간 cap이라 달이 바뀌었을 수 있음)
API 키가 교체돼, 이제 `chatbot`의 RAG는 `gemini-2.5-flash`로 실제 Gemini 응답을 정상적으로
받아옵니다(로컬에서 매뉴얼 질문 1개 + 매뉴얼 밖 질문 4개 curl 왕복으로 확인). 즉 텍스트 모델
차단은 해제된 상태입니다 — 다만 이번 세션에서 재검증한 건 `chatbot`뿐이고, `sensor/anomaly.py`의
`gemini_diagnosis`와 아래 이미지 생성(`gemini-2.5-flash-image`)은 별도로 다시 확인하지 않았습니다
(이미지 모델은 텍스트 모델과 과금·쿼터가 달라 여전히 막혀 있을 수 있음). 강화된 일러스트
프롬프트가 실제로 더 동화풍에 가까워졌는지는 이미지 생성 성공 사례를 얻은 뒤 재검증이 필요합니다. `growth_timeline_screen.dart`는 `illustrationUrl`이
있으면 그것을, 없으면(지금처럼 mock 모드이거나 변환 실패) `photoUrl`을, 둘 다 없으면 기존
placeholder 아이콘을 보여주도록 `imageUrl = entry.illustrationUrl ?? entry.photoUrl` 한 줄로
우선순위를 정했습니다.

### 비전 분석 (YOLOv8-cls 실제 추론)
`vision/yolo_inference.py`의 `analyze_image(image_path)`는 `backend/vision/weights/best.pt`가
있으면 실제 YOLOv8-cls(분류) 모델로 추론합니다. 이 가중치는 Mendeley "fig leaves dataset"
(CC BY 4.0, 무화과잎마름나방 감염 여부 기준 healthy/infected로 라벨링된 2,321장)으로 학습한
이진 분류 모델이며, val top1 정확도는 96.1%입니다. object detection이 아니라 classification이라
이미지 전체에 대한 라벨·확률만 나오고 잎의 위치 좌표는 나오지 않습니다 — 그래서
`_run_inference()`는 `location_info`를 항상 `None`으로 반환합니다(주석에도 "detection 모델
도입 시 실제 위치 정보로 교체 예정"이라고 명시). 모델의 클래스명(`healthy`/`infected`)은
`REAL_CLASS_TO_TAG`로 한국어 태그("정상"/"이상감지")에 매핑됩니다. `_get_model()`은
`ultralytics.YOLO`를 프로세스당 한 번만 lazy 로드해 전역(`_model`)에 캐싱합니다(최초 로드에
~8초가 걸려 매 요청마다 다시 로드하면 안 됨).

`best.pt`는 저장소에 커밋되어 있어(2.9MB, `.gitignore`의 `backend/vision/weights/` 제외 라인은
배포 시 이 가중치를 Render 등에도 그대로 가져가기 위해 제거함) 클론만 하면 바로 실제 추론이
됩니다. 그럼에도 이 파일이 없는 환경(얕은 클론, Git LFS 미설정 등)이거나 추론 중 예외가 나면
`analyze_image()`가 조용히 기존 mock
동작(`_mock_inference()`, `RESULT_TAGS`의 4개 태그 중 랜덤 선택 + 가짜 "선반X-Y번" 위치)으로
폴백합니다 — `sensor/anomaly.py`의 Gemini 폴백과 동일한 구조(게이트 체크 → try/except → 정적
폴백, 실제 호출부를 별도 함수로 분리해 테스트에서 mock 가능)입니다. `vision/tests.py`는 이 두
경로를 각각 검증합니다: `VisionAnalyzeViewTests`는 `vision.views.analyze_image`를 고정값으로
mock해 권한(재배자만 가능)·diary 연동 로직만 실제 추론 여부와 무관하게 검증하고,
`AnalyzeImageTests`는 `yolo_inference.py` 자체를 대상으로 가중치 파일 없음/추론 예외 시
mock 폴백 여부를 검증하며, 실제 추론 happy path(`test_real_inference_returns_valid_classification`)는
`@unittest.skipUnless(_MODEL_PATH.exists(), ...)`로 가중치가 있을 때만 돌게 해 이 파일이 없는
환경에서도 `manage.py test vision`이 항상 깨끗이 통과합니다. `VisionAnalyzeView`는 재배자만
호출 가능하며, `diary_id`를 함께 보내면 해당 `Diary.yolo_status_tag`도 갱신합니다(diary 소유권
검사 포함). `VisionAnalysis.result_tag`/`Diary.yolo_status_tag` 둘 다 `choices=` 없는 자유
`CharField`라 mock의 4개 태그와 실제 추론의 "정상"/"이상감지"가 같은 필드에 섞여도 마이그레이션
없이 그대로 저장됩니다.

프론트엔드(`grower/data/vision_repository.dart`)는 재배자가 일지를 작성해 `POST /api/diary/`가
성공한 직후, 사진이 있으면 같은 사진 바이트로 `POST /api/vision/analyze/`를 `diary_id`와 함께
백그라운드로 호출합니다(`diary_repository.dart`의 `createDiary()`가 생성된 diary id를 반환하도록
바뀐 것도 이 때문). `grower_diary_screen.dart`가 진행 중(스피너)/완료(결과 태그 배지)/실패(스낵바,
"분석에 실패했지만 일지는 저장되었습니다")를 화면에 안내하며, 분석이 실패해도 이미 저장된 일지
자체는 그대로 유지됩니다 — 일지 저장과 vision 분석을 하나의 트랜잭션처럼 묶지 않고 순차적인 두
API 호출로 분리한 것이 이 설계의 핵심입니다.

### RAG 챗봇 파이프라인
`chatbot/rag_pipeline.py`는 농촌진흥청 매뉴얼 기반 지식 문서 10개를 코드에 직접 하드코딩해두고
(PDF 등 외부 파일 의존 없음), `initialize_rag()`가 이를 ChromaDB로 임베딩해
`chatbot/vector_store/`에 저장(이미 저장되어 있으면 재임베딩 없이 로드)합니다. 이때 실제 벡터
저장/검색은 `chromadb` 패키지가 담당하는데, 한동안 `requirements.txt`에서 빠져 있어(로컬 venv에는
어쩌다 수동 설치돼 있어 티가 안 났음) 배포 환경(Render)에서는 `initialize_rag()` →
`Chroma(...)`가 `ImportError: Could not import chromadb python package`를 던졌고, 이걸
`ChatbotAskView`의 `except Exception`이 삼켜 **모든 챗봇 요청이 항상 `ERROR_ANSWER`로
폴백**했습니다 — 2026-08-26에 `chromadb==1.5.9`를 `requirements.txt`에 명시적으로 추가해
고쳤습니다(`chatbot/vector_store/`는 `.gitignore` 대상이라 배포 환경에는 없고, 첫 요청 때
`Chroma.from_documents()`로 10개 문서를 새로 임베딩해 만든 뒤 프로세스 수명 동안 캐싱합니다).
`ask_question()`은 Gemini(`LLM_MODEL = 'gemini-2.5-flash'`)로 답변을 생성하며,
`timeout=LLM_TIMEOUT_SECONDS`(원래 10초 → 20초, `gemini-2.5-flash`가 기본 thinking으로 5~8초가
걸려 배포 환경에서 10초는 종종 타임아웃 폴백을 유발함)를 둬 응답이 지연되면 타임아웃으로
실패시킵니다. 임베딩은 `EMBEDDING_MODEL = 'models/gemini-embedding-001'`을
쓰는데, 예전에 쓰던 `models/embedding-001`도 이 프로젝트의 API 키/버전에서 폐지되어 404가 나는 것을
확인해 함께 교체했습니다(임베딩 모델을 바꾸면 기존에 그 모델로 만든 벡터가 차원이 달라 호환되지
않으므로, `chatbot/vector_store/`를 지우고 새 모델로 재임베딩해 만들었습니다). 벡터스토어는
`chatbot/views.py`의 모듈 전역 `_vectorstore`에 프로세스당 한 번만 캐싱됩니다. `settings.GEMINI_API_KEY`가
비어있으면 `ChatbotAskView`는 RAG를 아예 호출하지 않고 고정 mock 응답("챗봇 서비스 준비 중입니다.")을
반환합니다 — 로컬 개발 시 API 키 없이도 앱이 동작하게 하기 위함입니다. 키가 있어도 `ask_question()`
호출이 실패하면(네트워크 오류, 타임아웃, 모델 오류 등 — `except Exception`으로 폭넓게 잡음)
`ChatbotAskView`가 500을 그대로 노출하지 않고 `ERROR_ANSWER`("죄송해요, 지금은 답변을 가져오지
못했어요. 잠시 후 다시 시도해주세요.")로 폴백합니다 — `sensor/anomaly.py`의 Gemini 폴백과 동일한
패턴입니다. 다만 이 폴백은 조용히 일어나 원인 파악이 어려워서(위 chromadb 사건이 오래 안 잡힌
이유), `except` 블록에서 `print(f'[Chatbot] RAG 응답 생성 실패, 폴백 사용: {e!r}')`로 예외를
서버 로그에 남깁니다(`seedlings/views.py`의 `[Email] ...` 실패 로그와 같은 `[Tag]` 컨벤션).
`ask_question()`은 `RetrievalQA.from_chain_type()`에 `chain_type_kwargs={'prompt': ANSWER_PROMPT}`로
커스텀 한국어 `PromptTemplate`을 넘깁니다 — LangChain 기본 프롬프트("문서에 근거 없으면 모른다고
답하라")가 매뉴얼 밖 질문("무화과 말고 다른 과일도 키울 수 있나요?" 등)을 지나치게 딱딱하게
거부하던 걸 고치려는 것으로, `ANSWER_PROMPT`는 (1) 프론트 UI의 '무화과 박사 피그' 캐릭터·친근한
존댓말 톤, (2) 참고 자료가 관련 있으면 우선 근거로 삼되 없어도 일반 원예 지식으로 답하기,
(3) 참고 자료 밖·불확실한 내용은 "일반적으로는"처럼 단정하지 않는 표현 쓰기를 지시합니다.
`chatbot/tests.py`는 `initialize_rag`/`ask_question`을 mock해 mock 응답/정상 RAG 응답/
호출 실패 시 폴백까지 세 경로를 모두 네트워크 호출 없이 검증하고, `AnswerPromptTests`가
`ANSWER_PROMPT`의 입력 변수(`{context, question}` — 어긋나면 `RetrievalQA`가 런타임에 깨짐)와
'무화과 박사 피그' 페르소나 문구를 못박습니다. 프롬프트가 실제로 매뉴얼 질문은 근거 기반으로,
매뉴얼 밖 질문은 거부하지 않고 답하는지는 실키로 curl 수동 검증했습니다 — sensor/diary와 동일하게
과금되는 실호출은 `manage.py test`에 넣지 않습니다.
`langchain` 1.x부터 API가 크게 바뀌어 `RetrievalQA`는 `langchain_classic.chains`에,
`RecursiveCharacterTextSplitter`는 `langchain_text_splitters`에 있습니다(`langchain.chains`/
`langchain.text_splitter` 아님).

### FCM 푸시 알림 (mock/실제 모드는 자격증명 설정 여부로 자동 분기)
`notifications/fcm.py`의 `send_push_notification(token, title, body)`는
`settings.FIREBASE_CREDENTIALS_PATH`와 `settings.FIREBASE_CREDENTIALS_JSON`이 **둘 다**
비어있으면 실제 전송 없이 print만 하는 mock 모드로 동작합니다. 둘 중 하나라도 있으면
`firebase_admin`을 lazy 초기화해 실제 FCM 메시지를 보냅니다. 두 값을 동시에 지원하는 이유는
로컬 개발과 배포 환경의 자격증명 주입 방식이 다르기 때문입니다 —
`FIREBASE_CREDENTIALS_PATH`는 로컬에 다운받은 서비스 계정 JSON 파일 경로를 가리키는 방식이고
(로컬 `.env`는 실제로 `FIREBASE_CREDENTIALS_PATH=firebase-adminsdk.json`으로 이미 설정돼 있어
로컬 개발 환경 자체는 이미 실제 발송 모드로 동작합니다 — mock 모드 테스트는 그래서
`@override_settings(FIREBASE_CREDENTIALS_PATH='', FIREBASE_CREDENTIALS_JSON='')`로 명시적으로
두 값을 비워야만 안정적으로 mock 모드를 재현할 수 있습니다), `FIREBASE_CREDENTIALS_JSON`은
서비스 계정 JSON 전체를 문자열 그대로 담는 환경변수입니다 — Render 같은 배포 환경은 무료
플랜에서 Shell/SSH 접근이 안 되므로(공식 문서로 확인, 파일을 서버에 직접 올릴 방법이 마땅치
않음) 파일 대신 환경변수 하나로 자격증명을 통째로 주입할 수 있어야 했습니다(Render의 Secret
Files 기능으로도 파일을 올릴 수는 있지만 대시보드 UI 기반이라 코드 변경이 필요 없는 대신,
Free 플랜에서도 그 기능 자체가 열려 있는지가 문서상 불명확해 환경변수 쪽을 기본 권장안으로
삼았습니다 — 코드는 둘 다 받아주므로 Secret Files를 쓰고 싶으면 `FIREBASE_CREDENTIALS_PATH`를
`/etc/secrets/<파일명>`으로 지정하기만 하면 됩니다). `_get_app()`은 `FIREBASE_CREDENTIALS_JSON`이
있으면 `json.loads()`로 파싱한 dict를(firebase_admin의 `credentials.Certificate`는 파일 경로
문자열과 dict를 둘 다 받습니다), 없으면 기존처럼 `FIREBASE_CREDENTIALS_PATH`를 그대로 씁니다.
`notifications/tests.py`의 `GetAppCredentialsTests`가 이 두 경로를 각각 `credentials.Certificate`
호출 인자로 검증합니다. `send_notification_to_user(user, title, body)`는
해당 유저의 `FCMToken`을 전부 조회해 순회 발송하며, `seedlings/views.py`의 `SeedlingCompleteView`
(`PATCH /api/seedlings/{id}/complete/`, 담당 재배자만 가능)가 묘목 완성 처리 후 이 함수를 호출해
입양자에게 알림을 보냅니다 — 앱 간 참조가 `seedlings` → `notifications.fcm`로 향하는 유일한 지점입니다.
`FCMToken.token`은 unique 필드이므로 등록 시 `(user, token)`이 아니라 `token` 하나로 중복을 판단합니다.

프론트엔드에서 토큰을 실제로 발급·등록하는 쪽은 Android 한정입니다. `core/notifications/
fcm_service.dart`의 `FcmService.getDeviceToken()`은 `kIsWeb`이거나 `Platform.isAndroid`가
아니면(web/windows 등) `google-services.json`이 Android에만 설정돼 있어 Firebase가 초기화되지
않으므로 항상 `null`을 반환합니다. `login_screen.dart`는 로그인 성공 직후 이 토큰을 가져와
`core/notifications/fcm_token_repository.dart`의 `registerToken()`으로
`POST /api/notifications/register-token/`을 호출하는데, 토큰이 `null`이거나 이 호출이 실패해도
`except`로 조용히 무시하고 로그인 흐름(라우트 이동)은 그대로 진행합니다 — 알림 등록은 로그인 성공의
부가 효과일 뿐 실패 조건이 아닙니다. Android 매니페스트에는 `POST_NOTIFICATIONS` 권한이 추가돼
있습니다.

`FcmService.getDeviceToken()` 안에서 `FirebaseMessaging.instance.requestPermission()`을 호출하는
바로 그 순간 OS의 `POST_NOTIFICATIONS` 권한 다이얼로그가 뜨는데, 이 시스템 다이얼로그는 디자인을
바꿀 수 없습니다. 그래서 `login_screen.dart`가 (Android에서, 계정당 최초 1회만) 그 앞에 Pig.Fig. 브랜드
톤의 커스텀 "프라이밍" 다이얼로그(`shared/widgets/notification_priming_dialog.dart`의
`showNotificationPrimingDialog()`)를 먼저 보여줍니다 — "허용할게요"를 누른 경우에만
`_registerPushToken()`(=`getDeviceToken()` 호출 경로)을 실행해 실제 OS 권한 요청까지 이어가고,
"나중에"를 누르면 `getDeviceToken()` 자체를 호출하지 않아 OS 권한 요청이 아예 트리거되지
않습니다. `FcmService`는 `requestPermission()`/`getToken()`이 분리되지 않은 그대로 두었습니다 —
"OS 권한 요청을 건너뛴다"는 요구가 이 메서드를 아예 호출하지 않는 것만으로 충분히 만족되기
때문입니다.

노출 여부는 `core/storage/notification_priming_storage.dart`의 `NotificationPrimingStorage`가
`CareInventoryStorage`/`InventoryStorage`와 동일하게 **계정(userId) 단위**의 `SharedPreferences`
키(`pigfig.notification_priming_seen.$userId`, 생성자 `NotificationPrimingStorage({required
this.userId})`)로 기록합니다 — "허용"이든 "나중에"든 응답과 무관하게, 한 번 판단이 끝난 계정에는
다시 묻지 않습니다. 같은 기기라도 계정마다 따로 판단하므로, A 계정으로 프라이밍에 응답한 뒤 같은
기기에서 B 계정으로 처음 로그인하면 B 계정에는 프라이밍이 한 번 더 뜹니다(예전에는 기기 단위라
안 떴음). `_submit()`이 로그인 응답의 `LoginResult.userId`를
`_needsNotificationPriming(userId)`/`_primeThenMaybeRegister(userId)`에 그대로 넘겨 이 저장소를
계정별로 생성합니다. (같은 패턴의 `mic_priming_storage.dart`는 이번 범위 밖이라 여전히 기기 단위입니다.)

이 다이얼로그를 넣기 위해 `login_screen.dart`의 `_submit()`에서 기존에 `unawaited(
_registerPushToken())`로 완전히 fire-and-forget이던 흐름을 바꿔야 했습니다 — 그대로 두면
`pushReplacementNamed()`가 로그인 라우트를 이미 교체한 뒤에 `showDialog()`가 유효하지 않은
context에서 뜨려는 레이스 컨디션이 생기기 때문입니다. 다만 매 로그인마다 등록 완료를 기다리게
하면 "로그인 흐름을 막지 않는다"는 기존 설계가 퇴보하므로, 프라이밍이 실제로 필요한
경우(=다이얼로그를 처음 보여주는 그 순간)에만 `await`로 응답을 기다리고, 이미 판단이 끝난
이후의 모든 로그인은 기존과 동일하게 `unawaited()`로 남겨뒀습니다 — 다이얼로그가 뜨는 것 자체가
의도된 1회성 마찰이라 그 경우만 예외로 취급한 것입니다. 다이얼로그 UI는
`features/auth/presentation/account_actions.dart`의 `confirmLogout()`(2버튼 `showDialog<bool>`
+ `Navigator.pop(true/false)` 시그니처)과 `games/shared/game_scaffold.dart`의
`GameScaffold.showResultDialog()`(흰 배경 + 둥근 모서리 + `barrierDismissible: false` +
`PigFigButton.primary`를 다이얼로그 content에 직접 넣는 시각 스타일)를 섞은 조합입니다.

### 묘목 입양(결제) 플로우 + 재배자 자동 배정
입양자가 무화과 묘목을 처음 입양하는 진입점은 `adopt_screen.dart`(`/adopter/adopt`, 홈 화면의
"무화과 입양하러 가기" CTA에서 진입)입니다. 실제 PG(결제) 연동은 없고, "결제하기" 버튼을 누르면
700ms 딜레이로 결제 성공을 흉내낸 뒤(mock) `SeedlingRepository.createSeedling()`으로
`POST /api/seedlings/`를 호출해 실제 `Seedling`을 생성합니다 — 결제 자체는 가짜지만 그 이후의
묘목 생성·재배자 배정은 전부 실제 백엔드 로직입니다. 생성 실패 시(예: 배정 가능한 재배자 없음)
`ApiException` 메시지를 스낵바로 보여주고 화면에 남아 재시도할 수 있습니다.

`seedlings/views.py`의 `SeedlingListCreateView.perform_create()`는 입양자만 호출 가능하며(재배자면
`PermissionDenied`), `grower`를 요청 바디가 아니라 서버가 직접 정합니다 — 전체 재배자 중
`status=GROWING`인 담당 묘목 수가 가장 적은 사람에게 자동 배정하고(동률이면 `pk` 오름차순으로
결정적 tie-break), 재배자가 한 명도 없으면 `grower=NULL`로 조용히 생성하지 않고 `ValidationError`
(400)로 명확히 실패시킵니다. 이 로직은 재배자가 여러 명일 때 신규 묘목이 한쪽으로 쏠리지 않게 하는
것이 목적이며, `seedlings/tests.py`에 이 자동 배정 happy path 테스트가 있습니다.

### 완성 묘목 수령/기부 선택
`Seedling.pickup_or_donate`(`PickupOrDonate` TextChoices: `pickup`/`donate`)와 `donate_type`
필드는 초기 마이그레이션(`0001_initial`)부터 모델에 존재했지만, 실제로 값을 갱신하는 엔드포인트가
없어 오랫동안 죽은 필드였습니다. `donate_type`도 원래 choices 없는 자유 `CharField`였는데, 계획서의
기부처 3가지(초등학교·복지시설 기증/도시농업 공동체·시민단체 연계/앱 내 나눔 분양)를 코드로
강제하기 위해 `Seedling.DonateType` TextChoices(`school_welfare`/`urban_farming_community`/
`in_app_sharing`)를 추가하고 `donate_type`에 `choices=`를 부여했습니다(`0002_alter_seedling_donate_type`
마이그레이션, DB 스키마 자체는 안 바뀌는 `AlterField`).

`PATCH /api/seedlings/{id}/pickup-donate/`(`SeedlingPickupDonateView`)는 `SeedlingCompleteView`와
대칭되는 설계입니다 — `SeedlingCompleteView`가 담당 재배자만 완성 처리할 수 있게 하는 것처럼, 이
뷰는 해당 묘목의 **입양자만**(`user.role == ADOPTER`이고 `seedling.adopter_id == user.pk`) 선택할
수 있게 `PermissionDenied`로 명시적으로 검사합니다. 추가로 `seedling.status != COMPLETED`면
`ValidationError`(400)로 막습니다 — 재배 중인 묘목에 미리 수령/기부를 선택하는 것은 의미가 없기
때문입니다. 입력 검증은 `SeedlingPickupDonateSerializer`(`serializers.Serializer` 기반, 모델
serializer 아님)가 담당하며, `pickup_or_donate='donate'`인데 `donate_type`이 없으면
`validate()`에서 400을 던집니다. `pickup`을 선택하면 요청에 `donate_type`이 섞여 들어와도 뷰가
무시하고 항상 `None`으로 정리해서 저장합니다.

이 엔드포인트는 재제출(선택 변경)을 막지 않습니다 — `SeedlingCompleteView`도 재호출 가드가 없는
것과 같은 수준을 유지했습니다. 다만 재제출을 허용하는 대신, 저장 전 기존 값과 비교해 **실제로
값이 바뀐 경우에만** `notifications.fcm.send_notification_to_user`로 재배자에게 알림을 보냅니다
(같은 선택을 실수로 여러 번 눌러도 재배자에게 중복 알림이 안 가도록). 알림 수신자가
`SeedlingCompleteView`(입양자에게 발송)와 반대로 **재배자**인 이유는, 수령/기부 선택 이후 실제로
행동해야 하는 쪽이 재배자이기 때문입니다(수령이면 픽업 방문을 준비해야 하고, 기부면 어느 기부처로
보내야 하는지 알아야 함). 기부를 선택했을 때 알림 문구에는 `Seedling.DonateType(donate_type).label`로
변환한 한국어 라벨을 넣습니다.

`pickup_donate_screen.dart`는 이 엔드포인트와 실제로 연동됩니다. `pickPrimarySeedling()`(재배중
묘목을 우선함)은 이 화면 목적과 맞지 않아 재사용하지 않고, `seedling_repository.dart`에 별도
헬퍼 `pickSeedlingForPickupDonate()`를 추가했습니다 — `status == completed`인 묘목 중 가장 최근에
완료된 것을 대상으로 삼으며, 이미 선택을 마친 완료 묘목도 포함합니다(백엔드가 재제출을 허용하므로
다시 바꿀 수 있게). 완료된 묘목이 하나도 없으면 선택 UI 대신 안내 문구만 보여줍니다(홈 화면과
동일한 로딩/에러/대상없음/데이터 4상태 분기). 화면 진입 시 대상 묘목의 기존
`pickupOrDonate`/`donateType`(둘 다 `Seedling` 모델에 새로 추가한 nullable 필드, JSON의
`pickup_or_donate`/`donate_type`을 파싱)이 있으면 그 값으로 선택 상태를 미리 채워, 이미 정한
선택을 다시 열었을 때 빈 화면이 아니라 직전 선택이 보이게 했습니다.

원래 "직접 수령" 선택 시에는 제출 버튼 자체가 렌더링되지 않았던 문제(`if (isDonate) [버튼] else
SizedBox`)를 고쳐, 이제 두 선택 모두 항상 `PigFigButton.primary`가 보이고 라벨만 분기합니다
("수령으로 확정하기 🧺" / "기부하고 인증서 받기 📜"). 기부처 mock 3곳(구체적 기관명, 예: "행복
지역아동센터")은 계획서 기준 3개 카테고리("초등학교·복지시설 기증"/"도시농업 공동체·시민단체
연계"/"앱 내 나눔 분양")로 교체했습니다 — 기존 mock 3곳을 살펴보면 셋 다 사실상 "복지시설 기증"
한 카테고리의 변주였고 나머지 두 카테고리에 대응하는 항목이 없어서, 억지로 매핑하는 대신
`Seedling.DonateType`과 1:1 대응하는 카테고리 자체를 카드로 노출하는 쪽을 선택했습니다.
`_Organization`은 각 카드에 대응하는 `DonateType` 값을 함께 들고 있어 선택 시 그대로
`updatePickupOrDonate()` 호출에 씁니다.

`SeedlingRepository.updatePickupOrDonate({seedlingId, choice, donateType})`은
`createSeedling()`과 동일한 토큰 확인 → `ApiException` 전파 패턴이며, `grower_repository.dart.
completeSeedling()`이 쓰는 `ApiClient.patch()`를 그대로 재사용합니다(이번엔 body에
`pickup_or_donate`/`donate_type`을 담아서 호출). 프론트 쪽 `PickupOrDonateChoice`/`DonateType`
enum은 백엔드 문자열 키와 정확히 1:1 대응하도록 `apiValue`/`fromApiValue`를 붙여
`SeedlingStatus`/`SeedlingStatusApi`와 같은 패턴을 따릅니다. 기부 확정 성공 시에는 기존과 동일하게
`donation-certificate` 화면으로 이동하고(다만 이제 PATCH 성공 **후에만** 이동), 수령 확정 성공
시에는 인증서가 필요 없으므로 스낵바("수령이 확정됐어요 🧺") + `Navigator.pop()`으로 마무리합니다.

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
  `pigfig_logo.dart`의 `PigFigLogo`는 claude.ai/design "PigFig Screens" 2a(메인 심볼)/2b(앱 아이콘
  락업) 섹션을 그대로 옮긴 로고 위젯입니다 — `FigTreeIllustration`/`PigCharacter`와 동일하게 이미지
  파일이 아니라 `Container`+`Stack` 도형 조합으로 그리며, 색상은 전부 `AppColors` 토큰만 씁니다
  (몸통=`pink500`, 잎=`green800`, 줄기=`brown600`). `size` 하나로 전체 크기를 받아 내부 비율을
  유지한 채 스케일되고(디자인의 150x170 기준 좌표를 비율로 변환), `variant`로 두 형태 중 고를 수
  있습니다 — `PigFigLogoVariant.symbol`(2a, 배경 없이 무화과+돼지 마크만 단독)과
  `PigFigLogoVariant.iconLockup`(2b, `pink500` 라운드 사각형 안에 흰색 마크). **현재 앱 전체(로그인
  화면 74px, `PigFigAppBar` 30px)는 `symbol`(2a)로 통일**되어 있고, 이게 위젯의 기본값이기도
  합니다. `iconLockup`(2b)은 지금 실제로 쓰는 곳은 없지만 나중에(예: 런처 아이콘, 파비콘) 필요할 수
  있어 위젯 자체는 지우지 않고 `variant` 옵션으로 남겨뒀습니다 — 삭제하지 말 것. 30px처럼 아주 작은
  크기에서는 `symbol`의 눈·주둥이 디테일이 몸통 색(`pink500`)과 명도 차이가 크지 않아 사실상 잘 안
  보이고 잎+실루엣 정도만 식별됩니다(Chrome에서 직접 크롭 확대해 확인) — 다만 임의로 `iconLockup`
  으로 되돌리지 않고 이 상태를 그대로 유지 중이니, 필요하면 재판단해주세요. `symbol` variant는 실제
  로고 이미지가 준비될 자리도 함께 마련해뒀습니다 — `build()`가 먼저 `Image.asset('assets/images/
  logo.png', width: size)`를 시도하고, `errorBuilder`로 로딩 실패(에셋 미존재)를 잡아 기존 도형
  그리기(`_FigPigMark`)로 폴백합니다. **`assets/images/logo.png`는 이제 실제 파일(500x500 PNG)로
  존재하며 앱 전체(로그인 화면·`PigFigAppBar`)가 이 실제 이미지를 렌더링합니다** — `errorBuilder`
  폴백은 더 이상 정상 경로에서 타지 않고 에셋이 사라지는 예외 상황을 위한 방어 코드로만 남아
  있습니다. 이미지 크기·비율은 처음엔 알 수 없는 상태였어서 `height`는 지정하지 않고 `width: size`만
  줘서 원본 비율을 유지한 채 스케일되게 했는데, 지금 넣은 파일이 정사각형(500x500)이라 결과적으로는
  차이가 없습니다 — `iconLockup` variant는 이미지 우선 로직 없이 기존 도형 그리기 그대로입니다(지금
  쓰는 곳이 없고, 같은 `logo.png`를 그대로 쓰기 애매하므로 필요해지면 별도 판단).
- 앱 아이콘(런처 아이콘)은 `flutter_launcher_icons`(dev dependency, `pubspec.yaml` 최하단에 설정
  블록) 패키지로 생성합니다. `image_path: "assets/icon/icon.png"`(`min_sdk_android: 24`—
  `android/app/build.gradle.kts`가 쓰는 `flutter.minSdkVersion`의 실제 값과 맞춤)로 설정돼 있고,
  이 설정 블록은 `flutter: assets:` 목록에는 등록하지 않습니다 — Flutter 런타임이 번들링할 대상이
  아니라 `flutter_launcher_icons` 커맨드가 직접 디스크에서 읽는 소스 파일이라 `pub get`/`analyze`/
  `run` 어느 것도 이 파일의 존재 여부를 검사하지 않기 때문입니다. **`assets/icon/icon.png`도 이제
  실제 파일로 존재하고(`assets/images/logo.png`와 동일한 파일), `dart run flutter_launcher_icons`가
  이미 실행되어 Android(`android/app/src/main/res/mipmap-*/ic_launcher.png`)와 iOS
  (`ios/Runner/Assets.xcassets/AppIcon.appiconset/`) 런처 아이콘이 실제 로고로 교체된 상태입니다**
  — 단, `pubspec.yaml`의 `flutter_launcher_icons:` 블록 바로 위 주석은 "image_path 파일이 아직
  없어서 지금 실행하면 에러가 난다"고 쓰여 있는데 이는 더 이상 사실이 아니므로(파일이 실행 전에
  이미 추가됨), 다음에 이 주석을 만지게 되면 함께 정리할 것.
- 라우팅은 `main.dart`의 `MaterialApp.routes`에 이름 있는 라우트로 전부 등록합니다(중첩 라우터 없음).
  로그인 성공 시 역할이 `adopter`면 `pushReplacementNamed('/adopter')`, `grower`면
  `pushReplacementNamed('/grower')`로 이동합니다(`login_screen.dart`).
- 케어 화면(`features/adopter/presentation/care/*.dart`) 3종은 각각 다른 제스처로 게이지 값을 올립니다:
  물주기=`onLongPressStart`/`onLongPressEnd`로 타이머 반복 증가, 영양제=`Draggable`/`DragTarget`,
  햇빛=`Slider`. 계획서상 이 케어는 "실제 재배와 분리된 미션형 연출"이라 서버(Django) 저장 대상은 아니라고
  판단했지만, 화면을 벗어나면(라우트 pop) 방금 완료한 케어까지 즉시 사라지는 건 그 의도와도 안 맞는
  진짜 결함이라 로컬 영속화만 추가했습니다 — `core/storage/care_storage.dart`의 `CareStorage`가
  `InventoryStorage`/`OnboardingStorage`와 동일한 `SharedPreferences` 래퍼 패턴으로 **게이지 %가
  아니라 화면별 마지막 완료 시각만** 저장합니다(연속값을 영속화하는 건 의미가 없고, "오늘/이번 주
  이미 했는지"만 기억하면 충분하기 때문). 물주기/영양제 2개 화면만 대상이고 햇빛은
  제외했습니다 — 햇빛은 `Slider`로 자유롭게 왔다갔다 조절하는 순수 다이얼이라 애초에 이산적인 "완료"
  개념이 없어서, 억지로 완료 상태를 만들면 기존의 자유로운 상호작용을 깨뜨리기 때문입니다.
  완료 판정 기준도 화면마다 다릅니다 — 물주기는 오늘(캘린더 날짜) 안에 완료 기록이 있으면 잠금,
  영양제는 화면 문구("7일에 한 번이면 충분해요")에 맞춰 최근 7일 이내(`DateTime.difference().inDays`
  기준 rolling window)면 잠금 + "다음 영양제까지 N일 남았어요"로 안내. 두 화면 모두 완료 시 게이지가
  100%를 처음 찍는 순간(`_completed` 가드로 1회만) `CareStorage.markCompleted()`를 호출하고, 그
  즉시 제스처를 잠급니다(`onLongPressStart: _completed ? null : ...` 패턴). 물주기 화면에
  있던 "누르는 동안 재배자에게 물주기 요청이 기록돼요"라는 안내 문구는 실제로는 아무 데도 기록되지
  않는 순수 장식이었던 걸 이번에 발견해, 실제 동작(이 기기에 로컬 저장)과 맞는 문구로 고쳤습니다.
  세 화면 모두 여전히 **서버에는** 저장되지 않습니다 — 이 기기를 벗어나면(재설치, 기기 변경)
  초기화됩니다.
- 케어 아이템은 원래 무제한으로 쓸 수 있었지만, 횟수제로 전환하면서 `core/storage/
  care_inventory_storage.dart`의 `CareInventoryStorage`(계정별 `SharedPreferences`, `CareStorage`/
  `InventoryStorage`와 동일한 컨벤션)가 `CareItemType`(`water`/`nutrient`/`pigFeed`) 보유 개수를
  관리합니다. `AuthRepository.login()` 성공 직후 `grantInitialIfNeeded()`를 호출해 계정당 물주기/
  영양제 각 2개를 최초 1회만 지급합니다(멱등 — `pigfig.care_inventory.granted.$userId` 플래그로
  로그인마다 재지급되지 않게 가드). 물주기/영양제 화면은 게이지를 100% 채우는 시점에
  `consume()`으로 1개를 차감하고, 0개면 게이지 UI 대신 `shared/widgets/care_out_of_stock_state.dart`의
  `CareOutOfStockState`("게임 탭에서 아이템을 모아보세요")를 보여줍니다. `grant()`(충전)는 이제 게임
  보상 지급 경로와 실제로 연결되어 있습니다 — `games/shared/game_items.dart`의 `rewardItems` 3종을
  각 `CareItemType`과 1:1로 대응하도록 이름·이모지를 바꿨습니다(`water_item`=물주기 아이템 💧,
  `nutrient_item`=영양제 아이템 🍃, `pig_feed_item`=돼지 먹이 🍖 — 이전에는 "무화과잎 부채"처럼
  장식용 이름이라 실제로 뭘로 쓰이는지 알기 어려웠습니다). 같은 파일의 `careItemTypeFor(item)`이
  `GameItem.id`를 보고 대응하는 `CareItemType`을 돌려주며(목록에 없는 id면 `ArgumentError`),
  `games_screen.dart`의 `_saveEarnedItems()`가 획득 아이템마다 `InventoryStorage.addItem()`(장식용,
  게임 탭 하단 "보유 아이템" 바 표시 목적)과 `CareInventoryStorage.grant(careItemTypeFor(item))`
  (실제 소비 가능한 개수)를 함께 호출하는 이중 구조입니다. `CareInventoryStorage` 인스턴스는
  `_initInventory()`에서 `InventoryStorage`와 같은 시점에 같은 userId로 함께 만듭니다(홈 화면
  `_fetchCareState()`가 쓰는 것과 동일한 생성 패턴). 이제 `pigFeed`도 게임에서 실제로 모을 수
  있어(위 "나무 방치 상태" 문단의 돼지 먹이 화면 참고) 항상 재고 0이던 상태를 벗어났습니다.
- 나무 방치 상태(`TreeStatus`: `healthy`/`wilted`/`pigInfested`, `shared/widgets/
  fig_tree_illustration.dart`)는 `home_screen.dart`의 `computeTreeStatus(lastCompleted)`가
  `CareStorage.mostRecentCompletion()`(물주기/영양제 중 더 최근 완료 시각, 기록이 아예 없으면 신규
  계정으로 보고 healthy) 이후 경과일로 계산합니다 — 3일 이상이면 `wilted`(잎·줄기 색이 어두운 갈색
  쪽으로 `Color.lerp` 보간), 6일 이상이면 `pigInfested`(같은 톤 + 나무 옆 돼지 이모지 오버레이)입니다.
  다만 화면에 실제 돼지 캐릭터(`PigCharacter`, 탭 가능)가 나타나는지는 이 톤과 별개로 결정됩니다 —
  `pigInfested`여도 최근 12시간 안에 이미 먹이를 줬으면(`CareStorage.isPigFedRecently()`) `showPig`는
  false가 되어, 나무 톤은 시든 채 유지하되 돼지·"6일이나 지났어요... 돼지가 찾아왔어요" 문구 대신
  "3일 동안 자리를 비웠더니..."로 낮춰 보여줍니다(화면에 없는 돼지를 언급하지 않도록). 돼지를 탭하면
  `/adopter/care/pig-feed`(`pig_feed_care_screen.dart`)로 이동합니다 — `PigFeedCareScreen`은 먹이
  (🍖)를 20번 탭해 포만 게이지를 채우는 화면이며, 완료 시 `CareInventoryStorage.consume(pigFeed)`로
  먹이 1개를 차감하고 `CareStorage.markPigFed()`로 시각을 기록한 뒤 "확인"을 누르면 `Navigator.
  pop(context, true)`로 홈 화면에 성공을 알립니다. 홈 화면은 이 결과를 받으면 즉시 `_isPigExiting`을
  켜서(그사이 `_load()`가 끝나기 전에 `showPig`가 이미 false로 바뀌어도 돼지가 화면에서 뚝 끊기지
  않도록) `AnimatedSlide`로 돼지를 좌우 무작위 방향(`Random().nextBool()`)으로 700ms 동안
  퇴장시킵니다 — `AnimatedSlide.onEnd`는 최초 mount 시에도 한 번 불리므로, 실제로 퇴장 중일 때만
  (`_isPigExiting == true`) 상태를 리셋하는 가드가 있습니다. 홈 화면 우측 케어 버튼 3개
  (`CareActionButton`)에는 물주기/영양제 보유 개수 배지가 붙어 `_fetchCareState()`가 조회한
  `CareInventoryStorage` 값을 표시합니다(햇빛은 소비 개념이 없어 배지 없음). 홈 화면의
  나무 일러스트와 화면 하단 흙 배경(`shared/widgets/ground_illustration.dart`의
  `GroundIllustration`)은 이제 화면 높이 비율 기반입니다 — 예전엔 흙 높이/곡선(160/50)과
  나무를 올리는 `Transform.translate` 오프셋(-50)이 고정 픽셀이라 실기기 화면 크기에 따라
  나무와 흙의 상대 위치가 어긋났습니다. `GroundIllustration.height`는 `MediaQuery.sizeOf(
  context).height * 0.175`(곡선은 그 높이의 0.3125), 나무 lift는 `screenH * _treeLiftRatio`
  (0.055)로, 화면 높이 914(저장소 `safe_area_layout_test.dart` 픽스처)에서 기존 값이 그대로
  재현되도록 역산한 비율입니다. `_SeedlingHome`의 `Column`도 `Spacer()`를 나무 '뒤'가 아니라
  배너와 나무 '사이'로 옮겨, 나무 밑동이 화면 상단 기준 고정 거리가 아니라 항상 화면
  하단(흙)에 붙도록 했습니다(겹침량이 화면 크기와 무관하게 일정). 다만 사용 가능 높이가
  ~675px 미만인 초소형 기기에서는 나무 박스(≈482px)+카드+배너가 body를 넘겨 나무 상단이
  여전히 잘립니다 — body 스크롤화는 이번 범위 밖입니다.
- `features/grower/presentation/grower_shell.dart`는 홈(`GrowerShelfScreen`)/일지
  (`GrowerDiaryScreen`)/환경점검(`GrowerSensorScreen`)/마이(`GrowerMypageScreen`) 4탭
  `StatefulWidget`입니다. `body: IndexedStack(index: _index, children: _screens)`로 네 화면을 전부
  트리에 유지한 채 화면만 바꿔치기하므로, 탭을 벗어났다 돌아와도 각 화면의 `State`(불러온 데이터,
  입력 중이던 값 등)가 사라지지 않습니다 — 예전엔 `_screens[_index]`로 매번 선택된 위젯 하나만
  트리에 있어서 탭을 바꾸면 이전 화면의 State가 그대로 dispose됐었습니다. 대가로, 로그인 직후
  네 탭이 한꺼번에 mount되면서 `GrowerRepository.fetchSeedlings()`를 부르는 화면(대시보드/일지/
  환경점검/마이 전부)이 동시에 각자 한 번씩 호출해 `GET /api/seedlings/`가 여러 번 중복 요청되는데,
  기능상 문제는 없고(각자 필요한 값만 씀) 별도 캐싱 레이어 없이 그대로 두었습니다. 각 탭 화면은
  `adopter`의 `HomeScreen`처럼 자기 자신도 `Scaffold`+`PigFigAppBar`를 갖고 있어 `GrowerShell`의
  `Scaffold.body`로 들어가는 중첩 Scaffold 구조입니다 — 새 탭을 추가할 때도 이 패턴을 따릅니다.
  다만 `IndexedStack`이 State를 보존한다는 건 각 화면의 `initState`가 최초 1번만 실행된다는
  뜻이라서, 탭을 벗어났다 돌아와도 데이터가 다시 조회되지 않는 부작용이 있었습니다(예: 재배자
  대시보드 탭을 벗어나 일지를 쓰고 돌아와도 통계가 안 바뀜). `core/revalidatable_state.dart`의
  `RevalidatableState<T>`(`revalidate()` 추상 메서드 하나짜리)로 이를 해결했습니다 — `Shell`이
  재조회가 필요한 화면마다 `GlobalKey<RevalidatableState>`를 쥐고 있다가, `_switchTab()`에서 탭
  인덱스가 실제로 바뀔 때만(같은 탭을 다시 눌러도 재조회하지 않도록 가드) 새로 활성화되는 탭의
  키로 `.currentState?.revalidate()`를 직접 호출합니다. `revalidate()` 구현은 stale-while-revalidate
  패턴을 따릅니다 — 로딩 스피너를 띄우거나 기존 데이터를 지우지 않고 백그라운드로만 다시 불러와
  성공하면 조용히 교체하고, 실패하면 기존 데이터를 그대로 둡니다(첫 진입이 아직 안 끝난 예외 상황만
  일반 로드로 대체). 현재 `HomeScreen`/`GrowthTimelineScreen`(`AdopterShell`)과
  `GrowerShelfScreen`/`GrowerMypageScreen`(`GrowerShell`)이 이 패턴을 쓰고, `GrowerDiaryScreen`/
  `GrowerSensorScreen`은 입력값이 매번 새로 작성되는 화면이라 재조회 이슈가 없어 적용하지 않았습니다.
  `login_screen.dart`는 로그인 응답의 `role`이 `grower`면 `pushReplacementNamed('/grower')`로 이동합니다
  (이전엔 "재배자 화면은 준비 중이에요" 스낵바만 띄웠으나 grower 플로우 구현 후 실제 이동으로 변경).
- 재배자 홈 탭(`GrowerShelfScreen`, `RevalidatableState`)은 담당 묘목을 "N단 선반"(참고 React 목업의
  구조를 그대로 포팅한 `_ShelfTier` — 브라켓바+쿨링팬 로우+LED바+화분 로우+받침대) 형태로 보여줍니다.
  `_fetchData()`가 `GrowerRepository.fetchSeedlings()`로 담당 묘목을 조회한 뒤, 묘목마다
  `DiaryRepository.fetchDiaries()`를 병렬 호출해 **가장 최근 일지**(`createdAt` 기준,
  백엔드 응답 순서가 보장되지 않으므로 클라이언트에서 직접 최댓값을 찾음 —
  `growth_timeline_screen.dart`와 동일한 이유)의 성장 단계(`growthStage` 코드값/한글 라벨)를
  화분마다 묶습니다. 헤더 아래 필터 버튼 4개(전체/발근중/잎성장/가지발달, `_ShelfFilterBar` — 4개가
  한 줄에서 밀리지 않도록 `Row`+`Expanded`로 균등 배분하고 `FittedBox(scaleDown)`로 긴 라벨도 줄바꿈
  없이 맞춥니다)가 이 성장 단계 코드값을 기준으로 화분을 걸러냅니다 — "전체"만 모든 화분(완료
  단계 포함)을 보여주고, 나머지 세 필터는 정확히 그 단계와 일치하는 화분만 남기므로 완료(mature)
  단계 화분은 "전체"에서만 보입니다. 필터 결과가 0개면 화분 없이 빈 선반 틀(브라켓/팬/LED/받침대)
  1단과 "해당 단계의 묘목이 없어요" 안내만 보여줍니다(`_EmptyPotArea`) — 담당 묘목 자체가 0마리인
  경우(`_EmptyState`)와는 다른 상태입니다. 한 단에는 화분 2개씩(`_chunkIntoTiers(entries, 2)`)
  배치되며, 화분 몸통/식물 아이콘/텍스트 치수는 원래 대비 1.2배 확대되어 있습니다(`_ShelfPot`,
  `maxWidth: 120`). 화분을 탭하면 `GrowerSeedlingAnalysisArgs`를 route argument로 담아
  `/grower/seedling-analysis`(현재는 최소 뼈대)로 이동합니다.
- `main()`의 `runApp(const PigFigApp(initialRoute: '/splash'))`가 진입점입니다.
  `features/splash/presentation/splash_screen.dart`의 `SplashScreen`이 베이지 배경에
  `PigFigLogo`(120px)를 `Hero(tag: 'pigfig-logo')`로 감싼 채 1.2초 보여준 뒤
  `pushReplacementNamed('/')`(로그인 화면)로 넘어갑니다 — `login_screen.dart`의 로고도 같은
  `Hero` 태그를 써서 전환 시 74px로 줄어들며 이어지는 애니메이션을 만듭니다. `PigFigApp` 생성자의
  `initialRoute` 기본값은 여전히 `/`(로그인)라서, `widget_test.dart`처럼 `PigFigApp()`을 인자 없이
  pump하는 기존 테스트는 영향받지 않고 `main()`에서만 `/splash`로 명시적으로 오버라이드합니다.
  온보딩(`features/onboarding/presentation/onboarding_screen.dart`, `PageView` 3장 — 서비스
  소개/시니어 재배자/앱으로 케어)은 이제 **"최초 1회만"이 아니라 입양자로 로그인에 성공할 때마다
  매번** 보여집니다 — `login_screen.dart`가 `role == adopter`면 무조건 `pushReplacementNamed(
  '/onboarding')`로 이동합니다. 예전에 노출 여부를 기록하던 `core/storage/onboarding_storage.dart`
  의 `OnboardingStorage`(`hasSeenOnboarding()`/`markSeen()`)는 이 흐름에서 더 이상 호출되지 않는
  **죽은 코드**입니다 — 클래스 자체는 나중에 "1회만 노출"로 되돌릴 가능성을 대비해 지우지 않고
  남겨뒀을 뿐, 지금은 어디서도 인스턴스화되지 않습니다. 마지막 페이지에서만 "시작하기 🌱" 버튼
  (`PigFigButton.positive`, `AppColors.green500`)이 보이고 "건너뛰기" 링크는 `Visibility(
  maintainSize: true)`로 자리만 차지한 채 숨겨집니다(디자인 문서가 "건너뛰기" 자리에 투명
  placeholder를 두는 것과 동일한 방식). 세 번째 페이지("앱으로 케어") 일러스트는 새로 그리지 않고
  기존 `shared/widgets/fig_tree_illustration.dart`의 `FigTreeIllustration(width: 44)`를 흰 카드
  안에 중앙 배치한 뒤, 물/햇빛/가지치기 아이콘 배지 3개(영양제 배지는 디자인 원본에 없어 의도적으로
  제외)를 감쌌습니다 — 배지는 온보딩 2가 이미 쓰던 `_EmojiBadge`를 재사용하되, 흰 배경에 옅은
  그림자가 있는 디자인이라 기본값 `false`인 `shadow` 파라미터를 추가해 온보딩 2 호출부는 그대로
  그림자 없이 두고 온보딩 3에서만 `true`로 켰습니다. `_pageCount` 상수 하나가 페이지 수·마지막
  페이지 판정·점 인디케이터 개수·건너뛰기 숨김을 전부 구동하는 구조라, 페이지를 추가할 때 이
  상수와 `PageView.children`만 바꾸면 나머지 로직은 그대로 따라옵니다. 온보딩 마지막 페이지의
  "시작하기"는 `/adopter`로 push할 뿐이라, 로그인 직후 온보딩을 거쳐 홈으로 들어가는 흐름이 매번
  반복됩니다.
- `adopter_shell.dart`도 `grower_shell.dart`와 동일하게 홈/게임/타임라인(`GrowthTimelineScreen`)/
  마이페이지 4탭(이 순서)을 `IndexedStack`으로 유지하는 `StatefulWidget`입니다(처음엔 `switch` 식으로
  선택된 화면 하나만 트리에 뒀는데, 두 `Shell` 모두 `IndexedStack`으로 바꿔 상태 보존과 구현 방식을
  통일했습니다). 홈/타임라인도 `grower_shell.dart` 문단에서 설명한 `RevalidatableState` +
  `GlobalKey` 패턴으로 탭 재진입 시 백그라운드 재조회를 합니다(완성 신고나 새 일지처럼 다른 곳에서
  바뀐 데이터가 반영되어야 하므로). `games_screen.dart`
  (1m)는 2x2 게임 카드 그리드(돼지 풍선 터뜨리기/무화과 퀴즈/해충 잡기/물주기 타이밍, 각 카드에
  `StatusBadge`로 난이도 배지) + 하단 "보유 아이템" 바로 구성됩니다. 구현 중 실제로 겪은 버그: 2x2
  카드를 각 `Row`+`Expanded`로 만들고 카드 높이를 맞추려고 `CrossAxisAlignment.stretch`를 줬는데,
  이 `Row`가 (`SingleChildScrollView` → `Column`으로 이어지는) 세로 방향이 unbounded인 컨텍스트에
  직접 놓여 있으면 `stretch`가 무한대 높이로 풀리면서 그 `Row` 이후의 형제 위젯(두 번째 카드 줄,
  보유 아이템 카드)이 전부 화면 밖으로 밀려나 안 보이는 문제가 있었습니다(디버그 assert가 release
  웹 빌드에서는 제거되어 에러도 없이 조용히 사라짐 — Playwright로 실제 렌더링을 확인하지 않았다면
  놓쳤을 버그). 각 `Row`를 `IntrinsicHeight`로 감싸 높이를 먼저 유한하게 확정시킨 뒤 `stretch`를
  적용하는 방식으로 해결했습니다.

  게임 4종(`games/balloon_pop/`, `games/fig_quiz/`, `games/pest_catch/`, `games/watering_timing/`)은
  모두 실제로 플레이 가능한 화면입니다. 각 게임은 `games/shared/game_scaffold.dart`의
  `GameScaffold`(제목+점수+닫기 헤더 공통 셸)로 본문을 감싸고, 종료 시 `GameResult`(점수/클리어
  여부/획득 아이템 목록/등급)를 만들어 `Navigator.pop(context, result)`로 `games_screen.dart`에
  돌려주는 동일한 패턴을 따릅니다. `GameScaffold.showResultDialog()`가 결과 다이얼로그(성공/실패
  문구 + 등급 배지 + 점수 + 획득 아이템 박스)를 공통으로 띄우는 것도 네 게임이 공유합니다.
  물주기 타이밍(`watering_timing_screen.dart`)의 `_TimingBar`는 왕복 트랙 + 초록 반투명 타겟 존 박스
  + 물방울 인디케이터로 구성되는데, "타겟 존 정중앙에서 탭하세요" 안내만 있고 정확한 지점 표시가
  없어 사용자가 헤매던 문제가 있어 **순수 시각 안내선**(빨간 세로선, width 3, `_centerLineWidth`)을
  추가했습니다 — 물방울 인디케이터가 `Positioned(left: controller.value * usable)`로 그려지므로
  같은 식에 `controller.value` 대신 `targetCenter`를 넣고 인디케이터 너비(`_indicatorSize`)의 절반만큼
  보정해(`targetCenter * usable + _indicatorSize / 2 - _centerLineWidth / 2`) 인디케이터가 정확히
  targetCenter에 있을 때의 위치, 그리고 타겟 존 박스의 정중앙(`zoneLeft + zoneWidth / 2`)과 좌표가
  일치합니다. 게임 로직(`_scoreFor`)이나 타겟 존 박스 자체는 그대로입니다. `watering_timing_test.dart`
  에 안내선 rect의 가로 중앙이 타겟 존 박스의 가로 중앙과 겹치는지(±0.5px) 검증하는 위젯 테스트가
  있습니다.
  `games_screen.dart`의 `_openGame()`은 `GameType` 기준 `switch`로 각 게임 화면을 push하고, 돌아온
  `GameResult.itemsEarned`(클리어 시에만 채워짐)를 `_saveEarnedItems()`가 순회하며 `core/storage/
  inventory_storage.dart`의 `InventoryStorage.addItem()`으로 하나씩 저장한 뒤 보유 아이템 바를 다시
  그립니다. `InventoryStorage`는 `TokenStorage`/`OnboardingStorage`와 동일한 `SharedPreferences`
  래퍼 컨벤션이며, 아이템 목록을 JSON 문자열 하나로 인코딩해 저장합니다(게임 종류·서버 저장 없이
  로컬에만 누적).

  각 게임의 점수는 `.clamp(0, 100)`으로 100점을 넘지 않게 잘리고(예: 돼지 풍선 터뜨리기는 동시
  최대 5개 풍선을 계속 터뜨리면 무제한 누적되는 것을 막기 위함), 클리어 기준은 4종 공통으로 50점
  이상입니다. `games/models/reward_grade.dart`의 `computeRewardGrade(score)`가 점수를 등급으로
  변환합니다 — 50점 미만은 클리어 실패로 `null`(등급 없음, 아이템도 없음), 50~69는 브론즈, 70~89는
  실버, 90~100은 골드(`RewardGrade` enum). `games/shared/game_items.dart`의 `rewardItems`는 4개
  게임이 공유하는 공용 아이템 풀(무화과잎 부채/시니어의 물뿌리개/햇살 한 줌 3종)이며,
  `rewardCountFor(type, grade)`가 등급·게임별 지급 개수를 결정합니다 — 브론즈는 모든 게임이
  1개로 동일하고, 실버는 돼지 풍선 터뜨리기만 1개고 나머지 세 게임은 2개, 골드는 물주기 타이밍만
  3개고 나머지 세 게임은 2개입니다("브론즈는 공통, 실버·골드는 게임마다 다르다"는 표 형태라
  게임별 로컬 상수 4곳에 중복 정의하는 대신 이 함수 하나로 모았습니다). `pickRewardItems(type,
  grade, random)`은 브론즈·실버에 한해 그 개수만큼 `rewardItems`에서 무작위로 뽑아
  `GameResult.itemsEarned`를 즉시 채웁니다(중복 허용, grade가 `null`이면 빈 리스트). 골드는
  게임 화면이 `pickRewardItems`를 호출하지 않고 `itemsEarned`를 빈 리스트로 남겨 `GameResult`를
  만듭니다 — 대신 `GameResult.gameType`(각 게임이 자신의 `GameType`을 함께 담음)을 보고
  `GameScaffold.showResultDialog()`가 `cleared && grade == RewardGrade.gold`일 때 일반 결과
  다이얼로그 대신 `_GoldRewardDialog`(private `StatefulWidget`)로 분기합니다. 이 다이얼로그는
  `rewardItems` 3종을 탭 가능한 카드로 나열하고, 카드를 탭할 때마다(같은 카드 중복 탭 허용) 그
  아이템의 선택 횟수가 우상단 "×N" 배지로 올라가며 상단에 "N/목표개수 선택됨" 진행 문구를
  보여줍니다. `rewardCountFor(gameType, RewardGrade.gold)`로 정한 목표 개수를 다 채워야 "확인"
  버튼이 활성화되고(그 전엔 `onPressed: null`이라 탭해도 반응 없음), 눌러야 선택한 아이템들로
  `itemsEarned`를 채운 새 `GameResult`를 만들어 다이얼로그를 닫고 게임 화면을 그 결과와 함께
  종료합니다. 아이템 카드가 3장 + 안내문까지 겹치면 작은 화면에서 다이얼로그 기본 높이를 넘길 수
  있어(다른 세 게임 대비 무화과 퀴즈 만점처럼 콘텐츠가 많은 경우, 위젯 테스트로 실제
  `RenderFlex` 오버플로를 확인했음), `AlertDialog(scrollable: true)`로 넘치는 대신 스크롤되게
  했습니다. `games_screen.dart`의 `_saveEarnedItems()`는 이 gameType 분기와 무관하게 항상
  `GameResult.itemsEarned`를 그대로 순회하므로, 골드 직접 선택 결과도 브론즈/실버와 동일한
  경로로 `InventoryStorage`에 저장됩니다(별도 분기 불필요).

  처음에는 `TokenStorage`/`OnboardingStorage`처럼 고정 키(`pigfig.inventory_items`) 하나로
  저장했는데, 이러면 같은 기기에서 A 계정으로 게임해 아이템을 모은 뒤 로그아웃하고 B 계정으로
  로그인해도 A의 아이템이 그대로 보이는 실제 버그가 있었다(로그아웃/회원탈퇴가 `TokenStorage`만
  지우고 `InventoryStorage`는 건드리지 않았기 때문). 아이템이 게임 탭 표시 외에 다른 기능(케어
  소비 등)에 쓰이는 곳이 없어 서버 모델을 새로 만들 정도는 아니라고 판단해, 대신 저장 키를
  `pigfig.inventory_items.$userId`로 바꿔 **계정별로 분리**했다 — 생성자에서
  `InventoryStorage({required userId})`로 userId를 고정해 받는 방식이라(메서드마다 인자로
  넘기지 않음), `games_screen.dart`는 `initState`에서 `TokenStorage.readUserId()`로 로그인한
  사용자 id를 먼저 조회한 뒤에만 `InventoryStorage` 인스턴스를 만든다(조회 전에는 `_inventory`가
  `null`이라 아이템 획득 콜백은 `_inventory?.addItem()`으로 안전하게 무시된다). userId는
  `AuthRepository.login()`이 로그인 응답의 `id`(accounts 앱의 `LoginView`가 `role`/`email`/
  `nickname`과 함께 내려줌)를 받아 `email`/`nickname`과 동일한 패턴으로 `TokenStorage`에 함께
  저장해둔 값이다. 로그아웃은 계정이 그대로
  남으므로 인벤토리를 지우지 않지만(다음에 같은 계정으로 로그인하면 자연히 그 계정 것만 다시
  보임), 회원탈퇴는 `AuthRepository.deleteAccount()`가 `DELETE /api/accounts/me/` 성공 직후 —
  `TokenStorage.clear()`로 userId를 지우기 전에 — `TokenStorage.readUserId()`로 얻은 값으로
  `InventoryStorage(userId: ...).clear()`를 호출해 그 계정의 로컬 아이템까지 함께 삭제한다.
  `frontend/test/inventory_storage_test.dart`가 userId별 키 분리와 `clear()`가 다른 계정 데이터에
  영향을 주지 않는지를 `SharedPreferences.setMockInitialValues`로 검증한다.

  `mypage_screen.dart`(`AdopterShell`의 네 번째 탭)는 이제 프로필 카드 + 2x2 `ServiceCard` 그리드로
  전면 개편됐습니다(과거엔 세로 리스트 메뉴 + "서포터 등급" 배너였으나 둘 다 제거). `StatelessWidget`
  이던 것도 `StatefulWidget`(`RevalidatableState`)으로 바뀌어, `AdopterShell`이 다른 탭에서 마이
  탭으로 돌아올 때마다 담당 묘목 수를 백그라운드로 재조회합니다. 프로필 카드는 `TokenStorage`에
  캐싱된 닉네임(비어있으면 "입양자"로 대체)/이메일과, `SeedlingRepository.fetchSeedlings()`로 실제
  조회한 "입양 중: N그루"(`StatusBadge`)를 보여줍니다 — 기존에 있던 무화과 진행률 게이지 박스는
  실제 데이터에 대응하는 값이 없어 제거했습니다. 카드 우상단 톱니바퀴 아이콘을 누르면
  `frontend/lib/features/adopter/presentation/account_settings_dialog.dart`의
  `showAccountSettingsDialog()`가 뜹니다 — 닉네임 입력 필드는 `frontend/lib/features/auth/data/
  accounts_repository.dart`의 `AccountsRepository.updateNickname()`으로 실제
  `PATCH /api/accounts/me/`를 호출해 서버에 저장한 뒤 `TokenStorage.saveNickname()`으로 로컬 캐시도
  갱신합니다. 알림 토글 3종(묘목 상태/이상, 오늘의 성장 일지, 수확&배송 일정)은
  `core/storage/notification_preference_storage.dart`의 `NotificationPreferenceStorage`(계정별
  `SharedPreferences` 키, 다른 로컬 storage 클래스와 동일한 컨벤션)에만 저장됩니다 — 서버에
  이 값으로 실제 발송을 필터링하는 로직은 아직 없어서, 다이얼로그에 "아직 실제 알림 종류 제어에는
  반영되지 않아요" 안내 문구를 함께 둡니다. 메뉴 그리드는
  `frontend/lib/shared/widgets/service_card.dart`의 공용 `ServiceCard` 위젯(재배자 마이페이지와
  공유)으로 4개(🎁 수령/기부 선택, 📜 기부 인증서, 🤖 AI 챗봇, 📋 입양 내역서 — 마지막 하나는 이번
  범위 밖이라 탭하면 스낵바만) 구성됩니다. "성장 타임라인"은 하단 탭으로 이미 승격돼 있어 그리드에는
  없습니다. "기부 인증서" 카드는 `/adopter/donation-certificates`(`donation_certificate_list_screen.dart`,
  완료+기부 확정 묘목 목록 — 카드 모드/목록 모드 토글)로 이동하고, 거기서 인증서를 열면 실제 묘목
  데이터로 `DonationCertificateArgs`를 채워 `/adopter/donation-certificate`
  (`donation_certificate_screen.dart`)로 넘깁니다. `pickup_donate_screen.dart`에서 기부처를 선택해
  바로 진입하는 경로도 같은 args를 씁니다(`GrowerCompleteArgs`와 동일한 route-argument 패턴 —
  자세한 동작·이미지 저장/공유는 아래 `donation_certificate_screen.dart` 문단 참고).
  디자인의 점선 테두리(일지 사진 업로드 박스, 기부 인증서 카드)는 Flutter에
  내장 dashed border가 없어 실선으로 근사했습니다. 화면 하단(그리드 밖, 별도 배치)에는
  "로그아웃"(muted 텍스트)과 "회원탈퇴"(더 작은 회색 텍스트)가 있습니다 — 로직은
  `features/auth/presentation/account_actions.dart`의 `confirmLogout()`/`confirmDeleteAccount()`를
  그대로 호출하는데, 이 두 함수는 `AlertDialog` 확인 → `AuthRepository.logout()`(로컬 토큰 삭제만)/
  `deleteAccount()`(`DELETE /api/accounts/me/` 호출 후 토큰 삭제) →
  `pushNamedAndRemoveUntil('/', (route) => false)`로 로그인 화면 이동(뒤로가기로 못 돌아오게
  네비게이션 스택을 전부 비움)까지를 한 번에 처리합니다.

  `GrowerShell`도 이제 홈/일지/환경점검/마이 4탭이라 같은 로그아웃/회원탈퇴 로직을
  `grower_mypage_screen.dart`(마이 탭)에서 그대로 재사용합니다 — 처음엔 마이페이지 탭이 없던
  시절이라 `GrowerDashboardScreen` 앱바에 사람 아이콘+바텀시트로 로그아웃 진입점을 임시로
  넣었었는데(`PigFigAppBar`의 `onProfileTap` 옵션), 마이 탭이 생기면서 중복이라 그 옵션과 바텀시트
  코드는 완전히 제거했습니다. `grower_mypage_screen.dart`도 입양자 마이페이지와 동일하게 프로필
  카드 + 2x2 `ServiceCard` 그리드로 개편됐습니다(과거엔 "📅 나의 재배 활동 보기" 버튼 하나만 있는
  단순한 화면). 프로필 카드는 이메일(백엔드에 프로필 조회 API가 없던 시절 로그인 시점 값을
  `TokenStorage`에 함께 저장해뒀다가 읽는 방식 유지 — 닉네임은 재배자 화면에는 아직 노출하지
  않음) + "담당 묘목 N그루"(`GrowerRepository.fetchSeedlings().length`)를 보여줍니다. 그리드 4개는
  📅 재배 활동 캘린더(`grower_activity_calendar_screen.dart`의 `GrowerActivityCalendarScreen`으로
  push), 🆘 도움 요청하기(바텀시트로 전화/문자 연결), 📊 환경 이상 감지 요약
  (`grower_anomaly_summary_screen.dart`, 신규 — `GrowerRepository.fetchSeedlings()`와
  `SensorRepository.fetchAnomalyHistory()`를 `Future.wait()`로 병렬 조회해 담당 묘목별 이상 건수를
  `GaugeBar`로 시각화하고 최근 발생일을 보여줌, 로딩/에러/빈 목록/데이터 4상태 분기), ❓ FAQ
  (`grower_faq_screen.dart`, 신규 — API 호출 없이 정적 데이터 7문항을 `ExpansionTile` 아코디언으로
  나열)입니다. 재배 활동 캘린더 화면은 묘목별 일지 화면(`grower_diary_screen.dart`)이 새로 작성할
  때만 쓰여서 과거 작성 이력을 전체적으로 돌아볼 방법이 없었던 것을 보완한 월별 달력 화면입니다.
  탭 화면이 아니라 `Navigator.pushNamed`로 진입하는 독립 push 화면이라 `RevalidatableState` 대신
  일반 `State`를 씁니다. `initState`에서 `GrowerRepository.
  fetchSeedlings()`로 담당 묘목 전체를 조회한 뒤, 각 묘목마다 `DiaryRepository.fetchDiaries()`를
  `Future.wait()`로 병렬 호출해 모든 일지를 모으고, `entry.createdAt.toLocal()`을 시분초 없이 자른
  날짜를 키로 `Map<DateTime, List<_DiaryOccurrence>>`에 묶습니다(`created_at`이 UTC라 그대로 자르면
  자정 근처 일지가 실제와 다른 날짜에 찍힐 수 있어 로컬 시각 변환을 먼저 함). 이 맵의 key 집합
  자체가 "일지가 있는 날짜들의 집합" 역할을 겸해서, 달력 각 칸의 점 표시 여부(`containsKey`)와
  선택한 날짜의 요약 카드 목록 조회를 같은 구조 하나로 처리합니다. 날짜를 탭하면 그 날 작성된 일지들을
  묘목 id와 함께 요약 카드로 보여주고(여러 묘목의 일지가 같은 날 섞여 있을 수 있음), 일지가 없으면
  "이 날은 작성한 일지가 없어요"를 보여줍니다. 담당 묘목이 하나도 없으면 달력 대신 안내 문구만
  띄웁니다(다른 화면들과 동일한 로딩/에러/빈 목록/데이터 4상태 분기).

  재배자 화면 전용 글자 크기 조절 기능도 있습니다. `grower_mypage_screen.dart`의 프로필 카드에
  입양자 마이페이지와 같은 톱니바퀴 아이콘을 추가했고(`_ProfileCard`를 `Stack`으로 바꿔 우상단에
  `IconButton` 배치), 탭하면 `grower_settings_dialog.dart`의 `showGrowerSettingsDialog()`가
  작게(1.0, 기존 화면 기본 크기와 동일)/보통(1.15)/크게(1.3) 3단계 버튼 + 실시간 미리보기 텍스트 +
  저장 버튼 모달을 띄웁니다. 배율은 `core/storage/grower_font_scale_storage.dart`의
  `GrowerFontScaleStorage`(`CareInventoryStorage`와 동일한 계정별 `SharedPreferences` 저장 패턴)에
  저장됩니다. 이 프로젝트는 `main.dart`의 `MaterialApp.routes`가 단일 루트 Navigator로 화면을 전부
  등록해(중첩 라우터 없음) `/grower/*` push 화면들이 `GrowerShell`의 자손이 아니라서, `GrowerShell`
  안에만 `MediaQuery` override를 두면 push 화면(완성 신고/일지/재배 활동 캘린더/이상 감지 요약/FAQ
  등)에는 적용되지 않는 문제가 있었습니다 — 그래서 `main.dart`가 `/grower`로 시작하는 라우트 엔트리
  8개 전부를 `grower_font_scale_scope.dart`의 `GrowerFontScaleScope`(저장된 배율을 읽어
  `MediaQuery(textScaler: TextScaler.linear(...))`로 감싸는 위젯)로 개별적으로 감쌉니다. 설정
  모달에서 저장 직후 재진입 없이 바로 반영되도록, `GrowerFontScaleScope.refresh(context)`가
  `context.findAncestorStateOfType()`으로 가장 가까운 조상 scope(=`/grower` 라우트를 감싼
  인스턴스, `GrowerShell`과 그 4탭 전체)를 찾아 저장된 값을 다시 읽게 합니다 — 다른 push 화면들은
  매번 새 라우트 인스턴스가 생성되므로 다음 진입 시 자연히 최신 값을 읽어 별도 갱신이 필요
  없습니다. `flutter build web` + Playwright(크롬 헤드리스, semantics DOM 활성화 후 시맨틱
  텍스트/좌표 클릭 혼용)로 데모 재배자 계정 로그인 → 크게(1.3배) 선택·저장 → 마이/홈(선반 뷰)/
  일지/환경점검/재배 활동 캘린더/FAQ(아코디언 펼침 포함)를 실제로 스크린샷 검증함 — 카드형
  레이아웃이 많은 화면들에서도 텍스트가 줄바꿈될 뿐 overflow(RenderFlex 경고)는 없었고, 마이 탭은
  재진입 없이 즉시 확대 반영되는 것까지 확인했습니다.
- `features/adopter/data/seedling_repository.dart`는 `grower/data/grower_repository.dart`와 동일한
  패턴(같은 `GET /api/seedlings/`, 같은 `Seedling`/`SeedlingStatus` 모양)을 입양자 쪽에도 그대로
  적용한 별도 파일입니다 — 기능이 겹치더라도 feature 간 참조 없이 각 feature가 자기 데이터 계층을
  갖는 이 프로젝트 컨벤션을 따릅니다. 여기에 `pickPrimarySeedling()` 헬퍼가 있는데, 입양자가 여러
  묘목을 가진 경우 홈/성장 타임라인에 보여줄 "대표 묘목"을 고릅니다(재배중인 것 중 가장 최근 시작한
  것 우선, 전부 완료 상태면 가장 최근 완료된 것) — 처음에는 응답의 첫 번째 항목을 그냥 썼다가, 완료된
  #1이 재배중인 #3보다 먼저 와서 홈 화면이 "이미 다 자란" 묘목을 보여주는 문제를 발견해 이 헬퍼로
  고쳤습니다. `home_screen.dart`는 이제 `StatefulWidget`으로 `initState`에서 이 repository를 호출해
  로딩/에러/(묘목 없음→ 입양 유도 CTA)/데이터 4가지 상태를 분기하며, 물주기 등 케어 게이지 3종은
  실제 묘목 데이터와 무관하게 동작합니다(로컬 영속화만 하며 서버에는 연동하지 않음, 위 케어 화면
  문단 참고).
- `growth_timeline_screen.dart`는 `AdopterShell`의 세 번째 탭("타임라인", 홈→게임→타임라인→마이
  순서)입니다 — 원래 마이페이지의 "성장 타임라인" 메뉴를 눌러야 들어갈 수 있었는데, 자주 확인하는
  화면이라 하단 탭으로 승격했습니다(마이페이지가 이후 리스트 메뉴 자체를 그리드로 개편하면서 이제는
  애초에 중복될 리스트 항목도 없습니다). 앱바는 탭 화면이라 `closeLabel: '닫기'`(누르면 pop)를
  주지 않고 인자 없는 `PigFigAppBar()`를 씁니다 — 탭 화면은 애초에 push되는 게 아니라
  `IndexedStack`으로 항상 트리에 떠 있어서 "닫을" 대상이 없기 때문입니다(한때 그 자리에
  `showNotificationBell: true`로 알림 종 아이콘을 뒀으나, onTap도 실제 알림 연동도 없는 순수
  장식이라 2026-08-26에 `PigFigAppBar`에서 파라미터·렌더링 블록·8개 화면 호출부까지 통째로
  제거했습니다 — 이제 `PigFigAppBar`는 로고+타이틀에 선택적 `closeLabel`만 있고, 알림 종이 있던
  자리는 `Spacer()`로 비워집니다). `StatefulWidget`으로
  `seedling_repository.dart`로 대표 묘목을 고른 뒤 `features/adopter/data/diary_repository.dart`
  의 `fetchDiaries()`로 `GET /api/diary/{seedling_id}/`를 호출합니다. 실제 `Diary` 모델에는 성장
  단계·키·잎 개수 필드가 없어(그건 애초에 mock이 지어낸 값) 카드는 날짜 + `content` 본문 +
  (있으면) `yolo_status_tag` 배지로 단순화됐고, `illustration`(Gemini 변환)이 있으면 그것을,
  없으면(mock 모드거나 변환 실패) 원본 `photo`를 `Image.network()`로 보여주며, 둘 다 없으면 기존
  "✨ 일러스트 변환" placeholder를 보여줍니다(`imageUrl = entry.illustrationUrl ?? entry.photoUrl`).
  응답 순서가 보장되지 않아 클라이언트에서 `created_at` 내림차순으로 정렬합니다. 각 카드는
  `GestureDetector`로 감싸 탭하면 `Navigator.pushNamed('/adopter/diary-detail', arguments:
  DiaryDetailArgs(...))`로 `diary_detail_screen.dart`의 `DiaryDetailScreen` 풀스크린 화면으로
  이동합니다 — 한때 "탭 목록 위에 살짝 띄우는 느낌"이 낫다고 판단해 중앙 카드 모달
  (`showDiaryDetailDialog()`, 너비 82%/최대 높이 80% 고정)로 바꾼 적이 있었는데, 재배자가 실제로
  찍은 세로로 긴 사진이 그 고정 비율 박스 안에서 `BoxFit.cover`로 위아래가 잘려 보이는 문제와
  다운로드 버튼을 넣을 자리가 마땅치 않은 문제가 겹쳐 다시 풀스크린 라우트(`DiaryDetailArgs`
  route-argument, `GrowerCompleteArgs`/`DonationCertificateArgs`와 동일하게 화면 자체는
  `ModalRoute.of(context)!.settings.arguments as DiaryDetailArgs`로 인자를 읽는 패턴)로 되돌렸습니다.
  이미지 영역은 화면 높이의 48%인 `SizedBox` 안에 `InteractiveViewer` + `Image.network(fit:
  BoxFit.contain)`을 넣어, 세로로 길든 가로로 길든 정사각형이든 잘리지 않고 레터박스로 전체가
  보이며 핀치 줌으로 확대해 볼 수 있습니다. 앱바는 다른 풀스크린 push 화면과 동일하게
  `PigFigAppBar(closeLabel: '닫기')`를 그대로 재사용합니다(임의의 액션 아이콘 슬롯이 없어 다운로드
  버튼은 앱바가 아니라 이미지/본문 아래에 배치, 아래 참고). `yolo_status_tag` 배지는 여전히 카드
  목록에만 남아 있고 상세 화면에는 넣지 않았습니다.

  화면에 표시된 이미지(일러스트 우선, 없으면 원본 사진 — 카드와 동일한 `illustration ?? photo`
  우선순위)가 있으면 그 아래에 `저장 📥` / `공유 📤` 두 버튼(`PigFigButton.outline`)이
  뜹니다(사진 자체가 없어 placeholder만 보이는 일지는 버튼을 아예 숨김). 원본 사진과 일러스트가
  둘 다 있어도 저장/공유 대상은 "지금 화면에 보이는 것" 하나뿐입니다 — 비개발자 사용자가
  헷갈리지 않도록 선택지를 늘리지 않기로 결정했습니다. 이미지 영역(스와이프로 프레임을 고르는
  `PhotoFrameCarousel`)의 현재 프레임을 `RepaintBoundary`로 캡처해 PNG 바이트를 얻은 뒤
  (`captureCurrentFrame()` — `index == _frameIndex`인 페이지에만 boundary를 씌워 스와이프
  애니메이션이 캡처에 섞이지 않음), 저장 버튼(`저장 📥`)은
  `core/download/image_downloader.dart`의 `saveImageBytes(bytes, filename)`, 공유 버튼
  (`공유 📤`)은 `share_plus`의 `SharePlus.instance.share(ShareParams(files: [XFile.fromData(...)]))`로
  넘깁니다(둘은 서로 로딩 중이면 상대 버튼을 비활성화. 파일명은 `diary_detail_screen.dart`의
  `buildDiaryImageFilename(diaryId, createdAt)`이 만드는 `pigfig_diary_{id}_{yyyyMMdd}.png`).
  `saveImageBytes`는 웹과 모바일에서 저장 방식이 완전히
  달라 `dart.library.io`/`dart.library.html` 조건부 export(`src/image_downloader_io.dart`/
  `src/image_downloader_web.dart`, 두 조건 중 어느 것도 안 맞을 때를 위한
  `src/image_downloader_stub.dart`는 사실상 선택될 일이 없는 더미)로 분기합니다 — 모바일은
  `gal` 패키지(`pubspec.yaml`에 신규 추가)로 `Gal.hasAccess()`/`requestAccess()` 확인 후
  `Gal.putImageBytes()`로 갤러리(앨범명 "Pig.Fig.")에 저장하고, 웹은 `package:web`(`dart:html`은
  deprecated라 쓰지 않음) + `dart:js_interop`으로 Blob URL을 가진 `<a download>` 앵커를 만들어
  클릭시켜 브라우저 다운로드를 트리거합니다. Android는 `gal`이 API 29+에서는 권한이 필요 없지만
  `minSdkVersion 24`를 지원하기 위해 `AndroidManifest.xml`에
  `WRITE_EXTERNAL_STORAGE`(`maxSdkVersion="28"`)를 추가했습니다. 저장 중에는 버튼이
  `PigFigButton`의 내장 `loading` 상태로 스피너를 보여주고, 성공/실패 모두 스낵바로 안내합니다
  (실패해도 일지 열람 자체는 그대로 유지 — vision/sensor의 폴백과 같은 "핵심 기능과 부가 기능을
  분리"하는 톤). Windows 데스크톱(`flutter run -d windows`)에서도 `gal`이 이론적으로는 지원한다고
  문서화돼 있지만 이 프로젝트는 실기기로 검증하지 않았습니다 — 실패하면 예외가 잡혀 스낵바로만
  안내되고 크래시하지 않습니다.
- `donation_certificate_screen.dart`의 `DonationCertificateCard`(단독 라우트
  `DonationCertificateScreen`과 `donation_certificate_list_screen.dart`의 카드 모드 세로
  `PageView` 양쪽에서 재사용)의 "이미지 저장"/"공유하기" 버튼은 이제 실제로 동작합니다 —
  `diary_detail_screen.dart`와 같은 "화면에 보이는 그대로 캡처 → `saveImageBytes` / `SharePlus`"
  패턴이지만, 캐러셀이 아니라 고정 카드 하나라 캡처 위임 대신 카드가 인증서 콘텐츠(`_CertificateContent`
  로 분리)를 직접 `RepaintBoundary(key:)`로 감싸고 `photo_frame_carousel.dart`의
  `captureCurrentFrame()`과 같은 방식(`RenderRepaintBoundary.toImage` → PNG)으로 캡처합니다.
  이를 위해 `StatelessWidget` → `StatefulWidget`으로 바꿔 `_downloading`/`_sharing` 로딩 상태
  (서로 로딩 중이면 상대 버튼 비활성, 각 버튼은 로딩 시 라벨 대신 `PigFigButton`과 같은 스피너)를
  갖고, `DonationCertificateArgs`에 `seedlingId`(int) 필드를 새로 추가했습니다 — 파일명은
  `buildCertificateImageFilename(seedlingId)` → `pigfig_certificate_{id}.png`
  (`buildDiaryImageFilename`과 같은 결의 순수 함수). 호출부 3곳(`donation_certificate_list_screen.dart`
  의 `_openCertificate`/`_buildCardMode`, `pickup_donate_screen.dart`의 `_submit`)이 전부
  `seedling.id`를 넘깁니다. 스낵바 톤은 diary_detail 그대로 — 저장 성공 `인증서를 저장했어요 📥`,
  저장 실패 `인증서 저장에 실패했어요...`, 공유 취소(`ShareResultStatus.dismissed`)는 조용히,
  공유 실패 `공유에 실패했어요...`(핵심/부가 기능 분리). 카드 모드 `PageView`에서는
  `DonationCertificateCard`에 `key: ValueKey(seedling.id)`를 줘, 세로 스와이프로 페이지 element가
  재사용될 때 이전 묘목의 로딩 상태가 새지 않게 합니다. `RepaintBoundary`가 감싸는 outer
  `Container`의 `boxShadow`는 레이아웃 바깥으로 번져 캡처 PNG에서는 소프트 섀도만 잘려 나옵니다
  (카드 본체·핑크 테두리·텍스트는 온전). 이번엔 복붙으로 갔고, `_download`/`_share`의 저장·공유·
  스낵바 본문을 `core/download/`의 공용 헬퍼로 뽑아 두 화면이 공유하는 리팩토링은 후속으로 남겼습니다.
- `grower_diary_screen.dart`는 이제 탭 진입 시 `GrowerRepository.fetchSeedlings()`로 담당 묘목
  목록을 불러와 상단에 선택 칩으로 보여줍니다(재배중인 묘목이 있으면 자동 선택) — 이전에는 이 화면이
  어떤 묘목에 대한 일지인지 알 방법이 전혀 없었기 때문에 실제 연동을 위해 꼭 필요했던 추가입니다.
  "성장 단계" 칩은 `Diary` 모델에 대응 필드가 없어 여전히 로컬 장식으로만 남습니다. "사진 추가하기"는
  `image_picker`(웹 포함 크로스플랫폼) 파일 선택기를 열어 바이트로 읽어 미리보기를 보여주고,
  "입양자에게 전달하기"는 `features/grower/data/diary_repository.dart`의 `createDiary()`로
  `POST /api/diary/`를 호출합니다 — 사진이 있으면 `multipart/form-data`(`ApiClient.postMultipart()`,
  신규 추가), 없으면 텍스트 필드만 보냅니다. 성공 시 폼을 초기화하고 스낵바를 띄웁니다.
- `grower_diary_list_screen.dart`의 일지 카드(`_DiaryCard`)에는 삭제 아이콘(`Icons.delete_outline`)이
  있어, 탭하면 `account_actions.dart`의 `confirmDeleteAccount()`와 같은 톤의 확인 다이얼로그를 띄운
  뒤 확인한 경우에만 `DiaryRepository.deleteDiary()`(`DELETE /api/diary/entry/{id}/`, `ApiClient.
  delete()` 재사용)를 호출합니다. 성공하면 `_entries`에서 즉시 제거 + "일지를 삭제했어요 🗑️" 스낵바,
  실패하면 서버 메시지를 스낵바로 안내합니다(`grower_diary_write_screen.dart` `_submit()`의 전송
  실패 스낵바와 같은 방식). 완료된 묘목의 일지는 백엔드가 400으로 막으므로 `GrowerDiaryListArgs.
  isCompleted`(호출부 `grower_diary_tab_screen.dart`/`grower_seedling_analysis_screen.dart` 두 곳이
  `SeedlingStatus`에서 채워 전달)가 true면 삭제 아이콘 자체를 렌더하지 않습니다.
- `grower_sensor_screen.dart`도 `grower_diary_screen.dart`와 동일한 묘목 선택 칩 패턴을 씁니다
  (`GrowerRepository.fetchSeedlings()` 재사용). "기록 저장하기"는 `features/grower/data/
  sensor_repository.dart`의 `createSensorData()`로 `POST /api/sensor/data/`를 호출하고, 응답의
  `is_anomaly`/`gemini_diagnosis`를 그대로 "⚠️ 이상 감지"(빨강)/"✅ 정상이에요"(초록) 박스에
  표시합니다 — 온도/습도/조도 세 값 중 어느 필드가 문제인지는 응답에 없어서(위 백엔드 섹션 참고)
  각 수치 행의 "정상/주의" 배지는 없앴고, 전체 판정만 보여줍니다. 저장 성공 시 같은 묘목의
  `GET /api/sensor/anomaly/{seedling_id}/`를 다시 호출해 화면 하단 "최근 이상 이력"(최대 3건,
  `recorded_at` 내림차순)도 함께 갱신합니다. `GrowerShell`이 `IndexedStack`으로 바뀐 뒤로는 다른
  탭으로 이동했다가 돌아와도 입력값(스테퍼로 조정한 온도/습도/조도)이 유지됩니다 — 이전에는
  탭 전환마다 State가 재생성돼 초기값으로 리셋됐었습니다.
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
- 반복되는 작업 절차(Flutter 화면 작업, API 연동, 백엔드 API 작업)는 Agent Skill로 정리되어
  `.claude/skills/<이름>/SKILL.md`에 있습니다(Claude Code가 실제로 인식하는 위치이며, 원본은
  `.agents/skills/`에도 동일하게 유지합니다 — `.claude/`는 보통 gitignore 대상이라 `.gitignore`에
  `!.claude/skills/` 예외를 추가해뒀습니다).

## 현재 개발 상태

- 백엔드: 7개 앱(accounts/seedlings/diary/sensor/vision/chatbot/notifications) 모두 구현 완료
- vision의 YOLOv8-cls 추론은 `backend/vision/weights/best.pt`(healthy/infected 이진 분류, val
  top1 96.1%, 2.9MB로 저장소에 커밋됨)로 실제 연동 완료(위 "비전 분석" 참고, 가중치
  없는 환경은 mock으로 자동 폴백). notifications는 `FIREBASE_CREDENTIALS_PATH`/
  `FIREBASE_CREDENTIALS_JSON`이 둘 다 미설정이면 mock 발송으로 대체되어(신규 클론 등 키 없는
  환경에서도 동작), 로컬 `.env`에는 이미 실제 서비스 계정 파일(`FIREBASE_CREDENTIALS_PATH=
  firebase-adminsdk.json`)이 설정돼 있어 로컬 개발 환경 자체는 실제 발송 모드로 동작 중.
  `GEMINI_API_KEY`는 이제 로컬 `.env`에 실제 값이 설정돼
  있고, `sensor/anomaly.py`의 `gemini_diagnosis`는 실제 Gemini API(`gemini-2.5-flash`)로 진단 문장을
  생성하도록 연동 완료(위 "센서 데이터 파이프라인" 참고). `chatbot` 앱도 `gemini-2.5-flash`(LLM)/
  `models/gemini-embedding-001`(임베딩)로 모델명을 갱신하고 `ChatbotAskView`에 예외 처리(Gemini
  호출 실패 시 500 대신 안내 메시지로 폴백)를 추가해 실키로 실제 Gemini RAG 응답이 오는 것까지
  검증 완료(위 "RAG 챗봇 파이프라인" 참고). **2026-08-26**: `chatbot` RAG가 배포 환경에서 항상
  폴백만 내던 원인이 `requirements.txt`에 `chromadb`가 빠진 것으로 밝혀져 `chromadb==1.5.9`를
  추가하고(로컬은 어쩌다 수동 설치돼 있어 정상 동작했음), 커스텀 프롬프트로 매뉴얼 밖 질문도
  '무화과 박사 피그' 톤으로 답하도록 고쳤으며(위 "RAG 챗봇 파이프라인" 참고), 로컬 서버 + curl로
  매뉴얼 질문 1개(근거 기반 답변) + 매뉴얼 밖 질문 4개(거부 없이 답변) 실 Gemini 응답을 재확인함.
  Render 반영에는 **`requirements.txt` 커밋 후 재배포가 필요**(Render는 배포 시 `pip install -r
  requirements.txt`를 다시 돌림). `diary`의 사진 → 일러스트 변환(`gemini-2.5-flash-image`,
  위 "일지 사진 → 일러스트 변환" 참고)은 프롬프트를 동화풍 스타일 키워드로 강화까지 마쳤지만, 코드/
  폴백 경로만 실서버로 검증됐을 뿐 실제 변환 성공 사례는 아직 확인하지 못했음 — 한동안 이 프로젝트
  API 키가 월간 지출 한도(`429 ... exceeded its monthly spending cap`)로 모든 Gemini 호출이 막혀
  있었으나, 2026-08-26 기준 텍스트 모델(`gemini-2.5-flash`) 호출은 위 chatbot 재검증에서 정상 동작
  확인 — 즉 한도는 풀린 것으로 보이나 이미지 생성 모델(`gemini-2.5-flash-image`)과 `sensor`의
  `gemini_diagnosis`는 이번에 따로 재확인하지 않았으므로, 일러스트 변환은 여전히 별도 재검증 필요
- DB(MySQL) 연결 및 `migrate` 완료 (`.env`에 실제 접속 정보 필요)
- 프론트엔드: 스플래시(`/splash`, `Hero` 전환) → 로그인, 입양자로 로그인 성공 시마다(1회성이 아님)
  온보딩(3장) 노출, 입양자 플로우(닉네임 입력 포함 회원가입/로그인/홈·게임·타임라인·마이페이지 4탭
  (이 순서)/무화과 입양(결제)/케어 3종/수령·기부 선택/기부 인증서/AI 챗봇), 재배자 플로우(홈·일지·
  환경점검·마이 4탭 + 묘목 완성 신고) 모두 구현됨. `AdopterShell`/`GrowerShell` 둘 다 `IndexedStack`
  으로 탭 상태를 보존합니다. 입양자/재배자 마이페이지는 2x2 `ServiceCard` 그리드(재배자는 재배 활동
  캘린더/도움 요청하기/환경 이상 감지 요약/FAQ, 입양자는 수령·기부 선택/기부 인증서/AI 챗봇/입양
  내역서)로 개편되었고, 톱니바퀴 아이콘의 `AccountSettingsDialog`로 닉네임을 실제 서버에 저장할 수
  있습니다. accounts(회원가입·로그인·로그아웃·프로필 조회/수정·회원탈퇴, Android는 FCM 토큰 등록도
  함께), seedlings(`GET /api/seedlings/` 목록
  조회, `POST /api/seedlings/` 입양(mock 결제 후 생성, 재배자 자동 배정), `PATCH /api/seedlings/{id}/
  complete/` 완성 신고), diary(`POST /api/diary/` 작성, `GET /api/diary/{seedling_id}/` 조회,
  `DELETE /api/diary/entry/{id}/` 재배자 본인 일지 삭제 — 완료된 묘목의 일지는 400으로 차단),
  vision(`POST /api/vision/analyze/`, 일지 사진 업로드 후 자동 분석), sensor
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
  보존됨; 무화과 입양(결제) 플로우는 로그인 → 입양 → 결제 → 홈 반영 → grower 자동 배정까지
  실기기(크롬)로 확인됨). 재배자 대시보드·입양자 홈·성장 타임라인·재배자 일지/환경 점검 작성·묘목
  입양·수령/기부 선택·마이페이지 프로필(닉네임 조회·수정, `GET`/`PATCH /api/accounts/me/`)이 모두
  실제 데이터를 씀. 케어 게이지 3종(물주기/영양제
  2종은 `CareStorage`로 로컬 영속화, 햇빛은 완료 개념이 없어 제외)은 계획서상 "실제
  재배와 분리된 미션형 연출"이라는 의도적 설계라 서버에는 연동하지 않음(위 "케어 화면" 문단 참고).
  물주기/영양제/돼지먹이 횟수제 전환(`CareInventoryStorage`), 나무 방치 상태(`TreeStatus`), 돼지
  출현·먹이 주기 케어(`PigFeedCareScreen`)·홈 화면 퇴장 애니메이션·보유 개수 배지까지 모두 구현
  완료. 게임 보상 → `CareInventoryStorage`로 이어지는 지급 경로(`careItemTypeFor`)도 연동
  완료되어 `pigFeed`를 포함한 3종 모두 게임으로 실제로 모을 수 있음(위 "케어 아이템" 문단 참고)
- 게임 탭의 실제 게임 4종(돼지 풍선 터뜨리기/무화과 퀴즈/해충 잡기/물주기 타이밍)은 모두 플레이
  가능하며, 점수는 100점 클램프·클리어 기준 50점으로 통일되고 50/70/90점 구간에 따라
  브론즈/실버/골드 등급(`computeRewardGrade`)이 매겨져 등급 배지와 함께 결과 다이얼로그에
  표시됨(위 "게임" 문단 참고). 브론즈·실버는 등급별 개수만큼 공용 아이템 풀에서 무작위 지급되고,
  골드는 결과 다이얼로그 안에서 사용자가 목표 개수만큼 직접 아이템을 골라 지급받는 UI까지 구현
  완료됨(`GameScaffold._GoldRewardDialog`). 획득 아이템은 `InventoryStorage`에 로컬로만 누적됨
  (서버 저장 없음, `pigfig.inventory_items.$userId`로 계정별 키 분리 완료 — 로그아웃 시 유지,
  회원탈퇴 시 삭제). vision은 백엔드
  실제 추론 + 재배자 일지 작성 시 프론트엔드 자동 호출까지 연동 완료. FCM은 Android 클라이언트가
  로그인 시 실제 토큰을 등록하도록 연동 완료(다른 플랫폼은 미지원)
- `PATCH /api/seedlings/{id}/pickup-donate/`(완성 묘목 수령/기부 선택)는 백엔드(models/
  serializers/views/urls + happy path·예외 케이스 테스트 15개 전부 통과)와 프론트엔드
  (`pickup_donate_screen.dart`) 모두 연동 완료(위 "완성 묘목 수령/기부 선택" 참고). `flutter
  analyze`/`flutter test` 통과 확인, 실행 중인 백엔드에 데모 계정으로 로그인해 PATCH 왕복(기부
  선택 → 수령으로 변경)까지 HTTP로 직접 검증함 — Chrome에서 화면을 직접 조작하는 수동 시연 확인은
  아직 별도로 하지 않았으므로 실제 배포/시연 전에 한 번 더 확인 권장
- 기부 인증서 카드(`donation_certificate_screen.dart`의 `DonationCertificateCard`)의 "이미지
  저장"/"공유하기"가 mock(`_showComingSoon`)에서 실제 동작으로 전환 완료(위 "프론트엔드 구조"의
  `donation_certificate_screen.dart` 문단 참고 — `RepaintBoundary` 캡처 + `saveImageBytes` /
  `SharePlus`, `diary_detail_screen.dart` 패턴 복붙). `flutter analyze` 0 이슈, 신규
  `test/donation_certificate_screen_test.dart`(위젯 렌더 + `buildCertificateImageFilename` 단위)
  포함 `flutter test` 통과(Winsock 플레이크는 파일 단위 재실행). `flutter build web` + Playwright
  헤드리스 크롬으로 데모 입양자 `dummy2@demo.com`(묘목 #4 완료·기부) 로그인 → 마이 → 기부 인증서
  진입 후, 카드 모드와 단독 라우트(목록형 → 카드 탭) 양쪽에서 "이미지 저장" 탭 시 브라우저 다운로드
  (`pigfig_certificate_4.png`, 유효한 PNG로 인증서 카드 이미지가 담김) + "인증서를 저장했어요 📥"
  스낵바, "공유하기" 탭 시 헤드리스 크롬은 `navigator.share`가 없어 "공유에 실패했어요..." 스낵바로
  우아하게 폴백(크래시 없음)까지 스크린샷 검증함
- 재배자 화면 전용 글자 크기 조절(작게/보통/크게, 위 "재배 활동 캘린더" 문단 아래 참고)은 프론트엔드
  전용 기능(백엔드 변경 없음)으로 완료. `flutter analyze`/`flutter test` 통과, `flutter build web` +
  Playwright 헤드리스 크롬으로 데모 재배자 계정 로그인 → 설정 모달에서 크게(1.3배) 선택·저장 →
  마이/홈(선반 뷰)/일지/환경점검/재배 활동 캘린더/FAQ(아코디언 펼침 포함) 스크린샷 검증까지 마침 —
  카드형 레이아웃이 밀집된 화면들에서도 overflow 없이 텍스트가 줄바꿈됨을 확인했고, 마이 탭은 저장
  즉시(재진입 없이) 확대 반영됨을 확인. 이 검증 중 별개로 로컬 개발 DB에 diary 앱의
  `0003_diary_growth_stage` 마이그레이션이 아직 적용되지 않아 `GET /api/diary/{id}/`가 500을
  내는 것을 발견함(`Unknown column 'diary_diary.growth_stage'`) — 이번 작업과 무관한 기존 이슈라
  손대지 않았으며, `backend/`에서 `python manage.py migrate`만 실행하면 해결됨(다음 세션이 이
  화면들에서 원인 불명의 500/빈 목록을 마주치면 먼저 확인할 것).