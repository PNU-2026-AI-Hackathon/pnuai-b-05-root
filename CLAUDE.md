# CLAUDE.md

Claude Code가 이 저장소에서 작업할 때 매 세션마다 참조하는 파일입니다.

## 프로젝트 개요

**Pig.Fig.** — 도심 유휴공간 기반 무화과 대리재배 모바일 플랫폼.
입양자(adopter)가 무화과 묘목을 입양하면, 재배자(grower)가 도심 유휴공간에서 실제로 키워주고
입양자는 앱을 통해 생육 과정을 지켜보다가 다 자란 무화과를 수령하거나 기부할 수 있는 서비스입니다.

## 기술 스택

- **프론트엔드**: Flutter
- **백엔드**: Django REST Framework
- **DB**: MySQL
- **비전 분석**: YOLOv8 (생육 상태/이상 탐지)
- **시계열 예측**: Prophet (생육 예측)
- **챗봇**: LangChain RAG + Gemini API
- **IoT 연동**: MQTT (센서 데이터 수집)
- **푸시 알림**: FCM (Firebase Cloud Messaging)

## 폴더 구조

```
pigfig/
├── backend/     # Django REST Framework 프로젝트
└── frontend/    # Flutter 프로젝트 (미개발)
```

## 백엔드 앱 구성

`backend/` 아래 다음 7개 Django 앱으로 구성됩니다.

- `accounts` — 사용자(입양자/재배자) 인증 및 계정 관리
- `seedlings` — 묘목 입양/재배 상태 관리
- `diary` — 재배 일지 (사진, 생육 기록)
- `sensor` — IoT 센서 데이터 (온습도, 조도 등)
- `vision` — YOLOv8 기반 이미지 분석
- `chatbot` — LangChain RAG + Gemini 기반 챗봇
- `notifications` — FCM 푸시 알림

## 개발 규칙

- 코드 주석은 **한국어**로 작성합니다.
- REST API는 `/api/앱명/` prefix를 따릅니다 (예: `/api/seedlings/`).
- 환경변수(SECRET_KEY, DB 정보, API 키 등)는 반드시 `.env`에서 로드하며, 코드에 하드코딩하지 않습니다.

## 현재 개발 상태

- 백엔드 Django 프로젝트 초기 세팅 완료 (앱 7개 생성, DRF/JWT/CORS 설정 완료)
- DB(MySQL)는 아직 미연결 — `.env`에 실제 접속 정보 입력 및 `migrate` 필요
- 프론트엔드(Flutter)는 아직 미착수
