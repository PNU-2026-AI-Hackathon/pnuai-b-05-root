# DESIGN.md

Pig.Fig. 서비스 플로우 및 API 설계 문서입니다.

## 사용자 역할

- **adopter (입양자)**: 무화과 묘목을 입양(결제)하고, 생육 과정을 지켜보다가 완성된 무화과를 수령하거나 기부하는 사용자
- **grower (재배자)**: 도심 유휴공간에서 실제로 묘목을 재배하고 일지를 작성하는 사용자

## 서비스 플로우

### 입양자 (adopter)

1. 결제 — 묘목 입양(결제) 진행
2. 케어 — 입양한 묘목의 생육 상태 확인
3. 타임라인 — 재배자가 작성한 일지/센서 데이터를 시간순으로 확인
4. 수령/기부 — 재배 완료 후 직접 수령하거나 기부 선택

### 재배자 (grower)

1. 대시보드 — 담당 묘목 목록 및 상태 확인
2. 일지 — 생육 일지(사진, 내용) 작성
3. 완성신고 — 재배 완료 처리 (`Seedling.status` → `completed`)

## API 설계

| Endpoint | Method | 설명 |
|---|---|---|
| `/api/accounts/register/` | POST | 회원가입 |
| `/api/accounts/login/` | POST | 로그인 (JWT 발급) |
| `/api/accounts/me/` | GET | 본인 프로필 조회 (email/nickname/role) |
| `/api/accounts/me/` | PATCH | 본인 닉네임 수정 (nickname만 변경 가능) |
| `/api/accounts/me/` | DELETE | 회원탈퇴 (본인 계정 소프트 삭제, `is_active=False`) |
| `/api/seedlings/` | GET/POST | 묘목 목록 조회 / 입양 생성 |
| `/api/seedlings/{id}/` | GET | 묘목 상세 조회 |
| `/api/seedlings/{id}/complete/` | PATCH | 재배자 묘목 완성 신고 (입양자에게 FCM 알림 발송) |
| `/api/seedlings/{id}/pickup-donate/` | PATCH | 입양자 수령/기부 선택 (완성된 묘목만, 재배자에게 FCM 알림 발송) |
| `/api/diary/` | POST | 재배 일지 작성 |
| `/api/diary/{seedling_id}/` | GET | 특정 묘목의 일지 목록 조회 |
| `/api/sensor/data/` | POST | 센서 데이터 수집 (MQTT 연동) |
| `/api/sensor/anomaly/{seedling_id}/` | GET | 특정 묘목의 이상치 이력 조회 |
| `/api/vision/analyze/` | POST | YOLOv8 이미지 분석 요청 |
| `/api/chatbot/ask/` | POST | LangChain RAG + Gemini 챗봇 질의 |
| `/api/notifications/register-token/` | POST | FCM 디바이스 토큰 등록 |
| `/api/notifications/test/` | POST | 본인에게 테스트 푸시 알림 발송 |
