from django.contrib.auth import authenticate
from rest_framework import serializers

from .models import User


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = ('email', 'password', 'role')

    def validate_email(self, value):
        # 이메일 중복 체크
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError('이미 가입된 이메일입니다.')
        return value

    def create(self, validated_data):
        return User.objects.create_user(**validated_data)


class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True)

    def validate(self, attrs):
        user = authenticate(
            username=attrs['email'],
            password=attrs['password'],
        )
        if user is None:
            raise serializers.ValidationError('이메일 또는 비밀번호가 올바르지 않습니다.')
        attrs['user'] = user
        return attrs
