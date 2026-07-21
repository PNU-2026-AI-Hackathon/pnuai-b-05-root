from unittest.mock import patch

from django.test import override_settings
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import User

from .views import ERROR_ANSWER, MOCK_ANSWER


class ChatbotAskViewTests(APITestCase):
    def setUp(self):
        self.adopter = User.objects.create_user(
            email='adopter@example.com', password='testpass123', role=User.Role.ADOPTER,
        )
        self.url = reverse('chatbot:ask')

    def test_unauthenticated_user_cannot_ask(self):
        response = self.client.post(self.url, {'question': '무화과 물은 얼마나 줘야 하나요?'})

        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    @override_settings(GEMINI_API_KEY='')
    def test_returns_mock_answer_without_gemini_api_key(self):
        self.client.force_authenticate(user=self.adopter)
        question = '무화과 물은 얼마나 줘야 하나요?'

        response = self.client.post(self.url, {'question': question})

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['question'], question)
        self.assertEqual(response.data['answer'], MOCK_ANSWER)

    @override_settings(GEMINI_API_KEY='dummy-key')
    def test_authenticated_user_gets_rag_answer(self):
        self.client.force_authenticate(user=self.adopter)
        question = '무화과 물은 얼마나 줘야 하나요?'
        mock_answer = '무화과는 겉흙이 마르면 충분히 물을 주는 것이 좋습니다.'

        with patch('chatbot.views._vectorstore', None), \
             patch('chatbot.views.initialize_rag', return_value='fake-vectorstore') as mock_init, \
             patch('chatbot.views.ask_question', return_value=mock_answer) as mock_ask:
            response = self.client.post(self.url, {'question': question})

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['question'], question)
        self.assertEqual(response.data['answer'], mock_answer)
        mock_init.assert_called_once()
        mock_ask.assert_called_once_with(question, 'fake-vectorstore')

    @override_settings(GEMINI_API_KEY='dummy-key')
    def test_falls_back_to_error_answer_when_gemini_call_fails(self):
        self.client.force_authenticate(user=self.adopter)
        question = '무화과 물은 얼마나 줘야 하나요?'

        with patch('chatbot.views._vectorstore', None), \
             patch('chatbot.views.initialize_rag', return_value='fake-vectorstore'), \
             patch('chatbot.views.ask_question', side_effect=Exception('timeout')):
            response = self.client.post(self.url, {'question': question})

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['question'], question)
        self.assertEqual(response.data['answer'], ERROR_ANSWER)
