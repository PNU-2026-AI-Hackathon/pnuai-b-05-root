from rest_framework import serializers

from .models import Seedling


class SeedlingSerializer(serializers.ModelSerializer):
    # adopter는 FK id로만 내려가므로, 재배자 화면이 담당 묘목의 입양자 상태를 파악할 수
    # 있도록 파생 필드 2개를 함께 내려준다(diary의 growth_stage_label과 동일한
    # SerializerMethodField 패턴 — 선언하면 fields='__all__'에 자동 포함된다).
    # adopter_is_active가 False면 회원탈퇴(소프트 삭제)한 입양자이며, 그 묘목은 재배자
    # 화면에 그대로 남으므로(데이터·재배정 유지) "탈퇴한 계정" 배지로만 안내한다.
    adopter_is_active = serializers.SerializerMethodField()
    adopter_nickname = serializers.SerializerMethodField()

    class Meta:
        model = Seedling
        fields = '__all__'

    def get_adopter_is_active(self, obj):
        return obj.adopter.is_active

    def get_adopter_nickname(self, obj):
        # 닉네임 미설정(빈 문자열)은 growth_stage_label과 동일하게 None으로 내려준다.
        return obj.adopter.nickname or None


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


class SeedlingCompleteSerializer(serializers.Serializer):
    """`PATCH /api/seedlings/{id}/complete/` 요청 바디 검증용.

    `SeedlingPickupDonateSerializer`와 같은 `serializers.Serializer` 기반이다.
    `height_cm`은 완성 신고 시 필수(모델 필드는 소급 데이터 때문에 nullable이지만
    새 신고에서는 여기서 강제), `final_photo`는 선택이다 — Gemini 쿼터/카메라 접근
    실패로 완성 신고 자체가 막히면 안 되기 때문이다(diary가 photo를 선택으로 두는 것과 동일).
    30cm 미만이어도 막지 않는다(재배자 판단에 맡기고 프론트에서 경고만 표시) — min_value는
    음수/0 같은 명백한 오입력만 거른다.
    """

    height_cm = serializers.IntegerField(min_value=1, max_value=500)
    final_photo = serializers.ImageField(required=False, allow_null=True)


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
