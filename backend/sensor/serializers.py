from rest_framework import serializers

from .models import SensorData


class SensorDataSerializer(serializers.ModelSerializer):
    class Meta:
        model = SensorData
        fields = '__all__'
        read_only_fields = ('recorded_at', 'is_anomaly', 'gemini_diagnosis')


class SensorDataCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = SensorData
        fields = ('id', 'seedling', 'temperature', 'humidity', 'light', 'recorded_at', 'is_anomaly', 'gemini_diagnosis')
        # is_anomaly/gemini_diagnosis는 perform_create에서 판정 후 채워지는 값이라 입력 불필요.
        read_only_fields = ('id', 'recorded_at', 'is_anomaly', 'gemini_diagnosis')
