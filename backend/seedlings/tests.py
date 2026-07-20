from unittest.mock import patch

from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import User

from .models import Seedling


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


class SeedlingCompleteViewTests(APITestCase):
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

        response = self.client.patch(self.url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.seedling.refresh_from_db()
        self.assertEqual(self.seedling.status, Seedling.Status.COMPLETED)
        self.assertIsNotNone(self.seedling.completed_at)
        mock_send_notification.assert_called_once_with(
            self.adopter, '묘목 완성!', '무화과 묘목이 완성됐어요. 수령 또는 기부를 선택해주세요.',
        )

    def test_adopter_cannot_complete_seedling(self):
        self.client.force_authenticate(user=self.adopter)

        response = self.client.patch(self.url)

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.seedling.refresh_from_db()
        self.assertEqual(self.seedling.status, Seedling.Status.GROWING)

    def test_other_grower_cannot_complete_unassigned_seedling(self):
        self.client.force_authenticate(user=self.other_grower)

        response = self.client.patch(self.url)

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
