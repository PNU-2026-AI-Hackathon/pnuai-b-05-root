"""Firebase Admin SDK 기반 FCM 푸시 알림 발송.

`FIREBASE_CREDENTIALS_PATH`/`FIREBASE_CREDENTIALS_JSON` 둘 다 `.env`에 설정되어 있지
않으면(로컬 개발 등) 실제 FCM 전송 대신 print로 대체하는 mock 모드로 동작한다.
파일 경로(`FIREBASE_CREDENTIALS_PATH`, 로컬 개발용)와 JSON 문자열 환경변수
(`FIREBASE_CREDENTIALS_JSON`, Render 등 쉘 접근이 안 되는 배포 환경용) 둘 다 지원하며,
JSON 쪽이 있으면 그걸 우선한다.
"""
import json

import firebase_admin
from django.conf import settings
from firebase_admin import credentials, messaging

_app = None


def _get_app():
    """Firebase Admin 앱을 lazy하게 초기화해 캐싱한다."""
    global _app
    if _app is None:
        if settings.FIREBASE_CREDENTIALS_JSON:
            cred = credentials.Certificate(json.loads(settings.FIREBASE_CREDENTIALS_JSON))
        else:
            cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)
        _app = firebase_admin.initialize_app(cred)
    return _app


def send_push_notification(token, title, body):
    """FCM 토큰 하나에 푸시 알림을 보낸다.

    `FIREBASE_CREDENTIALS_PATH`/`FIREBASE_CREDENTIALS_JSON`이 둘 다 없으면 실제 전송
    없이 print로만 출력하는 mock 모드로 동작한다.
    """
    if not (settings.FIREBASE_CREDENTIALS_PATH or settings.FIREBASE_CREDENTIALS_JSON):
        print(f'[FCM mock] token={token} title={title!r} body={body!r}')
        return

    message = messaging.Message(
        notification=messaging.Notification(title=title, body=body),
        token=token,
    )
    messaging.send(message, app=_get_app())


def send_notification_to_user(user, title, body):
    """해당 사용자가 등록한 모든 FCM 토큰으로 알림을 보낸다."""
    from .models import FCMToken

    tokens = FCMToken.objects.filter(user=user).values_list('token', flat=True)
    for token in tokens:
        send_push_notification(token, title, body)
