from django.conf import settings
from django.core.files.base import ContentFile
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
# diary 앱의 사진 -> 일러스트 변환 함수를 그대로 재사용한다. gemini_illustration은 앱 모델을
# import하지 않아 순환참조가 없다(seedlings -> notifications.fcm 참조와 같은 수준의 앱 간 참조).
from diary.gemini_illustration import convert_to_illustration
from notifications.fcm import send_notification_to_user

from .models import Seedling
from .serializers import (
    SeedlingCompleteSerializer,
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
    """묘목 완성 신고. 담당 재배자만 가능하며 status를 completed로 변경한다.

    완성 신고 시 재배자가 입력한 최종 수고(`height_cm`, 필수)와 최종 사진(`final_photo`,
    선택)을 함께 받는다. 사진이 있으면 `DiaryCreateView.perform_create()`와 동일하게
    `convert_to_illustration()`으로 동화풍 일러스트 변환까지 시도한다(실패해도 완성 신고
    자체는 정상 처리 — 원본 사진만 저장).
    """

    permission_classes = [IsAuthenticated]

    def patch(self, request, pk):
        user = request.user
        seedling = get_object_or_404(Seedling, pk=pk)

        if user.role != User.Role.GROWER or seedling.grower_id != user.pk:
            raise PermissionDenied('본인이 담당하는 묘목만 완성 신고할 수 있습니다.')

        serializer = SeedlingCompleteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        height_cm = serializer.validated_data['height_cm']
        final_photo = serializer.validated_data.get('final_photo')

        seedling.status = Seedling.Status.COMPLETED
        seedling.completed_at = timezone.now()
        seedling.height_cm = height_cm
        update_fields = ['status', 'completed_at', 'height_cm']
        if final_photo:
            seedling.final_photo = final_photo
            update_fields.append('final_photo')
        seedling.save(update_fields=update_fields)

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

        # 최종 사진 -> 동화풍 일러스트 변환 (diary/views.py의 perform_create와 동일 패턴).
        # 변환은 알림 발송 뒤에 둬서 Gemini 지연이 입양자 알림까지 늦추지 않게 한다.
        if seedling.final_photo:
            illustration_bytes = convert_to_illustration(seedling.final_photo.path)
            if illustration_bytes:
                seedling.final_illustration.save(
                    f'seedling_{seedling.pk}_final_illustration.png',
                    ContentFile(illustration_bytes),
                    save=True,
                )

        # APIView는 generic 뷰와 달리 시리얼라이저 context를 자동으로 넘기지 않으므로,
        # final_photo/final_illustration URL이 절대경로로 나가도록 request를 직접 넣는다.
        return Response(
            SeedlingSerializer(seedling, context={'request': request}).data
        )


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
