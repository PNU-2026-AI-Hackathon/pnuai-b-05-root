from rest_framework import serializers

from .models import Diary


class DiarySerializer(serializers.ModelSerializer):
    class Meta:
        model = Diary
        fields = '__all__'
        read_only_fields = ('grower', 'created_at', 'yolo_status_tag')


class DiaryCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Diary
        fields = ('id', 'seedling', 'content', 'photo')
