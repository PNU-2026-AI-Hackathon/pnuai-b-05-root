from django.conf import settings
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .rag_pipeline import ask_question, initialize_rag
from .serializers import ChatbotAskSerializer

MOCK_ANSWER = '챗봇 서비스 준비 중입니다.'
ERROR_ANSWER = '죄송해요, 지금은 답변을 가져오지 못했어요. 잠시 후 다시 시도해주세요.'

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
            try:
                answer = ask_question(question, _get_vectorstore())
            except Exception as e:
                # 네트워크 오류, 타임아웃, 모델 미지원, 벡터스토어(chromadb) 미설치 등
                # RAG 호출 실패 시 500을 그대로 노출하지 않고 안내 메시지로 폴백한다.
                # 폴백은 조용히 일어나므로(원인 파악이 어려움) 서버 로그에 예외를 남긴다.
                print(f'[Chatbot] RAG 응답 생성 실패, 폴백 사용: {e!r}')
                answer = ERROR_ANSWER
        else:
            answer = MOCK_ANSWER

        return Response({'question': question, 'answer': answer})
