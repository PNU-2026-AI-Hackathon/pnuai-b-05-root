from django.conf import settings
from django.core.mail import send_mail
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
from .serializers import (
    SeedlingCreateSerializer,
    SeedlingPickupDonateSerializer,
    SeedlingSerializer,
)


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

        try:
            nickname = seedling.adopter.nickname or '입양자'
            send_mail(
                subject=f'[Pig.Fig.] 무화과 #{seedling.pk}가 다 자랐어요 🎉',
                message=(
                    f'{nickname}님, 안녕하세요.\n\n'
                    f'정성껏 함께한 무화과 #{seedling.pk}가 드디어 완성되었어요! 🌱🍃\n\n'
                    '이제 앱에서 수령 또는 기부 중 하나를 선택해주세요.\n'
                    '완성된 묘목은 7일 내에 선택해주시면 좋아요.\n\n'
                    '감사합니다.\n'
                    'Pig.Fig. 드림 🐷🌱'
                ),
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[seedling.adopter.email],
                fail_silently=False,
            )
        except Exception as e:
            # SMTP 오류 등으로 이메일 발송이 실패해도 완성 처리 응답 자체는 그대로 성공시킨다.
            print(f'[Email] 완성 알림 발송 실패: seedling={seedling.pk} error={e}')

        return Response(SeedlingSerializer(seedling).data)


class SeedlingPickupDonateView(APIView):
    """완성된 묘목의 수령/기부 선택. 담당 입양자만 가능하며, 완성(completed) 상태에서만 허용한다."""

    permission_classes = [IsAuthenticated]

    def patch(self, request, pk):
        user = request.user
        seedling = get_object_or_404(Seedling, pk=pk)

        if user.role != User.Role.ADOPTER or seedling.adopter_id != user.pk:
            raise PermissionDenied('본인이 입양한 묘목만 수령/기부를 선택할 수 있습니다.')
        if seedling.status != Seedling.Status.COMPLETED:
            raise ValidationError('완성된 묘목만 수령/기부를 선택할 수 있습니다.')

        serializer = SeedlingPickupDonateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        pickup_or_donate = serializer.validated_data['pickup_or_donate']
        donate_type = (
            serializer.validated_data.get('donate_type')
            if pickup_or_donate == Seedling.PickupOrDonate.DONATE
            else None
        )

        changed = (
            seedling.pickup_or_donate != pickup_or_donate
            or seedling.donate_type != donate_type
        )
        seedling.pickup_or_donate = pickup_or_donate
        seedling.donate_type = donate_type
        seedling.save(update_fields=['pickup_or_donate', 'donate_type'])

        # 재제출로 값이 바뀌지 않았으면 재배자에게 같은 알림을 중복 발송하지 않는다.
        if changed and seedling.grower_id is not None:
            if pickup_or_donate == Seedling.PickupOrDonate.PICKUP:
                send_notification_to_user(
                    seedling.grower,
                    '수령 안내',
                    f'묘목 #{seedling.pk} 입양자가 직접 수령을 선택했어요. 방문 시 안내해주세요.',
                )
            else:
                donate_label = Seedling.DonateType(donate_type).label
                send_notification_to_user(
                    seedling.grower,
                    '기부 안내',
                    f'묘목 #{seedling.pk}가 "{donate_label}"로 기부하기로 결정됐어요.',
                )

        return Response(SeedlingSerializer(seedling).data)
