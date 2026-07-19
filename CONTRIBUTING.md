# 🐷🌿 Pig.Fig. 협업 가이드

> 팀 루트(Root)의 브랜치 · 커밋 · PR 규칙입니다.

---

## 0. 처음 시작하기 (최초 1회)

```bash
git clone https://github.com/PNU-2026-AI-Hackathon/pnuai-b-05-root.git
cd pnuai-b-05-root/backend
python -m venv venv
venv\Scripts\activate        # Windows
pip install -r requirements.txt
cp .env.example .env         # 실제 값 입력 필요
python manage.py migrate
python manage.py runserver
```

---

## 1. 황금률 세 가지

1. **`main`에 직접 푸시하지 않는다.** 모든 변경은 브랜치 → PR → 머지.
2. **한 브랜치 = 한 가지 작업.** 기능 두 개를 한 브랜치에 섞지 않기.
3. **PR은 작게.** 300줄 이하, 리뷰어가 10분 안에 읽을 수 있는 크기.

---

## 2. 작업 흐름 (매번 이 순서대로)

```bash
# ① 시작 전: main 최신화
git checkout main
git pull origin main

# ② 작업 브랜치 생성
git checkout -b feat/accounts-api

# ③ 작은 단위로 커밋
git add accounts/
git commit -m "feat: 회원가입/로그인 API 구현"

# ④ 푸시 전 검증
python manage.py check
python manage.py test

# ⑤ 브랜치 푸시 → GitHub에서 PR 생성
git push origin feat/accounts-api
```

---

## 3. 브랜치 이름 규칙

| 접두어 | 용도 | 예시 |
|---|---|---|
| `feat/` | 새 기능 | `feat/seedlings-api`, `feat/yolo-inference` |
| `fix/` | 버그 수정 | `fix/jwt-token-error` |
| `refactor/` | 구조 개선 | `refactor/sensor-views` |
| `docs/` | 문서 수정 | `docs/update-db-schema` |
| `chore/` | 설정·의존성 | `chore/add-prophet` |

소문자 + 하이픈, 영어로.

---

## 4. 커밋 메시지 규칙

```
<타입>: <무엇을> (한국어 OK, 50자 이내)
```

**좋은 예**
- `feat: 묘목 입양 API 구현`
- `fix: 타인 묘목 접근 시 404 처리`
- `docs: DB_SCHEMA에 SensorData 필드 추가`

**나쁜 예**: `수정`, `update`, `asdf`, `최종`, `진짜최종` ❌

---

## 5. Pull Request 규칙

PR 설명에 아래 세 가지를 씁니다:

```markdown
## 무엇을
accounts 앱 회원가입/로그인 API 구현

## 왜
DESIGN.md 기준 /api/accounts/register/, /api/accounts/login/ 엔드포인트 필요

## 확인 방법
1. python manage.py test accounts 실행
2. 3개 테스트 모두 통과 확인
```

- `python manage.py check` / `python manage.py test` 통과 상태로만 PR 올리기
- 리뷰어 1명 이상 승인 후 머지
- 머지 방식은 **Squash and merge** 권장

---

## 6. 충돌(Conflict) 났을 때

```bash
git checkout main && git pull origin main
git checkout feat/my-branch
git merge main
# 충돌 파일 정리 후
git add . && git commit
git push
```

---

## 7. 하지 말 것 ❌

| 금지 | 이유 |
|---|---|
| `main`에 직접 push | 리뷰 없이 팀 전체 코드가 바뀜 |
| `git push --force` | 팀원 커밋이 증발함 |
| `.env` 커밋 | API 키·DB 비밀번호 유출 |
| `venv/` 커밋 | 용량 폭발, .gitignore가 막아줌 |
| 거대 PR | 리뷰 불가능 → 버그 통과 |

---

## 8. 프로젝트 문서 지도

| 문서 | 내용 |
|---|---|
| [README.md](README.md) | 프로젝트 소개 |
| [CLAUDE.md](CLAUDE.md) | Claude Code 프로젝트 컨텍스트 |
| [DB_SCHEMA.md](DB_SCHEMA.md) | DB 테이블 설계 |
| [DESIGN.md](DESIGN.md) | 서비스 플로우 · API 설계 |
| [AGENTS.md](AGENTS.md) | Claude Code 행동 규칙 |
| 이 문서 | 협업 규칙 |