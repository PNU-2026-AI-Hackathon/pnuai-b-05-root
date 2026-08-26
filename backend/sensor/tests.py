from datetime import timedelta
from unittest.mock import patch

from django.test import override_settings
from django.urls import reverse
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import User
from seedlings.models import Seedling

from .models import SensorData


class SensorDataCreateViewTests(APITestCase):
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
        self.url = reverse('sensor:data-create')

    def test_grower_can_save_normal_sensor_data(self):
        self.client.force_authenticate(user=self.grower)
        data = {'seedling': self.seedling.pk, 'temperature': 24, 'humidity': 60, 'light': 500}

        response = self.client.post(self.url, data)

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        sensor_data = SensorData.objects.get()
        self.assertFalse(sensor_data.is_anomaly)
        self.assertIsNone(sensor_data.gemini_diagnosis)

    @override_settings(GEMINI_API_KEY='')
    def test_out_of_range_sensor_data_flagged_as_anomaly(self):
        self.client.force_authenticate(user=self.grower)
        data = {'seedling': self.seedling.pk, 'temperature': 50, 'humidity': 60, 'light': 500}

        response = self.client.post(self.url, data)

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        sensor_data = SensorData.objects.get()
        self.assertTrue(sensor_data.is_anomaly)
        self.assertIn('온도', sensor_data.gemini_diagnosis)

    @override_settings(GEMINI_API_KEY='dummy-key')
    def test_uses_gemini_diagnosis_when_api_key_present(self):
        self.client.force_authenticate(user=self.grower)
        data = {'seedling': self.seedling.pk, 'temperature': 50, 'humidity': 60, 'light': 500}
        mock_diagnosis = '온도가 조금 높아요. 통풍을 시켜주시면 좋아요.'

        with patch('sensor.anomaly._generate_gemini_diagnosis', return_value=mock_diagnosis) as mock_generate:
            response = self.client.post(self.url, data)

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        sensor_data = SensorData.objects.get()
        self.assertEqual(sensor_data.gemini_diagnosis, mock_diagnosis)
        mock_generate.assert_called_once_with(['temperature'], 50.0, 60.0, 500.0)

    @override_settings(GEMINI_API_KEY='dummy-key')
    def test_falls_back_to_static_template_when_gemini_call_fails(self):
        self.client.force_authenticate(user=self.grower)
        data = {'seedling': self.seedling.pk, 'temperature': 50, 'humidity': 60, 'light': 500}

        with patch('sensor.anomaly._generate_gemini_diagnosis', side_effect=Exception('timeout')):
            response = self.client.post(self.url, data)

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        sensor_data = SensorData.objects.get()
        self.assertIn('온도', sensor_data.gemini_diagnosis)

    def test_grower_cannot_save_data_for_unassigned_seedling(self):
        self.client.force_authenticate(user=self.other_grower)
        data = {'seedling': self.seedling.pk, 'temperature': 24, 'humidity': 60, 'light': 500}

        response = self.client.post(self.url, data)

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.assertEqual(SensorData.objects.count(), 0)


class SensorAnomalyListViewTests(APITestCase):
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
        SensorData.objects.create(
            seedling=self.seedling, temperature=24, humidity=60, light=500, is_anomaly=False,
        )
        SensorData.objects.create(
            seedling=self.seedling, temperature=50, humidity=60, light=500,
            is_anomaly=True, gemini_diagnosis='이상 감지: 온도 수치 이상',
        )
        self.url = reverse('sensor:anomaly-list', kwargs={'seedling_id': self.seedling.pk})

    def test_adopter_can_list_anomalies_only(self):
        self.client.force_authenticate(user=self.adopter)

        response = self.client.get(self.url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertTrue(response.data[0]['is_anomaly'])

    def test_unrelated_user_cannot_list_anomalies(self):
        self.client.force_authenticate(user=self.stranger)

        response = self.client.get(self.url)

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)


class SensorAnomalyListDateFilterTests(APITestCase):
    """`?days=N` 기간 필터. recorded_at은 auto_now_add라 생성 후 .update()로 백데이팅한다
    (seed_demo.py와 동일한 방식)."""

    def setUp(self):
        self.adopter = User.objects.create_user(
            email='adopter@example.com', password='testpass123', role=User.Role.ADOPTER,
        )
        self.grower = User.objects.create_user(
            email='grower@example.com', password='testpass123', role=User.Role.GROWER,
        )
        self.seedling = Seedling.objects.create(adopter=self.adopter, grower=self.grower)
        self.url = reverse('sensor:anomaly-list', kwargs={'seedling_id': self.seedling.pk})

        # 이상 데이터 3건을 각각 2일 / 10일 / 40일 전으로 백데이팅
        now = timezone.now()
        self.recent = self._make_anomaly(days_ago=2, now=now)
        self.mid = self._make_anomaly(days_ago=10, now=now)
        self.old = self._make_anomaly(days_ago=40, now=now)

        self.client.force_authenticate(user=self.grower)

    def _make_anomaly(self, *, days_ago, now):
        record = SensorData.objects.create(
            seedling=self.seedling, temperature=50, humidity=60, light=500,
            is_anomaly=True, gemini_diagnosis='이상 감지: 온도 수치 이상',
        )
        SensorData.objects.filter(pk=record.pk).update(
            recorded_at=now - timedelta(days=days_ago),
        )
        return record

    def test_days_7_returns_only_recent_window(self):
        response = self.client.get(self.url, {'days': 7})

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual([row['id'] for row in response.data], [self.recent.pk])

    def test_days_30_returns_wider_window(self):
        response = self.client.get(self.url, {'days': 30})

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(
            sorted(row['id'] for row in response.data),
            sorted([self.recent.pk, self.mid.pk]),
        )

    def test_no_days_param_returns_all(self):
        response = self.client.get(self.url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 3)

    def test_invalid_days_param_falls_back_to_all(self):
        for bad_value in ('abc', '-5', '0', '99999'):
            with self.subTest(days=bad_value):
                response = self.client.get(self.url, {'days': bad_value})

                self.assertEqual(response.status_code, status.HTTP_200_OK)
                self.assertEqual(len(response.data), 3)

    def test_days_filter_still_excludes_non_anomalies(self):
        normal = SensorData.objects.create(
            seedling=self.seedling, temperature=24, humidity=60, light=500, is_anomaly=False,
        )
        SensorData.objects.filter(pk=normal.pk).update(
            recorded_at=timezone.now() - timedelta(days=1),
        )

        response = self.client.get(self.url, {'days': 7})

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual([row['id'] for row in response.data], [self.recent.pk])
