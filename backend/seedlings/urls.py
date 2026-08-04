from django.urls import path

from .views import (
    SeedlingCompleteView,
    SeedlingDetailView,
    SeedlingListCreateView,
    SeedlingPickupDonateView,
)

app_name = 'seedlings'

urlpatterns = [
    path('', SeedlingListCreateView.as_view(), name='list-create'),
    path('<int:pk>/', SeedlingDetailView.as_view(), name='detail'),
    path('<int:pk>/complete/', SeedlingCompleteView.as_view(), name='complete'),
    path('<int:pk>/pickup-donate/', SeedlingPickupDonateView.as_view(), name='pickup-donate'),
]
