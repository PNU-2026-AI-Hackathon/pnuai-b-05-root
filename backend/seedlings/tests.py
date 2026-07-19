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
