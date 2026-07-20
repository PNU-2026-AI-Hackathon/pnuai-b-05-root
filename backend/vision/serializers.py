from rest_framework import serializers

from .models import VisionAnalysis


class VisionAnalyzeSerializer(serializers.Serializer):
    image = serializers.ImageField()
    diary_id = serializers.IntegerField(required=False, allow_null=True)


class VisionAnalysisResultSerializer(serializers.ModelSerializer):
    class Meta:
        model = VisionAnalysis
        fields = ('result_tag', 'confidence', 'location_info', 'analyzed_at')
