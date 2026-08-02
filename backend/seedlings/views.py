from django.db.models import Count, Q
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.generics import ListCreateAPIView, RetrieveAPIView
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.models import User
from notifications.fcm import send_notification_to_user

from .models import Seedling
from .serializers import SeedlingCreateSerializer, SeedlingSerializer


class SeedlingListCreateView(ListCreateAPIView):
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.role == User.Role.GROWER:
            return Seedling.objects.filter(grower=user)
        return Seedling.objects.filter(adopter=user)

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return SeedlingCreateSerializer
        return SeedlingSerializer

    def perform_create(self, serializer):
        user = self.request.user
        if user.role != User.Role.ADOPTER:
            raise PermissionDenied('입양자만 묘목을 입양할 수 있습니다.')

        # 재배중인 묘목이 가장 적은(=가장 여유 있는) 재배자에게 자동 배정한다.
        grower = (
            User.objects.filter(role=User.Role.GROWER)
            .annotate(
                growing_count=Count(
                    'growing_seedlings',
                    filter=Q(growing_seedlings__status=Seedling.Status.GROWING),
                )
            )
            .order_by('growing_count', 'pk')
            .first()
        )
        if grower is None:
            raise ValidationError('현재 배정 가능한 재배자가 없습니다. 잠시 후 다시 시도해주세요.')

        serializer.save(adopter=user, grower=grower)


class SeedlingDetailView(RetrieveAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = SeedlingSerializer

    def get_queryset(self):
        user = self.request.user
        return Seedling.objects.filter(Q(adopter=user) | Q(grower=user))


class SeedlingCompleteView(APIView):
    """묘목 완성 신고. 담당 재배자만 가능하며 status를 completed로 변경한다."""

    permission_classes = [IsAuthenticated]

    def patch(self, request, pk):
        user = request.user
        seedling = get_object_or_404(Seedling, pk=pk)

        if user.role != User.Role.GROWER or seedling.grower_id != user.pk:
            raise PermissionDenied('본인이 담당하는 묘목만 완성 신고할 수 있습니다.')

        seedling.status = Seedling.Status.COMPLETED
        seedling.completed_at = timezone.now()
        seedling.save(update_fields=['status', 'completed_at'])

        send_notification_to_user(
            seedling.adopter,
            '묘목 완성!',
            '무화과 묘목이 완성됐어요. 수령 또는 기부를 선택해주세요.',
        )

        return Response(SeedlingSerializer(seedling).data)
