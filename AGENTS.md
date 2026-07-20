# AGENTS.md

Claude Code가 이 저장소에서 코드를 생성/수정할 때 반드시 지켜야 할 행동 규칙입니다.

## 작업 전 필수 참조

코드를 생성하기 전에 반드시 다음 문서를 먼저 참조합니다.

1. [CLAUDE.md](CLAUDE.md) — 프로젝트 개요, 기술스택, 개발 규칙
2. [DB_SCHEMA.md](DB_SCHEMA.md) — 테이블/모델 설계
3. [DESIGN.md](DESIGN.md) — 서비스 플로우, API 설계

## 새 API 작업 순서

새로운 API를 만들 때는 반드시 다음 순서로 작업합니다.

1. `models.py`
2. `serializers.py`
3. `views.py`
4. `urls.py`

## 금지 사항

- `.env` 파일을 직접 수정하지 않습니다. 필요한 환경변수는 `.env.example`에 추가하고, 실제 값 입력은 사용자에게 요청합니다.
- 마이그레이션 파일(`migrations/*.py`)은 `makemigrations`로 자동 생성하되, 생성된 내용을 직접 편집하지 않습니다.
- 테스트 없이 `views.py`를 완성 상태로 두지 않습니다. 최소한 happy path(정상 케이스) 테스트를 포함합니다.

## 응답 형식

모든 API 응답은 항상 DRF의 `Response` 객체를 사용합니다 (`django.http.JsonResponse` 등 사용 금지).

## 출력 언어
- 작업 완료 요약, 설계 노트, 참고 사항 등 모든 텍스트 출력은 **한국어**로 작성합니다.
