from django.shortcuts import get_object_or_404
from rest_framework.exceptions import PermissionDenied
from rest_framework.generics import CreateAPIView, ListAPIView
from rest_framework.permissions import IsAuthenticated

from accounts.models import User
from seedlings.models import Seedling

from .anomaly import build_diagnosis_text, detect_anomaly
from .models import SensorData
from .serializers import SensorDataCreateSerializer, SensorDataSerializer


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

        return SensorData.objects.filter(seedling=seedling, is_anomaly=True)
