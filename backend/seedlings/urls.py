from django.urls import path

from .views import SeedlingDetailView, SeedlingListCreateView

app_name = 'seedlings'

urlpatterns = [
    path('', SeedlingListCreateView.as_view(), name='list-create'),
    path('<int:pk>/', SeedlingDetailView.as_view(), name='detail'),
]
