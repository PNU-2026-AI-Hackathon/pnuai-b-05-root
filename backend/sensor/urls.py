from django.urls import path

from .views import SensorAnomalyListView, SensorDataCreateView

app_name = 'sensor'

urlpatterns = [
    path('data/', SensorDataCreateView.as_view(), name='data-create'),
    path('anomaly/<int:seedling_id>/', SensorAnomalyListView.as_view(), name='anomaly-list'),
]
