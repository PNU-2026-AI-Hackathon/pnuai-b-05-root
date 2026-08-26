import io
import shutil
import tempfile
from unittest.mock import patch

from django.core import mail
from django.test import override_settings
from django.urls import reverse
from PIL import Image
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import User

from .models import Seedling

_MEDIA_ROOT = tempfile.mkdtemp()


def _generate_test_photo():
    """diary/tests.py의 동명 헬퍼와 동일 — 10x10 JPEG 하나를 메모리에 만든다."""
    buffer = io.BytesIO()
    Image.new('RGB', (10, 10), color='green').save(buffer, format='JPEG')
    buffer.seek(0)
    buffer.name = 'final.jpg'
    return buffer


class SeedlingListCreateViewTests(APITestCase):
    def setUp(self):
        self.adopter = User.objects.create_user(
            email='adopter@example.com', password='testpass123', role=User.Role.ADOPTER,
        )
        self.other_adopter = User.objects.create_user(
            email='other-adopter@example.com', password='testpass123', role=User.Role.ADOPTER,
        )
        self.grower = User.objects.create_user(
            email='grower@example.com', password='testpass123', role=User.Role.GROWER,
        )
        self.url = reverse('seedlings:list-create')

    def test_adopter_can_create_seedling(self):
        self.client.force_authenticate(user=self.adopter)

        response = self.client.post(self.url, {})

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(Seedling.objects.count(), 1)
        seedling = Seedling.objects.first()
        self.assertEqual(seedling.adopter, self.adopter)
        self.assertEqual(seedling.status, Seedling.Status.GROWING)

    def test_adopter_creation_assigns_grower_with_fewest_growing_seedlings(self):
        busy_grower = User.objects.create_user(
            email='busy-grower@example.com', password='testpass123', role=User.Role.GROWER,
        )
        Seedling.objects.create(
            adopter=self.other_adopter, grower=busy_grower, status=Seedling.Status.GROWING,
        )
        Seedling.objects.create(
            adopter=self.other_adopter, grower=busy_grower, status=Seedling.Status.GROWING,
        )
        # self.grower는 재배중인 묘목이 0건이라 이쪽으로 배정돼야 한다.
        self.client.force_authenticate(user=self.adopter)

        response = self.client.post(self.url, {})

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        seedling = Seedling.objects.get(pk=response.data['id'])
        self.assertEqual(seedling.grower, self.grower)

    def test_adopter_lists_only_own_seedlings(self):
        Seedling.objects.create(adopter=self.adopter)
        Seedling.objects.create(adopter=self.other_adopter)
        self.client.force_authenticate(user=self.adopter)

        response = self.client.get(self.url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]['adopter'], self.adopter.pk)


class SeedlingDetailViewTests(APITestCase):
    def setUp(self):
        self.adopter = User.objects.create_user(
            email='adopter@example.com', password='testpass123', role=User.Role.ADOPTER,
        )
        self.other_adopter = User.objects.create_user(
            email='other-adopter@example.com', password='testpass123', role=User.Role.ADOPTER,
        )
        self.seedling = Seedling.objects.create(adopter=self.adopter)

    def test_other_user_cannot_access_seedling(self):
        self.client.force_authenticate(user=self.other_adopter)
        url = reverse('seedlings:detail', kwargs={'pk': self.seedling.pk})

        response = self.client.get(url)

        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)


@override_settings(MEDIA_ROOT=_MEDIA_ROOT)
class SeedlingCompleteViewTests(APITestCase):
    @classmethod
    def tearDownClass(cls):
        super().tearDownClass()
        shutil.rmtree(_MEDIA_ROOT, ignore_errors=True)

    def setUp(self):
        self.adopter = User.objects.create_user(
            email='adopter@example.com', password='testpass123', role=User.Role.ADOPTER,
        )
        self.grower = User.objects.create_user(
            email='grower@example.com', password='testpass123', role=User.Role.GROWER,
        )
        self.other_grower = User.objects.create_user(
            email='other-grower@example.com', password='testpass123', role=User.Role.GROWER,
        )
        self.seedling = Seedling.objects.create(adopter=self.adopter, grower=self.grower)
        self.url = reverse('seedlings:complete', kwargs={'pk': self.seedling.pk})

    @patch('seedlings.views.send_notification_to_user')
    def test_grower_can_complete_own_seedling(self, mock_send_notification):
        self.client.force_authenticate(user=self.grower)

        response = self.client.patch(self.url, {'height_cm': 34})

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.seedling.refresh_from_db()
        self.assertEqual(self.seedling.status, Seedling.Status.COMPLETED)
        self.assertIsNotNone(self.seedling.completed_at)
        self.assertEqual(self.seedling.height_cm, 34)
        mock_send_notification.assert_called_once_with(
            self.adopter, '묘목 완성!', '무화과 묘목이 완성됐어요. 수령 또는 기부를 선택해주세요.',
        )

    @patch('seedlings.views.send_notification_to_user')
    def test_complete_requires_height_cm(self, mock_send_notification):
        self.client.force_authenticate(user=self.grower)

        response = self.client.patch(self.url)

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.seedling.refresh_from_db()
        self.assertEqual(self.seedling.status, Seedling.Status.GROWING)
        mock_send_notification.assert_not_called()

    @patch('seedlings.views.send_notification_to_user')
    def test_complete_rejects_non_positive_height(self, mock_send_notification):
        self.client.force_authenticate(user=self.grower)

        response = self.client.patch(self.url, {'height_cm': 0})

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    @patch('seedlings.views.send_notification_to_user')
    def test_complete_allows_height_below_30(self, mock_send_notification):
        """30cm 미만이어도 완성 신고를 막지 않는다(재배자 판단, 프론트에서 경고만)."""
        self.client.force_authenticate(user=self.grower)

        response = self.client.patch(self.url, {'height_cm': 22})

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.seedling.refresh_from_db()
        self.assertEqual(self.seedling.height_cm, 22)
        self.assertEqual(self.seedling.status, Seedling.Status.COMPLETED)

    @patch('seedlings.views.convert_to_illustration', return_value=b'fake-png-bytes')
    @patch('seedlings.views.send_notification_to_user')
    def test_complete_with_photo_converts_to_illustration(
        self, mock_send_notification, mock_convert,
    ):
        self.client.force_authenticate(user=self.grower)

        response = self.client.patch(
            self.url,
            {'height_cm': 34, 'final_photo': _generate_test_photo()},
            format='multipart',
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.seedling.refresh_from_db()
        self.assertTrue(self.seedling.final_photo)
        mock_convert.assert_called_once_with(self.seedling.final_photo.path)
        self.assertTrue(self.seedling.final_illustration)
        with self.seedling.final_illustration.open('rb') as f:
            self.assertEqual(f.read(), b'fake-png-bytes')

    @patch('seedlings.views.convert_to_illustration', return_value=None)
    @patch('seedlings.views.send_notification_to_user')
    def test_complete_saved_without_illustration_when_conversion_fails(
        self, mock_send_notification, mock_convert,
    ):
        self.client.force_authenticate(user=self.grower)

        response = self.client.patch(
            self.url,
            {'height_cm': 34, 'final_photo': _generate_test_photo()},
            format='multipart',
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.seedling.refresh_from_db()
        self.assertTrue(self.seedling.final_photo)
        self.assertFalse(self.seedling.final_illustration)

    @patch('seedlings.views.convert_to_illustration')
    @patch('seedlings.views.send_notification_to_user')
    def test_complete_without_photo_skips_conversion(
        self, mock_send_notification, mock_convert,
    ):
        self.client.force_authenticate(user=self.grower)

        response = self.client.patch(self.url, {'height_cm': 34})

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.seedling.refresh_from_db()
        self.assertFalse(self.seedling.final_photo)
        mock_convert.assert_not_called()

    @patch('seedlings.views.send_notification_to_user')
    def test_completing_seedling_sends_email_to_adopter(self, mock_send_notification):
        self.adopter.nickname = '단풍'
        self.adopter.save(update_fields=['nickname'])
        self.client.force_authenticate(user=self.grower)

        response = self.client.patch(self.url, {'height_cm': 34})

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(mail.outbox), 1)
        sent = mail.outbox[0]
        self.assertEqual(sent.to, [self.adopter.email])
        self.assertIn(f'#{self.seedling.pk}', sent.subject)
        self.assertIn('단풍님', sent.body)

    @patch('seedlings.views.send_mail', side_effect=Exception('smtp down'))
    @patch('seedlings.views.send_notification_to_user')
    def test_completing_seedling_succeeds_even_if_email_fails(
        self, mock_send_notification, mock_send_mail,
    ):
        self.client.force_authenticate(user=self.grower)

        response = self.client.patch(self.url, {'height_cm': 34})

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.seedling.refresh_from_db()
        self.assertEqual(self.seedling.status, Seedling.Status.COMPLETED)

    def test_adopter_cannot_complete_seedling(self):
        self.client.force_authenticate(user=self.adopter)

        response = self.client.patch(self.url, {'height_cm': 34})

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.seedling.refresh_from_db()
        self.assertEqual(self.seedling.status, Seedling.Status.GROWING)

    def test_other_grower_cannot_complete_unassigned_seedling(self):
        self.client.force_authenticate(user=self.other_grower)

        response = self.client.patch(self.url, {'height_cm': 34})

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)


class SeedlingPickupDonateViewTests(APITestCase):
    def setUp(self):
        self.adopter = User.objects.create_user(
            email='adopter@example.com', password='testpass123', role=User.Role.ADOPTER,
        )
        self.other_adopter = User.objects.create_user(
            email='other-adopter@example.com', password='testpass123', role=User.Role.ADOPTER,
        )
        self.grower = User.objects.create_user(
            email='grower@example.com', password='testpass123', role=User.Role.GROWER,
        )
        self.seedling = Seedling.objects.create(
            adopter=self.adopter, grower=self.grower, status=Seedling.Status.COMPLETED,
        )
        self.url = reverse('seedlings:pickup-donate', kwargs={'pk': self.seedling.pk})

    @patch('seedlings.views.send_notification_to_user')
    def test_adopter_can_choose_pickup(self, mock_send_notification):
        self.client.force_authenticate(user=self.adopter)

        response = self.client.patch(self.url, {'pickup_or_donate': 'pickup'})

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.seedling.refresh_from_db()
        self.assertEqual(self.seedling.pickup_or_donate, Seedling.PickupOrDonate.PICKUP)
        self.assertIsNone(self.seedling.donate_type)
        mock_send_notification.assert_called_once_with(
            self.grower,
            '수령 안내',
            f'묘목 #{self.seedling.pk} 입양자가 직접 수령을 선택했어요. 방문 시 안내해주세요.',
        )

    @patch('seedlings.views.send_notification_to_user')
    def test_adopter_can_choose_donate_with_type(self, mock_send_notification):
        self.client.force_authenticate(user=self.adopter)

        response = self.client.patch(
            self.url, {'pickup_or_donate': 'donate', 'donate_type': 'in_app_sharing'},
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.seedling.refresh_from_db()
        self.assertEqual(self.seedling.pickup_or_donate, Seedling.PickupOrDonate.DONATE)
        self.assertEqual(self.seedling.donate_type, Seedling.DonateType.IN_APP_SHARING)
        mock_send_notification.assert_called_once_with(
            self.grower,
            '기부 안내',
            f'묘목 #{self.seedling.pk}가 "앱 내 나눔 분양"로 기부하기로 결정됐어요.',
        )

    def test_other_adopter_cannot_choose(self):
        self.client.force_authenticate(user=self.other_adopter)

        response = self.client.patch(self.url, {'pickup_or_donate': 'pickup'})

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_grower_cannot_choose(self):
        self.client.force_authenticate(user=self.grower)

        response = self.client.patch(self.url, {'pickup_or_donate': 'pickup'})

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_growing_seedling_rejected(self):
        growing_seedling = Seedling.objects.create(
            adopter=self.adopter, grower=self.grower, status=Seedling.Status.GROWING,
        )
        url = reverse('seedlings:pickup-donate', kwargs={'pk': growing_seedling.pk})
        self.client.force_authenticate(user=self.adopter)

        response = self.client.patch(url, {'pickup_or_donate': 'pickup'})

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_donate_without_donate_type_rejected(self):
        self.client.force_authenticate(user=self.adopter)

        response = self.client.patch(self.url, {'pickup_or_donate': 'donate'})

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_invalid_donate_type_rejected(self):
        self.client.force_authenticate(user=self.adopter)

        response = self.client.patch(
            self.url, {'pickup_or_donate': 'donate', 'donate_type': 'not-a-real-type'},
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    @patch('seedlings.views.send_notification_to_user')
    def test_resubmitting_same_choice_does_not_resend_notification(self, mock_send_notification):
        self.client.force_authenticate(user=self.adopter)
        self.client.patch(self.url, {'pickup_or_donate': 'pickup'})
        mock_send_notification.reset_mock()

        response = self.client.patch(self.url, {'pickup_or_donate': 'pickup'})

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        mock_send_notification.assert_not_called()
