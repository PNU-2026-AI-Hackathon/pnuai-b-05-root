from django.db.models import Q
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework.exceptions import PermissionDenied
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
        serializer.save(adopter=user)


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
