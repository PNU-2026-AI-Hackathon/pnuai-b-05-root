from rest_framework import serializers

from .models import Diary


class DiarySerializer(serializers.ModelSerializer):
    # growth_stage(코드값)는 모델 필드라 fields = '__all__'로 이미 내려가지만,
    # 프론트엔드가 한글 라벨을 직접 매핑하지 않아도 되도록 get_growth_stage_display()
    # 결과를 growth_stage_label로 함께 내려준다. 값이 없는 일지(과거 데이터,
    # 선택 안 한 경우)는 None을 반환한다.
    growth_stage_label = serializers.SerializerMethodField()

    class Meta:
        model = Diary
        fields = '__all__'
        read_only_fields = ('grower', 'created_at', 'yolo_status_tag', 'illustration')

    def get_growth_stage_label(self, obj):
        return obj.get_growth_stage_display() if obj.growth_stage else None


class DiaryCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Diary
        fields = ('id', 'seedling', 'content', 'photo', 'growth_stage')
