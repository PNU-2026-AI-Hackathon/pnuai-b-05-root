# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Claude Code가 이 저장소에서 작업할 때 매 세션마다 참조하는 파일입니다.

## 프로젝트 개요

**Pig.Fig.** — 도심 유휴공간 기반 무화과 대리재배 모바일 플랫폼.
입양자(adopter)가 무화과 묘목을 입양하면, 재배자(grower)가 도심 유휴공간에서 실제로 키워주고
입양자는 앱을 통해 생육 과정을 지켜보다가 다 자란 무화과를 수령하거나 기부할 수 있는 서비스입니다.

## 기술 스택

- **프론트엔드**: Flutter (아직 미착수)
- **백엔드**: Django 6.0.7 + Django REST Framework 3.17.1 (djangorestframework-simplejwt로 JWT 인증)
- **DB**: MySQL 8.0
- **비전 분석**: YOLOv8 (생육 상태/이상 탐지) — 앱 스캐폴딩만 존재, 미구현
- **시계열 예측**: Prophet — 센서 이상 감지에 이미 사용 중 (`sensor/anomaly.py`)
- **챗봇**: LangChain RAG + Gemini API — 앱 스캐폴딩만 존재, 미구현
- **IoT 연동**: MQTT (paho-mqtt) — 센서 데이터 수집 (`sensor/mqtt_client.py`)
- **푸시 알림**: FCM (Firebase Cloud Messaging) — 앱 스캐폴딩만 존재, 미구현

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

## 백엔드 앱 구성 및 구현 상태

`backend/` 아래 다음 7개 Django 앱으로 구성됩니다. **accounts / seedlings / sensor만 구현되어 있고**,
나머지는 `models.py`/`views.py`가 비어있는 스캐폴딩 상태입니다 (`DB_SCHEMA.md`, `DESIGN.md`에 설계만 정의됨).

- `accounts` — 사용자(입양자/재배자) 인증 및 계정 관리 (구현됨)
- `seedlings` — 묘목 입양/재배 상태 관리 (구현됨)
- `sensor` — IoT 센서 데이터(온습도, 조도) 수집 + Prophet 이상 감지 (구현됨)
- `diary` — 재배 일지 (사진, 생육 기록) — 스캐폴딩만 존재
- `vision` — YOLOv8 기반 이미지 분석 — 스캐폴딩만 존재
- `chatbot` — LangChain RAG + Gemini 기반 챗봇 — 스캐폴딩만 존재
- `notifications` — FCM 푸시 알림 — 스캐폴딩만 존재

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

### URL 라우팅
루트 `config/urls.py`가 앱마다 `/api/<앱명>/` prefix로 각 앱의 `urls.py`를 include합니다
(예: `/api/sensor/` → `sensor/urls.py`). 새 앱도 이 컨벤션을 따릅니다.

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

## 현재 개발 상태

- 백엔드: accounts/seedlings/sensor 구현 완료, diary/vision/chatbot/notifications는 스캐폴딩만 존재
- DB(MySQL)는 아직 미연결 — `.env`에 실제 접속 정보 입력 및 `migrate` 필요
- 프론트엔드(Flutter)는 아직 미착수
