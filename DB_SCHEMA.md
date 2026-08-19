# DB_SCHEMA.md

Pig.Fig. 백엔드의 테이블(모델) 설계 문서입니다. 실제 구현 시 세부 필드 타입/제약조건은 각 앱의
`models.py`를 기준으로 하되, 변경 시 이 문서도 함께 갱신합니다.

## User (`accounts`)

| 필드 | 타입 | 설명 |
|---|---|---|
| id | PK | 사용자 ID |
| email | EmailField (unique) | 이메일 (로그인 ID) |
| password | CharField | 비밀번호 (해시 저장) |
| role | CharField (choices) | `adopter`(입양자) / `grower`(재배자) |
| nickname | CharField (blank, default='') | 닉네임. 회원가입 시 선택 입력, 미입력 시 빈 문자열(자동 채움 없음) |
| created_at | DateTimeField | 가입일시 |

## Seedling (`seedlings`)

| 필드 | 타입 | 설명 |
|---|---|---|
| id | PK | 묘목 ID |
| adopter | FK → User | 입양자 |
| grower | FK → User | 재배자 |
| status | CharField (choices) | `growing`(재배중) / `completed`(완료) |
| started_at | DateTimeField | 재배 시작일 |
| completed_at | DateTimeField (nullable) | 재배 완료일 |
| pickup_or_donate | CharField (choices) | 수령(`pickup`) / 기부(`donate`) |
| donate_type | CharField (choices, nullable) | 기부 유형(기부 선택 시): `school_welfare`(초등학교·복지시설 기증) / `urban_farming_community`(도시농업 공동체·시민단체 연계) / `in_app_sharing`(앱 내 나눔 분양) |

## Diary (`diary`)

| 필드 | 타입 | 설명 |
|---|---|---|
| id | PK | 일지 ID |
| seedling | FK → Seedling | 대상 묘목 |
| grower | FK → User | 작성한 재배자 |
| content | TextField | 일지 내용 |
| photo | ImageField | 생육 사진 (MEDIA_ROOT에 저장) |
| illustration | ImageField (nullable) | photo를 Gemini로 변환한 동화풍 일러스트 (변환 실패/미설정 시 null) |
| created_at | DateTimeField | 작성일시 |
| yolo_status_tag | CharField | YOLOv8 분석 결과 상태 태그 |

## SensorData (`sensor`)

| 필드 | 타입 | 설명 |
|---|---|---|
| id | PK | 센서 데이터 ID |
| seedling | FK → Seedling | 대상 묘목 |
| temperature | FloatField | 온도 |
| humidity | FloatField | 습도 |
| light | FloatField | 조도 |
| recorded_at | DateTimeField | 측정일시 |
| is_anomaly | BooleanField | 이상치 여부 |
| gemini_diagnosis | TextField (nullable) | Gemini API 진단 결과 |

## VisionAnalysis (`vision`)

| 필드 | 타입 | 설명 |
|---|---|---|
| id | PK | 분석 결과 ID |
| diary | FK → Diary (nullable) | 연결된 일지 (있으면 diary.yolo_status_tag도 함께 갱신) |
| image | ImageField | 분석 대상 이미지 (MEDIA_ROOT에 저장) |
| result_tag | CharField | 분석 결과 (정상/수분부족/과습/조명이상) |
| confidence | FloatField | 신뢰도 (기본값 0.0) |
| location_info | CharField (nullable) | 묘목 위치 (예: "선반1-3번") |
| analyzed_at | DateTimeField | 분석일시 |

## FCMToken (`notifications`)

| 필드 | 타입 | 설명 |
|---|---|---|
| id | PK | 토큰 ID |
| user | FK → User | 토큰을 등록한 사용자 |
| token | CharField (unique) | FCM 디바이스 토큰 |
| created_at | DateTimeField | 등록일시 |
