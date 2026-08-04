from unittest.mock import patch

from django.test import TestCase, override_settings
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import User

from . import fcm as fcm_module
from .models import FCMToken


class FCMTokenRegisterViewTests(APITestCase):
    def setUp(self):
        self.adopter = User.objects.create_user(
            email='adopter@example.com', password='testpass123', role=User.Role.ADOPTER,
        )
        self.url = reverse('notifications:register-token')

    def test_register_token(self):
        self.client.force_authenticate(user=self.adopter)

        response = self.client.post(self.url, {'token': 'device-token-1'})

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['message'], '토큰 등록 완료')
        self.assertEqual(FCMToken.objects.count(), 1)
        self.assertEqual(FCMToken.objects.get().user, self.adopter)

    def test_duplicate_token_is_ignored(self):
        self.client.force_authenticate(user=self.adopter)
        FCMToken.objects.create(user=self.adopter, token='device-token-1')

        response = self.client.post(self.url, {'token': 'device-token-1'})

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(FCMToken.objects.count(), 1)


class NotificationTestViewTests(APITestCase):
    def setUp(self):
        self.adopter = User.objects.create_user(
            email='adopter@example.com', password='testpass123', role=User.Role.ADOPTER,
        )
        self.url = reverse('notifications:test')

    @override_settings(FIREBASE_CREDENTIALS_PATH='', FIREBASE_CREDENTIALS_JSON='')
    @patch('notifications.fcm.print')
    def test_send_test_notification_in_mock_mode(self, mock_print):
        FCMToken.objects.create(user=self.adopter, token='device-token-1')
        self.client.force_authenticate(user=self.adopter)

        response = self.client.post(self.url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['message'], '알림 발송 완료')
        mock_print.assert_called_once()

    @override_settings(FIREBASE_CREDENTIALS_PATH='/fake/path.json', FIREBASE_CREDENTIALS_JSON='')
    @patch('notifications.fcm.messaging.send')
    @patch('notifications.fcm._get_app')
    def test_send_test_notification_calls_messaging_send_when_credentials_configured(
        self, mock_get_app, mock_send,
    ):
        FCMToken.objects.create(user=self.adopter, token='device-token-1')
        self.client.force_authenticate(user=self.adopter)

        response = self.client.post(self.url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        mock_get_app.assert_called_once()
        mock_send.assert_called_once()


class GetAppCredentialsTests(TestCase):
    """`_get_app()`이 FIREBASE_CREDENTIALS_JSON/PATH 중 어느 쪽으로 초기화되는지 검증한다."""

    def setUp(self):
        # 모듈 전역 캐시라 테스트 간에 남아있으면 다른 테스트에 영향을 주므로 매번 초기화한다.
        fcm_module._app = None

    def tearDown(self):
        fcm_module._app = None

    @override_settings(
        FIREBASE_CREDENTIALS_PATH='', FIREBASE_CREDENTIALS_JSON='{"type": "service_account", "project_id": "fake"}',
    )
    @patch('notifications.fcm.firebase_admin.initialize_app')
    @patch('notifications.fcm.credentials.Certificate')
    def test_get_app_parses_json_env_var_as_dict(self, mock_certificate, mock_initialize_app):
        fcm_module._get_app()

        mock_certificate.assert_called_once_with(
            {'type': 'service_account', 'project_id': 'fake'},
        )

    @override_settings(FIREBASE_CREDENTIALS_PATH='/fake/path.json', FIREBASE_CREDENTIALS_JSON='')
    @patch('notifications.fcm.firebase_admin.initialize_app')
    @patch('notifications.fcm.credentials.Certificate')
    def test_get_app_falls_back_to_path_when_json_env_var_absent(
        self, mock_certificate, mock_initialize_app,
    ):
        fcm_module._get_app()

        mock_certificate.assert_called_once_with('/fake/path.json')
