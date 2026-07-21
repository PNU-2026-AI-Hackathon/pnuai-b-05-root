import io
import shutil
import tempfile
from unittest.mock import patch

from django.test import TestCase, override_settings
from django.urls import reverse
from PIL import Image
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import User
from seedlings.models import Seedling

from .gemini_illustration import convert_to_illustration
from .models import Diary

MEDIA_ROOT = tempfile.mkdtemp()


def _generate_test_photo():
    buffer = io.BytesIO()
    Image.new('RGB', (10, 10), color='green').save(buffer, format='JPEG')
    buffer.seek(0)
    buffer.name = 'photo.jpg'
    return buffer


@override_settings(MEDIA_ROOT=MEDIA_ROOT)
class DiaryCreateViewTests(APITestCase):
    @classmethod
    def tearDownClass(cls):
        super().tearDownClass()
        shutil.rmtree(MEDIA_ROOT, ignore_errors=True)

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

    def test_photo_converted_to_illustration_when_conversion_succeeds(self):
        self.client.force_authenticate(user=self.grower)
        fake_illustration_bytes = b'fake-png-bytes'
        data = {
            'seedling': self.seedling.pk,
            'content': '사진과 함께 작성한 일지',
            'photo': _generate_test_photo(),
        }

        with patch(
            'diary.views.convert_to_illustration', return_value=fake_illustration_bytes,
        ) as mock_convert:
            response = self.client.post(self.url, data, format='multipart')

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        diary = Diary.objects.get()
        mock_convert.assert_called_once_with(diary.photo.path)
        self.assertTrue(diary.illustration)
        with diary.illustration.open('rb') as f:
            self.assertEqual(f.read(), fake_illustration_bytes)

    def test_diary_saved_without_illustration_when_conversion_fails(self):
        self.client.force_authenticate(user=self.grower)
        data = {
            'seedling': self.seedling.pk,
            'content': '변환이 실패해도 저장은 돼야 함',
            'photo': _generate_test_photo(),
        }

        with patch('diary.views.convert_to_illustration', return_value=None):
            response = self.client.post(self.url, data, format='multipart')

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        diary = Diary.objects.get()
        self.assertTrue(diary.photo)
        self.assertFalse(diary.illustration)

    def test_no_conversion_attempted_when_photo_not_provided(self):
        self.client.force_authenticate(user=self.grower)
        data = {'seedling': self.seedling.pk, 'content': '사진 없는 일지'}

        with patch('diary.views.convert_to_illustration') as mock_convert:
            response = self.client.post(self.url, data)

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        mock_convert.assert_not_called()


class ConvertToIllustrationTests(TestCase):
    """`gemini_illustration.convert_to_illustration()` 자체를 뷰 없이 검증한다."""

    @override_settings(GEMINI_API_KEY='')
    def test_returns_none_without_calling_gemini_when_api_key_missing(self):
        with patch('diary.gemini_illustration._generate_illustration') as mock_generate:
            result = convert_to_illustration('irrelevant/path.jpg')

        self.assertIsNone(result)
        mock_generate.assert_not_called()

    @override_settings(GEMINI_API_KEY='dummy-key')
    def test_returns_bytes_when_generation_succeeds(self):
        fake_bytes = b'fake-illustration-bytes'

        with patch(
            'diary.gemini_illustration._generate_illustration', return_value=fake_bytes,
        ) as mock_generate:
            result = convert_to_illustration('irrelevant/path.jpg')

        self.assertEqual(result, fake_bytes)
        mock_generate.assert_called_once_with('irrelevant/path.jpg')

    @override_settings(GEMINI_API_KEY='dummy-key')
    def test_falls_back_to_none_when_generation_raises(self):
        with patch(
            'diary.gemini_illustration._generate_illustration',
            side_effect=Exception('quota exceeded'),
        ):
            result = convert_to_illustration('irrelevant/path.jpg')

        self.assertIsNone(result)


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
