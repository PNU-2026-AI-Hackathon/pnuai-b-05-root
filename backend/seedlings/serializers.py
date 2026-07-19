from rest_framework import serializers

from .models import Seedling


class SeedlingSerializer(serializers.ModelSerializer):
    class Meta:
        model = Seedling
        fields = '__all__'


class SeedlingCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Seedling
        fields = (
            'id',
            'adopter',
            'grower',
            'status',
            'started_at',
            'completed_at',
            'pickup_or_donate',
            'donate_type',
        )
        # adopter는 요청 사용자로 자동 할당되므로 입력 불필요
        read_only_fields = ('id', 'adopter', 'grower', 'status', 'started_at', 'completed_at')
