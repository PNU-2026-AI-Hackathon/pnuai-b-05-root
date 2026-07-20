from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .fcm import send_notification_to_user
from .models import FCMToken
from .serializers import FCMTokenRegisterSerializer


class FCMTokenRegisterView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = FCMTokenRegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        token = serializer.validated_data['token']

        FCMToken.objects.get_or_create(token=token, defaults={'user': request.user})

        return Response({'message': '토큰 등록 완료'})


class NotificationTestView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        send_notification_to_user(
            request.user,
            '테스트 알림',
            'Pig.Fig. 푸시 알림이 정상적으로 동작합니다.',
        )

        return Response({'message': '알림 발송 완료'})
