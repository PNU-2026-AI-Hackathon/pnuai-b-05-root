import io
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from django.test import TestCase, override_settings
from django.urls import reverse
from PIL import Image
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import User
from diary.models import Diary
from seedlings.models import Seedling

from . import yolo_inference
from .models import VisionAnalysis
from .yolo_inference import RESULT_TAGS, analyze_image

MEDIA_ROOT = tempfile.mkdtemp()

MOCK_ANALYSIS_RESULT = {
    'result_tag': '정상',
    'confidence': 0.91,
    'location_info': '선반1-1번',
}


def _generate_test_image():
    buffer = io.BytesIO()
    Image.new('RGB', (10, 10), color='green').save(buffer, format='JPEG')
    buffer.seek(0)
    buffer.name = 'test.jpg'
    return buffer


@override_settings(MEDIA_ROOT=MEDIA_ROOT)
class VisionAnalyzeViewTests(APITestCase):
    """뷰 단위 테스트. 권한/소유권/diary 연동만 검증하며 실제 추론 여부와는 무관해야 하므로
    `analyze_image`를 고정값으로 mock한다."""

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

        analyze_patcher = patch(
            'vision.views.analyze_image', return_value=MOCK_ANALYSIS_RESULT,
        )
        self.mock_analyze = analyze_patcher.start()
        self.addCleanup(analyze_patcher.stop)

    def test_grower_can_analyze_image(self):
        self.client.force_authenticate(user=self.grower)

        response = self.client.post(
            self.url, {'image': _generate_test_image()}, format='multipart',
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['result_tag'], MOCK_ANALYSIS_RESULT['result_tag'])
        self.assertEqual(response.data['confidence'], MOCK_ANALYSIS_RESULT['confidence'])
        self.assertEqual(response.data['location_info'], MOCK_ANALYSIS_RESULT['location_info'])
        self.assertIsNotNone(response.data['analyzed_at'])
        self.assertEqual(VisionAnalysis.objects.count(), 1)

    def test_adopter_cannot_analyze_image(self):
        self.client.force_authenticate(user=self.adopter)

        response = self.client.post(
            self.url, {'image': _generate_test_image()}, format='multipart',
        )

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.assertEqual(VisionAnalysis.objects.count(), 0)
        self.mock_analyze.assert_not_called()

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


class AnalyzeImageTests(TestCase):
    """`yolo_inference.analyze_image()` 자체를 뷰 없이 검증한다."""

    def test_falls_back_to_mock_when_weights_file_missing(self):
        missing_path = Path(tempfile.gettempdir()) / 'pigfig_no_such_weights' / 'best.pt'

        with patch.object(yolo_inference, '_MODEL_PATH', missing_path):
            result = analyze_image('irrelevant/path.jpg')

        self.assertIn(result['result_tag'], RESULT_TAGS)

    def test_falls_back_to_mock_when_inference_raises(self):
        # "파일은 있음" 게이트만 통과시키고(실제 모델은 로드하지 않음), 추론 자체가
        # 실패하는 상황을 흉내낸다.
        existing_path = Path(__file__)

        with patch.object(yolo_inference, '_MODEL_PATH', existing_path), patch(
            'vision.yolo_inference._run_inference', side_effect=Exception('추론 실패'),
        ):
            result = analyze_image('irrelevant/path.jpg')

        self.assertIn(result['result_tag'], RESULT_TAGS)

    @unittest.skipUnless(
        yolo_inference._MODEL_PATH.exists(), 'best.pt 가중치가 없어 스킵',
    )
    def test_real_inference_returns_valid_classification(self):
        temp_dir = tempfile.mkdtemp()
        try:
            image_path = str(Path(temp_dir) / 'leaf.jpg')
            Image.new('RGB', (224, 224), color='green').save(image_path)

            result = analyze_image(image_path)
        finally:
            shutil.rmtree(temp_dir, ignore_errors=True)

        self.assertIn(result['result_tag'], ('정상', '이상감지'))
        self.assertIsInstance(result['confidence'], float)
        self.assertTrue(0.0 <= result['confidence'] <= 1.0)
        self.assertIsNone(result['location_info'])
