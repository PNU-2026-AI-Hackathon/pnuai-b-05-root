from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from .models import User


class RegisterViewTests(APITestCase):
    def test_register_success(self):
        url = reverse('accounts:register')
        data = {
            'email': 'adopter@example.com',
            'password': 'testpass123',
            'role': User.Role.ADOPTER,
        }

        response = self.client.post(url, data)

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['message'], '회원가입 성공')
        self.assertEqual(response.data['email'], data['email'])
        self.assertEqual(response.data['role'], data['role'])
        self.assertTrue(User.objects.filter(email=data['email']).exists())

    def test_register_duplicate_email_fails(self):
        User.objects.create_user(
            email='adopter@example.com',
            password='testpass123',
            role=User.Role.ADOPTER,
        )
        url = reverse('accounts:register')
        data = {
            'email': 'adopter@example.com',
            'password': 'anotherpass123',
            'role': User.Role.GROWER,
        }

        response = self.client.post(url, data)

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(User.objects.filter(email=data['email']).count(), 1)


class LoginViewTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            email='grower@example.com',
            password='testpass123',
            role=User.Role.GROWER,
        )

    def test_login_success(self):
        url = reverse('accounts:login')
        data = {
            'email': 'grower@example.com',
            'password': 'testpass123',
        }

        response = self.client.post(url, data)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('access', response.data)
        self.assertIn('refresh', response.data)
        self.assertEqual(response.data['role'], User.Role.GROWER)
        self.assertEqual(response.data['id'], self.user.id)
        self.assertEqual(response.data['email'], self.user.email)
        self.assertEqual(response.data['nickname'], '')


class AccountViewTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            email='adopter@example.com',
            password='testpass123',
            role=User.Role.ADOPTER,
            nickname='입양이',
        )
        self.url = reverse('accounts:me')

    def test_unauthenticated_get_is_rejected(self):
        response = self.client.get(self.url)

        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_get_returns_own_profile(self):
        self.client.force_authenticate(user=self.user)

        response = self.client.get(self.url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['email'], self.user.email)
        self.assertEqual(response.data['nickname'], '입양이')
        self.assertEqual(response.data['role'], User.Role.ADOPTER)

    def test_patch_updates_nickname_only(self):
        self.client.force_authenticate(user=self.user)

        response = self.client.patch(self.url, {'nickname': '새이름'})

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.user.refresh_from_db()
        self.assertEqual(self.user.nickname, '새이름')

    def test_patch_ignores_email_and_role(self):
        self.client.force_authenticate(user=self.user)

        response = self.client.patch(
            self.url, {'nickname': '새이름', 'email': 'hacked@example.com', 'role': User.Role.GROWER},
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.user.refresh_from_db()
        self.assertEqual(self.user.email, 'adopter@example.com')
        self.assertEqual(self.user.role, User.Role.ADOPTER)

    def test_unauthenticated_delete_is_rejected(self):
        response = self.client.delete(self.url)

        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
        self.user.refresh_from_db()
        self.assertTrue(self.user.is_active)

    def test_delete_account_deactivates_user(self):
        self.client.force_authenticate(user=self.user)

        response = self.client.delete(self.url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.user.refresh_from_db()
        self.assertFalse(self.user.is_active)

    def test_login_fails_after_account_deleted(self):
        self.client.force_authenticate(user=self.user)
        self.client.delete(self.url)

        login_url = reverse('accounts:login')
        response = self.client.post(
            login_url, {'email': self.user.email, 'password': 'testpass123'},
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
