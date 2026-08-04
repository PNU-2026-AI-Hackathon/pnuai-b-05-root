from rest_framework import serializers

from .models import Seedling


class SeedlingSerializer(serializers.ModelSerializer):
    class Meta:
        model = Seedling
        fields = '__all__'


class SeedlingPickupDonateSerializer(serializers.Serializer):
    """`PATCH /api/seedlings/{id}/pickup-donate/` 요청 바디 검증용.

    `pickup_or_donate`가 `donate`일 때만 `donate_type`을 필수로 받고,
    `pickup`일 때는 입력값과 무관하게 저장 시 `None`으로 정리한다(뷰에서 처리).
    """

    pickup_or_donate = serializers.ChoiceField(choices=Seedling.PickupOrDonate.choices)
    donate_type = serializers.ChoiceField(
        choices=Seedling.DonateType.choices, required=False, allow_null=True,
    )

    def validate(self, attrs):
        if attrs['pickup_or_donate'] == Seedling.PickupOrDonate.DONATE and not attrs.get('donate_type'):
            raise serializers.ValidationError(
                {'donate_type': '기부를 선택한 경우 기부 유형을 함께 보내야 합니다.'}
            )
        return attrs


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
