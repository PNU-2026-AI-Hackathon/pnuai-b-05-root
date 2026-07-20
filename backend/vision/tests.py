import io
import shutil
import tempfile

from django.test import override_settings
from django.urls import reverse
from PIL import Image
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import User
from diary.models import Diary
from seedlings.models import Seedling

from .models import VisionAnalysis
from .yolo_inference import RESULT_TAGS

MEDIA_ROOT = tempfile.mkdtemp()


def _generate_test_image():
    buffer = io.BytesIO()
    Image.new('RGB', (10, 10), color='green').save(buffer, format='JPEG')
    buffer.seek(0)
    buffer.name = 'test.jpg'
    return buffer


@override_settings(MEDIA_ROOT=MEDIA_ROOT)
class VisionAnalyzeViewTests(APITestCase):
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
        self.seedling = Seedling.objects.create(adopter=self.adopter, grower=self.grower)
        self.url = reverse('vision:analyze')

    def test_grower_can_analyze_image(self):
        self.client.force_authenticate(user=self.grower)

        response = self.client.post(
            self.url, {'image': _generate_test_image()}, format='multipart',
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIn(response.data['result_tag'], RESULT_TAGS)
        self.assertTrue(0.7 <= response.data['confidence'] <= 0.99)
        self.assertIsNotNone(response.data['location_info'])
        self.assertIsNotNone(response.data['analyzed_at'])
        self.assertEqual(VisionAnalysis.objects.count(), 1)

    def test_adopter_cannot_analyze_image(self):
        self.client.force_authenticate(user=self.adopter)

        response = self.client.post(
            self.url, {'image': _generate_test_image()}, format='multipart',
        )

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.assertEqual(VisionAnalysis.objects.count(), 0)

    def test_diary_yolo_status_tag_updated_when_diary_id_provided(self):
        self.client.force_authenticate(user=self.grower)
        diary = Diary.objects.create(
            seedling=self.seedling, grower=self.grower, content='오늘의 관찰 일지',
        )

        response = self.client.post(
            self.url,
            {'image': _generate_test_image(), 'diary_id': diary.pk},
            format='multipart',
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        diary.refresh_from_db()
        self.assertEqual(diary.yolo_status_tag, response.data['result_tag'])
        analysis = VisionAnalysis.objects.get()
        self.assertEqual(analysis.diary_id, diary.pk)
