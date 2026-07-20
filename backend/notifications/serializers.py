from rest_framework import serializers


class FCMTokenRegisterSerializer(serializers.Serializer):
    token = serializers.CharField(max_length=255)
