from unittest.mock import patch

from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import User

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

    @patch('notifications.fcm.print')
    def test_send_test_notification_in_mock_mode(self, mock_print):
        FCMToken.objects.create(user=self.adopter, token='device-token-1')
        self.client.force_authenticate(user=self.adopter)

        response = self.client.post(self.url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['message'], '알림 발송 완료')
        mock_print.assert_called_once()
