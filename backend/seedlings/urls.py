from django.urls import path

from .views import SeedlingCompleteView, SeedlingDetailView, SeedlingListCreateView

app_name = 'seedlings'

urlpatterns = [
    path('', SeedlingListCreateView.as_view(), name='list-create'),
    path('<int:pk>/', SeedlingDetailView.as_view(), name='detail'),
    path('<int:pk>/complete/', SeedlingCompleteView.as_view(), name='complete'),
]
