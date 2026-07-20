from django.conf import settings
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .rag_pipeline import ask_question, initialize_rag
from .serializers import ChatbotAskSerializer

MOCK_ANSWER = '챗봇 서비스 준비 중입니다.'

_vectorstore = None


def _get_vectorstore():
    """RAG 벡터스토어를 프로세스당 한 번만 초기화해 재사용한다."""
    global _vectorstore
    if _vectorstore is None:
        _vectorstore = initialize_rag()
    return _vectorstore


class ChatbotAskView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = ChatbotAskSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        question = serializer.validated_data['question']

        if settings.GEMINI_API_KEY:
            answer = ask_question(question, _get_vectorstore())
        else:
            answer = MOCK_ANSWER

        return Response({'question': question, 'answer': answer})
