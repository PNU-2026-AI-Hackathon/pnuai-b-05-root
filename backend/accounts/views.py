from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from .serializers import LoginSerializer, RegisterSerializer


class RegisterView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        return Response(
            {
                'message': '회원가입 성공',
                'email': user.email,
                'role': user.role,
            },
            status=status.HTTP_201_CREATED,
        )


class LoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.validated_data['user']
        refresh = RefreshToken.for_user(user)
        return Response(
            {
                'access': str(refresh.access_token),
                'refresh': str(refresh),
                'role': user.role,
            },
            status=status.HTTP_200_OK,
        )


class AccountDeleteView(APIView):
    """회원탈퇴. 본인 계정만 소프트 삭제(`is_active=False`)한다.

    하드 삭제 대신 소프트 삭제를 쓰는 이유: `Seedling`/`Diary` 등이 유저를 FK로
    참조하는데, 재배자가 탈퇴한다고 담당 묘목까지 연쇄 삭제되면 그 묘목을 보고 있는
    입양자 쪽 데이터(일지·성장 타임라인 등)까지 깨진다. `is_active=False`가 되면
    simplejwt가 기존 access 토큰까지 즉시 무효화하고(`JWTAuthentication.get_user()`가
    `is_active`를 확인함) `authenticate()`도 더 이상 성공하지 않아(Django
    `ModelBackend.user_can_authenticate()`가 `is_active`를 확인함) 재로그인도
    막힌다 — 둘 다 Django/simplejwt 기본 동작이라 이 뷰에서 따로 처리할 필요는 없다.
    """

    permission_classes = [IsAuthenticated]

    def delete(self, request):
        user = request.user
        user.is_active = False
        user.save(update_fields=['is_active'])
        return Response({'message': '회원탈퇴가 완료되었습니다.'})
