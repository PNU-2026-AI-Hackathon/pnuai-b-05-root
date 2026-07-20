from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import User
from seedlings.models import Seedling

from .models import Diary


class DiaryCreateViewTests(APITestCase):
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
        self.url = reverse('diary:create')

    def test_grower_can_create_diary_for_own_seedling(self):
        self.client.force_authenticate(user=self.grower)
        data = {'seedling': self.seedling.pk, 'content': '오늘은 새순이 돋았습니다.'}

        response = self.client.post(self.url, data)

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(Diary.objects.count(), 1)
        diary = Diary.objects.first()
        self.assertEqual(diary.grower, self.grower)
        self.assertEqual(diary.seedling, self.seedling)

    def test_grower_cannot_create_diary_for_unassigned_seedling(self):
        self.client.force_authenticate(user=self.other_grower)
        data = {'seedling': self.seedling.pk, 'content': '담당 아닌 묘목 일지'}

        response = self.client.post(self.url, data)

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.assertEqual(Diary.objects.count(), 0)


class DiaryListViewTests(APITestCase):
    def setUp(self):
        self.adopter = User.objects.create_user(
            email='adopter@example.com', password='testpass123', role=User.Role.ADOPTER,
        )
        self.grower = User.objects.create_user(
            email='grower@example.com', password='testpass123', role=User.Role.GROWER,
        )
        self.stranger = User.objects.create_user(
            email='stranger@example.com', password='testpass123', role=User.Role.ADOPTER,
        )
        self.seedling = Seedling.objects.create(adopter=self.adopter, grower=self.grower)
        Diary.objects.create(seedling=self.seedling, grower=self.grower, content='첫 일지')
        self.url = reverse('diary:list', kwargs={'seedling_id': self.seedling.pk})

    def test_adopter_can_list_diaries(self):
        self.client.force_authenticate(user=self.adopter)

        response = self.client.get(self.url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)

    def test_grower_can_list_diaries(self):
        self.client.force_authenticate(user=self.grower)

        response = self.client.get(self.url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)

    def test_unrelated_user_cannot_list_diaries(self):
        self.client.force_authenticate(user=self.stranger)

        response = self.client.get(self.url)

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
