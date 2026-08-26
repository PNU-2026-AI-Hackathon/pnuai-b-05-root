from django.core.files.base import ContentFile
from django.shortcuts import get_object_or_404
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.generics import CreateAPIView, DestroyAPIView, ListAPIView
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
            illustration_bytes = convert_to_illustration(diary.photo.path)
            if illustration_bytes:
                diary.illustration.save(
                    f'diary_{diary.pk}_illustration.png',
                    ContentFile(illustration_bytes),
                    save=True,
                )


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


class DiaryDestroyView(DestroyAPIView):
    """`DELETE /api/diary/entry/{id}/` — 재배자 본인이 작성한 일지 삭제.

    `DiaryCreateView.perform_create()`와 대칭으로, permission class가 아니라
    `perform_destroy()` 안에서 `request.user.role`과 `Diary.grower`를 직접 비교한다.
    완료된 묘목의 일지는 입양자의 성장 타임라인에 이미 확정 아카이브로 노출됐을 수 있어
    삭제를 막는다(`SeedlingPickupDonateView`의 status 가드와 동일한 형태, 조건만 반대).
    """

    permission_classes = [IsAuthenticated]
    queryset = Diary.objects.select_related('seedling').all()

    def perform_destroy(self, instance):
        user = self.request.user
        if user.role != User.Role.GROWER or instance.grower_id != user.pk:
            raise PermissionDenied('본인이 작성한 일지만 삭제할 수 있습니다.')
        if instance.seedling.status == Seedling.Status.COMPLETED:
            raise ValidationError('완료된 묘목의 일지는 삭제할 수 없습니다.')
        instance.delete()
