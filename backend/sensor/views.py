from datetime import timedelta

from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework.exceptions import PermissionDenied
from rest_framework.generics import CreateAPIView, ListAPIView
from rest_framework.permissions import IsAuthenticated

from accounts.models import User
from seedlings.models import Seedling

from .anomaly import build_diagnosis_text, detect_anomaly
from .models import SensorData
from .serializers import SensorDataCreateSerializer, SensorDataSerializer

# ?days= 로 지정할 수 있는 조회 기간 상한(약 10년). 이보다 크거나 1 미만이면
# 잘못된 값으로 보고 필터를 걸지 않는다(timedelta OverflowError 방지 겸용).
MAX_ANOMALY_DAYS = 3650


def _parse_days(raw):
    """?days= 쿼리 파라미터를 파싱한다.

    값이 없거나(전체 기간 선택) 유효하지 않으면(음수·0·문자열·범위 초과) None을 반환해
    호출부가 기간 필터를 걸지 않도록 한다 — 프론트는 7/30/없음만 보내는 닫힌 구조라
    잘못된 값에 400을 내기보다 이 프로젝트 전반의 "게이트 체크 → 폴백" 기조를 따른다.
    """
    if raw is None:
        return None
    try:
        days = int(raw)
    except (TypeError, ValueError):
        return None
    return days if 1 <= days <= MAX_ANOMALY_DAYS else None


class SensorDataCreateView(CreateAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = SensorDataCreateSerializer

    def perform_create(self, serializer):
        user = self.request.user
        if user.role != User.Role.GROWER:
            raise PermissionDenied('재배자만 센서 데이터를 등록할 수 있습니다.')

        seedling = serializer.validated_data['seedling']
        if seedling.grower_id != user.pk:
            raise PermissionDenied('본인이 담당하는 묘목에만 센서 데이터를 등록할 수 있습니다.')

        temperature = serializer.validated_data['temperature']
        humidity = serializer.validated_data['humidity']
        light = serializer.validated_data['light']

        is_anomaly, anomaly_fields = detect_anomaly(seedling, temperature, humidity, light)
        gemini_diagnosis = (
            build_diagnosis_text(anomaly_fields, temperature, humidity, light) if is_anomaly else None
        )

        serializer.save(is_anomaly=is_anomaly, gemini_diagnosis=gemini_diagnosis)


class SensorAnomalyListView(ListAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = SensorDataSerializer

    def get_queryset(self):
        user = self.request.user
        seedling = get_object_or_404(Seedling, pk=self.kwargs['seedling_id'])

        if user.pk not in (seedling.adopter_id, seedling.grower_id):
            raise PermissionDenied('해당 묘목의 입양자 또는 재배자만 조회할 수 있습니다.')

        queryset = SensorData.objects.filter(seedling=seedling, is_anomaly=True)

        days = _parse_days(self.request.query_params.get('days'))
        if days is not None:
            queryset = queryset.filter(recorded_at__gte=timezone.now() - timedelta(days=days))

        return queryset.order_by('-recorded_at')
