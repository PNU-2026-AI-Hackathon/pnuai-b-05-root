from rest_framework import serializers


class ChatbotAskSerializer(serializers.Serializer):
    question = serializers.CharField()
