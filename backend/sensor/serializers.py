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
        fields = ('id', 'seedling', 'temperature', 'humidity', 'light')
