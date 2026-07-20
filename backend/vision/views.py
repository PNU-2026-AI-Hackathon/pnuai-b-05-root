from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.exceptions import PermissionDenied
from rest_framework.generics import CreateAPIView
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from accounts.models import User
from diary.models import Diary

from .models import VisionAnalysis
from .serializers import VisionAnalysisResultSerializer, VisionAnalyzeSerializer
from .yolo_inference import analyze_image


class VisionAnalyzeView(CreateAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = VisionAnalyzeSerializer

    def create(self, request, *args, **kwargs):
        user = request.user
        if user.role != User.Role.GROWER:
            raise PermissionDenied('재배자만 이미지 분석을 요청할 수 있습니다.')

        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        diary = None
        diary_id = serializer.validated_data.get('diary_id')
        if diary_id is not None:
            diary = get_object_or_404(Diary, pk=diary_id)
            if diary.grower_id != user.pk:
                raise PermissionDenied('본인이 작성한 일지에만 분석 결과를 연결할 수 있습니다.')

        analysis = VisionAnalysis.objects.create(
            diary=diary,
            image=serializer.validated_data['image'],
        )

        result = analyze_image(analysis.image.path)
        analysis.result_tag = result['result_tag']
        analysis.confidence = result['confidence']
        analysis.location_info = result['location_info']
        analysis.save()

        if diary is not None:
            diary.yolo_status_tag = analysis.result_tag
            diary.save(update_fields=['yolo_status_tag'])

        return Response(
            VisionAnalysisResultSerializer(analysis).data,
            status=status.HTTP_201_CREATED,
        )
