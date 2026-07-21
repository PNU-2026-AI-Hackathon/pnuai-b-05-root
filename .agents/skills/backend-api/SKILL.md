---
name: backend-api
description: Pig.Fig. Django 백엔드에서 새 API를 추가하거나 기존 API를 수정할 때 따르는 표준 절차(AGENTS.md 요약을 절차화). models→serializers→views→urls 순서, view 내 명시적 권한 체크 패턴, 외부 API(Gemini 등) 폴백 처리, 테스트 작성 규칙을 다룬다. "이 앱에 API 추가해줘", "이 엔드포인트 수정해줘" 같은 요청에 사용한다.
---

# Django API 작업 (Pig.Fig.)

작업 전 [AGENTS.md](../../../AGENTS.md)와 [CLAUDE.md](../../../CLAUDE.md)의 "아키텍처" 섹션을 참고한다.
이 스킬은 반복되는 절차만 정리한 것이고, 두 문서가 원본이다.

## 1. 작업 순서: models → serializers → views → urls

새 API는 반드시 이 순서로 만든다. 모델 변경 시:

```bash
cd backend
python manage.py makemigrations <app명>   # 마이그레이션은 이 명령으로만 생성
```

생성된 마이그레이션 파일은 직접 편집하지 않는다.

serializer가 필요 없는 경우도 있다(예: `AccountDeleteView`처럼 요청 바디도 없고 응답도 단순 메시지뿐인
엔드포인트, 또는 `SeedlingCompleteView`처럼 PATCH 입력을 받지 않고 서버 쪽 로직만 도는 엔드포인트) —
그럴 땐 억지로 빈 serializer를 만들지 말고 view에서 바로 처리한다. 응답 직렬화가 필요하면 기존
`XSerializer(instance).data`를 그대로 쓴다.

## 2. 권한 체크: permission class 대신 view 안에서 명시적으로

이 프로젝트는 DRF 오브젝트 레벨 permission class를 쓰지 않는다. 대신 `perform_create`/`get_queryset`/
`patch`/`delete` 안에서 `request.user.role`과 관련 FK(`seedling.adopter_id`, `seedling.grower_id` 등)를
직접 비교해 안 맞으면 `PermissionDenied`를 raise한다. 기준 패턴은 `sensor/views.py`:

```python
class SensorDataCreateView(CreateAPIView):
    permission_classes = [IsAuthenticated]  # 인증 여부만 여기서, 역할/소유권은 아래서

    def perform_create(self, serializer):
        user = self.request.user
        if user.role != User.Role.GROWER:
            raise PermissionDenied('재배자만 센서 데이터를 등록할 수 있습니다.')
        seedling = serializer.validated_data['seedling']
        if seedling.grower_id != user.pk:
            raise PermissionDenied('본인이 담당하는 묘목에만 센서 데이터를 등록할 수 있습니다.')
        ...
```

새 view를 만들 때도 `Seedling.adopter`/`Seedling.grower` 기준으로 동일한 명시적 체크를 따른다. 본인
계정만 다루는 엔드포인트(예: 회원탈퇴)는 별도 소유권 체크 없이 `request.user`를 그대로 쓰면 된다.

## 3. 외부 API(Gemini 등) 호출은 반드시 폴백 처리

`sensor/anomaly.py`의 `build_diagnosis_text()`, `chatbot/views.py`의 `ChatbotAskView`가 기준 패턴이다:

```python
if settings.GEMINI_API_KEY:
    try:
        return _call_real_api(...)
    except Exception:
        pass  # 또는 폴백 값으로 대체
return _static_fallback(...)
```

- `GEMINI_API_KEY`가 비어 있으면(로컬 기본값) 아예 호출하지 않고 정적 응답/mock으로 대체 — API 키
  없이도 로컬 개발이 가능해야 한다.
- 키가 있어도 호출이 실패하면(네트워크 오류, 타임아웃, 모델 폐지로 인한 404 등) `except Exception`으로
  폭넓게 잡아 500을 그대로 노출하지 않고 안내 메시지/정적 템플릿으로 폴백한다.
- 타임아웃을 반드시 지정한다(`ChatGoogleGenerativeAI(..., timeout=...)`).
- 모델명이 실제로 사용 가능한지 의심되면(과거 `gemini-1.5-flash`, `models/embedding-001`이 이 프로젝트
  키에서 폐지되어 404였던 사례가 있음) `google.genai.Client(api_key=...).models.list()`로 먼저
  확인한다 — 문서 대신 실제 API로 검증한다.

## 4. 테스트

- `views.py`를 테스트 없이 완성 상태로 두지 않는다. 최소 happy path 하나는 반드시 포함한다.
- 권한 체크가 있으면 "거부되는 케이스"(미인증, 잘못된 role, 남의 묘목)도 각각 테스트한다.
- 외부 API를 부르는 로직은 `@override_settings(GEMINI_API_KEY='')`로 폴백 경로를 네트워크 호출 없이
  고정하고, `unittest.mock.patch`로 "키 있을 때 성공"/"키 있어도 호출 실패 시 폴백" 두 경로를 각각
  검증한다(`sensor/tests.py`, `chatbot/tests.py` 참고). 실키로 실제 호출을 검증하고 싶으면 별도로
  스크립트를 짜서 수동 실행하고, `manage.py test`에는 포함하지 않는다(테스트 스위트는 항상 네트워크
  없이 통과해야 함).

```bash
python manage.py test <앱명>
python manage.py test <앱명>.tests.<클래스>.<메서드>   # 단일 테스트
python manage.py check
```

## 5. 응답/그 외 규칙

- API 응답은 항상 DRF `Response`(`django.http.JsonResponse` 금지).
- REST 경로는 `/api/<앱명>/` prefix.
- `.env`는 직접 수정하지 않는다. 새 환경변수는 `.env.example`에 추가하고 실제 값은 사용자에게 요청.
- 완료 후 `DESIGN.md`의 API 표에도 새 엔드포인트를 한 줄 추가해 문서를 맞춘다.
