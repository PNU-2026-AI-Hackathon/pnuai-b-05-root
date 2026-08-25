from django.core.files.base import ContentFile
from django.shortcuts import get_object_or_404
from rest_framework.exceptions import PermissionDenied
from rest_framework.generics import CreateAPIView, ListAPIView
from rest_framework.permissions import IsAuthenticated

from accounts.models import User
from seedlings.models import Seedling

from .gemini_illustration import convert_to_illustration
from .models import Diary
from .serializers import DiaryCreateSerializer, DiarySerializer


class DiaryCreateView(CreateAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = DiaryCreateSerializer

    def perform_create(self, serializer):
        user = self.request.user
        if user.role != User.Role.GROWER:
            raise PermissionDenied('재배자만 일지를 작성할 수 있습니다.')

        seedling = serializer.validated_data['seedling']
        if seedling.grower_id != user.pk:
            raise PermissionDenied('본인이 담당하는 묘목에만 일지를 작성할 수 있습니다.')

        diary = serializer.save(grower=user)

        if diary.photo:
            try:
                illustration_bytes = convert_to_illustration(diary.photo)
                if illustration_bytes:
                    diary.illustration.save(
                        f'diary_{diary.pk}_illustration.png',
                        ContentFile(illustration_bytes),
                        save=True,
                    )
            except Exception as e:
                # 사진 읽기/Gemini 변환/일러스트 저장 중 어떤 이유로 실패해도(스토리지 접근
                # 오류 등) diary는 이미 저장된 뒤이므로 응답은 그대로 성공시킨다.
                print(f'[Diary] 일러스트 변환 실패: diary={diary.pk} error={e}')


class DiaryListView(ListAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = DiarySerializer

    def get_queryset(self):
        user = self.request.user
        seedling_id = self.kwargs['seedling_id']
        seedling = get_object_or_404(Seedling, pk=seedling_id)

        if user.pk not in (seedling.adopter_id, seedling.grower_id):
            raise PermissionDenied('해당 묘목의 입양자 또는 재배자만 조회할 수 있습니다.')

        return Diary.objects.filter(seedling=seedling)
