from unittest.mock import patch

from django.test import override_settings
from django.urls import reverse
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
