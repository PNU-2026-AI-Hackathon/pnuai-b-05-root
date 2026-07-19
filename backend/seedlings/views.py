from django.db.models import Q
from rest_framework.exceptions import PermissionDenied
from rest_framework.generics import ListCreateAPIView, RetrieveAPIView
from rest_framework.permissions import IsAuthenticated

from accounts.models import User

from .models import Seedling
from .serializers import SeedlingCreateSerializer, SeedlingSerializer


class SeedlingListCreateView(ListCreateAPIView):
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.role == User.Role.GROWER:
            return Seedling.objects.filter(grower=user)
        return Seedling.objects.filter(adopter=user)

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return SeedlingCreateSerializer
        return SeedlingSerializer

    def perform_create(self, serializer):
        user = self.request.user
        if user.role != User.Role.ADOPTER:
            raise PermissionDenied('입양자만 묘목을 입양할 수 있습니다.')
        serializer.save(adopter=user)


class SeedlingDetailView(RetrieveAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = SeedlingSerializer

    def get_queryset(self):
        user = self.request.user
        return Seedling.objects.filter(Q(adopter=user) | Q(grower=user))
